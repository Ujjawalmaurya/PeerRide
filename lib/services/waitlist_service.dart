import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../utils/app_logger.dart';

class WaitlistService {
  final Ref _ref;

  WaitlistService(this._ref);

  Future<bool> joinWaitlist({
    required double lat,
    required double lng,
    required String contact,
    required String city,
  }) async {
    try {
      final dio = _ref.read(dioProvider);
      log.i('[WAITLIST] Requesting waitlist for city: $city, contact: $contact');
      
      final response = await dio.post(
        'sos/waitlist',
        data: {
          'lat': lat,
          'lng': lng,
          'contact': contact,
          'city': city,
        },
      );
      
      log.i('[WAITLIST] Response status: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      log.e('[WAITLIST] Join waitlist failed: $e');
      return false;
    }
  }
}

final waitlistServiceProvider = Provider<WaitlistService>((ref) {
  return WaitlistService(ref);
});
