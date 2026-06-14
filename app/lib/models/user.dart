class AppUser {
  final int id;
  final String email;
  final String displayName;
  final String role;

  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      email: json['email'] as String,
      displayName: json['displayName'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
    );
  }
}
