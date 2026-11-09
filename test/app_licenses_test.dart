import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/licenses/app_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'noty czcionek OFL i mapy mięśni (MIT) trafiają do rejestru licencji',
    () async {
      registerAppLicenses();
      registerAppLicenses(); // drugi raz nic nie dubluje

      final entries = await LicenseRegistry.licenses.toList();
      final ours = entries
          .where(
            (e) => e.packages.any(
              (p) => kAppLicenseAssets.any((a) => a.package == p),
            ),
          )
          .toList();

      expect(ours, hasLength(kAppLicenseAssets.length));
      String textOf(String package) => ours
          .firstWhere((e) => e.packages.contains(package))
          .paragraphs
          .map((p) => p.text)
          .join('\n');
      expect(textOf('Manrope (czcionka)'), contains('SIL Open Font License'));
      expect(
        textOf('Barlow Condensed (czcionka)'),
        contains('SIL Open Font License'),
      );
      expect(
        textOf('react-native-body-highlighter (mapa mięśni)'),
        contains('MIT License'),
      );
    },
  );
}
