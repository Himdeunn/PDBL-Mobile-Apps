import 'dart:async';
import 'package:isar_community/isar.dart';
import 'package:intl/intl.dart';
import '../../../core/storage/local_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/utils/notification_helper.dart';
import '../../../features/profile/services/global_reminder_scheduler.dart';
import 'widget_sync_service.dart';

import '../models/task_local.dart';

class TaskRepository {
  final ApiClient _api = ApiClient();
  Isar get _isar => LocalDatabase.isar;

  // Track pending syncs to avoid race conditions during background refreshes
  static final Map<int, int> _pendingSyncsCount = {};
  static final Map<int, Timer> _debounceTimers = {};
  // Debounce timers specifically for team task toggle (prevent rapid-click spam to server)
  static final Map<int, Timer> _toggleDebounceTimers = {};
  // Track the LAST intended toggle state while debouncing, so only 1 request fires
  static final Map<int, bool> _pendingToggleTarget = {};

  // Prevent redundant server fetches during a session (persists across instances)
  static DateTime? _lastServerFetch;
  static const _fetchCooldown = Duration(minutes: 2);

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
        .teamIdIsNull()
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
      await GlobalReminderScheduler.scheduleBeforeDeadlineForTask(
        taskId: task.id,
        taskTitle: task.title,
        taskDescription: task.description,
        priority: task.priority,
        deadline: finalDeadline,
          isTeam: false,
      );
    }
    
    // Trigger Widget Sync
    final allTasks = await _isar.taskLocals.where().findAll();
    await WidgetSyncService.syncFocusTodayWidget(allTasks);
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
      await GlobalReminderScheduler.scheduleBeforeDeadlineForTask(
        taskId: task.id,
        taskTitle: task.title,
        taskDescription: task.description,
        priority: task.priority,
        deadline: finalDeadline,
          isTeam: task.teamId != null,
      );
    }
    
    // Trigger Widget Sync
    final allTasks = await _isar.taskLocals.where().findAll();
    await WidgetSyncService.syncFocusTodayWidget(allTasks);
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
        GlobalReminderScheduler.scheduleBeforeDeadlineForTask(
          taskId: task.id,
          taskTitle: task.title,
          taskDescription: task.description,
          priority: task.priority,
          deadline: finalDeadline,
          isTeam: task.teamId != null,
        );
      } else {
        NotificationHelper.cancelTaskReminders(task.id);
        GlobalReminderScheduler.cancelBeforeDeadlineForTask(task.id);
      }
      
      // Trigger Widget Sync
      _isar.taskLocals.where().findAll().then((allTasks) {
        WidgetSyncService.syncFocusTodayWidget(allTasks);
      });
    });
  }

  /// Toggle completion status for a task.
  /// - Personal task: flip immediately, sync with debounce.
  /// - Team task: debounce rapid taps (800ms), then send ONE request to server.
  ///   Optimistic UI is applied immediately, but corrected from server truth after sync.
  Future<void> toggleTaskStatus(TaskLocal task, String userEmail) async {
    if (task.teamId != null && task.apiId != null) {
      // ── TEAM TASK ──────────────────────────────────────────────────────────
      // Determine what the new intended state should be.
      // If the user is tapping rapidly, we track the LAST intended state
      // and only fire ONE request to server after they stop tapping.
      final taskId = task.id;
      final currentTarget = _pendingToggleTarget[taskId];

      // Each tap flips the intended target:
      // If no pending target yet → flip from current DB state
      // If already have a pending target → flip that target
      final bool newTarget = currentTarget != null ? !currentTarget : !task.isCompleted;
      _pendingToggleTarget[taskId] = newTarget;

      // 1. Optimistic local update for instant UI feedback
      await _isar.writeTxn(() async {
        final fresh = await _isar.taskLocals.get(taskId);
        if (fresh != null) {
          fresh.isCompleted = newTarget;
          fresh.isSynced = false;
          await _isar.taskLocals.put(fresh);
        }
      });

      // 2. Cancel any previous pending server call — debounce 800ms
      _toggleDebounceTimers[taskId]?.cancel();
      _toggleDebounceTimers[taskId] = Timer(const Duration(milliseconds: 800), () async {
        _toggleDebounceTimers.remove(taskId);
        final intendedState = _pendingToggleTarget.remove(taskId);
        if (intendedState == null) return;

        try {
          final response = await _api.post('todos/${task.apiId}/toggle-member');
          final todoData = response.data['todo'];
          if (todoData != null) {
            // Server is always the source of truth.
            // isCompleted for THIS user = email ada di completedBy ATAU task sudah fully complete
            // Ini memastikan kalau owner check (is_completed=true), semua member ikut ter-checked
            final List<dynamic> completedByRaw = todoData['completed_by'] ?? [];
            final completedByStr = completedByRaw
                .map((e) => e.toString().toLowerCase().trim())
                .join(',');
            final assignedEmailsRaw = todoData['assigned_emails'];
            final int totalAssigned = assignedEmailsRaw is List ? assignedEmailsRaw.length : 0;
            final bool isFullyCompleted = todoData['is_completed'] == true;
            final bool myEmailChecked = completedByRaw.any(
              (e) => e.toString().toLowerCase().trim() == userEmail.toLowerCase().trim(),
            );
            // If task is fully completed (e.g. owner checked), everyone sees it as checked
            final bool newIsCompleted = isFullyCompleted || myEmailChecked;

            await _isar.writeTxn(() async {
              final fresh = await _isar.taskLocals.get(taskId);
              if (fresh != null) {
                fresh.isCompleted = newIsCompleted;
                fresh.leaderChecked = isFullyCompleted && !myEmailChecked;
                fresh.completedBy = completedByStr.isEmpty ? null : completedByStr;
                fresh.totalAssigned = totalAssigned;
                fresh.isSynced = true;
                await _isar.taskLocals.put(fresh);
              }
            });
            
            // Trigger Widget Sync after team status update
            final allTasks = await _isar.taskLocals.where().findAll();
            await WidgetSyncService.syncFocusTodayWidget(allTasks);
          }
        } catch (_) {
          // Server call failed: revert optimistic update to previous known state
          await _isar.writeTxn(() async {
            final fresh = await _isar.taskLocals.get(taskId);
            if (fresh != null) {
              fresh.isCompleted = !intendedState; // revert
              fresh.isSynced = false;
              await _isar.taskLocals.put(fresh);
            }
          });
        }
      });
    } else {
      // ── PERSONAL TASK ──────────────────────────────────────────────────────
      // For personal tasks: flip immediately, debounce sync to avoid server spam
      await _isar.writeTxn(() async {
        task.isCompleted = !task.isCompleted;
        task.isSynced = false;
        task.lastLocalUpdate = DateTime.now().millisecondsSinceEpoch;
        await _isar.taskLocals.put(task);
      });
      await _syncSingleTask(task);
      
      // Trigger Widget Sync
      final allTasks = await _isar.taskLocals.where().findAll();
      await WidgetSyncService.syncFocusTodayWidget(allTasks);
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
      await GlobalReminderScheduler.cancelBeforeDeadlineForTask(task.id);
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
    
    // Cancel any scheduled local notifications (deadline + global reminders)
    await NotificationHelper.cancelTaskReminders(task.id);
    await GlobalReminderScheduler.cancelBeforeDeadlineForTask(task.id);
    
    // Trigger Widget Sync
    final allTasks = await _isar.taskLocals.where().findAll();
    await WidgetSyncService.syncFocusTodayWidget(allTasks);
  }

  Future<void> fetchTasksFromServer(String userEmail, {bool force = false}) async {
    final now = DateTime.now();
    if (!force && _lastServerFetch != null && now.difference(_lastServerFetch!) < _fetchCooldown) {
      return;
    }
    _lastServerFetch = now;

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
              final bool isFullyCompleted = todo['is_completed'] == true;
              final bool myEmailChecked = completedBy.any((e) =>
                e.toString().toLowerCase().trim() == userEmail.toLowerCase().trim()
              );
              // If owner checked (is_completed=true), semua member ikut ter-checked di lokal
              task.isCompleted = isFullyCompleted || myEmailChecked;
              // leader checked = fully completed but current user didn't check themselves
              task.leaderChecked = isFullyCompleted && !myEmailChecked;
              // Save completedBy and totalAssigned so progress selalu visible
              task.completedBy = completedBy
                  .map((e) => e.toString().toLowerCase().trim())
                  .join(',');
              final assignedEmailsRaw = todo['assigned_emails'];
              task.totalAssigned = assignedEmailsRaw is List ? assignedEmailsRaw.length : 0;
            } else {
              task.isCompleted = todo['is_completed'] ?? false;
              task.leaderChecked = false;
            }

            task.isSynced = true;
            task.teamId = todo['team_id'];

            if (todo['assigned_emails'] != null && todo['assigned_emails'] is List) {
              final List<dynamic> assignedList = todo['assigned_emails'] as List;
              task.assignedEmails = assignedList.join(',');
              // Build display names: prefer name from user object if available,
              // otherwise extract the part before '@' from the email
              final assignedNames = assignedList.map((e) {
                final emailStr = e.toString().trim();
                // email prefix as fallback username
                return emailStr.contains('@') ? emailStr.split('@').first : emailStr;
              }).toList();
              task.assignedUsernames = assignedNames.join(',');
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
              GlobalReminderScheduler.scheduleBeforeDeadlineForTask(
                taskId: task.id,
                taskTitle: task.title,
                taskDescription: task.description,
                priority: task.priority,
                deadline: finalDeadline,
                isTeam: task.teamId != null,
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
      final isNewTask = task.apiId == null;

      final validPriorities = ['high', 'medium', 'low'];
      final safePriority = validPriorities.contains(task.priority.toLowerCase())
          ? task.priority.toLowerCase()
          : 'medium';

      final assignedList = task.assignedEmails
          ?.split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final payload = {
        'judul': (task.title.isNotEmpty) ? task.title : 'Untitled',
        if (task.description != null && task.description!.isNotEmpty)
          'deskripsi': task.description,
        if (task.dueDate != null)
          'deadline':
              '${DateFormat('yyyy-MM-dd').format(task.dueDate!)} ${task.dueTime ?? '23:59:00'}',
        'priority': safePriority,
        'is_completed': task.isCompleted,
        'device_id': await SecureStorage.getDeviceId(),
        // team_id only sent on creation — immutable after that, avoids exists:teams,id 422 on PUT
        if (isNewTask && task.teamId != null) 'team_id': task.teamId,
        if (assignedList != null && assignedList.isNotEmpty)
          'assigned_emails': assignedList,
      };

      if (isNewTask) {
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

  // Reactive stream for tasks — includes both personal and team tasks
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

    // Separate tasks that were already synced (have apiId) from truly local ones
    final List<TaskLocal> unsynced = [];

    await _isar.writeTxn(() async {
      for (var task in guestTasks) {
        task.userEmail = newEmail;
        task.lastLocalUpdate = DateTime.now().millisecondsSinceEpoch;

        if (task.apiId != null) {
          // Already synced to server — just reassign email, keep apiId to avoid duplicates
          task.isSynced = true;
        } else {
          // Never synced — mark for creation on server
          task.isSynced = false;
          unsynced.add(task);
        }

        await _isar.taskLocals.put(task);
      }
    });

    if (unsynced.isNotEmpty) {
      await syncTasksInBulk(unsynced);
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
        await GlobalReminderScheduler.scheduleBeforeDeadlineForTask(
          taskId: task.id,
          taskTitle: task.title,
          taskDescription: task.description,
          priority: task.priority,
          deadline: finalDeadline,
          isTeam: task.teamId != null,
        );
      }
    }
  }
}
