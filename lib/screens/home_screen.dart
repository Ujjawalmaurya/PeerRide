import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/rides_provider.dart';
import '../providers/wallet_provider.dart';
import 'ride_detail_screen.dart';
import 'wallet_screen.dart';
import 'auth_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  Future<void> _handleLogout() async {
    await ref.read(authProvider.notifier).logout();
    ref.invalidate(ridesProvider);
    ref.invalidate(walletProvider);
    ref.invalidate(pendingRidesProvider);
    if (mounted) {
      Navigator.of(
        context,
      ).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthScreen()), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider).value;
    final isRider = auth?.user?.role == 'rider';

    final List<Widget> riderScreens = [const RiderMapView(), const MyRidesView(), const WalletScreen()];

    final List<Widget> driverScreens = [
      const AvailableRidesView(),
      const MyRidesView(),
      const WalletScreen(),
    ];

    final currentScreens = isRider ? riderScreens : driverScreens;

    return Scaffold(
      appBar: AppBar(
        title: Text(isRider ? 'Rider - P2P Cab' : 'Driver - P2P Cab'),
        actions: [IconButton(icon: const Icon(Icons.logout), tooltip: 'Logout', onPressed: _handleLogout)],
      ),
      body: currentScreens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: Icon(isRider ? Icons.map : Icons.list),
            label: isRider ? 'Book' : 'Available',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.history), label: 'My Rides'),
          const BottomNavigationBarItem(icon: Icon(Icons.wallet), label: 'Wallet'),
        ],
      ),
    );
  }
}

class RiderMapView extends ConsumerStatefulWidget {
  const RiderMapView({super.key});

  @override
  ConsumerState<RiderMapView> createState() => _RiderMapViewState();
}

class _RiderMapViewState extends ConsumerState<RiderMapView> {
  final _pickupController = TextEditingController(text: 'Park Street');
  final _dropController = TextEditingController(text: 'Airport');
  bool _isBooking = false;

  // Fake coordinates for demo markers
  static const _pickupLatLng = LatLng(22.5726, 88.3639); // Park Street, Kolkata
  static const _dropLatLng = LatLng(22.6520, 88.4463); // Airport area

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: GoogleMap(
            initialCameraPosition: const CameraPosition(target: LatLng(22.6100, 88.4050), zoom: 12),
            markers: {
              const Marker(
                markerId: MarkerId('pickup'),
                position: _pickupLatLng,
                infoWindow: InfoWindow(title: 'Pickup', snippet: 'Park Street'),
                icon: BitmapDescriptor.defaultMarker,
              ),
              Marker(
                markerId: const MarkerId('drop'),
                position: _dropLatLng,
                infoWindow: const InfoWindow(title: 'Drop', snippet: 'Airport'),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              ),
            },
            myLocationEnabled: false,
            zoomControlsEnabled: true,
          ),
        ),
        Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _pickupController,
                  decoration: const InputDecoration(
                    labelText: 'Pickup',
                    prefixIcon: Icon(Icons.my_location, color: Colors.red),
                  ),
                ),
                TextField(
                  controller: _dropController,
                  decoration: const InputDecoration(
                    labelText: 'Drop',
                    prefixIcon: Icon(Icons.location_on, color: Colors.green),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isBooking
                        ? null
                        : () async {
                            setState(() => _isBooking = true);
                            try {
                              final ride = await ref
                                  .read(ridesProvider.notifier)
                                  .createRide(
                                    _pickupController.text,
                                    _dropController.text,
                                    startLat: _pickupLatLng.latitude,
                                    startLng: _pickupLatLng.longitude,
                                    endLat: _dropLatLng.latitude,
                                    endLng: _dropLatLng.longitude,
                                  );
                              if (mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => RideDetailScreen(rideId: ride.id)),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to book: $e'), backgroundColor: Colors.red),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _isBooking = false);
                            }
                          },
                    child: _isBooking
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Find Cab'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class MyRidesView extends ConsumerWidget {
  const MyRidesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rides = ref.watch(ridesProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(ridesProvider),
      child: rides.when(
        data: (list) => list.isEmpty
            ? const Center(child: Text('No rides yet'))
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final ride = list[index];
                  return ListTile(
                    leading: _statusIcon(ride.status),
                    title: Text('${ride.pickup} → ${ride.drop}'),
                    subtitle: Text('${ride.status.toUpperCase()} · ₹${ride.fare}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RideDetailScreen(rideId: ride.id)),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text('Error: $err'),
              TextButton(onPressed: () => ref.invalidate(ridesProvider), child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return const Icon(Icons.schedule, color: Colors.orange);
      case 'accepted':
        return const Icon(Icons.check_circle_outline, color: Colors.blue);
      case 'started':
        return const Icon(Icons.directions_car, color: Colors.teal);
      case 'completed':
        return const Icon(Icons.done_all, color: Colors.green);
      default:
        return const Icon(Icons.help_outline, color: Colors.grey);
    }
  }
}

class AvailableRidesView extends ConsumerWidget {
  const AvailableRidesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rides = ref.watch(pendingRidesProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(pendingRidesProvider),
      child: rides.when(
        data: (list) => list.isEmpty
            ? const Center(child: Text('No rides available right now'))
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final ride = list[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => RideDetailScreen(rideId: ride.id)),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.local_taxi, color: Colors.teal),
                        title: Text('${ride.pickup} → ${ride.drop}'),
                        subtitle: Text('${ride.distanceKm} km · ₹${ride.fare}'),
                        trailing: _AcceptButton(rideId: ride.id),
                      ),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text('Error: $err'),
              TextButton(onPressed: () => ref.invalidate(pendingRidesProvider), child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

class _AcceptButton extends ConsumerStatefulWidget {
  final String rideId;
  const _AcceptButton({required this.rideId});

  @override
  ConsumerState<_AcceptButton> createState() => _AcceptButtonState();
}

class _AcceptButtonState extends ConsumerState<_AcceptButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _loading
          ? null
          : () async {
              setState(() => _loading = true);
              try {
                await ref.read(ridesProvider.notifier).acceptRide(widget.rideId);
                ref.invalidate(pendingRidesProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ride accepted!'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
                }
              } finally {
                if (mounted) setState(() => _loading = false);
              }
            },
      child: _loading
          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Text('Accept'),
    );
  }
}
