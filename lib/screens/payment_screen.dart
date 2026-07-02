import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../providers/payment_provider.dart';
import '../providers/wallet_provider.dart';
import '../utils/app_logger.dart';
import 'tracking_screen.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final String rideId;
  final double fare;
  final String? familyShareUrl;

  const PaymentScreen({
    super.key,
    required this.rideId,
    required this.fare,
    this.familyShareUrl,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  late Razorpay _razorpay;
  String? _lastOrderId;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    
    // Load fare breakdown
    Future.microtask(() {
      ref.read(paymentProvider.notifier).loadFare(widget.rideId);
    });
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    log.i('[PAYMENT] Razorpay payment success: ${response.paymentId}');
    
    final success = await ref.read(paymentProvider.notifier).verifyUPIPayment(
          rideId: widget.rideId,
          orderId: response.orderId ?? _lastOrderId ?? '',
          paymentId: response.paymentId ?? '',
          signature: response.signature ?? '',
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment Successful! Dispatching ambulance.'), backgroundColor: Colors.green),
      );
      // Navigate to tracking
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => TrackingScreen(rideId: widget.rideId)),
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    log.e('[PAYMENT] Razorpay payment error: ${response.code} - ${response.message}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment Failed: ${response.message}'), backgroundColor: Colors.red),
    );
  }

  Future<void> _startUPIPayment() async {
    final paymentState = ref.read(paymentProvider).value;
    if (paymentState == null || paymentState.isProcessing) return;

    // 1. Create order
    final order = await ref.read(paymentProvider.notifier).payViaUPI(widget.rideId);
    if (order == null) return;

    _lastOrderId = order['orderId'];

    // 2. Open Razorpay Checkout
    final options = {
      'key': order['keyId'],
      'amount': order['amount'], // in paise
      'name': 'AmbulanceChain',
      'order_id': order['orderId'],
      'description': 'Emergency Booking Payment',
      'timeout': 300,
      'prefill': {
        'contact': '9876543210',
        'email': 'patient@ambulancechain.com',
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      log.e('[PAYMENT] Failed to open Razorpay: $e');
    }
  }

  Future<void> _startWalletPayment() async {
    final balance = ref.read(walletProvider).value ?? 0;

    if (balance < widget.fare) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient wallet balance. You have ₹$balance, but need ₹${widget.fare}.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final success = await ref.read(paymentProvider.notifier).payViaWallet(widget.rideId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escrow payment successful! Dispatching ambulance.'), backgroundColor: Colors.green),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => TrackingScreen(rideId: widget.rideId)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentAsync = ref.watch(paymentProvider);
    final walletAsync = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ambulance Checkout'),
      ),
      body: paymentAsync.when(
        data: (state) {
          final breakdown = state.fareBreakdown;
          if (breakdown == null) {
            return const Center(child: Text('Failed to load fare details'));
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Fare Breakdown',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  // Breakdown card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          _buildFareRow('Base Fare', '₹${breakdown.baseFare.toStringAsFixed(0)}'),
                          const SizedBox(height: 12),
                          _buildFareRow('Distance Charge', '₹${breakdown.distanceCharge.toStringAsFixed(0)}'),
                          const SizedBox(height: 12),
                          _buildFareRow('Surcharge (Ambulance Type)', '₹${breakdown.ambulanceTypeSurcharge.toStringAsFixed(0)}'),
                          if (breakdown.citySurcharge > 0) ...[
                            const SizedBox(height: 12),
                            _buildFareRow('City Demand Charge', '₹${breakdown.citySurcharge.toStringAsFixed(0)}', isSurcharge: true),
                          ],
                          const Divider(height: 32, thickness: 1),
                          _buildFareRow(
                            'Total Amount Due',
                            '₹${breakdown.total.toStringAsFixed(0)}',
                            isTotal: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const Spacer(),

                  if (state.error != null) ...[
                    Text(
                      state.error!,
                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Payment Buttons
                  ElevatedButton(
                    onPressed: state.isProcessing ? null : _startUPIPayment,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: state.isProcessing
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Pay via UPI / Card', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                  
                  // Wallet Button
                  OutlinedButton(
                    onPressed: state.isProcessing ? null : _startWalletPayment,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: walletAsync.when(
                      data: (balance) => Text(
                        'Pay via Wallet (Balance: ₹$balance)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      loading: () => const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      error: (_, __) => const Text('Pay via Wallet Escrow'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading checkout: $err')),
      ),
    );
  }

  Widget _buildFareRow(String label, String value, {bool isTotal = false, bool isSurcharge = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isSurcharge ? Colors.orange : null,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 22 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.bold,
            color: isTotal ? Colors.redAccent : (isSurcharge ? Colors.orange : null),
          ),
        ),
      ],
    );
  }
}
