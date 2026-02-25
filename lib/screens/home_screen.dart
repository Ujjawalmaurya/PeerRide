import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/rides_provider.dart';
import 'ride_detail_screen.dart';
import 'wallet_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

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
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Expanded(child: Center(child: Text('Google Map Placeholder\n(Markers: Pickup & Drop)'))),
        Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _pickupController,
                  decoration: const InputDecoration(labelText: 'Pickup'),
                ),
                TextField(
                  controller: _dropController,
                  decoration: const InputDecoration(labelText: 'Drop'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      try {
                        final ride = await ref
                            .read(ridesProvider.notifier)
                            .createRide(_pickupController.text, _dropController.text);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => RideDetailScreen(rideId: ride.id)),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    },
                    child: const Text('Find Cab'),
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
    return rides.when(
      data: (list) => ListView.builder(
        itemCount: list.length,
        itemBuilder: (context, index) {
          final ride = list[index];
          return ListTile(
            title: Text('${ride.pickup} to ${ride.drop}'),
            subtitle: Text('Status: ${ride.status.toUpperCase()}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailScreen(rideId: ride.id))),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('Error: $err')),
    );
  }
}

class AvailableRidesView extends ConsumerWidget {
  const AvailableRidesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rides = ref.watch(pendingRidesProvider);
    return rides.when(
      data: (list) => ListView.builder(
        itemCount: list.length,
        itemBuilder: (context, index) {
          final ride = list[index];
          return ListTile(
            title: Text('${ride.pickup} to ${ride.drop}'),
            subtitle: Text('Fare: ₹${ride.fare}'),
            trailing: ElevatedButton(
              onPressed: () => ref.read(ridesProvider.notifier).acceptRide(ride.id),
              child: const Text('Accept'),
            ),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('Error: $err')),
    );
  }
}
