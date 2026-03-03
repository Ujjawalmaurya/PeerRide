import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import '../models/user_model.dart';
import '../utils/app_logger.dart';

final dioProvider = Provider<Dio>((ref) {
  final baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:1205/api/';
  log.i('[DIO] Base URL → $baseUrl');

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 3),
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        const storage = FlutterSecureStorage();
        final token = await storage.read(key: 'jwt');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        final fullUrl = '${options.baseUrl}${options.path}';
        log.d('[DIO] ${options.method} → $fullUrl');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        log.d('[DIO] ← ${response.statusCode} ${response.requestOptions.path}');
        return handler.next(response);
      },
      onError: (error, handler) {
        final data = error.response?.data;
        String? errorMsg;
        String? detail;
        if (data is Map) {
          errorMsg = data['message']?.toString();
          detail = data['error']?.toString();
        } else {
          errorMsg = data?.toString();
        }

        log.e('[DIO] ✗ ${error.requestOptions.path}', error: detail ?? errorMsg ?? error.message);
        return handler.next(error);
      },
    ),
  );

  return dio;
});

class AuthState {
  final User? user;
  final String? token;

  AuthState({this.user, this.token});
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  final _storage = const FlutterSecureStorage();

  @override
  Future<AuthState> build() async {
    log.i('[AUTH] Checking stored session...');
    final token = await _storage.read(key: 'jwt');
    final userJson = await _storage.read(key: 'user');

    if (token != null && userJson != null) {
      final user = User.fromJson(jsonDecode(userJson));
      log.i('[AUTH] Restored session for ${user.email} (${user.role})');
      return AuthState(user: user, token: token);
    }
    log.i('[AUTH] No stored session found');
    return AuthState();
  }

  Future<void> login(String email, String password) async {
    log.i('[AUTH] Login attempt → $email');
    state = const AsyncLoading();
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('auth/login', data: {'email': email, 'password': password});

      final token = response.data['token'];
      final user = User.fromJson(response.data['user']);

      await _storage.write(key: 'jwt', value: token);
      await _storage.write(key: 'user', value: jsonEncode(user.toJson()));

      log.i('[AUTH] ✅ Login success → ${user.email} (${user.role})');
      state = AsyncValue.data(AuthState(user: user, token: token));
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map) ? (data['message']?.toString() ?? e.message) : e.message;
      log.w('[AUTH] ✗ Login failed → $msg');
      state = AsyncValue.error(msg ?? 'Login failed', StackTrace.current);
    } catch (e, st) {
      log.e('[AUTH] ✗ Login error', error: e);
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> register(String email, String password, String role, String walletAddress) async {
    log.i('[AUTH] Register attempt → $email as $role');
    state = const AsyncLoading();
    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        'auth/register',
        data: {
          'email': email.trim(),
          'password': password.trim(),
          'role': role,
          'walletAddress': walletAddress.trim(),
        },
      );
      log.i('[AUTH] ✅ Registration success → ${email.trim()}');
      await login(email, password);
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map) ? (data['message']?.toString() ?? e.message) : e.message;
      log.w('[AUTH] ✗ Register failed → $msg');
      state = AsyncValue.error(msg ?? 'Registration failed', StackTrace.current);
    } catch (e, st) {
      log.e('[AUTH] ✗ Register error', error: e);
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    log.i('[AUTH] Logging out...');
    await _storage.deleteAll();
    log.i('[AUTH] ✅ Session cleared');
    state = AsyncValue.data(AuthState());
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
