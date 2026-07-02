import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/ride_model.dart';
import '../providers/auth_provider.dart';
import '../providers/rides_provider.dart';
import '../providers/tracking_provider.dart';
import '../providers/wallet_provider.dart';
import '../utils/app_logger.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  final String rideId;
  final String? familyToken;

  const TrackingScreen({
    super.key,
    required this.rideId,
    this.familyToken,
  });

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    // Initialize live tracking via Socket
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(trackingProvider.notifier).initTracking(
            widget.rideId,
            familyToken: widget.familyToken,
          );
    });
  }

  void _updateMarkers(TrackingState state, double pickupLat, double pickupLng, double dropLat, double dropLng) {
    _markers.clear();

    // 1. Pickup Marker (Red)
    _markers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(pickupLat, pickupLng),
        infoWindow: const InfoWindow(title: 'Pickup Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );

    // 2. Drop/Hospital Marker (Green)
    _markers.add(
      Marker(
        markerId: const MarkerId('drop'),
        position: LatLng(dropLat, dropLng),
        infoWindow: const InfoWindow(title: 'Hospital / Destination'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    );

    // 3. Driver Marker (Blue/Ambulance representation)
    if (state.driverLat != null && state.driverLng != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(state.driverLat!, state.driverLng!),
          rotation: state.heading,
          infoWindow: InfoWindow(
            title: 'Ambulance',
            snippet: 'Speed: ${state.speed.toStringAsFixed(1)} km/h',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );

      // Smoothly animate map camera to focus on driver
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(LatLng(state.driverLat!, state.driverLng!)),
        );
      }
    }
  }

  void _fitMapBounds(double pLat, double pLng, double dLat, double dLng, double? drLat, double? drLng) {
    if (_mapController == null) return;

    double minLat = pLat;
    double maxLat = pLat;
    double minLng = pLng;
    double maxLng = pLng;

    final coords = [
      LatLng(pLat, pLng),
      LatLng(dLat, dLng),
      if (drLat != null && drLng != null) LatLng(drLat, drLng),
    ];

    for (final c in coords) {
      if (c.latitude < minLat) minLat = c.latitude;
      if (c.latitude > maxLat) maxLat = c.latitude;
      if (c.longitude < minLng) minLng = c.longitude;
      if (c.longitude > maxLng) maxLng = c.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.005, minLng - 0.005),
          northeast: LatLng(maxLat + 0.005, maxLng + 0.005),
        ),
        50,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(trackingProvider);
    final rideAsync = ref.watch(currentRideProvider(widget.rideId));
    final auth = ref.watch(authProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking'),
        actions: [
          if (trackingState.isConnected)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Icon(Icons.wifi, color: Colors.green),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Icon(Icons.wifi_off, color: Colors.red),
            ),
        ],
      ),
      body: rideAsync.when(
        data: (ride) {
          final pLat = ride.startLat ?? 0.0;
          final pLng = ride.startLng ?? 0.0;
          final dLat = ride.endLat ?? 0.0;
          final dLng = ride.endLng ?? 0.0;

          // Rebuild map markers dynamically
          _updateMarkers(trackingState, pLat, pLng, dLat, dLng);

          final initialCamera = LatLng(
            trackingState.driverLat ?? pLat,
            trackingState.driverLng ?? pLng,
          );

          return Stack(
            children: [
              // 1. Google Map View
              GoogleMap(
                initialCameraPosition: CameraPosition(target: initialCamera, zoom: 14),
                markers: _markers,
                myLocationButtonEnabled: false,
                onMapCreated: (controller) {
                  _mapController = controller;
                  // Autofit bounds initially
                  _fitMapBounds(pLat, pLng, dLat, dLng, trackingState.driverLat, trackingState.driverLng);
                },
              ),

              // 2. Offline Status Banner
              if (trackingState.isDriverOffline)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    color: Colors.red.shade100,
                    child: const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Driver is currently offline. Attempting to reconnect...',
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 3. Info Overlay Card
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ride: #${widget.rideId.substring(widget.rideId.length - 6).toUpperCase()}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor(trackingState.status, ride.status),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _getStatusText(trackingState.status, ride.status),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            const Icon(Icons.timer, color: Colors.teal),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Estimated Arrival (ETA)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                Text(
                                  trackingState.etaMinutes != null
                                      ? '${trackingState.etaMinutes!.toStringAsFixed(0)} mins'
                                      : 'Calculating...',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.center_focus_strong, color: Colors.teal),
                              tooltip: 'Recenter Map',
                              onPressed: () => _fitMapBounds(
                                pLat,
                                pLng,
                                dLat,
                                dLng,
                                trackingState.driverLat,
                                trackingState.driverLng,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Actions inside sheet
                        _buildActionButtons(context, auth, ride, trackingState),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text('Error: $err'),
              TextButton(
                onPressed: () => ref.invalidate(currentRideProvider(widget.rideId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, AuthState? auth, Ride ride, TrackingState trackState) {
    final isDriver = auth?.user != null && auth!.user!.role == 'driver';

    if (isDriver) {
      // Driver action buttons for status updates
      if (ride.status == 'accepted') {
        if (trackState.status == 'arrived') {
          return const SizedBox(
            width: double.infinity,
            child: Card(
              color: Colors.tealAccent,
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  'Waiting for Rider to start the ride and lock the funds on-chain.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                ),
              ),
            ),
          );
        }

        return _ActionButton(
          label: 'Arrived at Pickup',
          icon: Icons.store,
          onAction: () async {
            await ref.read(trackingProvider.notifier).updateDriverStatus(widget.rideId, 'arrived');
          },
        );
      }

      if (ride.status == 'started') {
        return _ActionButton(
          label: 'Complete Ride (Release Funds)',
          icon: Icons.done_all,
          onAction: () async {
            final tx = await ref.read(ridesProvider.notifier).endRide(widget.rideId);
            await ref.read(trackingProvider.notifier).updateDriverStatus(widget.rideId, 'completed');
            if (context.mounted) {
              _showTxDialog(context, 'Escrow Complete', tx);
            }
          },
        );
      }
    } else {
      // Rider action buttons
      if (ride.status == 'accepted') {
        return Column(
          children: [
            const Text(
              'Once the driver arrives, start the ride to lock the escrow fare.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            _ActionButton(
              label: 'Start Ride (Lock Funds)',
              icon: Icons.lock,
              onAction: () async {
                final balance = ref.read(walletProvider).value ?? 0;
                if (balance < ride.fare) {
                  _showInsufficientFundsDialog(context, ride.fare, balance);
                  return;
                }
                final tx = await ref.read(ridesProvider.notifier).startRide(widget.rideId);
                await ref.read(trackingProvider.notifier).updateDriverStatus(widget.rideId, 'transporting');
                if (context.mounted) {
                  _showTxDialog(context, 'Escrow Lock Initiated', tx);
                }
              },
            ),
          ],
        );
      }
    }

    return const SizedBox.shrink();
  }

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

  void _showInsufficientFundsDialog(BuildContext context, int fare, num balance) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Insufficient Funds'),
        content: Text(
          'You need ₹$fare in your wallet to start this ride.\n\n'
          'Current balance: ₹$balance\n'
          'Shortfall: ₹${fare - balance}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  Color _getStatusColor(String trackStatus, String rideStatus) {
    if (rideStatus == 'completed') return Colors.blue;
    switch (trackStatus) {
      case 'enroute':
        return Colors.amber;
      case 'arrived':
        return Colors.purple;
      case 'transporting':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String trackStatus, String rideStatus) {
    if (rideStatus == 'completed') return 'Completed';
    switch (trackStatus) {
      case 'enroute':
        return 'Enroute to Pickup';
      case 'arrived':
        return 'Arrived at Pickup';
      case 'transporting':
        return 'Transporting patient';
      case 'completed':
        return 'Completed';
      default:
        return rideStatus.toUpperCase();
    }
  }
}

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
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: _loading
            ? null
            : () async {
                setState(() => _loading = true);
                try {
                  await widget.onAction();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Action failed: $e'), backgroundColor: Colors.red),
                    );
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
        label: Text(widget.label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
