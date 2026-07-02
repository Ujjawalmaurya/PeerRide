import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_provider.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showRejectDialog(String driverId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Verification'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason for Rejection',
            hintText: 'Aadhaar document blurred or invalid',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              
              Navigator.pop(context);
              final success = await ref.read(adminProvider.notifier).rejectDriver(driverId, reason);
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Driver rejected' : 'Failed to reject driver'),
                    backgroundColor: success ? Colors.orange : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Admin Console'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.verified_user_rounded), text: 'Verifications'),
            Tab(icon: Icon(Icons.analytics_rounded), text: 'Analytics & Cities'),
          ],
        ),
      ),
      body: adminState.when(
        data: (state) => TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Verifications List
            _buildVerificationsTab(state),
            // Tab 2: Analytics & Cities List
            _buildAnalyticsTab(state),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $err', style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(adminProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationsTab(AdminState state) {
    final verifications = state.pendingVerifications;

    if (verifications.isEmpty) {
      return const Center(
        child: Text(
          'No pending driver verifications.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: verifications.length,
      itemBuilder: (context, index) {
        final item = verifications[index];
        final driver = item['driverId'] ?? {};
        final driverId = driver['_id'] ?? item['driverId'];

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      driver['email'] ?? 'Driver ID: ${driverId.toString().substring(0, 8)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Chip(
                      label: const Text('PENDING', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      backgroundColor: Colors.amber.withOpacity(0.15),
                    )
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Wallet: ${driver['walletAddress'] ?? 'Unlinked'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                const Text('Uploaded Documents:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                _buildDocumentLink('Aadhaar Card URL', item['aadhaarUrl']),
                _buildDocumentLink('Vehicle Registration Card', item['vehicleRegUrl']),
                _buildDocumentLink('Ambulance Permit URL', item['ambulancePermitUrl']),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: state.isProcessing ? null : () => _showRejectDialog(driverId),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: state.isProcessing
                            ? null
                            : () async {
                                final success = await ref.read(adminProvider.notifier).approveDriver(driverId);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(success ? 'Driver approved' : 'Approval failed'),
                                      backgroundColor: success ? Colors.green : Colors.red,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDocumentLink(String label, String? url) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, size: 18, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (url != null)
            TextButton(
              onPressed: () {
                // Link opens in browser
              },
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
              child: const Text('View Document', style: TextStyle(fontSize: 12)),
            )
          else
            const Text('Not Uploaded', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab(AdminState state) {
    final stats = state.stats ?? {};
    final driverStats = stats['drivers'] ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row of stats cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Active Ambulances',
                  '${driverStats['active'] ?? 0}/${driverStats['total'] ?? 0}',
                  Icons.local_shipping_rounded,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Rides Today',
                  '${stats['ridesToday'] ?? 0}',
                  Icons.airline_seat_flat_angled_rounded,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMetricCard(
            "Today's Revenue",
            '₹${stats['revenueToday'] ?? 0}',
            Icons.account_balance_wallet_rounded,
            Colors.purple,
          ),
          
          const SizedBox(height: 24),
          const Text(
            'Active Coverage Cities',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),
          
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.cities.length,
            itemBuilder: (context, index) {
              final city = state.cities[index];
              final cityStats = city['stats'] ?? {};
              final isActive = city['isActive'] ?? true;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  child: Icon(
                    Icons.location_city_rounded,
                    color: isActive ? Colors.green : Colors.red,
                  ),
                ),
                title: Text('${city['name']}, ${city['state']}'),
                subtitle: Text('Demand Multiplier: ${city['surchargeMultiplier']}x'),
                trailing: Text(
                  '${cityStats['activeDrivers'] ?? 0} active / ${cityStats['ridesToday'] ?? 0} rides',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
