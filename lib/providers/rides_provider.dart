import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ride_model.dart';
import 'auth_provider.dart';

import 'dart:math';

class RidesNotifier extends AsyncNotifier<List<Ride>> {
  @override
  Future<List<Ride>> build() async {
    final auth = ref.watch(authProvider).value;
    if (auth?.user == null) return [];
    return _fetchRides();
  }

  Future<List<Ride>> _fetchRides() async {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/rides/my-rides');
    final List list = response.data;
    return list.map((e) => Ride.fromJson(e)).toList();
  }

  Future<Ride> createRide(String pickup, String drop) async {
    final dio = ref.read(dioProvider);

    // Fake distance/fare calculation
    final distance = Random().nextInt(11) + 5; // 5-15 km
    final fare = 50 + (distance * 20);

    final response = await dio.post(
      '/rides/create',
      data: {'pickup': pickup, 'drop': drop, 'distanceKm': distance, 'fare': fare},
    );
    final ride = Ride.fromJson(response.data);
    ref.invalidateSelf();
    return ride;
  }

  Future<void> acceptRide(String rideId) async {
    final dio = ref.read(dioProvider);
    await dio.post('/rides/accept/$rideId');
    ref.invalidateSelf();
    // Also invalidate individual ride providers if any
    ref.invalidate(currentRideProvider(rideId));
  }

  Future<String> startRide(String rideId) async {
    final dio = ref.read(dioProvider);
    final response = await dio.post('/rides/start/$rideId');
    ref.invalidateSelf();
    ref.invalidate(currentRideProvider(rideId));
    return response.data['txHash'];
  }

  Future<String> endRide(String rideId) async {
    final dio = ref.read(dioProvider);
    final response = await dio.post('/rides/end/$rideId');
    ref.invalidateSelf();
    ref.invalidate(currentRideProvider(rideId));
    return response.data['txHash'];
  }
}

final ridesProvider = AsyncNotifierProvider<RidesNotifier, List<Ride>>(RidesNotifier.new);

// Family provider for a single ride
final currentRideProvider = FutureProvider.family<Ride, String>((ref, rideId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/rides/$rideId');
  return Ride.fromJson(response.data);
});

// Provider for pending rides (available for drivers)
final pendingRidesProvider = FutureProvider<List<Ride>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/rides/pending'); // Assuming this endpoint exists or filter my-rides
  final List list = response.data;
  return list.map((e) => Ride.fromJson(e)).toList();
});
