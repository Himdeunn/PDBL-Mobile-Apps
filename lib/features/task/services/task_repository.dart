import 'dart:async';
import 'package:isar_community/isar.dart';
import 'package:intl/intl.dart';
import '../../../core/storage/local_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/utils/notification_helper.dart';

import '../models/task_local.dart';

class TaskRepository {
  final ApiClient _api = ApiClient();
  Isar get _isar => LocalDatabase.isar;

  // Track pending syncs to avoid race conditions during background refreshes
  static final Map<int, int> _pendingSyncsCount = {};
  static final Map<int, Timer> _debounceTimers = {};

  Future<List<TaskLocal>> getAllTasks(String userEmail) async {
    return await _isar.taskLocals
        .filter()
        .userEmailEqualTo(userEmail)
        .findAll();
  }

  Future<List<TaskLocal>> getTasksForDate(
    DateTime date,
    String userEmail,
  ) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return await _isar.taskLocals
        .filter()
        .userEmailEqualTo(userEmail)
        .and()
        .dueDateBetween(
          startOfDay,
          endOfDay,
          includeLower: true,
          includeUpper: false,
        )
        .findAll();
  }

  Future<List<TaskLocal>> getTasksByPriority(
    String priority,
    String userEmail,
  ) async {
    return await _isar.taskLocals
        .filter()
        .userEmailEqualTo(userEmail)
        .and()
        .priorityEqualTo(priority, caseSensitive: false)
        .findAll();
  }

  Future<void> createTask(TaskLocal task, String userEmail) async {
    task.userEmail = userEmail;
    // 1. Save locally first (offline first)
    await _isar.writeTxn(() async {
      task.isSynced = false;
      await _isar.taskLocals.put(task);
    });

    // 2. Attempt sync immediately if possible
    await _syncSingleTask(task);

    // 3. Schedule local reminders if deadline exists
    if (task.dueDate != null) {
      DateTime finalDeadline = task.dueDate!;
      if (task.dueTime != null) {
        try {
          final timeParts = task.dueTime!.split(':');
          finalDeadline = DateTime(
            task.dueDate!.year,
            task.dueDate!.month,
            task.dueDate!.day,
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
            timeParts.length > 2 ? int.parse(timeParts[2]) : 0,
          );
        } catch (_) {}
      }
      await NotificationHelper.scheduleDeadlineReminders(
        taskId: task.id,
        title: task.title,
        description: task.description,
        priority: task.priority,
        deadline: finalDeadline,
      );
    }
    // WidgetService.fullSync();
  }

  Future<void> createTeamTask(TaskLocal task, String userEmail, List<String> assignedEmails) async {
    task.userEmail = userEmail;
    task.assignedEmails = assignedEmails.join(',');
    // 1. Save locally first (offline first)
    await _isar.writeTxn(() async {
      task.isSynced = false;
      await _isar.taskLocals.put(task);
    });

    // 2. Attempt sync immediately if possible
    await _syncSingleTask(task);

    // 3. Schedule local reminders if deadline exists
    if (task.dueDate != null) {
      DateTime finalDeadline = task.dueDate!;
      if (task.dueTime != null) {
        try {
          final timeParts = task.dueTime!.split(':');
          finalDeadline = DateTime(
            task.dueDate!.year,
            task.dueDate!.month,
            task.dueDate!.day,
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
            timeParts.length > 2 ? int.parse(timeParts[2]) : 0,
          );
        } catch (_) {}
      }
      await NotificationHelper.scheduleDeadlineReminders(
        taskId: task.id,
        title: task.title,
        description: task.description,
        priority: task.priority,
        isTeam: task.teamId != null,
        deadline: finalDeadline,
      );
    }
    // WidgetService.fullSync();
  }

  Future<void> updateTask(TaskLocal task) async {
    await _isar.writeTxn(() async {
      task.isSynced = false;
      task.lastLocalUpdate = DateTime.now().millisecondsSinceEpoch;
      await _isar.taskLocals.put(task);
    });

    // Debounce sync to avoid spamming the server and reduce race conditions
    _debounceTimers[task.id]?.cancel();
    _debounceTimers[task.id] = Timer(const Duration(milliseconds: 500), () {
      _syncSingleTask(task);
      _debounceTimers.remove(task.id);

      // Re-schedule reminders in case deadline changed
      if (task.dueDate != null) {
        DateTime finalDeadline = task.dueDate!;
        if (task.dueTime != null) {
          try {
            final timeParts = task.dueTime!.split(':');
            finalDeadline = DateTime(
              task.dueDate!.year,
              task.dueDate!.month,
              task.dueDate!.day,
              int.parse(timeParts[0]),
              int.parse(timeParts[1]),
              timeParts.length > 2 ? int.parse(timeParts[2]) : 0,
            );
          } catch (_) {}
        }
        NotificationHelper.scheduleDeadlineReminders(
          taskId: task.id,
          title: task.title,
          description: task.description,
          priority: task.priority,
          isTeam: task.teamId != null,
          deadline: finalDeadline,
        );
      } else {
        NotificationHelper.cancelTaskReminders(task.id);
      }
    });
    // WidgetService.fullSync();
  }

  /// Specialized method to toggle completion status.
  /// For team tasks, it hits the individual /toggle-member endpoint.
  /// For personal tasks, it uses the standard update/sync flow.
  Future<void> toggleTaskStatus(TaskLocal task, String userEmail) async {
    // 1. Toggle locally first for instant UI feedback
    bool newStatus = !task.isCompleted;
    await _isar.writeTxn(() async {
      task.isCompleted = newStatus;
      task.isSynced = false;
      task.lastLocalUpdate = DateTime.now().millisecondsSinceEpoch;
      await _isar.taskLocals.put(task);
    });

    // 2. Perform server sync
    if (task.teamId != null && task.apiId != null) {
      // Team task: use specialized toggle endpoint
      try {
        final response = await _api.post('todos/${task.apiId}/toggle-member');
        if (response.data['status'] == 'success' || response.data['message'] != null) {
          final todoData = response.data['todo'];
          if (todoData != null) {
            await _isar.writeTxn(() async {
              // Update local state with latest from server (e.g. global is_completed)
              final List<dynamic> completedBy = todoData['completed_by'] ?? [];
              task.isCompleted = completedBy.any((e) => 
                e.toString().toLowerCase().trim() == userEmail.toLowerCase().trim()
              );
              task.isSynced = true;
              await _isar.taskLocals.put(task);
            });
          }
        }
      } catch (e) {
        // Fallback or silent failure
      }
    } else {
      // Personal task or unsynced task: use standard sync
      await _syncSingleTask(task);
    }
  }

  Future<void> deleteTask(TaskLocal task) async {
    // Cancel any pending syncs for this task
    _debounceTimers[task.id]?.cancel();
    _debounceTimers.remove(task.id);
    if (task.userEmail == 'guest' || task.apiId == null) {
      await _isar.writeTxn(() async {
        await _isar.taskLocals.delete(task.id);
      });
      await NotificationHelper.cancelTaskReminders(task.id);
      return;
    }

    try {
      await _api.dio.delete('todos/${task.apiId}');
    } catch (_) {
      // Even if API fails, we delete locally for now.
      // A more robust system would queue for deletion.
    }
    await _isar.writeTxn(() async {
      await _isar.taskLocals.delete(task.id);
    });
    
    // Cancel any scheduled local notifications
    await NotificationHelper.cancelTaskReminders(task.id);
    // WidgetService.fullSync();
  }

  Future<void> fetchTasksFromServer(String userEmail) async {
    // Enable fetching for both registered users and guests (via device_id)
    
    int currentPage = 1;
    bool hasNextPage = true;

    while (hasNextPage) {
      try {
        final response = await _api.get('todos', queryParameters: {
          'page': currentPage,
          'assigned_only': 1,
        });
        final dynamic rawData = response.data;

        if (rawData is! Map || rawData['status'] != 'success') {
          hasNextPage = false;
          break;
        }

        final List<dynamic> todos = (rawData['todos'] is List) ? rawData['todos'] : [];
        final pagination = rawData['pagination'];

        if (pagination is Map) {
          final int currentPageVal = (pagination['current_page'] as num?)?.toInt() ?? currentPage;
          final int lastPageVal = (pagination['last_page'] as num?)?.toInt() ?? currentPage;
          hasNextPage = currentPageVal < lastPageVal;
          if (hasNextPage) currentPage++;
        } else {
          hasNextPage = false;
        }

        if (todos.isEmpty) {
            hasNextPage = false;
            break;
        }

        await _isar.writeTxn(() async {
          for (var todo in todos) {
            final int apiId = todo['id'];
            final existing = await _isar.taskLocals.filter().apiIdEqualTo(apiId).findFirst();

            final task = existing ?? TaskLocal();

            // CRITICAL: Prevent race conditions with pending local changes
            final isPending = (_pendingSyncsCount[task.id] ?? 0) > 0;
            if (existing != null && (!existing.isSynced || isPending)) {
              continue;
            }

            task.apiId = apiId;
            task.userEmail = userEmail;
            task.title = todo['judul'] ?? 'Untitled';
            task.description = todo['deskripsi'];
            task.priority = todo['priority'] ?? 'medium';
            
            // Map individual completion for team tasks
            if (todo['team_id'] != null && todo['completed_by'] != null) {
              final List<dynamic> completedBy = todo['completed_by'] as List;
              task.isCompleted = completedBy.any((e) => 
                e.toString().toLowerCase().trim() == userEmail.toLowerCase().trim()
              );
            } else {
              task.isCompleted = todo['is_completed'] ?? false;
            }
            
            task.isSynced = true;
            task.teamId = todo['team_id'];

            if (todo['assigned_emails'] != null && todo['assigned_emails'] is List) {
              task.assignedEmails = (todo['assigned_emails'] as List).join(',');
            }

            if (todo['deadline'] != null) {
              try {
                final DateTime dt = DateTime.parse(todo['deadline']);
                task.dueDate = DateTime(dt.year, dt.month, dt.day);
                task.dueTime = DateFormat('HH:mm:ss').format(dt);
              } catch (_) {}
            }

            // Batched put inside transaction
            await _isar.taskLocals.put(task);

            // Schedule reminders
            if (task.dueDate != null) {
              DateTime finalDeadline = task.dueDate!;
              if (task.dueTime != null) {
                try {
                  final timeParts = task.dueTime!.split(':');
                  finalDeadline = DateTime(
                    task.dueDate!.year,
                    task.dueDate!.month,
                    task.dueDate!.day,
                    int.parse(timeParts[0]),
                    int.parse(timeParts[1]),
                    timeParts.length > 2 ? int.parse(timeParts[2]) : 0,
                  );
                } catch (_) {}
              }
              NotificationHelper.scheduleDeadlineReminders(
                taskId: task.id,
                title: task.title,
                description: task.description,
                priority: task.priority,
                isTeam: task.teamId != null,
                deadline: finalDeadline,
              );
            }
          }
        });

      } catch (e) {
        // Stop on error to prevent infinite loops
        hasNextPage = false;
      }
    }
  }

  Future<void> _syncSingleTask(TaskLocal task) async {
    // Enable syncing for both registered users and guests (via device_id)
    _pendingSyncsCount[task.id] = (_pendingSyncsCount[task.id] ?? 0) + 1;
    try {
      final payload = {
        'judul': task.title,
        if (task.description != null) 'deskripsi': task.description,
        if (task.dueDate != null)
          'deadline':
              '${DateFormat('yyyy-MM-dd').format(task.dueDate!)} ${task.dueTime ?? '23:59:00'}',
        'priority': task.priority,
        'is_completed': task.isCompleted,
        'created_at': DateTime.now().toIso8601String(),
        'device_id': await SecureStorage.getDeviceId(),
        if (task.teamId != null) 'team_id': task.teamId,
        if (task.assignedEmails != null && task.assignedEmails!.isNotEmpty)
          'assigned_emails': task.assignedEmails!.split(','),
      };

      if (task.apiId == null) {
        // Create (POST)
        final response = await _api.post('todos', data: payload);
        final data = response.data['todo'];

        await _isar.writeTxn(() async {
          task.apiId = data['id'];
          task.isSynced = true;
          await _isar.taskLocals.put(task);
        });
      } else {
        // Update (PUT)
        await _api.dio.put('todos/${task.apiId}', data: payload);

        await _isar.writeTxn(() async {
          // RE-FETCH: Check if the task was modified locally while the sync was in progress
          final current = await _isar.taskLocals.get(task.id);
          if (current != null &&
              current.lastLocalUpdate == task.lastLocalUpdate) {
            task.isSynced = true;
            await _isar.taskLocals.put(task);
          }
        });
      }
    } catch (e) {
      // Silently fail, could be network or session issues
    } finally {
      final count = (_pendingSyncsCount[task.id] ?? 1) - 1;
      if (count <= 0) {
        _pendingSyncsCount.remove(task.id);
      } else {
        _pendingSyncsCount[task.id] = count;
      }
    }
  }

  // Reactive stream for tasks
  Stream<List<TaskLocal>> watchTasksForDate(DateTime date, String userEmail) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _isar.taskLocals
        .filter()
        .userEmailEqualTo(userEmail)
        .and()
        .dueDateBetween(
          startOfDay,
          endOfDay,
          includeLower: true,
          includeUpper: false,
        )
        .watch(fireImmediately: true);
  }

  Stream<List<TaskLocal>> watchAllTasks(String userEmail) {
    return _isar.taskLocals
        .filter()
        .userEmailEqualTo(userEmail)
        .watch(fireImmediately: true);
  }

  // Migrate guest tasks to user email
  Future<void> migrateGuestTasksToUser(String newEmail) async {
    final guestTasks = await _isar.taskLocals
        .filter()
        .userEmailEqualTo('guest')
        .findAll();

    if (guestTasks.isEmpty) return;

    await _isar.writeTxn(() async {
      for (var task in guestTasks) {
        task.userEmail = newEmail;
        task.apiId = null; // Ensure they are created as new records for the real user
        task.isSynced = false; // Mark for re-sync with new user email/token
        task.lastLocalUpdate = DateTime.now().millisecondsSinceEpoch;
        await _isar.taskLocals.put(task);
      }
    });

    // Use bulk sync instead of sequential sync for performance if upgrading from guest
    // Gather all newly assigned tasks that need to be pushed to the server
    final tasksToSync = await _isar.taskLocals
        .filter()
        .userEmailEqualTo(newEmail)
        .apiIdIsNull()
        .findAll();

    if (tasksToSync.isNotEmpty) {
      await syncTasksInBulk(tasksToSync);
    }
  }

  // Sync a list of tasks in a single request (Bulk Sync)
  Future<void> syncTasksInBulk(List<TaskLocal> tasks) async {
    if (tasks.isEmpty) return;

    try {
      final List<Map<String, dynamic>> payload = tasks.map((task) {
        return {
          'local_id': task.id,
          'judul': task.title,
          'deskripsi': task.description,
          'is_completed': task.isCompleted,
          'deadline': task.dueDate != null 
              ? '${DateFormat('yyyy-MM-dd').format(task.dueDate!)} ${task.dueTime ?? '23:59:00'}'
              : null,
          'priority': task.priority,
          'team_id': task.teamId,
          if (task.assignedEmails != null && task.assignedEmails!.isNotEmpty)
            'assigned_emails': task.assignedEmails!.split(','),
        };
      }).toList();

      final response = await _api.post('todos/bulk', data: {'tasks': payload});
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        final List<dynamic> results = response.data['results'];
        
        await _isar.writeTxn(() async {
          for (var result in results) {
            final int localId = result['local_id'];
            final int apiId = result['api_id'];
            
            final task = await _isar.taskLocals.get(localId);
            if (task != null) {
              task.apiId = apiId;
              task.isSynced = true;
              await _isar.taskLocals.put(task);
            }
          }
        });
      }
    } catch (e) {
      // In case of bulk failure, let them be picked up by standard syncAllUnsyncedTasks
      // which will retry one by one later.
    }
  }

  // Called to push all unsynced tasks to the backend
  Future<void> syncAllUnsyncedTasks() async {
    final unsynced = await _isar.taskLocals
        .filter()
        .isSyncedEqualTo(false)
        .findAll();

    // Process one by one, not multiple in same time
    for (var task in unsynced) {
      await _syncSingleTask(task);
    }
  }

  // Re-schedule notifications for all uncompleted tasks for the current user
  Future<void> rescheduleAllVisibleTasks(String userEmail) async {
    final tasks = await _isar.taskLocals
        .filter()
        .userEmailEqualTo(userEmail)
        .and()
        .isCompletedEqualTo(false)
        .findAll();

    for (var task in tasks) {
      if (task.dueDate != null) {
        DateTime finalDeadline = task.dueDate!;
        if (task.dueTime != null) {
          try {
            final timeParts = task.dueTime!.split(':');
            finalDeadline = DateTime(
              task.dueDate!.year,
              task.dueDate!.month,
              task.dueDate!.day,
              int.parse(timeParts[0]),
              int.parse(timeParts[1]),
              timeParts.length > 2 ? int.parse(timeParts[2]) : 0,
            );
          } catch (_) {}
        }
        await NotificationHelper.scheduleDeadlineReminders(
          taskId: task.id,
          title: task.title,
          description: task.description,
          priority: task.priority,
          isTeam: task.teamId != null,
          deadline: finalDeadline,
        );
      }
    }
  }
}
