import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import 'home_screen.dart';
import '../utils/app_logger.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController(text: '123456');
  final _walletController = TextEditingController();
  String _role = 'rider';
  bool _isLogin = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _walletController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    // Robust navigation listener
    ref.listen(authProvider, (prev, next) {
      log.d('[AUTH] State changed: ${prev?.hasValue} -> ${next.hasValue}');

      if (next.hasError) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error.toString()), backgroundColor: Colors.red));
      } else if (next.hasValue && next.value?.user != null) {
        log.i('[AUTH] Redirecting to HomeScreen...');

        // Success notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isLogin ? 'Welcome back!' : 'Account created successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Use pushAndRemoveUntil to clear navigation stack
        Navigator.of(
          context,
        ).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Login' : 'Register')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.directions_car, size: 64, color: Colors.teal),
            const SizedBox(height: 16),
            Text(
              _isLogin ? 'Welcome Back' : 'Join P2P Cab',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                hintText: 'e.g. rider',
                suffixText: ' @cab.in',
                suffixStyle: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            if (!_isLogin) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _role,
                items: [
                  'rider',
                  'driver',
                ].map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(),
                onChanged: (v) => setState(() => _role = v!),
                decoration: const InputDecoration(
                  labelText: 'Your Role',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _walletController,
                decoration: const InputDecoration(
                  labelText: 'Wallet Address',
                  prefixIcon: Icon(Icons.account_balance_wallet),
                  hintText: '0x...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: auth.isLoading
                  ? null
                  : () async {
                      FocusScope.of(context).unfocus();
                      var email = _emailController.text.trim();
                      final pw = _passwordController.text.trim();
                      final wallet = _walletController.text.trim();

                      if (email.isEmpty || pw.isEmpty) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
                        return;
                      }

                      if (!email.contains('@')) {
                        email = '$email@cab.in';
                      }

                      log.i('[AUTH] Processing ${_isLogin ? 'Login' : 'Register'} → $email');

                      try {
                        if (_isLogin) {
                          await ref.read(authProvider.notifier).login(email, pw);
                        } else {
                          if (wallet.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Wallet address is required for registration')),
                            );
                            return;
                          }
                          await ref.read(authProvider.notifier).register(email, pw, _role, wallet);
                        }

                        // Explicit navigation backup
                        final currentAuth = ref.read(authProvider);
                        if (currentAuth.hasValue && currentAuth.value?.user != null && mounted) {
                          log.i('[AUTH] Manual redirect trigger');
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const HomeScreen()),
                            (route) => false,
                          );
                        }
                      } catch (e) {
                        // Error is handled by state listener, but logging here too
                        log.e('[AUTH] Interaction failed', error: e);
                      }
                    },
              child: auth.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(_isLogin ? 'LOGIN' : 'REGISTER'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _isLogin = !_isLogin),
              child: Text(_isLogin ? 'Don\'t have an account? Register' : 'Already have an account? Login'),
            ),
          ],
        ),
      ),
    );
  }
}
