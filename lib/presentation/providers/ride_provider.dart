import 'package:flutter/material.dart';
import '../../data/models/ride_model.dart';
import '../../data/repositories/ride_repository.dart';

class RideProvider extends ChangeNotifier {
  final RideRepository _rideRepository = RideRepository();
  List<RideModel> _availableRides = [];
  List<RideModel> _rideHistory = [];
  bool _isLoading = false;
  String? _error;

  List<RideModel> get availableRides => _availableRides;
  List<RideModel> get rideHistory => _rideHistory;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchAvailableRides() async {
    _isLoading = true;
    notifyListeners();
    try {
      _availableRides = await _rideRepository.getAvailableRides();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchRideHistory() async {
    _isLoading = true;
    notifyListeners();
    try {
      _rideHistory = await _rideRepository.getRideHistory();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> requestRide(LocationModel pickup, LocationModel drop, double fare) async {
    try {
      await _rideRepository.requestRide(pickup: pickup, drop: drop, fare: fare);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }
}
