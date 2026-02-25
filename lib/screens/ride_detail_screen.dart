import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/rides_provider.dart';
import '../providers/auth_provider.dart';

import 'package:flutter/services.dart';

class RideDetailScreen extends ConsumerWidget {
  final String rideId;
  const RideDetailScreen({super.key, required this.rideId});

  void _showTxDialog(BuildContext context, String title, String txHash) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Action successful! Blockchain TX:'),
            const SizedBox(height: 8),
            SelectableText(
              txHash,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: txHash));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('TX Hash copied!')));
            },
            child: const Text('Copy'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rideAsync = ref.watch(currentRideProvider(rideId));
    final auth = ref.watch(authProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Ride Details')),
      body: rideAsync.when(
        data: (ride) => SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ID: ${ride.id}', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Text('From: ${ride.pickup}', style: Theme.of(context).textTheme.headlineSmall),
              Text('To: ${ride.drop}', style: Theme.of(context).textTheme.headlineSmall),
              const Divider(height: 32),

              _infoRow('Status', ride.status.toUpperCase(), isBold: true),
              _infoRow('Fare', '₹${ride.fare}'),
              _infoRow('Distance', '${ride.distanceKm} km'),

              const SizedBox(height: 32),

              if (ride.status == 'accepted' && auth?.user?.role == 'rider')
                _actionButton(context, 'Start Ride (Lock Funds)', () async {
                  final tx = await ref.read(ridesProvider.notifier).startRide(ride.id);
                  _showTxDialog(context, 'Ride Started', tx);
                }),

              if (ride.status == 'started' && auth?.user?.role == 'driver')
                _actionButton(context, 'End Ride (Release Funds)', () async {
                  final tx = await ref.read(ridesProvider.notifier).endRide(ride.id);
                  _showTxDialog(context, 'Ride Completed', tx);
                }),

              const SizedBox(height: 24),
              ExpansionTile(
                title: const Text('Blockchain Transparency', style: TextStyle(fontWeight: FontWeight.bold)),
                leading: const Icon(Icons.security, color: Colors.teal),
                children: [
                  if (ride.txHash != null) _txTile(context, 'Creation', ride.txHash!),
                  if (ride.reserveTxHash != null) _txTile(context, 'Escrow Lock', ride.reserveTxHash!),
                  if (ride.releaseTxHash != null) _txTile(context, 'Escrow Release', ride.releaseTxHash!),
                  if (ride.txHash == null && ride.reserveTxHash == null && ride.releaseTxHash == null)
                    const Padding(padding: EdgeInsets.all(16.0), child: Text('No transactions yet.')),
                ],
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _actionButton(BuildContext context, String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }

  Widget _txTile(BuildContext context, String label, String hash) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      subtitle: Text(
        hash,
        style: const TextStyle(fontSize: 10),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.copy, size: 16),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: hash));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hash copied!')));
        },
      ),
    );
  }
}
