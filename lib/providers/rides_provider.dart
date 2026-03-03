import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/ride_model.dart';
import '../utils/app_logger.dart';
import 'auth_provider.dart';
import 'wallet_provider.dart';

import 'dart:async';
import 'dart:math';

class RidesNotifier extends AsyncNotifier<List<Ride>> {
  @override
  Future<List<Ride>> build() async {
    final auth = ref.watch(authProvider).value;
    if (auth?.user == null) {
      log.d('[RIDES] No user session — skipping fetch');
      return [];
    }

    // Start polling every 5 seconds
    final timer = Timer.periodic(const Duration(seconds: 5), (t) async {
      final rides = await _fetchRides();
      state = AsyncData(rides);
      // Also refresh any active detail screen
      for (final ride in rides) {
        if (ride.status != 'pending') {
          ref.invalidate(currentRideProvider(ride.id));
        }
      }
    });

    ref.onDispose(() => timer.cancel());

    return _fetchRides();
  }

  Future<List<Ride>> _fetchRides() async {
    try {
      log.d('[RIDES] Heartbeat: fetching rides...');
      final dio = ref.read(dioProvider);
      final response = await dio.get('rides/my-rides');
      final data = response.data;
      if (data is List) {
        final rides = data.map((e) => Ride.fromJson(e)).toList();
        return rides;
      }
      return state.value ?? [];
    } catch (e) {
      log.e('[RIDES] Polling failed: $e');
      return state.value ?? [];
    }
  }

  Future<Ride> createRide(
    String pickup,
    String drop, {
    double? startLat,
    double? startLng,
    double? endLat,
    double? endLng,
  }) async {
    final dio = ref.read(dioProvider);

    int distance;
    if (startLat != null && startLng != null && endLat != null && endLng != null) {
      final distanceInMeters = Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
      distance = (distanceInMeters / 1000).round();
      if (distance < 1) distance = 1; // Minimum 1km
    } else {
      distance = Random().nextInt(11) + 5;
    }

    final fare = 50 + (distance * 20);

    log.i('[RIDES] Creating ride: $pickup → $drop ($distance km, ₹$fare)');
    final response = await dio.post(
      'rides/create',
      data: {'pickup': pickup, 'drop': drop, 'distanceKm': distance, 'fare': fare},
    );
    final ride = Ride.fromJson(response.data);
    log.i('[RIDES] ✅ Ride created: ${ride.id}');
    ref.invalidateSelf();
    return ride;
  }

  Future<void> acceptRide(String rideId) async {
    log.i('[RIDES] Accepting ride: $rideId');
    final dio = ref.read(dioProvider);
    await dio.post('rides/accept/$rideId');
    log.i('[RIDES] ✅ Ride accepted: $rideId');
    ref.invalidateSelf();
    ref.invalidate(currentRideProvider(rideId));
  }

  Future<String> startRide(String rideId) async {
    log.i('[RIDES] Starting ride: $rideId (locking funds in escrow)');
    final dio = ref.read(dioProvider);
    final response = await dio.post('rides/start/$rideId');
    final txHash = response.data['txHash'] as String;
    log.i('[RIDES] ✅ Ride started: $rideId | txHash: $txHash');
    ref.invalidateSelf();
    ref.invalidate(currentRideProvider(rideId));
    ref.invalidate(walletProvider);
    return txHash;
  }

  Future<String> endRide(String rideId) async {
    log.i('[RIDES] Ending ride: $rideId (releasing funds to driver)');
    final dio = ref.read(dioProvider);
    final response = await dio.post('rides/end/$rideId');
    final txHash = response.data['txHash'] as String;
    log.i('[RIDES] ✅ Ride completed: $rideId | txHash: $txHash');
    ref.invalidateSelf();
    ref.invalidate(currentRideProvider(rideId));
    ref.invalidate(walletProvider);
    return txHash;
  }
}

final ridesProvider = AsyncNotifierProvider<RidesNotifier, List<Ride>>(RidesNotifier.new);

final currentRideProvider = FutureProvider.family<Ride, String>((ref, rideId) async {
  log.d('[RIDES] Fetching ride details: $rideId');
  final dio = ref.read(dioProvider);
  final response = await dio.get('rides/$rideId');
  return Ride.fromJson(response.data);
});

final pendingRidesProvider = FutureProvider<List<Ride>>((ref) async {
  log.i('[RIDES] Fetching available rides for driver...');
  final dio = ref.read(dioProvider);
  final response = await dio.get('rides/available');
  final data = response.data;
  if (data is List) {
    final rides = data.map((e) => Ride.fromJson(e)).toList();
    log.i('[RIDES] ✅ ${rides.length} available rides found');
    return rides;
  }
  return [];
});
