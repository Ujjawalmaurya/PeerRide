import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../providers/rides_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';

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
              // Route header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.my_location, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Text(ride.pickup, style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 9),
                        child: Container(width: 2, height: 20, color: Colors.grey.shade300),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Text(ride.drop, style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Status Timeline
              _StatusTimeline(currentStatus: ride.status),

              const SizedBox(height: 16),

              // Info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _infoRow('Ride ID', ride.id.substring(ride.id.length - 6)),
                      _infoRow('Fare', '₹${ride.fare}'),
                      _infoRow('Distance', '${ride.distanceKm} km'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              _FareBreakdown(fare: ride.fare),

              const SizedBox(height: 24),

              // Action buttons
              if (ride.status == 'pending' && auth?.user?.role == 'driver')
                _ActionButton(
                  label: 'Accept Ride',
                  icon: Icons.thumb_up,
                  onAction: () async {
                    await ref.read(ridesProvider.notifier).acceptRide(ride.id);
                    ref.invalidate(pendingRidesProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ride accepted!'), backgroundColor: Colors.green),
                      );
                    }
                  },
                ),

              if (ride.status == 'accepted' && auth?.user?.role == 'rider')
                _ActionButton(
                  label: 'Start Ride (Lock Funds)',
                  icon: Icons.lock,
                  onAction: () async {
                    final balance = ref.read(walletProvider).value ?? 0;
                    if (balance < ride.fare) {
                      if (context.mounted) {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Insufficient Funds'),
                            content: Text(
                              'You need ₹${ride.fare} in your wallet to start this ride.\n\n'
                              'Current balance: ₹$balance\n'
                              'Shortfall: ₹${ride.fare - balance}',
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                            ],
                          ),
                        );
                      }
                      return;
                    }

                    final tx = await ref.read(ridesProvider.notifier).startRide(ride.id);
                    if (context.mounted) _showTxDialog(context, 'Ride Started', tx);
                  },
                ),

              if (ride.status == 'started' && auth?.user?.role == 'driver')
                _ActionButton(
                  label: 'End Ride (Release Funds)',
                  icon: Icons.lock_open,
                  onAction: () async {
                    final tx = await ref.read(ridesProvider.notifier).endRide(ride.id);
                    if (context.mounted) _showTxDialog(context, 'Ride Completed', tx);
                  },
                ),

              const SizedBox(height: 24),

              // Blockchain Transparency
              Card(
                child: ExpansionTile(
                  title: const Text('Blockchain Transparency', style: TextStyle(fontWeight: FontWeight.bold)),
                  leading: const Icon(Icons.security, color: Colors.teal),
                  initiallyExpanded: ride.txHash != null,
                  children: [
                    if (ride.txHash != null) _txTile(context, 'Escrow Lock', ride.txHash!),
                    if (ride.reserveTxHash != null && ride.reserveTxHash != ride.txHash)
                      _txTile(context, 'Reserve TX', ride.reserveTxHash!),
                    if (ride.releaseTxHash != null) _txTile(context, 'Escrow Release', ride.releaseTxHash!),
                    if (ride.txHash == null && ride.reserveTxHash == null && ride.releaseTxHash == null)
                      const Padding(padding: EdgeInsets.all(16.0), child: Text('No transactions yet.')),
                  ],
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text('Error: $err'),
              TextButton(
                onPressed: () => ref.invalidate(currentRideProvider(rideId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _txTile(BuildContext context, String label, String hash) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      subtitle: Text(
        hash,
        style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            tooltip: 'Copy hash',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: hash));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hash copied!')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser, size: 16),
            tooltip: 'View transaction',
            onPressed: () {
              final rpcUrl = dotenv.env['HARDHAT_EXPLORER_URL'] ?? 'http://localhost:8545';
              launchUrl(Uri.parse(rpcUrl), mode: LaunchMode.externalApplication);
            },
          ),
        ],
      ),
    );
  }
}

// --- Status Timeline Widget ---

class _StatusTimeline extends StatelessWidget {
  final String currentStatus;
  const _StatusTimeline({required this.currentStatus});

  static const _steps = [
    {'key': 'pending', 'label': 'Pending', 'icon': Icons.schedule},
    {'key': 'accepted', 'label': 'Accepted', 'icon': Icons.check_circle_outline},
    {'key': 'started', 'label': 'Started', 'icon': Icons.directions_car},
    {'key': 'completed', 'label': 'Completed', 'icon': Icons.done_all},
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _steps.indexWhere((s) => s['key'] == currentStatus);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: List.generate(_steps.length * 2 - 1, (i) {
            if (i.isOdd) {
              // Connector line
              final stepIndex = i ~/ 2;
              final isDone = stepIndex < currentIndex;
              return Expanded(
                child: Container(height: 3, color: isDone ? Colors.teal : Colors.grey.shade300),
              );
            }

            final stepIndex = i ~/ 2;
            final step = _steps[stepIndex];
            final isDone = stepIndex < currentIndex;
            final isCurrent = stepIndex == currentIndex;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? Colors.teal
                        : isCurrent
                        ? Colors.teal.shade100
                        : Colors.grey.shade200,
                    border: isCurrent ? Border.all(color: Colors.teal, width: 2) : null,
                  ),
                  child: Icon(
                    step['icon'] as IconData,
                    size: 18,
                    color: isDone
                        ? Colors.white
                        : isCurrent
                        ? Colors.teal
                        : Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step['label'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isDone || isCurrent ? Colors.teal : Colors.grey,
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// --- Action Button with Loading ---

class _ActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function() onAction;

  const _ActionButton({required this.label, required this.icon, required this.onAction});

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: _loading
            ? null
            : () async {
                setState(() => _loading = true);
                try {
                  await widget.onAction();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                  }
                } finally {
                  if (mounted) setState(() => _loading = false);
                }
              },
        icon: _loading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Icon(widget.icon),
        label: Text(widget.label),
      ),
    );
  }
}
// --- Fare Breakdown Widget ---

class _FareBreakdown extends StatelessWidget {
  final int fare;
  const _FareBreakdown({required this.fare});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Fare Transparency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            // Segmented Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    Expanded(flex: 70, child: Container(color: Colors.teal)),
                    Expanded(flex: 20, child: Container(color: Colors.amber)),
                    Expanded(flex: 10, child: Container(color: Colors.blueGrey.shade300)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _legendItem('Driver', 70, Colors.teal),
                _legendItem('Fuel', 20, Colors.amber),
                _legendItem('Platform', 10, Colors.blueGrey.shade300),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(String label, int percentage, Color color) {
    final amount = (fare * percentage) / 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }
}
