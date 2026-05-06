import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/task/models/task_local.dart';
import '../../features/profile/models/notification_local.dart';

class LocalDatabase {
  static late Isar isar;
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized && isar.isOpen) return;

    final dir = await getApplicationDocumentsDirectory();
    final existing = Isar.getInstance();
    if (existing != null && existing.isOpen) {
      isar = existing;
      _isInitialized = true;
      return;
    }

    isar = await Isar.open(
      [TaskLocalSchema, NotificationLocalSchema],
      directory: dir.path,
    );
    _isInitialized = true;
  }

  static Future<void> clearAll() async {
    await isar.writeTxn(() => isar.clear());
  }
}
