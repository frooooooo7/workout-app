import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/domain/models/post_draft.dart';
import 'package:gym/features/training/presentation/screens/plan_appearance_screen.dart';

// Najmniejszy poprawny PNG 1×1.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  /// Otwiera ekran „Wygląd planu” i zbiera to, co zwróci po „Gotowe”.
  Future<ValueNotifier<PlanAppearanceResult?>> openScreen(
    WidgetTester tester, {
    String? coverUrl,
    Uint8List? coverBytes,
  }) async {
    final popped = ValueNotifier<PlanAppearanceResult?>(null);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              popped.value = await Navigator.of(context)
                  .push<PlanAppearanceResult>(
                    MaterialPageRoute(
                      builder: (_) => PlanAppearanceScreen(
                        planName: 'Push',
                        subtitle: '',
                        selectedDays: const [1],
                        coverUrl: coverUrl,
                        coverBytes: coverBytes,
                        pickPhoto: (_, _) async => PickedPostPhoto(
                          bytes: Uint8List.fromList(_png),
                          filename: 'okladka.png',
                        ),
                      ),
                    ),
                  );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return popped;
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> done(WidgetTester tester) =>
      tapKey(tester, 'plan-appearance-done');

  testWidgets('picking a cover returns it as a change', (tester) async {
    final popped = await openScreen(tester);
    await tapKey(tester, 'plan-cover-add');
    // Telefon pyta o źródło (aparat / galeria); komputer idzie od razu do galerii.
    if (find
        .byKey(const ValueKey('plan-cover-gallery'))
        .evaluate()
        .isNotEmpty) {
      await tapKey(tester, 'plan-cover-gallery');
    }

    expect(find.byKey(const ValueKey('plan-cover-change')), findsOneWidget);
    await done(tester);

    final change = popped.value?.cover;
    expect(change, isA<SetPostPhoto>());
    expect((change! as SetPostPhoto).photo.filename, 'okladka.png');
  });

  testWidgets('removing an existing cover returns a remove change', (
    tester,
  ) async {
    final popped = await openScreen(
      tester,
      coverBytes: Uint8List.fromList(_png),
    );

    await tapKey(tester, 'plan-cover-remove');
    expect(find.byKey(const ValueKey('plan-cover-add')), findsOneWidget);

    await done(tester);
    expect(popped.value?.cover, isA<RemovePostPhoto>());
  });

  testWidgets('leaving the cover alone returns keep', (tester) async {
    final popped = await openScreen(
      tester,
      coverUrl: '/uploads/plan-covers/x.webp',
    );
    await done(tester);
    expect(popped.value?.cover, isA<KeepPostPhoto>());
  });
}
