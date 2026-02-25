import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

class WalletNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    // Re-run when auth state changes (e.g. user logs in)
    final auth = ref.watch(authProvider).value;
    if (auth?.user == null) return 0;
    return _fetchBalance();
  }

  Future<int> _fetchBalance() async {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/wallet/balance');
    return int.parse(response.data['balance'].toString());
  }

  Future<String> addMoney(int amount) async {
    final dio = ref.read(dioProvider);
    final response = await dio.post('/wallet/add-money', data: {'amount': amount});

    // Refresh balance after transaction
    ref.invalidateSelf();
    return response.data['txHash'];
  }
}

final walletProvider = AsyncNotifierProvider<WalletNotifier, int>(WalletNotifier.new);
