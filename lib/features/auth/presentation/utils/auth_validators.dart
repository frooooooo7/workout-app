import 'dart:convert';

String? validateAuthEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'E-mail jest wymagany.';
  }
  final regex = RegExp(r'^[\w\-.+]+@[\w\-]+\.[a-zA-Z]{2,}$');
  if (!regex.hasMatch(value.trim())) {
    return 'Podaj prawidłowy adres e-mail.';
  }
  return null;
}

String? validateLoginPassword(String? value) {
  if (value == null || value.isEmpty) return 'Hasło jest wymagane.';
  return null;
}

/// bcrypt na serwerze bierze pod uwagę tylko 72 bajty hasła (UTF-8) —
/// dłuższe serwer odrzuca (`password_too_long`).
const kMaxPasswordBytes = 72;

String? validateRegisterPassword(String? value) {
  if (value == null || value.isEmpty) return 'Hasło jest wymagane.';
  if (value.length < 8) return 'Min. 8 znaków.';
  if (utf8.encode(value).length > kMaxPasswordBytes) {
    return 'Maks. 72 znaki.';
  }
  if (!value.contains(RegExp(r'[A-Z]'))) return 'Wymagana wielka litera.';
  if (!value.contains(RegExp(r'[0-9]'))) return 'Wymagana cyfra.';
  return null;
}
