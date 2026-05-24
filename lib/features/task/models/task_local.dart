import 'package:isar_community/isar.dart';

part 'task_local.g.dart';

@collection
class TaskLocal {
  Id id = Isar.autoIncrement;

  int? apiId; // ID from backend if synced

  late String title;

  String? description;

  DateTime? dueDate;

  String? dueTime;

  late String priority; // 'high', 'medium', 'low'

  bool isCompleted = false;

  bool isSynced = false;

  int lastLocalUpdate = 0; // Timestamp for version-aware sync

  String? userEmail; // To scope tasks to the logged-in user

  int? teamId; // ID of the team if this is a group task

  String? assignedEmails; // Comma-separated emails for team task assignment

  // Team task progress — synced from server, NOT used for personal tasks
  String? completedBy; // Comma-separated emails who have checked this task
  int totalAssigned = 0; // Total number of assigned members

  // Not persisted — computed at display time from assignedEmails (email-prefix fallback)
  @ignore
  String? assignedUsernames;

  // Not persisted — computed at display time from isCompleted + completedBy
  @ignore
  bool leaderChecked = false;
}
