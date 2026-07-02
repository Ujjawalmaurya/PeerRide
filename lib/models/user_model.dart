class User {
  final String id;
  final String email;
  final String role;
  final String walletAddress;
  final String verificationStatus; // 'none' | 'pending' | 'approved' | 'rejected'

  User({
    required this.id,
    required this.email,
    required this.role,
    required this.walletAddress,
    required this.verificationStatus,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      walletAddress: json['walletAddress'] ?? '',
      verificationStatus: json['verificationStatus'] ?? 'none',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'role': role,
        'walletAddress': walletAddress,
        'verificationStatus': verificationStatus,
      };
}
