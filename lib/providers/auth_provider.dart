import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import '../models/user_model.dart';

// We'll define the dioProvider later, but for now we use a basic instance
final dioProvider = Provider<Dio>((ref) {
  final baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:5000/api';

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
        return handler.next(options);
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
    final token = await _storage.read(key: 'jwt');
    final userJson = await _storage.read(key: 'user');

    if (token != null && userJson != null) {
      return AuthState(user: User.fromJson(jsonDecode(userJson)), token: token);
    }
    return AuthState();
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('/auth/login', data: {'email': email, 'password': password});

      final token = response.data['token'];
      final user = User.fromJson(response.data['user']);

      await _storage.write(key: 'jwt', value: token);
      await _storage.write(key: 'user', value: jsonEncode(user.toJson()));

      state = AsyncValue.data(AuthState(user: user, token: token));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> register(String email, String password, String role, String walletAddress) async {
    state = const AsyncLoading();
    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        '/auth/register',
        data: {'email': email, 'password': password, 'role': role, 'walletAddress': walletAddress},
      );
      // After register, you might want to call login or notify success
      await login(email, password);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    state = AsyncValue.data(AuthState());
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
