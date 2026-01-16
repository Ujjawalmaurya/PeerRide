import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/utils/shared_prefs.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/ride_provider.dart';
import 'routes/app_routes.dart';
import 'core/constants/app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPrefs.init();
  runApp(const P2PRideApp());
}

class P2PRideApp extends StatelessWidget {
  const P2PRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RideProvider()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
        initialRoute: '/',
        routes: AppRoutes.getRoutes(),
      ),
    );
  }
}
