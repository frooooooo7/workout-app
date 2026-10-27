import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/exercise_library_prefetch.dart';

/// Jednorazowy ekran po pierwszym zalogowaniu na urządzeniu: pobiera bazę
/// ćwiczeń i wszystkie ilustracje, żeby biblioteka działała bez internetu.
class ExerciseLibrarySetupScreen extends StatefulWidget {
  const ExerciseLibrarySetupScreen({
    super.key,
    required this.prefetch,
    required this.onDone,
    required this.onSkip,
    this.minimumDuration = const Duration(seconds: 2),
  });

  final Future<ExerciseLibraryPrefetchResult> Function({
    void Function(int done, int total)? onProgress,
  })
  prefetch;

  /// Wszystko pobrane — zapisz to i przejdź dalej.
  final VoidCallback onDone;

  /// Użytkownik nie chce czekać (np. brak sieci) — spróbujemy przy
  /// następnym uruchomieniu.
  final VoidCallback onSkip;

  /// Na szybkim Wi-Fi wszystko pobiera się w ułamku sekundy — ekran nie
  /// może tylko mignąć, użytkownik ma zdążyć przeczytać, co się dzieje.
  final Duration minimumDuration;

  @override
  State<ExerciseLibrarySetupScreen> createState() =>
      _ExerciseLibrarySetupScreenState();
}

class _ExerciseLibrarySetupScreenState
    extends State<ExerciseLibrarySetupScreen> {
  int _done = 0;
  int _total = 0;
  bool _listReady = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _failed = false;
      _listReady = false;
      _done = 0;
      _total = 0;
    });
    final started = DateTime.now();
    ExerciseLibraryPrefetchResult? result;
    try {
      result = await widget.prefetch(
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() {
            _listReady = true;
            _done = done;
            _total = total;
          });
        },
      );
    } catch (_) {
      result = null;
    }
    if (!mounted) return;
    if (result != null && result.isComplete) {
      final left = widget.minimumDuration - DateTime.now().difference(started);
      if (left > Duration.zero) await Future<void>.delayed(left);
      if (!mounted) return;
      widget.onDone();
    } else {
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total == 0 ? null : _done / _total;
    final status = _failed
        ? 'Nie udało się pobrać wszystkiego. Sprawdź internet i spróbuj '
              'ponownie. Możesz też pominąć, a pobierzemy resztę przy '
              'następnym uruchomieniu.'
        : !_listReady
        ? 'Pobieranie listy ćwiczeń…'
        : 'Pobieranie ilustracji: $_done z $_total';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _failed
                        ? Icons.cloud_off_rounded
                        : Icons.fitness_center_rounded,
                    color: _failed ? AppColors.textSubtle : AppColors.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Pobieramy bazę ćwiczeń',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.screenTitle,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ćwiczenia i ich ilustracje zapisują się na telefonie, '
                  'żeby biblioteka działała także bez internetu. Robimy to '
                  'tylko raz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                if (!_failed)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      key: const Key('exercise-library-progress'),
                      value: progress,
                      minHeight: 6,
                      color: AppColors.primary,
                      backgroundColor: AppColors.surfaceVariant,
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  status,
                  key: const Key('exercise-library-status'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.tabular(
                    const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSubtle,
                    ),
                  ),
                ),
                const Spacer(),
                if (_failed) ...[
                  FilledButton(
                    onPressed: _run,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Spróbuj ponownie'),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: widget.onSkip,
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      foregroundColor: AppColors.textSubtle,
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Pomiń na razie'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
