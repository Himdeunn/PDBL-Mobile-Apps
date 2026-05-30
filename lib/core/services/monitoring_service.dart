import 'dart:async';
import 'dart:io' show Platform;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../network/api_client.dart';
import '../storage/secure_storage.dart';

class MonitoringService {
  static final MonitoringService _instance = MonitoringService._internal();
  factory MonitoringService() => _instance;
  MonitoringService._internal();

  final ApiClient _api = ApiClient();
  final List<Map<String, dynamic>> _queue = [];
  final List<Map<String, dynamic>> _breadcrumbs = [];
  Timer? _heartbeatTimer;
  DateTime? _sessionStartedAt;
  String? _sessionKey;
  String? _appVersion;
  bool _flushing = false;
  bool _reducedFrequency = false;

  Future<void> start({required Duration startupDuration}) async {
    _sessionStartedAt = DateTime.now();
    _sessionKey ??= const Uuid().v4();
    _appVersion ??= (await PackageInfo.fromPlatform()).version;
    await track('app_opened', category: 'session', metadata: {'startup_ms': startupDuration.inMilliseconds});
    await track('session_started', category: 'session');
    await track('startup_time', category: 'performance', duration: startupDuration);
    await track(startupDuration.inSeconds > 5 ? 'cold_start' : 'warm_start', category: 'performance', duration: startupDuration);
    _startHeartbeat();
  }

  Future<void> lifecycle(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        await track('app_resumed', category: 'lifecycle');
        _startHeartbeat();
        break;
      case AppLifecycleState.paused:
        await track('app_paused', category: 'lifecycle');
        _heartbeatTimer?.cancel();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        await track('app_backgrounded', category: 'lifecycle');
        break;
      case AppLifecycleState.detached:
        await track('app_terminated', category: 'lifecycle');
        await track('session_ended', category: 'session');
        _heartbeatTimer?.cancel();
        break;
    }
  }

  Future<void> screenLoaded(String screen, Duration duration) async {
    _breadcrumb('screen', screen);
    await track('screen_loaded', category: 'performance', screen: screen, duration: duration);
  }

  Future<void> featureUsed(String feature, {String? screen}) async {
    _breadcrumb('feature', feature);
    await track('feature_used', category: 'feature', feature: feature, screen: screen);
  }

  Future<void> frontendError(Object error, StackTrace stackTrace) async {
    await track('frontend_error', category: 'error', metadata: {
      'error_type': error.runtimeType.toString(),
      'breadcrumbs': List<Map<String, dynamic>>.from(_breadcrumbs),
    });
  }

  Future<void> track(String eventType, {String category = 'mobile', String? screen, String? feature, Duration? duration, Map<String, dynamic>? metadata}) async {
    _queue.add(await _eventPayload(eventType, category: category, screen: screen, feature: feature, duration: duration, metadata: metadata));
    await flush();
  }

  Future<void> flush() async {
    if (_flushing || _queue.isEmpty) return;
    _flushing = true;
    try {
      while (_queue.isNotEmpty) {
        await _api.post('monitoring/events', data: _queue.first);
        _queue.removeAt(0);
      }
    } catch (_) {
      if (_queue.length > 50) _queue.removeRange(0, _queue.length - 50);
    } finally {
      _flushing = false;
    }
  }

  void reduceFrequencyForBattery() {
    _reducedFrequency = true;
    _heartbeatTimer?.cancel();
    _startHeartbeat();
    unawaited(track('battery_guard_reduced_frequency', category: 'performance'));
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(Duration(minutes: _reducedFrequency ? 5 : 1), (_) => unawaited(track('session_heartbeat', category: 'session')));
  }

  Future<Map<String, dynamic>> _eventPayload(String eventType, {required String category, String? screen, String? feature, Duration? duration, Map<String, dynamic>? metadata}) async {
    final connectivity = await Connectivity().checkConnectivity();
    final networkType = connectivity.map((item) => item.name).join(',');
    final deviceId = await SecureStorage.getDeviceId();
    final startedAt = _sessionStartedAt ?? DateTime.now();
    _sessionStartedAt ??= startedAt;
    _sessionKey ??= const Uuid().v4();
    _appVersion ??= (await PackageInfo.fromPlatform()).version;
    return {
      'event_type': eventType,
      'category': category,
      'session_key': _sessionKey,
      'device_id': deviceId,
      'duration_ms': duration?.inMilliseconds,
      'screen': screen,
      'feature': feature,
      'network_type': networkType,
      'offline': connectivity.contains(ConnectivityResult.none),
      'occurred_at': DateTime.now().toIso8601String(),
      'started_at': startedAt.toIso8601String(),
      'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      'app_version': _appVersion,
      'timezone': DateTime.now().timeZoneName,
      'locale': PlatformDispatcher.instance.locale.toLanguageTag(),
      'metadata': _safeMetadata(metadata ?? const {}),
    };
  }

  Map<String, dynamic> _safeMetadata(Map<String, dynamic> metadata) {
    const blocked = {'message', 'body', 'content', 'password', 'token', 'authorization', 'otp', 'secret'};
    final safe = <String, dynamic>{};
    metadata.forEach((key, value) {
      if (blocked.contains(key.toLowerCase())) return;
      if (value is String) {
        safe[key] = value.length > 200 ? value.substring(0, 200) : value;
      } else if (value is num || value is bool || value == null) {
        safe[key] = value;
      } else if (value is Map<String, dynamic>) {
        safe[key] = _safeMetadata(value);
      } else if (value is List) {
        safe[key] = value.whereType<Map<String, dynamic>>().map(_safeMetadata).toList();
      }
    });
    return safe;
  }

  void _breadcrumb(String type, String value) {
    _breadcrumbs.add({'type': type, 'value': value, 'at': DateTime.now().toIso8601String()});
    if (_breadcrumbs.length > 10) _breadcrumbs.removeAt(0);
  }
}
