import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/auth/presentation/screens/login_screen.dart';
import 'package:gym/features/auth/presentation/widgets/auth_card.dart';
import 'package:gym/features/auth/presentation/widgets/auth_hero_background.dart';
import 'package:gym/features/auth/presentation/widgets/login_notice_banner.dart';

void main() {
  testWidgets('ekran powitalny pokazuje kartę z marką i akcjami', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.byType(AuthHeroBackground), findsOneWidget);
    expect(find.byType(AuthCard), findsOneWidget);
    expect(find.text('STRONGER'), findsOneWidget);
    expect(find.text('Trenuj mądrze.'), findsOneWidget);
    expect(find.text('Osiągaj więcej.'), findsOneWidget);
    expect(find.text('Zaloguj się'), findsOneWidget);
    expect(find.text('Utwórz konto'), findsOneWidget);
    expect(find.text('lub kontynuuj z'), findsNothing);
    expect(find.byIcon(Icons.apple), findsNothing);
    expect(find.byIcon(Icons.facebook_rounded), findsNothing);
    // Hero w tle + logo w karcie:
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.byKey(loginNoticeBannerKey), findsNothing);
  });

  testWidgets('pokazuje komunikat po zakończeniu sesji i pozwala go zamknąć', (
    tester,
  ) async {
    final notice = ValueNotifier<String?>('Konto zostało usunięte.');
    addTearDown(notice.dispose);

    await tester.pumpWidget(MaterialApp(home: LoginScreen(notice: notice)));

    expect(find.byKey(loginNoticeBannerKey), findsOneWidget);
    expect(find.text('Konto zostało usunięte.'), findsOneWidget);

    await tester.tap(find.byTooltip('Zamknij'));
    await tester.pump();

    expect(notice.value, isNull);
    expect(find.byKey(loginNoticeBannerKey), findsNothing);
  });
}
