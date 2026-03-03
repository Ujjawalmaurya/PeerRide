import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'utils/app_logger.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  log.i('[APP] Starting P2P Cab...');
  await dotenv.load(fileName: '.env');
  log.i('[APP] Environment loaded — API_URL: ${dotenv.env['API_URL']}');
  runApp(const ProviderScope(child: CabApp()));
}

class CabApp extends StatelessWidget {
  const CabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'P2P Cab',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
