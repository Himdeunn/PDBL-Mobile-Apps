import 'package:isar/isar.dart';

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
}
