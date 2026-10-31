import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/body_highlighter/models/muscle_highlight.dart';
import 'package:gym/features/body_highlighter/models/muscle_intensity.dart';
import 'package:gym/features/body_highlighter/painters/body_highlighter_painter.dart';
import 'package:gym/features/body_highlighter/widgets/muscle_body_highlighter.dart';

void main() {
  group('snapshot cache', () {
    Widget host(Set<MuscleHighlight> highlights) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: MuscleBodyHighlighter(
            width: 90,
            height: 202,
            highlights: highlights,
            animationDuration: const Duration(milliseconds: 100),
          ),
        ),
      ),
    );

    BodyHighlighterPainter painter(WidgetTester tester) {
      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(MuscleBodyHighlighter),
          matching: find.byType(CustomPaint),
        ),
      );
      return paint.painter! as BodyHighlighterPainter;
    }

    testWidgets('settled silhouette is rendered once and reused', (
      tester,
    ) async {
      final chest = {
        const MuscleHighlight(muscle: 'chest', intensity: MuscleIntensity.high),
      };

      await tester.runAsync(() async {
        await tester.pumpWidget(host(chest));
        // Wczytanie JSON-a z assetów.
        for (var i = 0; i < 50; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
        }
      });
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      final cache = painter(tester).snapshotCache!;
      expect(cache.hasImage, isTrue);
      expect(cache.renderCount, 1);

      // Kolejne klatki (np. przewijanie) i przebudowy z tymi samymi danymi nie
      // renderują zdjęcia od nowa.
      await tester.pumpWidget(host(chest));
      await tester.pump(const Duration(milliseconds: 16));
      expect(cache.renderCount, 1);

      // Zmiana podświetlenia: animacja rysuje wektorowo, a po jej końcu
      // powstaje jedno nowe zdjęcie.
      final legs = {
        const MuscleHighlight(
          muscle: 'quadriceps',
          intensity: MuscleIntensity.low,
        ),
      };
      await tester.pumpWidget(host(legs));
      await tester.pump(const Duration(milliseconds: 50));
      expect(painter(tester).animating, isTrue);
      expect(cache.renderCount, 1);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(painter(tester).animating, isFalse);
      expect(cache.hasImage, isTrue);
      expect(cache.renderCount, 2);
    });
  });
}
