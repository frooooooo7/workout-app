import 'dart:math' as math;

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

enum _Phase { list, images, done, failed }

enum _StepState { waiting, active, done, failed }

class _ExerciseLibrarySetupScreenState
    extends State<ExerciseLibrarySetupScreen> {
  _Phase _phase = _Phase.list;
  int _done = 0;
  int _total = 0;

  /// Nieudana próba: czy w ogóle mamy listę ćwiczeń (wtedy zawiodły tylko
  /// ilustracje).
  bool _listFailed = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _phase = _Phase.list;
      _listFailed = false;
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
            _phase = _Phase.images;
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
      setState(() => _phase = _Phase.done);
      final left = widget.minimumDuration - DateTime.now().difference(started);
      if (left > Duration.zero) await Future<void>.delayed(left);
      if (!mounted) return;
      widget.onDone();
    } else {
      setState(() {
        _phase = _Phase.failed;
        _listFailed = result == null || result.exercises == 0;
      });
    }
  }

  double? get _progress => switch (_phase) {
    _Phase.list => null,
    _Phase.images => _total == 0 ? 1 : _done / _total,
    _Phase.done => 1,
    _Phase.failed => 0,
  };

  String get _title => switch (_phase) {
    _Phase.failed => 'Nie udało się pobrać bazy ćwiczeń',
    _Phase.done => 'Biblioteka gotowa',
    _ => 'Pobieramy bazę ćwiczeń',
  };

  String get _subtitle => switch (_phase) {
    _Phase.failed =>
      'Sprawdź internet i spróbuj ponownie. Możesz też pominąć, '
          'a pobierzemy resztę przy następnym uruchomieniu.',
    _Phase.done => 'Ćwiczenia i ilustracje działają teraz także offline.',
    _ =>
      'Zapisujemy ćwiczenia i ich ilustracje na telefonie, żeby działały '
          'także bez internetu.',
  };

  _StepState get _listStep => switch (_phase) {
    _Phase.list => _StepState.active,
    _Phase.failed when _listFailed => _StepState.failed,
    _ => _StepState.done,
  };

  _StepState get _imagesStep => switch (_phase) {
    _Phase.list => _StepState.waiting,
    _Phase.images => _StepState.active,
    _Phase.done => _StepState.done,
    _Phase.failed => _listFailed ? _StepState.waiting : _StepState.failed,
  };

  _StepState get _offlineStep =>
      _phase == _Phase.done ? _StepState.done : _StepState.waiting;

  @override
  Widget build(BuildContext context) {
    final failed = _phase == _Phase.failed;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.55),
              radius: 0.9,
              colors: [AppColors.heroGlow, AppColors.background],
            ),
          ),
          child: SafeArea(
            // Niski ekran (albo duża czcionka systemowa) — przewijamy zamiast
            // ucinać przyciski.
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(0, constraints.maxHeight - 32),
                  ),
                  child: IntrinsicHeight(child: _content(failed)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(bool failed) {
    return Column(
      children: [
        const Spacer(flex: 3),
        _ProgressRing(
          progress: _progress,
          phase: _phase,
          done: _done,
          total: _total,
        ),
        const SizedBox(height: 36),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            _title,
            key: ValueKey(_title),
            textAlign: TextAlign.center,
            style: AppTextStyles.screenTitle.copyWith(fontSize: 24),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            _subtitle,
            key: ValueKey(_subtitle),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 28),
        _Steps(
          children: [
            _StepRow(label: 'Lista ćwiczeń', state: _listStep),
            _StepRow(
              label: 'Ilustracje',
              state: _imagesStep,
              trailing: _total == 0 ? null : '$_done / $_total',
            ),
            _StepRow(label: 'Tryb offline', state: _offlineStep),
          ],
        ),
        const Spacer(flex: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: failed
              ? _FailureActions(onRetry: _run, onSkip: widget.onSkip)
              : const _OnceNote(),
        ),
      ],
    );
  }
}

/// Pierścień postępu z procentem w środku. Bez znanej liczby ilustracji
/// (pobieranie listy) kręci się nieokreślony łuk.
class _ProgressRing extends StatefulWidget {
  const _ProgressRing({
    required this.progress,
    required this.phase,
    required this.done,
    required this.total,
  });

  final double? progress;
  final _Phase phase;
  final int done;
  final int total;

