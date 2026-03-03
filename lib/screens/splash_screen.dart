import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/backend_provider.dart';
import '../utils/app_logger.dart';
import 'home_screen.dart';
import 'auth_screen.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backendState = ref.watch(backendProvider);

    return backendState.when(
      data: (backend) {
        if (backend.status == BackendStatus.disconnected) {
          log.w('[SPLASH] Backend offline — showing error screen');
          return _DisconnectedScreen(error: backend.error ?? 'Unknown error', url: backend.baseUrl);
        }

        // Backend is connected, now check auth
        log.i('[SPLASH] Backend online — checking auth state');
        return _AuthGate();
      },
      loading: () => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Connecting to server...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
      error: (err, st) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }
}

class _AuthGate extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return authState.when(
      data: (auth) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (auth.user != null) {
            log.i('[SPLASH] User found → navigating to HomeScreen');
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
          } else {
            log.i('[SPLASH] No user → navigating to AuthScreen');
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen()));
          }
        });
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }
}

class _DisconnectedScreen extends ConsumerWidget {
  final String error;
  final String url;
  const _DisconnectedScreen({required this.error, required this.url});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Backend Unreachable', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Cannot connect to:\n$url',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => ref.read(backendProvider.notifier).retry(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text(
                'Make sure backend is running:\nnpm run dev (in CabContract/)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
