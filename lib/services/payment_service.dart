import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../utils/app_logger.dart';

class PaymentService {
  final Ref _ref;

  PaymentService(this._ref);

  Future<Map<String, dynamic>?> createOrder(String rideId) async {
    try {
      final dio = _ref.read(dioProvider);
      log.i('[PAYMENT_SERVICE] Creating order for ride: $rideId');
      final response = await dio.post(
        'payment/create-order',
        data: {'rideId': rideId},
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      log.e('[PAYMENT_SERVICE] Create order failed: $e');
      return null;
    }
  }

  Future<bool> verifyPayment({
    required String rideId,
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      final dio = _ref.read(dioProvider);
      log.i('[PAYMENT_SERVICE] Verifying payment for ride: $rideId, paymentId: $paymentId');
      final response = await dio.post(
        'payment/verify',
        data: {
          'rideId': rideId,
          'orderId': orderId,
          'paymentId': paymentId,
          'signature': signature,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      log.e('[PAYMENT_SERVICE] Payment verification failed: $e');
      return false;
    }
  }
}

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService(ref);
});
