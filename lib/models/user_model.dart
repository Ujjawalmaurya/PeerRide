class User {
  final String id;
  final String email;
  final String role;
  final String walletAddress;

  User({required this.id, required this.email, required this.role, required this.walletAddress});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      walletAddress: json['walletAddress'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'email': email, 'role': role, 'walletAddress': walletAddress};
}
