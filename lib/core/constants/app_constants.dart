import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'P2PRide';

  // Minimalist Palette
  static const Color primaryColor = Color(0xFF1A1A1A); // Almost Black
  static const Color backgroundColor = Colors.white;
  static const Color surfaceColor = Color(0xFFFAFAFA);
  static const Color inputFillColor = Color(0xFFF0F0F0);

  static const Color textBodyColor = Color(0xFF1A1A1A);
  static const Color textFadedColor = Color(0xFF818181);

  // Sizes
  static const double defaultPadding = 24.0;
  static const double borderRadius = 12.0;
  static const double inputHeight = 52.0;

  // Storage Keys
  static const String tokenKey = 'jwt_token';
  static const String userKey = 'user_data';
}
