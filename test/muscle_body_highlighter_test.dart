import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/body_highlighter/data/body_highlighter_asset_loader.dart';
import 'package:gym/features/body_highlighter/widgets/muscle_body_highlighter.dart';

void main() {
  testWidgets('missing body asset does not leave an endless spinner', (
    tester,
  ) async {
    BodyHighlighterAssetLoader.instance.clearCache();
    // Np. web offline: plik sylwetki nie dociera.
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (_) async => null,
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        null,
      );
      BodyHighlighterAssetLoader.instance.clearCache();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MuscleBodyHighlighter(width: 120, height: 240)),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
