import 'package:isar_community/isar.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/local_database.dart';
import '../../../core/storage/secure_storage.dart';
import '../models/notification_local.dart';

/// Offline-first notification service.
/// Reads from local Isar DB first, syncs with backend when online.
class NotificationService {
  final ApiClient _api = ApiClient();
  Isar get _isar => LocalDatabase.isar;

  // ─── Local reads ────────────────────────────────────────────────────────────

  Future<List<NotificationLocal>> getLocalNotifications(String userEmail) async {
    return await _isar.notificationLocals
        .filter()
        .userEmailEqualTo(userEmail)
        .and()
        .isDeletedLocallyEqualTo(false)
        .sortByCreatedAtDesc()
        .findAll();
  }

  // ─── Sync from server ───────────────────────────────────────────────────────

  /// Fetch latest notifications from server and upsert into local DB.
  /// Safe to call even when offline — errors are silently ignored.
  Future<void> syncFromServer({int page = 1}) async {
    try {
      final token = await SecureStorage.getToken();
      if (token == null || token.isEmpty) return;

      final email = await SecureStorage.getEmail();
      if (email == null) return;

      final response = await _api.get('/notifications?page=$page');
      final rawData = response.data;

      List<dynamic> items = [];
      if (rawData is List) {
        items = rawData;
      } else if (rawData is Map && rawData['data'] is List) {
        items = rawData['data'];
      }

      await _isar.writeTxn(() async {
        for (final item in items) {
          final int apiId = item['id'];
          final existing = await _isar.notificationLocals
              .filter()
              .apiIdEqualTo(apiId)
              .findFirst();

          final notif = existing ?? NotificationLocal();
          notif.apiId = apiId;
          notif.userEmail = email;
          notif.message = item['message'] ?? '';
          notif.type = item['type'] ?? 'general';
          notif.isRead = item['read_at'] != null;
          notif.isSynced = true;
          notif.isDeletedLocally = false;

          try {
            notif.createdAt = DateTime.parse(item['created_at']);
          } catch (_) {
            notif.createdAt = DateTime.now();
          }

          await _isar.notificationLocals.put(notif);
        }
      });
    } catch (e) {
      // Offline or server error — local data remains intact
    }
  }

  // ─── Sync pending writes to server ─────────────────────────────────────────

  /// Push any pending local changes (mark-read, deletes) to the server.
  Future<void> syncPendingToServer() async {
    try {
      final token = await SecureStorage.getToken();
      if (token == null || token.isEmpty) return;

      // Push pending deletes
      final pendingDeletes = await _isar.notificationLocals
          .filter()
          .isDeletedLocallyEqualTo(true)
          .isSyncedEqualTo(false)
          .findAll();

      for (final notif in pendingDeletes) {
        if (notif.apiId != null) {
          try {
            await _api.delete('/notifications/${notif.apiId}');
            await _isar.writeTxn(() async {
              await _isar.notificationLocals.delete(notif.id);
            });
          } catch (_) {}
        }
      }
    } catch (e) {
      // Silently fail
    }
  }

  // ─── Actions ────────────────────────────────────────────────────────────────

  Future<void> markAsRead(int localId) async {
    // Optimistic local update
    final notif = await _isar.notificationLocals.get(localId);
    if (notif == null) return;

    await _isar.writeTxn(() async {
      notif.isRead = true;
      await _isar.notificationLocals.put(notif);
    });

    // Best-effort server sync
    if (notif.apiId != null) {
      try {
        await _api.post('/notifications/${notif.apiId}/read');
      } catch (_) {}
    }
  }

  Future<void> markAllAsRead(String userEmail) async {
    final unread = await _isar.notificationLocals
        .filter()
        .userEmailEqualTo(userEmail)
        .isReadEqualTo(false)
        .findAll();

    await _isar.writeTxn(() async {
      for (final n in unread) {
        n.isRead = true;
        await _isar.notificationLocals.put(n);
      }
    });

    // Best-effort server sync
    try {
      await _api.post('/notifications/read-all');
    } catch (_) {}
  }

  Future<void> deleteNotification(int localId) async {
    final notif = await _isar.notificationLocals.get(localId);
    if (notif == null) return;

    if (notif.apiId == null) {
      // Local-only: hard delete immediately
      await _isar.writeTxn(() async {
        await _isar.notificationLocals.delete(localId);
      });
      return;
    }

    // Mark for deletion; actual server delete happens in syncPendingToServer
    await _isar.writeTxn(() async {
      notif.isDeletedLocally = true;
      notif.isSynced = false;
      await _isar.notificationLocals.put(notif);
    });

    // Best-effort immediate server delete
    try {
      await _api.delete('/notifications/${notif.apiId}');
      await _isar.writeTxn(() async {
        await _isar.notificationLocals.delete(localId);
      });
    } catch (_) {
      // Will be cleaned up by syncPendingToServer on next online session
    }
  }

  /// Add a local-only notification (e.g. from a scheduled alarm callback).
  Future<void> addLocalNotification({
    required String userEmail,
    required String message,
    String type = 'general',
  }) async {
    final notif = NotificationLocal()
      ..userEmail = userEmail
      ..message = message
      ..type = type
      ..isRead = false
      ..isSynced = false
      ..createdAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.notificationLocals.put(notif);
    });
  }
}
