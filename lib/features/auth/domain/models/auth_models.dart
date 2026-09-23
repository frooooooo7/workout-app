class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.onboardingCompleted = true,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;

  /// `false` tylko dla świeżo założonego konta, dopóki użytkownik nie
  /// przejdzie (albo nie pominie) onboardingu profilu.
  final bool onboardingCompleted;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        email: json['email'] as String,
        firstName: json['firstName'] as String,
        lastName: json['lastName'] as String,
        // Starsze API i cache sprzed onboardingu nie mają tego pola —
        // takie konta traktujemy jak skonfigurowane.
        onboardingCompleted: json['onboardingCompleted'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'onboardingCompleted': onboardingCompleted,
      };

  AuthUser copyWith({
    String? firstName,
    String? lastName,
    bool? onboardingCompleted,
  }) {
    return AuthUser(
      id: id,
      email: email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }

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
