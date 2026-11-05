class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.onboardingCompleted = true,
    this.createdAt,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;

  /// `false` tylko dla świeżo założonego konta, dopóki użytkownik nie
  /// przejdzie (albo nie pominie) onboardingu profilu.
  final bool onboardingCompleted;

  /// Założenie konta — od tego dnia liczy się miesiąc PRO. Brak w starszym
  /// API i cache; wtedy nie pokazujemy żadnych ekranów PRO.
  final DateTime? createdAt;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    email: json['email'] as String,
    firstName: json['firstName'] as String,
    lastName: json['lastName'] as String,
    // Starsze API i cache sprzed onboardingu nie mają tego pola —
    // takie konta traktujemy jak skonfigurowane.
    onboardingCompleted: json['onboardingCompleted'] as bool? ?? true,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'firstName': firstName,
    'lastName': lastName,
    'onboardingCompleted': onboardingCompleted,
    if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
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
      createdAt: createdAt,
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
