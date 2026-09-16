import '../network/api_client.dart';

/// Czy nieudaną operację synchronizacji warto ponawiać automatycznie.
enum SyncFailureKind {
  /// Brak sieci, timeout, błąd serwera, limit żądań, wygasły token —
  /// ponowienie za chwilę ma sens.
  transient,

  /// Serwer odrzucił dane (4xx). Ponawianie w pętli nic nie zmieni, więc
  /// wiersz trzeba oznaczyć i pokazać użytkownikowi.
  permanent,

  /// `410` — rekord został usunięty (np. na innym urządzeniu). To nie jest
  /// błąd do pokazania ani do ponawiania: silnik usuwa lokalną kopię.
  gone,
}

const _retryableClientErrors = {401, 408, 409, 425, 429};

SyncFailureKind classifySyncFailure(ApiException error) {
  final status = error.statusCode;
  if (status == null || status >= 500) return SyncFailureKind.transient;
  if (status == 410) return SyncFailureKind.gone;
  if (_retryableClientErrors.contains(status)) return SyncFailureKind.transient;
  if (status >= 400) return SyncFailureKind.permanent;
  return SyncFailureKind.transient;
}

/// `ApiClient` zamienia każdy problem z transportem na `network_error` bez
/// kodu HTTP — to jest właśnie „offline”.
bool isNetworkFailure(ApiException error) => error.statusCode == null;

/// `410 session_deleted` — sesja ma nagrobek na serwerze; lokalną kopię
/// trzeba usunąć, a nie ponawiać zapis.
bool isGoneFailure(ApiException error) => error.statusCode == 410;
