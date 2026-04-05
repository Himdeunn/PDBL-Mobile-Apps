import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/task/models/task_local.dart';
import '../../features/profile/models/notification_local.dart';

class LocalDatabase {
  static late Isar isar;

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open(
      [TaskLocalSchema, NotificationLocalSchema],
      directory: dir.path,
    );
  }

  static Future<void> clearAll() async {
    await isar.writeTxn(() => isar.clear());
  }
}
