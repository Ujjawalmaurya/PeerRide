import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../utils/app_logger.dart';

class SocketService {
  io.Socket? _socket;
  
  final _connectionController = StreamController<bool>.broadcast();
  final _locationController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  final _driverOfflineController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<Map<String, dynamic>> get locationStream => _locationController.stream;
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;
  Stream<Map<String, dynamic>> get driverOfflineStream => _driverOfflineController.stream;

  bool get isConnected => _socket?.connected ?? false;

  void connect(String token) {
    if (_socket != null) {
      log.w('[SOCKET] Already initialized. Disconnecting previous socket...');
      disconnect();
    }

    final rawUrl = dotenv.env['API_URL'] ?? 'http://localhost:1205/api/';
    final socketUrl = rawUrl.replaceAll('/api/', '').replaceAll('/api', '');

    log.i('[SOCKET] Connecting to $socketUrl with token: ${token.substring(0, min(token.length, 10))}...');

    _socket = io.io(socketUrl, io.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .setAuth({'token': token})
      .build()
    );

    _socket!.onConnect((_) {
      log.i('[SOCKET] ✅ Connected to server');
      _connectionController.add(true);
    });

    _socket!.onDisconnect((data) {
      log.w('[SOCKET] ❌ Disconnected from server: $data');
      _connectionController.add(false);
    });

    _socket!.onConnectError((data) {
      log.e('[SOCKET] ⚠️ Connection Error', error: data);
      _connectionController.add(false);
    });

    // Listen to backend events
    _socket!.on('location:update', (data) {
      log.d('[SOCKET] location:update received: $data');
      if (data is Map) {
        _locationController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('status:update', (data) {
      log.d('[SOCKET] status:update received: $data');
      if (data is Map) {
        _statusController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('driver:offline', (data) {
      log.w('[SOCKET] driver:offline received: $data');
      if (data is Map) {
        _driverOfflineController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.connect();
  }

  void joinRide(String rideId) {
    if (_socket == null || !_socket!.connected) {
      log.w('[SOCKET] Cannot join ride: socket not connected');
      return;
    }
    log.i('[SOCKET] Joining ride room: ride:$rideId');
    _socket!.emit('ride:join', {'rideId': rideId});
  }

  void updateLocation({
    required String driverId,
    required String rideId,
    required double lat,
    required double lng,
    double heading = 0.0,
    double speed = 0.0,
  }) {
    if (_socket == null || !_socket!.connected) {
      log.w('[SOCKET] Cannot send location: socket not connected');
      return;
    }
    _socket!.emit('driver:location', {
      'driverId': driverId,
      'rideId': rideId,
      'lat': lat,
      'lng': lng,
      'heading': heading,
      'speed': speed,
    });
  }

  void updateStatus({
    required String driverId,
    required String rideId,
    required String status,
  }) {
    if (_socket == null || !_socket!.connected) {
      log.w('[SOCKET] Cannot update status: socket not connected');
      return;
    }
    log.i('[SOCKET] Sending status update: $status');
    _socket!.emit('driver:status', {
      'driverId': driverId,
      'rideId': rideId,
      'status': status,
    });
  }

  void disconnect() {
    if (_socket != null) {
      log.i('[SOCKET] Disconnecting socket...');
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
  }

  int min(int a, int b) => a < b ? a : b;
}
