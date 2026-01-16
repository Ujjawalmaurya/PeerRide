class WalletModel {
  final String walletAddress;
  final double balance;

  WalletModel({required this.walletAddress, required this.balance});

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(walletAddress: json['walletAddress'], balance: (json['balance'] as num).toDouble());
  }
}
