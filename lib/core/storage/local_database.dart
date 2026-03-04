import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/task/models/task_local.dart';

class LocalDatabase {
  static late Isar isar;

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open([TaskLocalSchema], directory: dir.path);
  }
}
