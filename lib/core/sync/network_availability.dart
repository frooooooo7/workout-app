import 'package:connectivity_plus/connectivity_plus.dart';

/// `true`, gdy telefon ma jakiekolwiek połączenie (Wi-Fi, komórkowe,
/// Ethernet, VPN…), `false` bez żadnego.
///
/// To nie gwarantuje działającego internetu (np. Wi-Fi siłowni z ekranem
/// logowania) — dlatego [SyncCoordinator] traktuje to tylko jako sygnał do
/// próby, a ponawianie z narastającym odstępem zostaje jako zabezpieczenie.
Stream<bool> networkAvailabilityChanges([Connectivity? connectivity]) {
  return (connectivity ?? Connectivity()).onConnectivityChanged
      .map(
        (results) =>
            results.any((result) => result != ConnectivityResult.none),
      )
      .distinct();
}
