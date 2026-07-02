import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../providers/auth_provider.dart';
import '../utils/app_logger.dart';

class SOSState {
  final Map<String, dynamic>? ride;
  final bool isBooking;
  final String? errorMessage;
  final String? paymentStatus;
  final String? familyShareUrl;
  final bool serviceUnavailable;
  final String? nearestCity;

  SOSState({
    this.ride,
    this.isBooking = false,
    this.errorMessage,
    this.paymentStatus,
    this.familyShareUrl,
    this.serviceUnavailable = false,
    this.nearestCity,
  });

  SOSState copyWith({
    Map<String, dynamic>? ride,
    bool? isBooking,
    String? errorMessage,
    String? paymentStatus,
    String? familyShareUrl,
    bool? serviceUnavailable,
    String? nearestCity,
  }) {
    return SOSState(
      ride: ride ?? this.ride,
      isBooking: isBooking ?? this.isBooking,
      errorMessage: errorMessage ?? this.errorMessage,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      familyShareUrl: familyShareUrl ?? this.familyShareUrl,
      serviceUnavailable: serviceUnavailable ?? this.serviceUnavailable,
      nearestCity: nearestCity ?? this.nearestCity,
    );
  }
}

class SOSBookingResult {
  final bool success;
  final bool serviceUnavailable;
  final String? nearestCity;
  final String? familyShareUrl;
  final Map<String, dynamic>? ride;
  final String? errorMessage;

  SOSBookingResult({
    required this.success,
    this.serviceUnavailable = false,
    this.nearestCity,
    this.familyShareUrl,
    this.ride,
    this.errorMessage,
  });
}

class SOSNotifier extends AutoDisposeAsyncNotifier<SOSState> {
  @override
  Future<SOSState> build() async {
    return SOSState();
  }

  Future<SOSBookingResult> bookSOS({
    required String pickup,
    Map<String, dynamic>? patientInfo,
    String ambulanceType = 'basic',
  }) async {
    state = AsyncData(SOSState(isBooking: true));
    try {
      final dio = ref.read(dioProvider);
      
      final response = await dio.post(
        'sos/sos',
        data: {
          'pickup': pickup,
          'patientInfo': patientInfo,
          'ambulanceType': ambulanceType,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data;
        final ride = data['ride'] as Map<String, dynamic>;
        final familyShareUrl = data['familyShareUrl'] as String?;
        final paymentStatus = ride['paymentStatus'] as String?;

        state = AsyncData(SOSState(
          ride: ride,
          familyShareUrl: familyShareUrl,
          paymentStatus: paymentStatus,
          isBooking: false,
        ));

        return SOSBookingResult(
          success: true,
          familyShareUrl: familyShareUrl,
          ride: ride,
        );
      }
      
      throw Exception('Unexpected response status: ${response.statusCode}');
    } on DioException catch (e) {
      log.e('[SOS_PROVIDER] Booking network request failed: ${e.message}');
      
      if (e.response?.statusCode == 422) {
        final data = e.response?.data;
        if (data is Map && data['error'] == 'SERVICE_NOT_AVAILABLE') {
          final nearestCity = data['nearestCity'] as String?;
          state = AsyncData(SOSState(
            serviceUnavailable: true,
            nearestCity: nearestCity,
            isBooking: false,
          ));
          return SOSBookingResult(
            success: false,
            serviceUnavailable: true,
            nearestCity: nearestCity,
          );
        }
      }

      final errMsg = e.response?.data?['message'] ?? e.message ?? 'Unknown error';
      state = AsyncData(SOSState(
        errorMessage: errMsg,
        isBooking: false,
      ));
      return SOSBookingResult(
        success: false,
        errorMessage: errMsg,
      );
    } catch (e) {
      log.e('[SOS_PROVIDER] Booking failed: $e');
      state = AsyncData(SOSState(
        errorMessage: e.toString(),
        isBooking: false,
      ));
      return SOSBookingResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
}

final sosProvider = AutoDisposeAsyncNotifierProvider<SOSNotifier, SOSState>(SOSNotifier.new);
