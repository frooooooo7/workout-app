import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/exercise.dart';
import 'exercise_image_uri.dart';

/// Pamięta, że na tym urządzeniu baza ćwiczeń konta została już pobrana
/// razem z ilustracjami — robimy to tylko raz.
abstract class ExerciseLibraryReadyStore {
  Future<bool> isReady(String userId);
  Future<void> markReady(String userId);
}

class SharedPreferencesExerciseLibraryReadyStore
    implements ExerciseLibraryReadyStore {
  const SharedPreferencesExerciseLibraryReadyStore();

  static String _key(String userId) => 'exercise_library_ready_v1_$userId';

  @override
  Future<bool> isReady(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(userId)) ?? false;
  }

  @override
  Future<void> markReady(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(userId), true);
  }
}

class ExerciseLibraryPrefetchResult {
  const ExerciseLibraryPrefetchResult({
    required this.exercises,
    required this.images,
    required this.failedImages,
  });

  final int exercises;
  final int images;
  final int failedImages;

  /// Lista ćwiczeń jest na miejscu i każda ilustracja leży na dysku.
  bool get isComplete => exercises > 0 && failedImages == 0;
}

/// Pobiera listę ćwiczeń z serwera do lokalnej bazy, a potem wszystkie
/// ilustracje do pamięci obrazków na dysku, żeby biblioteka działała offline
/// od pierwszego uruchomienia.
class ExerciseLibraryPrefetcher {
  ExerciseLibraryPrefetcher({
    required this.pullExercises,
    required this.loadExercises,
    required this.cacheImage,
    this.concurrency = 4,
    this.imageTimeout = const Duration(seconds: 8),
    this.pullTimeout = const Duration(seconds: 8),
  });

  /// Synchronizacja ćwiczeń z serwerem (błędy sieci połyka sama).
  final Future<void> Function() pullExercises;

  /// Ćwiczenia z lokalnej bazy po synchronizacji.
  final Future<List<Exercise>> Function() loadExercises;

  /// Zapisuje obrazek na dysku; rzuca, gdy się nie udało.
  final Future<void> Function(String url) cacheImage;

  final int concurrency;

  /// Bez sieci pojedyncze żądanie potrafi wisieć do limitu klienta HTTP —
  /// ekran ma szybko pokazać „Spróbuj ponownie”, a nie czekać minutami.
  final Duration imageTimeout;

  /// Lista z serwera — po tym czasie bierzemy to, co już jest w lokalnej
  /// bazie (synchronizacja dokończy się w tle).
  final Duration pullTimeout;

  /// [onProgress] dostaje liczbę gotowych i wszystkich ilustracji.
  Future<ExerciseLibraryPrefetchResult> run({
    void Function(int done, int total)? onProgress,
  }) async {
    try {
      await pullExercises().timeout(pullTimeout);
    } on TimeoutException {
      /* bez sieci: dalej z lokalną bazą */
    }
    final exercises = await loadExercises();
    final urls = <String>{
      for (final exercise in exercises)
        if (exerciseImageResolvedUri(exercise.imageUrl) case final uri?)
          uri.toString(),
    }.toList();

    var done = 0;
    var failed = 0;
    var succeeded = 0;
    onProgress?.call(0, urls.length);

    // Pierwsza runda w całości nieudana = brak sieci; nie męczymy reszty.
    bool offline() => succeeded == 0 && failed >= concurrency;

    var next = 0;
    Future<void> worker() async {
      while (next < urls.length && !offline()) {
        final url = urls[next++];
        try {
          await cacheImage(url).timeout(imageTimeout);
          succeeded++;
        } catch (_) {
          failed++;
        }
        done++;
        onProgress?.call(done, urls.length);
      }
    }

    await Future.wait([for (var i = 0; i < concurrency; i++) worker()]);

    return ExerciseLibraryPrefetchResult(
      exercises: exercises.length,
      images: urls.length,
      // Pominięte po wykryciu braku sieci też się nie pobrały.
      failedImages: urls.length - succeeded,
    );
  }
}
