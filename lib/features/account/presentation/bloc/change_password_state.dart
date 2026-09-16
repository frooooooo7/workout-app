import '../../../auth/presentation/utils/auth_validators.dart';

class ChangePasswordState {
  const ChangePasswordState({
    this.currentPassword = '',
    this.newPassword = '',
    this.confirmPassword = '',
    this.submitting = false,
    this.error,
    this.succeeded = false,
  });

  final String currentPassword;
  final String newPassword;
  final String confirmPassword;
  final bool submitting;

  /// Błąd z serwera (po polsku).
  final String? error;

  /// Hasło zmienione, nowy token zapisany — ekran się zamyka.
  final bool succeeded;

  /// Błąd pola „Nowe hasło” — reguły jak przy rejestracji + inne niż obecne.
  /// Puste pole nie pokazuje błędu (przycisk i tak jest nieaktywny).
  String? get newPasswordError {
    if (newPassword.isEmpty) return null;
    final rule = validateRegisterPassword(newPassword);
    if (rule != null) return rule;
    if (newPassword == currentPassword) {
      return 'Nowe hasło musi różnić się od obecnego.';
    }
    return null;
  }

  String? get confirmPasswordError {
    if (confirmPassword.isEmpty) return null;
    if (confirmPassword != newPassword) return 'Hasła nie są identyczne.';
    return null;
  }

  bool get isValid =>
      currentPassword.isNotEmpty &&
      validateRegisterPassword(newPassword) == null &&
      newPassword != currentPassword &&
      confirmPassword == newPassword;

  bool get canSubmit => isValid && !submitting && !succeeded;

  ChangePasswordState copyWith({
    String? currentPassword,
    String? newPassword,
    String? confirmPassword,
    bool? submitting,
    String? error,
    bool clearError = false,
    bool? succeeded,
  }) {
    return ChangePasswordState(
      currentPassword: currentPassword ?? this.currentPassword,
      newPassword: newPassword ?? this.newPassword,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      submitting: submitting ?? this.submitting,
      error: clearError ? null : (error ?? this.error),
      succeeded: succeeded ?? this.succeeded,
    );
  }
}
