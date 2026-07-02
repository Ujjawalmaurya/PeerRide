import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/fare_breakdown.dart';
import '../services/payment_service.dart';
import '../providers/rides_provider.dart';
import '../providers/wallet_provider.dart';
import '../utils/app_logger.dart';

class PaymentState {
  final FareBreakdown? fareBreakdown;
  final bool isProcessing;
  final String? error;
  final bool isPaid;

  PaymentState({
    this.fareBreakdown,
    this.isProcessing = false,
    this.error,
    this.isPaid = false,
  });

  PaymentState copyWith({
    FareBreakdown? fareBreakdown,
    bool? isProcessing,
    String? error,
    bool? isPaid,
  }) {
    return PaymentState(
      fareBreakdown: fareBreakdown ?? this.fareBreakdown,
      isProcessing: isProcessing ?? this.isProcessing,
      error: error ?? this.error,
      isPaid: isPaid ?? this.isPaid,
    );
  }
}

class PaymentNotifier extends AutoDisposeAsyncNotifier<PaymentState> {
  @override
  Future<PaymentState> build() async {
    return PaymentState();
  }

  Future<void> loadFare(String rideId) async {
    state = const AsyncLoading();
    try {
      log.i('[PAYMENT_PROVIDER] Loading fare for ride: $rideId');
      final ride = await ref.read(currentRideProvider(rideId).future);
      
      // Parse fareBreakdown from ride JSON
      final breakdownData = ride.toJson()['fareBreakdown'] as Map<String, dynamic>?;
      if (breakdownData != null) {
        final breakdown = FareBreakdown.fromJson(breakdownData);
        state = AsyncData(PaymentState(fareBreakdown: breakdown));
      } else {
        // Fallback if not found
        state = AsyncData(PaymentState(
          fareBreakdown: FareBreakdown(
            baseFare: 200.0,
            distanceCharge: (ride.distanceKm * 15).toDouble(),
            ambulanceTypeSurcharge: 0.0,
            citySurcharge: 0.0,
            total: ride.fare.toDouble(),
          ),
        ));
      }
    } catch (e) {
      log.e('[PAYMENT_PROVIDER] Failed to load fare: $e');
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<Map<String, dynamic>?> payViaUPI(String rideId) async {
    state = AsyncData(state.value!.copyWith(isProcessing: true, error: null));
    try {
      final order = await ref.read(paymentServiceProvider).createOrder(rideId);
      state = AsyncData(state.value!.copyWith(isProcessing: false));
      return order;
    } catch (e) {
      log.e('[PAYMENT_PROVIDER] UPI order creation failed: $e');
      state = AsyncData(state.value!.copyWith(isProcessing: false, error: e.toString()));
      return null;
    }
  }

  Future<bool> verifyUPIPayment({
    required String rideId,
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    state = AsyncData(state.value!.copyWith(isProcessing: true, error: null));
    try {
      final success = await ref.read(paymentServiceProvider).verifyPayment(
            rideId: rideId,
            orderId: orderId,
            paymentId: paymentId,
            signature: signature,
          );
      
      if (success) {
        state = AsyncData(state.value!.copyWith(isProcessing: false, isPaid: true));
        ref.invalidate(ridesProvider);
        ref.invalidate(currentRideProvider(rideId));
      } else {
        state = AsyncData(state.value!.copyWith(isProcessing: false, error: 'Signature verification failed.'));
      }
      return success;
    } catch (e) {
      log.e('[PAYMENT_PROVIDER] UPI verification failed: $e');
      state = AsyncData(state.value!.copyWith(isProcessing: false, error: e.toString()));
      return false;
    }
  }

  Future<bool> payViaWallet(String rideId) async {
    state = AsyncData(state.value!.copyWith(isProcessing: true, error: null));
    try {
      final dio = ref.read(dioProvider);
      log.i('[PAYMENT_PROVIDER] Paying via wallet for ride: $rideId');
      
      final response = await dio.post(
        'wallet/pay',
        data: {'rideId': rideId},
      );

      if (response.statusCode == 200) {
        state = AsyncData(state.value!.copyWith(isProcessing: false, isPaid: true));
        ref.invalidate(ridesProvider);
        ref.invalidate(currentRideProvider(rideId));
        ref.invalidate(walletProvider);
        return true;
      }
      
      throw Exception(response.data['message'] ?? 'Payment failed');
    } catch (e) {
      log.e('[PAYMENT_PROVIDER] Wallet payment failed: $e');
      state = AsyncData(state.value!.copyWith(isProcessing: false, error: e.toString()));
      return false;
    }
  }
}

final paymentProvider = AutoDisposeAsyncNotifierProvider<PaymentNotifier, PaymentState>(PaymentNotifier.new);
