import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import '../services/socket_service.dart';
import '../utils/app_logger.dart';
import '../utils/haversine.dart';
import 'auth_provider.dart';
import 'rides_provider.dart';

class TrackingState {
  final bool isConnected;
  final double? driverLat;
  final double? driverLng;
  final double heading;
  final double speed;
  final double? etaMinutes;
  final String status; // 'enroute' | 'arrived' | 'transporting' | 'completed' | 'unknown'
  final bool isDriverOffline;

  TrackingState({
    this.isConnected = false,
    this.driverLat,
    this.driverLng,
    this.heading = 0.0,
    this.speed = 0.0,
    this.etaMinutes,
    this.status = 'unknown',
    this.isDriverOffline = false,
  });

  TrackingState copyWith({
    bool? isConnected,
    double? driverLat,
    double? driverLng,
    double? heading,
    double? speed,
    double? etaMinutes,
    String? status,
    bool? isDriverOffline,
  }) {
    return TrackingState(
      isConnected: isConnected ?? this.isConnected,
      driverLat: driverLat ?? this.driverLat,
      driverLng: driverLng ?? this.driverLng,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      status: status ?? this.status,
      isDriverOffline: isDriverOffline ?? this.isDriverOffline,
    );
  }
}

class TrackingNotifier extends AutoDisposeNotifier<TrackingState> {
  final _socketService = SocketService();
  StreamSubscription? _locationSub;
  StreamSubscription? _statusSub;
  StreamSubscription? _offlineSub;
  StreamSubscription? _connectionSub;
  StreamSubscription? _gpsSub;

  @override
  TrackingState build() {
    ref.onDispose(() {
      log.i('[TRACKING] Disposing tracking notifier...');
      _gpsSub?.cancel();
      _locationSub?.cancel();
      _statusSub?.cancel();
      _offlineSub?.cancel();
      _connectionSub?.cancel();
      _socketService.disconnect();
    });

    return TrackingState();
  }

  Future<void> initTracking(String rideId, {String? familyToken}) async {
    log.i('[TRACKING] Initializing live tracking for ride: $rideId');
    
    // 1. Get token
    String? token = familyToken;
    if (token == null) {
      const storage = FlutterSecureStorage();
      token = await storage.read(key: 'jwt');
    }

    if (token == null) {
      log.e('[TRACKING] Failed to initialize: No JWT token or familyToken provided');
      return;
    }

    // 2. Connect socket
    _socketService.connect(token);

    // 3. Listen to connection state
    _connectionSub = _socketService.connectionStream.listen((connected) {
      state = state.copyWith(isConnected: connected);
      if (connected) {
        _socketService.joinRide(rideId);
      }
    });

    // 4. Setup listeners for updates
    _locationSub = _socketService.locationStream.listen((data) {
      final lat = data['lat'] as double?;
      final lng = data['lng'] as double?;
      final heading = (data['heading'] as num?)?.toDouble() ?? 0.0;
      final speed = (data['speed'] as num?)?.toDouble() ?? 0.0;

      if (lat != null && lng != null) {
        state = state.copyWith(
          driverLat: lat,
          driverLng: lng,
          heading: heading,
          speed: speed,
          isDriverOffline: false,
        );

        _calculateEta(rideId, lat, lng, speed);
      }
    });

    _statusSub = _socketService.statusStream.listen((data) {
      final status = data['status'] as String?;
      if (status != null) {
        state = state.copyWith(status: status);
      }
    });

    _offlineSub = _socketService.driverOfflineStream.listen((data) {
      state = state.copyWith(isDriverOffline: true);
    });

    // 5. If user is a driver, start publishing GPS coordinate updates
    final auth = ref.read(authProvider).value;
    if (auth?.user != null && auth!.user!.role == 'driver') {
      await _startDriverGpsTracking(auth.user!.id, rideId);
    }
  }

  Future<void> updateDriverStatus(String rideId, String status) async {
    final auth = ref.read(authProvider).value;
    if (auth?.user == null || auth!.user!.role != 'driver') return;
    
    _socketService.updateStatus(
      driverId: auth.user!.id,
      rideId: rideId,
      status: status,
    );
    state = state.copyWith(status: status);
  }

  Future<void> _startDriverGpsTracking(String driverId, String rideId) async {
    log.i('[TRACKING] Starting driver GPS publisher...');
    
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      log.w('[TRACKING] Location services are disabled');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        log.w('[TRACKING] Location permissions are denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      log.w('[TRACKING] Location permissions are permanently denied');
      return;
    }

    // Configure Geolocator settings (high accuracy, update intervals)
    const LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5, // Update every 5 meters
    );

    _gpsSub = Geolocator.getPositionStream(locationSettings: settings).listen((Position position) {
      log.d('[TRACKING] GPS position: ${position.latitude}, ${position.longitude}');
      
      _socketService.updateLocation(
        driverId: driverId,
        rideId: rideId,
        lat: position.latitude,
        lng: position.longitude,
        heading: position.heading,
        speed: position.speed,
      );

      state = state.copyWith(
        driverLat: position.latitude,
        driverLng: position.longitude,
        heading: position.heading,
        speed: position.speed,
      );
    });
  }

  void _calculateEta(String rideId, double driverLat, double driverLng, double speedKmh) {
    try {
      final rideAsyncValue = ref.read(currentRideProvider(rideId));
      final ride = rideAsyncValue.value;
      if (ride == null) return;

      // Determine target destination based on status
      double targetLat;
      double targetLng;

      if (state.status == 'enroute' || ride.status == 'accepted') {
        // Driver is heading to pickup patient
        targetLat = ride.startLat ?? 0.0;
        targetLng = ride.startLng ?? 0.0;
      } else {
        // Driver is transporting patient to hospital/drop
        targetLat = ride.endLat ?? 0.0;
        targetLng = ride.endLng ?? 0.0;
      }

      if (targetLat == 0.0 || targetLng == 0.0) return;

      final distanceKm = calculateHaversineDistance(
        driverLat,
        driverLng,
        targetLat,
        targetLng,
      );

      // Estimate travel time: if vehicle is moving, use actual speed, otherwise assume average 30 km/h traffic speed
      final speed = speedKmh > 0 ? speedKmh : 30.0;
      final timeHours = distanceKm / speed;
      final double etaMinutes = timeHours * 60.0;

      state = state.copyWith(etaMinutes: etaMinutes);
    } catch (e) {
      log.e('[TRACKING] ETA calculation error: $e');
    }
  }
}

final trackingProvider = AutoDisposeNotifierProvider<TrackingNotifier, TrackingState>(TrackingNotifier.new);
