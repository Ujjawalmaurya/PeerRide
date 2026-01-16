import '../models/ride_model.dart';
import '../services/api_service.dart';
import '../../core/config/api_config.dart';

class RideRepository {
  final ApiService _apiService = ApiService();

  Future<RideModel> requestRide({
    required LocationModel pickup,
    required LocationModel drop,
    required double fare,
  }) async {
    final response = await _apiService.post(
      ApiConfig.requestRide,
      data: {'pickupLocation': pickup.toJson(), 'dropLocation': drop.toJson(), 'fare': fare},
    );
    return RideModel.fromJson(response.data['ride']);
  }

  Future<List<RideModel>> getAvailableRides() async {
    final response = await _apiService.get(ApiConfig.availableRides);
    final List rides = response.data['rides'];
    return rides.map((e) => RideModel.fromJson(e)).toList();
  }

  Future<void> acceptRide(int rideId) async {
    await _apiService.post(ApiConfig.acceptRide(rideId));
  }

  Future<void> startRide(int rideId) async {
    await _apiService.post(ApiConfig.startRide(rideId));
  }

  Future<void> completeRide(int rideId) async {
    await _apiService.post(ApiConfig.completeRide(rideId));
  }

  Future<List<RideModel>> getRideHistory() async {
    final response = await _apiService.get(ApiConfig.rideHistory);
    final List rides = response.data['rides'];
    return rides.map((e) => RideModel.fromJson(e)).toList();
  }
}
