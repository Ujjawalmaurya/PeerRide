import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/auth_provider.dart';
import '../providers/sos_provider.dart';
import 'city_unavailable_screen.dart';
import 'payment_screen.dart';
import 'tracking_screen.dart';
import '../utils/app_logger.dart';

class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _holdTimer;
  double _holdProgress = 0.0;
  bool _isHolding = false;
  bool _isBooking = false;

  // Optional Patient Info fields
  final _nameController = TextEditingController(text: 'John Doe');
  final _conditionController = TextEditingController(text: 'Cardiac');
  final _bloodController = TextEditingController(text: 'O+');
  final _allergiesController = TextEditingController(text: 'Penicillin');
  bool _showPatientForm = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _holdTimer?.cancel();
    _nameController.dispose();
    _conditionController.dispose();
    _bloodController.dispose();
    _allergiesController.dispose();
    super.dispose();
  }

  void _onHoldStart() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isHolding = true;
      _holdProgress = 0.0;
    });

    const tick = Duration(milliseconds: 30);
    int elapsed = 0;
    
    _holdTimer = Timer.periodic(tick, (timer) {
      elapsed += 30;
      setState(() {
        _holdProgress = elapsed / 3000.0; // 3 seconds hold
      });

      // Provide subtle micro-haptics during hold
      if (elapsed % 300 == 0) {
        HapticFeedback.lightImpact();
      }

      if (elapsed >= 3000) {
        timer.cancel();
        _onHoldComplete();
      }
    });
  }

  void _onHoldEnd() {
    _holdTimer?.cancel();
    setState(() {
      _isHolding = false;
      _holdProgress = 0.0;
    });
  }

  Future<void> _onHoldComplete() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _isHolding = false;
      _holdProgress = 0.0;
      _isBooking = true;
    });

    try {
      log.i('[SOS] SOS hold complete! Requesting location...');
      
      // Request GPS permissions & coordinates
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final lat = position.latitude;
      final lng = position.longitude;
      log.i('[SOS] GPS Grabbed: lat=$lat, lng=$lng');

      // Book SOS via provider
      final sosNotifier = ref.read(sosProvider.notifier);
      final bookingResult = await sosNotifier.bookSOS(
        pickup: '$lat,$lng',
        patientInfo: {
          'name': _nameController.text.trim(),
          'condition': _conditionController.text.trim(),
          'bloodGroup': _bloodController.text.trim(),
          'allergies': _allergiesController.text.trim(),
        },
        ambulanceType: 'basic', // default type
      );

      if (!mounted) return;

      if (bookingResult.serviceUnavailable) {
        // Redirection to city unavailable waitlist screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CityUnavailableScreen(
              lat: lat,
              lng: lng,
              nearestCity: bookingResult.nearestCity,
            ),
          ),
        );
      } else if (bookingResult.success && bookingResult.ride != null) {
        final ride = bookingResult.ride!;
        
        if (ride['paymentStatus'] == 'waived' || ride['paymentStatus'] == 'insurance') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SOS Booked! Routing to live tracking...'), backgroundColor: Colors.green),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => TrackingScreen(rideId: ride['id'])),
          );
        } else {
          // Navigate to PaymentScreen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentScreen(
                rideId: ride['id'],
                fare: (ride['fare'] as num).toDouble(),
                familyShareUrl: bookingResult.familyShareUrl,
              ),
            ),
          );
        }
      } else {
        throw Exception(bookingResult.errorMessage ?? 'Booking failed');
      }

    } catch (e) {
      log.e('[SOS] Booking failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Emergency Booking Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBooking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'AmbulanceChain',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Press and hold the SOS button for 3 seconds',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              // SOS Button hold trigger
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTapDown: (_) => _isBooking ? null : _onHoldStart(),
                    onTapUp: (_) => _onHoldEnd(),
                    onTapCancel: () => _onHoldEnd(),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Pulse Glow Rings
                        if (!_isBooking)
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Container(
                                width: 220 + (_pulseController.value * 40),
                                height: 220 + (_pulseController.value * 40),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.red.withOpacity(0.15 * (1.0 - _pulseController.value)),
                                ),
                              );
                            },
                          ),
                        
                        // Hold Progress Ring
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: CircularProgressIndicator(
                            value: _holdProgress,
                            strokeWidth: 8,
                            backgroundColor: Colors.grey.withOpacity(0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
                          ),
                        ),
                        
                        // Inner Red button
                        Container(
                          width: 175,
                          height: 175,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.4),
                                blurRadius: 16,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isBooking
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.emergency_share_rounded,
                                        size: 44,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _isHolding ? 'HOLDING...' : 'SOS',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 22,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              
              // Patient form toggle
              TextButton.icon(
                onPressed: () => setState(() => _showPatientForm = !_showPatientForm),
                icon: Icon(_showPatientForm ? Icons.expand_less : Icons.expand_more),
                label: const Text('Add Patient & Medical Info (Optional)'),
              ),

              if (_showPatientForm) ...[
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Patient Name'),
                        ),
                        TextField(
                          controller: _conditionController,
                          decoration: const InputDecoration(labelText: 'Emergency Medical Condition'),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _bloodController,
                                decoration: const InputDecoration(labelText: 'Blood Group'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: _allergiesController,
                                decoration: const InputDecoration(labelText: 'Known Allergies'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ] else
                const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
