import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ride_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../data/models/ride_model.dart';
import '../../../core/constants/app_constants.dart';

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
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
        title: const Text('Find a Ride'),
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
            ? const Center(child: Text('No rides available right now.'))
            : ListView.builder(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                itemCount: rideProvider.availableRides.length,
                itemBuilder: (context, index) {
                  final ride = rideProvider.availableRides[index];
                  return _RideCard(ride: ride);
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRequestRideSheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showRequestRideSheet(BuildContext context) {
    // Basic implementation for now
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Request a New Ride', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final success = await context.read<RideProvider>().requestRide(
                  LocationModel(latitude: 0, longitude: 0, address: 'Current Location'),
                  LocationModel(latitude: 0, longitude: 0, address: 'Destination'),
                  10.0,
                );
                if (success && mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Ride requested!')));
                }
              },
              child: const Text('Request Mock Ride (\$10)'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  final RideModel ride;

  const _RideCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Ride #${ride.rideId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '\$${ride.fare.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.radio_button_checked, color: Colors.blue),
              title: Text(ride.pickupLocation.address),
              dense: true,
            ),
            ListTile(
              leading: const Icon(Icons.location_on, color: Colors.red),
              title: Text(ride.dropLocation.address),
              dense: true,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(label: Text(ride.status)),
                ElevatedButton(
                  onPressed: ride.status == 'REQUESTED' ? () {} : null,
                  child: const Text('View Details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
