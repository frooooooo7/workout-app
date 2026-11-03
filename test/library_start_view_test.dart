import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/library/domain/models/library_part.dart';
import 'package:gym/features/library/presentation/bloc/library_cubit.dart';
import 'package:gym/features/library/presentation/widgets/exercise_row.dart';
import 'package:gym/features/library/presentation/widgets/library_start_view.dart';

const _recent = Exercise(
  id: 'r1',
  name: 'Wyciskanie sztangi na ławce płaskiej z bardzo długą nazwą',
  muscles: [MuscleGroup.chest],
  category: ExerciseCategory.compound,
);

Widget _host(Widget child, {double width = 375, double scale = 1}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 900),
        textScaler: TextScaler.linear(scale),
      ),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('LibraryPart', () {
    test('stuknięcie manekina trafia w partię', () {
      expect(LibraryPart.fromSlug('chest'), LibraryPart.chest);
      expect(LibraryPart.fromSlug('trapezius'), LibraryPart.back);
      expect(LibraryPart.fromSlug('quadriceps'), LibraryPart.legs);
      expect(LibraryPart.fromSlug('forearm'), LibraryPart.forearms);
      expect(LibraryPart.fromSlug('head'), isNull);
    });

    test('liczy ćwiczenia jak filtr listy (grupa zbiorcza obejmuje mięśnie)', () {
      const lats = Exercise(
        id: 'l',
        name: 'Ściąganie',
        muscles: [MuscleGroup.lats],
        category: ExerciseCategory.compound,
      );
      expect(LibraryPart.back.countIn([lats, _recent]), 1);
      expect(LibraryPart.chest.countIn([lats, _recent]), 1);
      expect(LibraryPart.calves.countIn([lats, _recent]), 0);
    });
  });

  for (final (width, scale) in [(320.0, 1.0), (320.0, 2.0), (375.0, 1.3), (768.0, 1.0)]) {
    testWidgets('ekran startowy mieści się: ${width.toInt()} px, tekst ×$scale',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      LibraryPart? tapped;
      var showAll = 0;
      await tester.pumpWidget(
        _host(
          LibraryStartView(
            overview: LibraryOverview(
              total: 98,
              partCounts: {for (final p in LibraryPart.values) p: 12},
              recent: const [_recent],
            ),
            onPartTap: (part) => tapped = part,
            onShowAll: () => showAll++,
            onExerciseTap: (_) {},
          ),
          width: width,
          scale: scale,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Wszystkie (98)'), findsOneWidget);
      expect(find.text('OSTATNIO ROBIONE'), findsOneWidget);
      expect(find.text('Klatka'), findsOneWidget);

      await tester.tap(find.text('Wszystkie (98)'));
      expect(showAll, 1);
      await tester.scrollUntilVisible(
        find.text('Przedramiona'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Przedramiona'));
      await tester.pump();
      await tester.tap(find.text('Przedramiona'));
      expect(tapped, LibraryPart.forearms);
    });
  }

  testWidgets('bez historii nie pokazuje wiersza „Ostatnio robione”',
      (tester) async {
    await tester.pumpWidget(
      _host(
        LibraryStartView(
          overview: const LibraryOverview(total: 3),
          onPartTap: (_) {},
          onShowAll: () {},
          onExerciseTap: (_) {},
        ),
      ),
    );
    expect(find.text('OSTATNIO ROBIONE'), findsNothing);
    expect(find.text('Wybierz partię'.toUpperCase()), findsOneWidget);
  });

  testWidgets('wiersz listy: nazwa, partia i sprzęt, gwiazdka', (tester) async {
    var favourite = 0;
    await tester.pumpWidget(
      _host(
        ExerciseRow(
          exercise: _recent,
          onFavouriteTap: () => favourite++,
        ),
      ),
    );
    expect(find.text(_recent.name), findsOneWidget);
    expect(find.text('Klatka'), findsOneWidget);
    await tester.tap(find.byTooltip('Dodaj do ulubionych'));
    expect(favourite, 1);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.5, 2.0]) {
    testWidgets('wiersz listy rośnie z tekstem ×$scale bez przepełnienia', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 320,
            child: ExerciseRow(exercise: _recent),
          ),
          width: 320,
          scale: scale,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(ExerciseRow)).height,
        greaterThanOrEqualTo(ExerciseRow.height),
      );
    });
  }
}
