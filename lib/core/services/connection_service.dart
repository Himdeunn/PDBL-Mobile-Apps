// lib/core/services/connection_service.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectionService {
  static final ConnectionService _instance = ConnectionService._internal();
  factory ConnectionService() => _instance;

  ConnectionService._internal() {
    _connectivity.onConnectivityChanged.listen((results) {
      _connectionController.add(_hasNetworkInterface(results));
    });
  }

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  bool _hasNetworkInterface(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  Future<bool> isConnected() async {
    final results = await _connectivity.checkConnectivity();
    return _hasNetworkInterface(results);
  }

  Future<bool> refresh() async {
    final connected = await isConnected();
    _connectionController.add(connected);
    return connected;
  }

  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;

  Stream<bool> get isConnectedStream => _connectionController.stream;
}
