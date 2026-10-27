import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/data/exercise_library_prefetch.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/library/presentation/screens/exercise_library_setup_screen.dart';

Exercise _exercise(String id, {String? imageUrl}) => Exercise(
  id: id,
  name: 'Ćwiczenie $id',
  muscles: const [MuscleGroup.chest],
  category: ExerciseCategory.compound,
  imageUrl: imageUrl,
);

void main() {
  group('ExerciseLibraryPrefetcher', () {
    test('pulls first, then caches every distinct illustration', () async {
      final calls = <String>[];
      final progress = <(int, int)>[];
      final prefetcher = ExerciseLibraryPrefetcher(
        pullExercises: () async => calls.add('pull'),
        loadExercises: () async {
          calls.add('load');
          return [
            _exercise('1', imageUrl: 'https://cdn.test/a.webp'),
            _exercise('2', imageUrl: 'https://cdn.test/b.webp'),
            _exercise('3', imageUrl: 'https://cdn.test/a.webp'),
            _exercise('4'),
          ];
        },
        cacheImage: (url) async => calls.add(url),
      );

      final result = await prefetcher.run(
        onProgress: (done, total) => progress.add((done, total)),
      );

      expect(calls.take(2), ['pull', 'load']);
      expect(calls.skip(2).toSet(), {
        'https://cdn.test/a.webp',
        'https://cdn.test/b.webp',
      });
      expect(result.exercises, 4);
      expect(result.images, 2);
      expect(result.failedImages, 0);
      expect(result.isComplete, isTrue);
      expect(progress.first, (0, 2));
      expect(progress.last, (2, 2));
    });

    test('counts failed images and is not complete', () async {
      final prefetcher = ExerciseLibraryPrefetcher(
        pullExercises: () async {},
        loadExercises: () async => [
          _exercise('1', imageUrl: 'https://cdn.test/ok.webp'),
          _exercise('2', imageUrl: 'https://cdn.test/broken.webp'),
        ],
        cacheImage: (url) async {
          if (url.contains('broken')) throw Exception('offline');
        },
      );

      final result = await prefetcher.run();

      expect(result.failedImages, 1);
      expect(result.isComplete, isFalse);
    });

    test('stops early when the first round of images all fail', () async {
      var attempts = 0;
      final prefetcher = ExerciseLibraryPrefetcher(
        pullExercises: () async {},
        loadExercises: () async => [
          for (var i = 0; i < 20; i++)
            _exercise('$i', imageUrl: 'https://cdn.test/$i.webp'),
        ],
        cacheImage: (_) async {
          attempts++;
          throw Exception('offline');
        },
        concurrency: 4,
      );

      final result = await prefetcher.run();

      // Kilka żądań już w locie, ale nie cała lista.
      expect(attempts, lessThan(2 * 4));
      expect(result.failedImages, 20);
      expect(result.isComplete, isFalse);
    });

    test('gives up on an image that hangs', () async {
      final prefetcher = ExerciseLibraryPrefetcher(
        pullExercises: () async {},
        loadExercises: () async => [
          _exercise('1', imageUrl: 'https://cdn.test/slow.webp'),
        ],
        cacheImage: (_) => Completer<void>().future,
        imageTimeout: const Duration(milliseconds: 20),
      );

      expect((await prefetcher.run()).failedImages, 1);
    });

    test('does not wait forever for the exercise list', () async {
      final prefetcher = ExerciseLibraryPrefetcher(
        pullExercises: () => Completer<void>().future,
        loadExercises: () async => [_exercise('1')],
        cacheImage: (_) async {},
        pullTimeout: const Duration(milliseconds: 20),
      );

      expect((await prefetcher.run()).exercises, 1);
    });

    test('an empty library (offline first login) is not complete', () async {
      final prefetcher = ExerciseLibraryPrefetcher(
        pullExercises: () async {},
        loadExercises: () async => const [],
        cacheImage: (_) async {},
      );

      expect((await prefetcher.run()).isComplete, isFalse);
    });
  });

  group('ExerciseLibrarySetupScreen', () {
    testWidgets('shows progress and finishes on success', (tester) async {
      var done = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ExerciseLibrarySetupScreen(
            prefetch: ({onProgress}) async {
              onProgress?.call(0, 2);
              await Future<void>.delayed(const Duration(milliseconds: 10));
              onProgress?.call(1, 2);
              await Future<void>.delayed(const Duration(milliseconds: 10));
              onProgress?.call(2, 2);
              return const ExerciseLibraryPrefetchResult(
                exercises: 2,
                images: 2,
                failedImages: 0,
              );
            },
            onDone: () => done++,
            onSkip: () {},
            minimumDuration: const Duration(milliseconds: 500),
          ),
        ),
      );

      expect(find.text('Pobieramy bazę ćwiczeń'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 15));
      expect(find.text('Pobieranie ilustracji: 1 z 2'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 15));
      // Ekran nie znika od razu, nawet gdy wszystko już pobrane.
      expect(done, 0);
      await tester.pump(const Duration(milliseconds: 500));
      expect(done, 1);
    });

    testWidgets('offers retry and skip when something failed', (tester) async {
      var attempts = 0;
      var skipped = 0;
      var done = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ExerciseLibrarySetupScreen(
            prefetch: ({onProgress}) async {
              attempts++;
              return ExerciseLibraryPrefetchResult(
                exercises: 2,
                images: 2,
                failedImages: attempts == 1 ? 1 : 0,
              );
            },
            onDone: () => done++,
            onSkip: () => skipped++,
            minimumDuration: Duration.zero,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Nie udało się pobrać bazy ćwiczeń'), findsOneWidget);
      expect(find.text('Spróbuj ponownie'), findsOneWidget);
      expect(find.text('Pomiń na razie'), findsOneWidget);
      expect(done, 0);

      await tester.tap(find.text('Spróbuj ponownie'));
      await tester.pump();
      expect(attempts, 2);
      expect(done, 1);
      expect(skipped, 0);
    });
  });
}
