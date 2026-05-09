import 'package:isar_community/isar.dart';

part 'notification_local.g.dart';

@collection
class NotificationLocal {
  Id id = Isar.autoIncrement;

  int? apiId; // ID from backend if synced

  late String message;

  String type = 'general'; // 'invite', 'kick', 'ban', 'general'

  bool isRead = false;

  bool isSynced = false; // false = belum di-push ke server

  bool isDeletedLocally = false; // pending deletion sync

  late DateTime createdAt;

  String? userEmail; // scope ke user yang login
}