  @override
  State<_ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<_ProgressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSpin();
  }

  @override
  void didUpdateWidget(covariant _ProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSpin();
  }

  void _syncSpin() {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final indeterminate = widget.progress == null;
    if (indeterminate && !reduceMotion) {
      if (!_spin.isAnimating) _spin.repeat();
    } else if (_spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final failed = widget.phase == _Phase.failed;
    final color = failed ? AppColors.textMuted : AppColors.primary;

    return SizedBox.square(
      dimension: 176,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: widget.progress ?? 0.22),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => AnimatedBuilder(
          animation: _spin,
          builder: (context, _) => CustomPaint(
            painter: _RingPainter(
              value: value,
              rotation: widget.progress == null ? _spin.value : 0,
              color: color,
              glow: !failed,
            ),
            child: Center(child: _center(failed)),
          ),
        ),
      ),
    );
  }

  Widget _center(bool failed) {
    final Widget child;
    if (failed) {
      child = const Icon(
        Icons.cloud_off_rounded,
        key: ValueKey('failed'),
        size: 44,
        color: AppColors.textSubtle,
      );
    } else if (widget.phase == _Phase.done) {
      child = const Icon(
        Icons.check_rounded,
        key: ValueKey('done'),
        size: 56,
        color: AppColors.primaryVariant,
      );
    } else if (widget.progress == null) {
      child = const Icon(
        Icons.fitness_center_rounded,
        key: ValueKey('list'),
        size: 40,
        color: AppColors.primaryVariant,
      );
    } else {
      final percent = (widget.progress! * 100).floor();
      child = Column(
        key: const ValueKey('percent'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$percent%',
            key: const Key('exercise-library-percent'),
            style: AppTextStyles.number(size: 44),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.done} z ${widget.total}',
            style: AppTextStyles.tabular(AppTextStyles.caption),
          ),
        ],
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.85, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.rotation,
    required this.color,
    required this.glow,
  });

  final double value;
  final double rotation;
  final Color color;
  final bool glow;

  static const _stroke = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(_stroke / 2 + 6);

    canvas.drawArc(
      arcRect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..color = AppColors.surfaceVariant,
    );

    final sweep = math.pi * 2 * value.clamp(0.0, 1.0);
    if (sweep <= 0) return;
    final start = -math.pi / 2 + rotation * math.pi * 2;

    if (glow) {
      canvas.drawArc(
        arcRect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke + 6
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    canvas.drawArc(
      arcRect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: math.pi * 2,
          transform: GradientRotation(start),
          colors: glow
              ? const [AppColors.primary, AppColors.primaryVariant]
              : [color, color],
          stops: [0, value.clamp(0.01, 1.0)],
        ).createShader(arcRect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.rotation != rotation ||
      old.color != color ||
      old.glow != glow;
}

class _Steps extends StatelessWidget {
  const _Steps({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.state, this.trailing});

  final String label;
  final _StepState state;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final labelColor = switch (state) {
      _StepState.waiting => AppColors.textMuted,
      _StepState.failed => AppColors.textSubtle,
      _ => AppColors.textPrimary,
    };

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          SizedBox.square(dimension: 22, child: _StepIcon(state: state)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              key: label == 'Ilustracje'
                  ? const Key('exercise-library-count')
                  : null,
              style: AppTextStyles.tabular(
                const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StepIcon extends StatelessWidget {
  const _StepIcon({required this.state});

  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final Widget child = switch (state) {
      _StepState.waiting => Container(
        key: const ValueKey('waiting'),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.borderStrong, width: 2),
        ),
      ),
      _StepState.active => const Padding(
        key: ValueKey('active'),
        padding: EdgeInsets.all(2),
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppColors.primary,
        ),
      ),
      _StepState.done => Container(
        key: const ValueKey('done'),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary,
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 15,
          color: AppColors.onPrimary,
        ),
      ),
      _StepState.failed => Container(
        key: const ValueKey('failed'),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.strengthWeak.withValues(alpha: 0.18),
        ),
        child: const Icon(
          Icons.priority_high_rounded,
          size: 14,
          color: AppColors.strengthWeak,
        ),
      ),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: child,
    );
  }
}

class _OnceNote extends StatelessWidget {
  const _OnceNote();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bolt_rounded, size: 16, color: AppColors.textMuted),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              'Robimy to tylko raz',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FailureActions extends StatelessWidget {
  const _FailureActions({required this.onRetry, required this.onSkip});

  final VoidCallback onRetry;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton(
          onPressed: onRetry,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const Text('Spróbuj ponownie'),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: onSkip,
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
    );
  }
}
