import '../models/user_model.dart';
import '../services/api_service.dart';
import '../../core/config/api_config.dart';
import '../../core/utils/shared_prefs.dart';

class AuthRepository {
  final ApiService _apiService = ApiService();

  Future<UserModel> login(String email, String password) async {
    final response = await _apiService.post(ApiConfig.login, data: {'email': email, 'password': password});

    await SharedPrefs.setToken(response.data['token']);
    return UserModel.fromJson(response.data['user']);
  }

  Future<UserModel> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    final response = await _apiService.post(
      ApiConfig.register,
      data: {'name': name, 'email': email, 'phone': phone, 'password': password, 'role': role},
    );

    await SharedPrefs.setToken(response.data['token']);
    return UserModel.fromJson(response.data['user']);
  }
}
