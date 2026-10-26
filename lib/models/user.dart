class User {
  const User({
    required this.id,
    required this.name,
    required this.username,
    required this.pinHash,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String username;
  final String pinHash;
  final String role;
  final bool isActive;
  final String createdAt;

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int,
      name: map['name'] as String,
      username: map['username'] as String,
      pinHash: map['pin_hash'] as String,
      role: map['role'] as String,
      isActive: (map['is_active'] as int?) == 1,
      createdAt: map['created_at'] as String,
    );
  }
}
