import '../network/api_client.dart';

/// Czy nieudaną operację synchronizacji warto ponawiać automatycznie.
enum SyncFailureKind {
  /// Brak sieci, timeout, błąd serwera, limit żądań, wygasły token —
  /// ponowienie za chwilę ma sens.
  transient,

  /// Serwer odrzucił dane (4xx). Ponawianie w pętli nic nie zmieni, więc
  /// wiersz trzeba oznaczyć i pokazać użytkownikowi.
  permanent,
}

const _retryableClientErrors = {401, 408, 409, 425, 429};

SyncFailureKind classifySyncFailure(ApiException error) {
  final status = error.statusCode;
  if (status == null || status >= 500) return SyncFailureKind.transient;
  if (_retryableClientErrors.contains(status)) return SyncFailureKind.transient;
  if (status >= 400) return SyncFailureKind.permanent;
  return SyncFailureKind.transient;
}

/// `ApiClient` zamienia każdy problem z transportem na `network_error` bez
/// kodu HTTP — to jest właśnie „offline”.
bool isNetworkFailure(ApiException error) => error.statusCode == null;
