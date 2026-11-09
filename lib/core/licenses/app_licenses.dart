import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Noty licencyjne dołączanych zasobów, które nie przychodzą z paczek pub:
/// czcionki (SIL OFL 1.1) i dane mapy mięśni (MIT). Pokazuje je ekran
/// „Licencje” (`showLicensePage`) razem z licencjami paczek Fluttera.
const kAppLicenseAssets = <({String package, String asset})>[
  (package: 'Manrope (czcionka)', asset: 'assets/fonts/OFL-Manrope.txt'),
  (
    package: 'Barlow Condensed (czcionka)',
    asset: 'assets/fonts/OFL-BarlowCondensed.txt',
  ),
  (
    package: 'react-native-body-highlighter (mapa mięśni)',
    asset: 'assets/body_highlighter/LICENSE',
  ),
];

var _registered = false;

/// Rejestruje noty z [kAppLicenseAssets] w [LicenseRegistry] (raz).
void registerAppLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    for (final entry in kAppLicenseAssets) {
      final text = await rootBundle.loadString(entry.asset);
      yield LicenseEntryWithLineBreaks([entry.package], text);
    }
  });
}

/// Tylko dla testów: pozwala zarejestrować noty ponownie.
@visibleForTesting
void resetAppLicensesForTest() => _registered = false;
