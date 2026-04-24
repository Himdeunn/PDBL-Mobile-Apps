import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService {
  static final FirebaseRemoteConfig _rc = FirebaseRemoteConfig.instance;

  static Future<void> initialize() async {
    await _rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval:
          kReleaseMode ? const Duration(hours: 1) : Duration.zero,
    ));

    await _rc.setDefaults({
      // ── Maintenance ──────────────────────────────────────────────────────
      'maintenance_enabled': false,
      'maintenance_title': "We'll Be Right Back",
      'maintenance_message':
          "We're doing some maintenance to improve Wudi for you. We'll be back online shortly!",
      'maintenance_estimated_end': '',

      // ── App Update ───────────────────────────────────────────────────────
      'force_update_enabled': false,
      'optional_update_enabled': false,
      'min_version': '1.0.0',
      'latest_version': '1.0.0',
      'update_url_android': '',
      'update_title': 'Update Available',
      'update_message':
          "A new version of Wudi is ready! Update now to get the latest features and improvements.",
      'update_changelog': '',
    });

    try {
      await _rc.fetchAndActivate();
    } catch (_) {
      // Silently use cached / default values on network failure
    }
  }

  /// Stream that emits whenever Firebase pushes a new remote config.
  /// Automatically fetches + activates the update before emitting.
  static Stream<void> get onUpdated => _rc.onConfigUpdated.asyncMap((_) async {
    try {
      await _rc.activate();
    } catch (_) {}
  });

  // ── Maintenance getters ──────────────────────────────────────────────────
  static bool get maintenanceEnabled => _rc.getBool('maintenance_enabled');
  static String get maintenanceTitle => _rc.getString('maintenance_title');
  static String get maintenanceMessage => _rc.getString('maintenance_message');
  static String get maintenanceEstimatedEnd =>
      _rc.getString('maintenance_estimated_end');

  // ── Update getters ───────────────────────────────────────────────────────
  static bool get forceUpdateEnabled => _rc.getBool('force_update_enabled');
  static bool get optionalUpdateEnabled => _rc.getBool('optional_update_enabled');
  static String get minVersion => _rc.getString('min_version');
  static String get latestVersion => _rc.getString('latest_version');
  static String get updateUrlAndroid => _rc.getString('update_url_android');
  static String get updateTitle => _rc.getString('update_title');
  static String get updateMessage => _rc.getString('update_message');
  static String get updateChangelog => _rc.getString('update_changelog');

  // ── Version helpers ──────────────────────────────────────────────────────

  /// Returns negative if [a] < [b], 0 if equal, positive if [a] > [b].
  static int compareVersions(String a, String b) {
    final pa = _parts(a);
    final pb = _parts(b);
    for (int i = 0; i < 3; i++) {
      final diff = (i < pa.length ? pa[i] : 0) - (i < pb.length ? pb[i] : 0);
      if (diff != 0) return diff;
    }
    return 0;
  }

  static List<int> _parts(String v) =>
      v.split('.').map((s) => int.tryParse(s) ?? 0).toList();
}
