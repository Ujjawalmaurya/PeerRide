import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/app_logger.dart';
import 'auth_provider.dart';

class WalletNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final auth = ref.watch(authProvider).value;
    if (auth?.user == null) {
      log.d('[WALLET] No user session — returning 0');
      return 0;
    }
    return _fetchBalance();
  }

  Future<int> _fetchBalance() async {
    try {
      log.i('[WALLET] Fetching balance...');
      final dio = ref.read(dioProvider);
      final response = await dio.get('wallet/balance');
      final data = response.data;
      if (data is Map && data.containsKey('balance')) {
        final balance = int.parse(data['balance'].toString());
        log.i('[WALLET] ✅ Balance: ₹$balance');
        return balance;
      }
      return 0;
    } catch (e) {
      log.e('[WALLET] Failed to fetch balance: $e');
      return 0;
    }
  }

  Future<String> addMoney(int amount) async {
    log.i('[WALLET] Adding ₹$amount...');
    final dio = ref.read(dioProvider);
    final response = await dio.post('wallet/add-money', data: {'amount': amount});
    final txHash = response.data['txHash'] as String;
    log.i('[WALLET] ✅ Added ₹$amount | txHash: $txHash');

    ref.invalidateSelf();
    return txHash;
  }
}

final walletProvider = AsyncNotifierProvider<WalletNotifier, int>(WalletNotifier.new);
