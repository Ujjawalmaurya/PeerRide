class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String walletAddress;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.walletAddress,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['_id'],
      name: json['name'],
      email: json['email'],
      role: json['role'],
      walletAddress: json['walletAddress'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'email': email, 'role': role, 'walletAddress': walletAddress};
  }
}
