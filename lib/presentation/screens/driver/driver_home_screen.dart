import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ride_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../data/models/ride_model.dart';
import '../../../core/constants/app_constants.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<RideProvider>().fetchAvailableRides();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rideProvider = context.watch<RideProvider>();
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Rides'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              authProvider.logout();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => rideProvider.fetchAvailableRides(),
        child: rideProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : rideProvider.availableRides.isEmpty
            ? const Center(child: Text('No rides requested yet.'))
            : ListView.builder(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                itemCount: rideProvider.availableRides.length,
                itemBuilder: (context, index) {
                  final ride = rideProvider.availableRides[index];
                  return _AvailableRideCard(ride: ride);
                },
              ),
      ),
    );
  }
}

class _AvailableRideCard extends StatelessWidget {
  final RideModel ride;

  const _AvailableRideCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ListTile(
              title: Text('Ride #${ride.rideId}'),
              subtitle: Text('Fare: \$${ride.fare}'),
              trailing: ElevatedButton(
                onPressed: () {
                  // TODO: Implement accept ride
                },
                child: const Text('Accept'),
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.circle, size: 12),
                      const SizedBox(width: 8),
                      Text(ride.pickupLocation.address),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 12),
                      const SizedBox(width: 8),
                      Text(ride.dropLocation.address),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
