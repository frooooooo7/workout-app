import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/constants/api_constants.dart';

void main() {
  bool release(String origin) =>
      isCleartextApiOriginAllowed(origin, isRelease: true);

  group('isCleartextApiOriginAllowed w buildzie release', () {
    test('https jest zawsze dozwolony', () {
      expect(release('https://api.example.com'), isTrue);
      expect(release('https://api.example.com:8443'), isTrue);
      expect(release('HTTPS://api.example.com'), isTrue);
    });

    test('http do publicznego hosta jest odrzucany', () {
      expect(release('http://api.example.com'), isFalse);
      expect(release('http://8.8.8.8:3000'), isFalse);
      expect(release('http://172.32.0.1:3000'), isFalse);
      expect(release('http://localhost.evil.com'), isFalse);
      expect(release('http://192.168.1.20.evil.com'), isFalse);
    });

    test('http do maszyn lokalnych jest dozwolony', () {
      expect(release('http://localhost:3000'), isTrue);
      expect(release('http://127.0.0.1:3000'), isTrue);
      expect(release('http://10.0.2.2:3000'), isTrue);
      expect(release('http://192.168.0.173:3000'), isTrue);
      expect(release('http://172.16.5.4:3000'), isTrue);
      expect(release('http://komputer.local:3000'), isTrue);
    });

    test('inne schematy i śmieci są odrzucane', () {
      expect(release('ftp://localhost'), isFalse);
      expect(release(''), isFalse);
      expect(release('api.example.com'), isFalse);
    });
  });

  test('poza release dowolny adres jest dozwolony', () {
    expect(
      isCleartextApiOriginAllowed('http://api.example.com', isRelease: false),
      isTrue,
    );
  });
}
