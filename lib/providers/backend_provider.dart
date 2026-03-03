import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';
import '../utils/app_logger.dart';

enum BackendStatus { checking, connected, disconnected }

class BackendState {
  final BackendStatus status;
  final String? error;
  final String baseUrl;

  BackendState({required this.status, this.error, required this.baseUrl});
}

class BackendNotifier extends AsyncNotifier<BackendState> {
  @override
  Future<BackendState> build() async {
    final baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:5000/api';
    log.i('[BACKEND] Checking connectivity → $baseUrl');
    return _checkConnection(baseUrl);
  }

  Future<BackendState> _checkConnection(String baseUrl) async {
    try {
      // Hit the root endpoint to check if backend is alive
      final rootUrl = baseUrl.replaceAll('/api', '');
      final dio = Dio(
        BaseOptions(connectTimeout: const Duration(seconds: 3), receiveTimeout: const Duration(seconds: 3)),
      );
      final response = await dio.get(rootUrl);

      if (response.statusCode == 200) {
        log.i('[BACKEND] ✅ Connected to $baseUrl');
        return BackendState(status: BackendStatus.connected, baseUrl: baseUrl);
      } else {
        log.w('[BACKEND] ⚠️ Unexpected status: ${response.statusCode}');
        return BackendState(
          status: BackendStatus.disconnected,
          error: 'Unexpected status: ${response.statusCode}',
          baseUrl: baseUrl,
        );
      }
    } on DioException catch (e) {
      log.e('[BACKEND] ❌ Cannot reach $baseUrl', error: e.message);
      return BackendState(
        status: BackendStatus.disconnected,
        error: e.message ?? 'Connection failed',
        baseUrl: baseUrl,
      );
    } catch (e) {
      log.e('[BACKEND] ❌ Unexpected error', error: e);
      return BackendState(status: BackendStatus.disconnected, error: e.toString(), baseUrl: baseUrl);
    }
  }

  Future<void> retry() async {
    final baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:5000/api';
    log.i('[BACKEND] Retrying connection to $baseUrl...');
    state = const AsyncLoading();
    state = AsyncValue.data(await _checkConnection(baseUrl));
  }
}

final backendProvider = AsyncNotifierProvider<BackendNotifier, BackendState>(BackendNotifier.new);
