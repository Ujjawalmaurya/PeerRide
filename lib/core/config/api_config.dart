class ApiConfig {
  static const String baseUrl = 'http://localhost:3000/api'; // Change to your IP for physical devices

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';

  // Rides
  static const String requestRide = '/ride/request';
  static const String availableRides = '/ride/available';
  static const String rideHistory = '/ride/history';
  static String acceptRide(int id) => '/ride/$id/accept';
  static String startRide(int id) => '/ride/$id/start';
  static String completeRide(int id) => '/ride/$id/complete';

  // Wallet
  static const String getBalance = '/wallet/balance';
  static const String depositFunds = '/wallet/deposit';
}
