import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../utils/app_logger.dart';

class AdminState {
  final List<dynamic> pendingVerifications;
  final List<dynamic> cities;
  final Map<String, dynamic>? stats;
  final bool isProcessing;
  final String? error;

  AdminState({
    required this.pendingVerifications,
    required this.cities,
    this.stats,
    this.isProcessing = false,
    this.error,
  });

  AdminState copyWith({
    List<dynamic>? pendingVerifications,
    List<dynamic>? cities,
    Map<String, dynamic>? stats,
    bool? isProcessing,
    String? error,
  }) {
    return AdminState(
      pendingVerifications: pendingVerifications ?? this.pendingVerifications,
      cities: cities ?? this.cities,
      stats: stats ?? this.stats,
      isProcessing: isProcessing ?? this.isProcessing,
      error: error ?? this.error,
    );
  }
}

class AdminNotifier extends AutoDisposeAsyncNotifier<AdminState> {
  @override
  Future<AdminState> build() async {
    return _fetchInitialData();
  }

  Future<AdminState> _fetchInitialData() async {
    try {
      final dio = ref.read(dioProvider);
      
      final verificationsResponse = await dio.get('admin/verifications/pending');
      final statsResponse = await dio.get('admin/stats');
      final citiesResponse = await dio.get('admin/cities');

      return AdminState(
        pendingVerifications: verificationsResponse.data as List<dynamic>,
        cities: citiesResponse.data as List<dynamic>,
        stats: statsResponse.data as Map<String, dynamic>,
      );
    } catch (e) {
      log.e('[ADMIN_PROVIDER] Failed to fetch initial data: $e');
      throw Exception('Failed to load admin panel data: $e');
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchInitialData());
  }

  Future<bool> approveDriver(String driverId) async {
    try {
      final dio = ref.read(dioProvider);
      state = AsyncData(state.value!.copyWith(isProcessing: true));
      
      await dio.post('admin/verifications/$driverId/approve');
      
      log.i('[ADMIN] Approved driver: $driverId');
      await refresh();
      return true;
    } catch (e) {
      log.e('[ADMIN] Approve driver failed: $e');
      state = AsyncData(state.value!.copyWith(isProcessing: false, error: e.toString()));
      return false;
    }
  }

  Future<bool> rejectDriver(String driverId, String reason) async {
    try {
      final dio = ref.read(dioProvider);
      state = AsyncData(state.value!.copyWith(isProcessing: true));
      
      await dio.post(
        'admin/verifications/$driverId/reject',
        data: {'reason': reason},
      );
      
      log.i('[ADMIN] Rejected driver: $driverId. Reason: $reason');
      await refresh();
      return true;
    } catch (e) {
      log.e('[ADMIN] Reject driver failed: $e');
      state = AsyncData(state.value!.copyWith(isProcessing: false, error: e.toString()));
      return false;
    }
  }
}

final adminProvider = AutoDisposeAsyncNotifierProvider<AdminNotifier, AdminState>(AdminNotifier.new);
