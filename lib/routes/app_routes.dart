import 'package:flutter/material.dart';
import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/auth/register_screen.dart';
import '../presentation/screens/rider/rider_home_screen.dart';
import '../presentation/screens/driver/driver_home_screen.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> getRoutes() {
    return {
      '/': (context) => const LoginScreen(),
      '/register': (context) => const RegisterScreen(),
      '/rider_home': (context) => const RiderHomeScreen(),
      '/driver_home': (context) => const DriverHomeScreen(),
    };
  }
}
