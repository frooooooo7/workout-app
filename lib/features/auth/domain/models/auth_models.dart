class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        email: json['email'] as String,
        firstName: json['firstName'] as String,
        lastName: json['lastName'] as String,
      );

  String get fullName => '$firstName $lastName';
}

class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final AuthUser user;

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        token: json['token'] as String,
        user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      );
}
