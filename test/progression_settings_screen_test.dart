import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/units/weight_unit.dart';
import 'package:gym/features/training/data/progression_settings_store.dart';
import 'package:gym/features/training/domain/models/progression_settings.dart';
import 'package:gym/features/training/presentation/screens/progression_settings_screen.dart';
import 'package:gym/features/training/presentation/widgets/progression/plan_progression_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Remote implements ProgressionSettingsRemote {
  ProgressionSettings? saved;

  @override
  Future<ProgressionSettings?> fetch() async => null;

  @override
  Future<void> save(ProgressionSettings settings) async => saved = settings;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WeightUnits.notifier.value = WeightUnit.kg;
  });
  tearDown(() => WeightUnits.notifier.value = WeightUnit.kg);

  Future<(ProgressionSettingsStore, _Remote)> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = ProgressionSettingsStore();
    final remote = _Remote();
    await store.attach('u1', remote);
    await tester.pumpWidget(
      MaterialApp(home: ProgressionSettingsScreen(store: store)),
    );
    return (store, remote);
  }

  testWidgets('starts off, picks a fixed step and saves it', (tester) async {
    final (store, remote) = await pump(tester);

    expect(find.text('Wyłączona'), findsOneWidget);
    expect(find.byKey(const ValueKey('progression-options')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('progression-method-fixed')));
    await tester.pumpAndSettle();
    expect(store.current.method, ProgressionMethod.fixed);
    expect(find.byKey(const ValueKey('progression-options')), findsOneWidget);
    // Podgląd: 60 → 62,5 przy kroku 2,5 kg.
    expect(find.text('+2,5'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('progression-step-1,25')));
    await tester.pumpAndSettle();
    expect(store.current.step, 1.25);

    await tester.tap(find.byKey(const ValueKey('progression-deload-switch')));
    await tester.pumpAndSettle();
    expect(store.current.deload, isTrue);

    await tester.tap(find.byKey(const ValueKey('progression-sessions-2')));
    await tester.pumpAndSettle();
    expect(store.current.sessionsToIncrease, 2);

    await store.idle;
    expect(remote.saved, store.current);
  });

  testWidgets('custom step via "Inny…"', (tester) async {
    final (store, _) = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('progression-method-fixed')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('progression-step-custom')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('progression-custom-field')),
      '3,75',
    );
    await tester.tap(find.byKey(const ValueKey('progression-custom-ok')));
    await tester.pumpAndSettle();
    expect(store.current.step, 3.75);
  });

  testWidgets('pounds: steps are offered and saved in lb', (tester) async {
    WeightUnits.notifier.value = WeightUnit.lb;
    final (store, _) = await pump(tester);

    await tester.tap(find.byKey(const ValueKey('progression-method-fixed')));
    await tester.pumpAndSettle();
    expect(store.current.unit, WeightUnit.lb);
    expect(store.current.step, 5);
    expect(find.byKey(const ValueKey('progression-step-10')), findsOneWidget);
  });

  testWidgets('double progression shows +1 rep in the preview', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('progression-method-double')));
    await tester.pumpAndSettle();
    expect(find.text('+1 powt.'), findsOneWidget);
    expect(find.text('NASTĘPNYM RAZEM · ZAKRES 8–12'), findsOneWidget);
  });

  testWidgets('plan sheet: own method or back to the account setting', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    PlanProgressionChoice? choice;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => choice = await showPlanProgressionSheet(
              context,
              planName: 'Push A',
              own: null,
              account: const ProgressionSettings(
                method: ProgressionMethod.fixed,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Progresja w planie „Push A”'), findsOneWidget);
    expect(find.text('Stały krok · +2,5 kg'), findsOneWidget);

    final percent = find.byKey(const ValueKey('progression-method-percent'));
    await tester.ensureVisible(percent);
    await tester.pumpAndSettle();
    await tester.tap(percent);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-progression-done')));
    await tester.pumpAndSettle();
    expect(choice?.progression?.method, ProgressionMethod.percent);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('progression-method-inherit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-progression-done')));
    await tester.pumpAndSettle();
    expect(choice, isNotNull);
    expect(choice!.progression, isNull);
  });
}
