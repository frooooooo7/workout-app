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

String? validateRegisterPassword(String? value) {
  if (value == null || value.isEmpty) return 'Hasło jest wymagane.';
  if (value.length < 8) return 'Min. 8 znaków.';
  if (!value.contains(RegExp(r'[A-Z]'))) return 'Wymagana wielka litera.';
  if (!value.contains(RegExp(r'[0-9]'))) return 'Wymagana cyfra.';
  return null;
}
