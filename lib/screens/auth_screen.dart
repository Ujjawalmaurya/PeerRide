import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _walletController = TextEditingController();
  String _role = 'rider';
  bool _isLogin = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Login' : 'Register')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            if (!_isLogin) ...[
              DropdownButtonFormField<String>(
                value: _role,
                items: ['rider', 'driver'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) => setState(() => _role = v!),
                decoration: const InputDecoration(labelText: 'Role'),
              ),
              TextField(
                controller: _walletController,
                decoration: const InputDecoration(labelText: 'Wallet Address'),
              ),
            ],
            const SizedBox(height: 20),
            Consumer(
              builder: (context, ref, _) {
                final auth = ref.watch(authProvider);
                return ElevatedButton(
                  onPressed: auth.isLoading
                      ? null
                      : () async {
                          try {
                            if (_isLogin) {
                              await ref
                                  .read(authProvider.notifier)
                                  .login(_emailController.text, _passwordController.text);
                            } else {
                              await ref
                                  .read(authProvider.notifier)
                                  .register(
                                    _emailController.text,
                                    _passwordController.text,
                                    _role,
                                    _walletController.text,
                                  );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                          }
                        },
                  child: auth.isLoading
                      ? const CircularProgressIndicator()
                      : Text(_isLogin ? 'Login' : 'Register'),
                );
              },
            ),
            TextButton(
              onPressed: () => setState(() => _isLogin = !_isLogin),
              child: Text(_isLogin ? 'Need an account? Register' : 'Have an account? Login'),
            ),
          ],
        ),
      ),
    );
  }
}
