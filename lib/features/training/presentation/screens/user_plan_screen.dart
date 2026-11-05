import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/sync/network_availability.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/plan_colors.dart';
import '../../../../core/utils/polish_plural.dart';
import '../../../../core/widgets/app_tab_header.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../library/presentation/widgets/exercise_thumbnail.dart';
import '../../data/plan_sharing_repository.dart';
import '../../domain/models/custom_training_plan.dart';
import '../utils/plan_copy.dart';
import '../widgets/ongoing_workout/rest_timer_controls.dart'
    show formatRestRemaining;
import '../widgets/plans/plan_card.dart' show planMuscleFocus;
import '../widgets/training_staggered_entrance.dart';

/// Autor planu pokazywany w nagłówku podglądu.
class PlanOwner {
  const PlanOwner({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.handle = '',
    this.avatarUrl,
    this.isFollowing = false,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String handle;
  final String? avatarUrl;
  final bool isFollowing;
}

class UserPlanArgs {
  const UserPlanArgs({required this.plan, required this.owner});

  final CustomTrainingPlan plan;
  final PlanOwner owner;
}

/// Podgląd publicznego planu innej osoby: ćwiczenia, serie, przerwy
/// i superserie, z przyciskiem „Skopiuj do moich planów”.
class UserPlanScreen extends StatefulWidget {
  const UserPlanScreen({
    super.key,
    required this.args,
    required this.repository,
    this.connectivity,
  });

  final UserPlanArgs args;
  final PlanSharingRepository repository;

  /// Test seam; domyślnie systemowy stan sieci.
  final Connectivity? connectivity;

  @override
  State<UserPlanScreen> createState() => _UserPlanScreenState();
}

class _UserPlanScreenState extends State<UserPlanScreen> {
  bool _online = true;
  bool _copying = false;
  StreamSubscription<bool>? _network;

  CustomTrainingPlan get _plan => widget.args.plan;

  @override
  void initState() {
    super.initState();
    unawaited(_watchNetwork());
  }

  Future<void> _watchNetwork() async {
    final connectivity = widget.connectivity ?? Connectivity();
    try {
      final results = await connectivity.checkConnectivity();
      if (mounted) {
        setState(
          () => _online = results.any((r) => r != ConnectivityResult.none),
        );
      }
      if (!mounted) return;
      _network = networkAvailabilityChanges(connectivity).listen((online) {
        if (mounted) setState(() => _online = online);
      }, onError: (Object _) {});
    } catch (_) {
      // Brak wtyczki (testy, web bez API) — zakładamy sieć, błąd i tak
      // pokaże komunikat.
    }
  }

  @override
  void dispose() {
    _network?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    if (_copying) return;
    HapticFeedback.mediumImpact();
    setState(() => _copying = true);
    final ok = await copyPlanAndOpenPlans(
      context,
      () => widget.repository.copyPlan(_plan.id),
    );
    if (!ok && mounted) setState(() => _copying = false);
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final owner = widget.args.owner;
    final color = PlanColors.of(plan.name, colorKey: plan.colorKey);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OwnerHeader(owner: owner, onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageGutter,
                  AppSpacing.xs,
                  AppSpacing.pageGutter,
                  AppSpacing.lg,
                ),
                children: [
                  TrainingStaggeredEntrance(
                    index: 0,
                    child: _PlanHero(plan: plan, color: color),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text('ĆWICZENIA', style: AppTextStyles.eyebrow),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TrainingStaggeredEntrance(
                    index: 1,
                    child: _ExerciseList(plan: plan),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pageGutter,
                AppSpacing.xs,
                AppSpacing.pageGutter,
                AppSpacing.md + bottomInset,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.textMuted,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _online
                              ? 'Ciężary ${owner.handle.isEmpty ? 'autora' : '@${owner.handle}'}'
                                    ' nie są kopiowane, dobierzesz swoje.'
                              : 'Kopiowanie planu wymaga internetu.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      key: const ValueKey('user-plan-copy'),
                      onPressed: _online && !_copying ? _copy : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        disabledBackgroundColor: AppColors.surfaceVariant,
                        disabledForegroundColor: AppColors.textMuted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      icon: _copying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AppColors.textSecondary,
                              ),
                            )
                          : const Icon(Icons.copy_rounded, size: 20),
                      label: const Text('Skopiuj do moich planów'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerHeader extends StatelessWidget {
  const _OwnerHeader({required this.owner, required this.onBack});

  final PlanOwner owner;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (owner.handle.isNotEmpty) '@${owner.handle}',
      if (owner.isFollowing) 'obserwujesz',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageGutter,
        AppSpacing.xs,
        AppSpacing.pageGutter,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          AppTabHeaderButton.back(onPressed: onBack),
          const SizedBox(width: AppSpacing.sm),
          UserAvatar.fromNames(
            firstName: owner.firstName,
            lastName: owner.lastName,
            imageUrl: owner.avatarUrl,
            size: UserAvatarSize.xs,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${owner.firstName} ${owner.lastName}'.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanHero extends StatelessWidget {
  const _PlanHero({required this.plan, required this.color});

  final CustomTrainingPlan plan;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final exercises = plan.exercises.length;
    final sets = plan.exercises.fold(0, (sum, e) => sum + e.sets.length);
    final muscles = planMuscleFocus(plan);
    final copies = plan.copyCount;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        gradient: RadialGradient(
          center: const Alignment(1.1, -1.3),
          radius: 1.4,
          colors: [color.withValues(alpha: 0.13), AppColors.surface],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'PLAN',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              if (copies > 0) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'skopiowany $copies '
                  '${polishPlural(copies, 'raz', 'razy', 'razy')}',
                  style: AppTextStyles.caption.copyWith(fontSize: 13),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            plan.name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.1,
            ),
          ),
          if (muscles.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              muscles.join(' · '),
              style: AppTextStyles.caption.copyWith(fontSize: 14),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          DefaultTextStyle(
            style: AppTextStyles.tabular(
              const TextStyle(
                color: AppColors.textSubtle,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Wrap(
              spacing: AppSpacing.md,
              children: [
                Text(
                  '$exercises '
                  '${polishPlural(exercises, 'ćwiczenie', 'ćwiczenia', 'ćwiczeń')}',
                ),
                Text('$sets ${polishPlural(sets, 'seria', 'serie', 'serii')}'),
                Text('~${plan.estimatedMinutes} min'),
              ],
            ),
          ),
          if (plan.note case final note? when note.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              note.trim(),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ćwiczenia planu; superseria jako blok z akcentem i przerwą po rundzie.
class _ExerciseList extends StatelessWidget {
  const _ExerciseList({required this.plan});

  final CustomTrainingPlan plan;

  @override
  Widget build(BuildContext context) {
    final exercises = plan.exercises;
    final children = <Widget>[];
    var i = 0;
    while (i < exercises.length) {
      final group = exercises[i].supersetGroup;
      var end = i + 1;
      if (group != null) {
        while (end < exercises.length &&
            exercises[end].supersetGroup == group) {
          end++;
        }
      }
      if (children.isNotEmpty) children.add(const _Divider());
      if (group != null && end - i > 1) {
        children.add(
          _SupersetBlock(
            label: group,
            rest: plan.restFor(exercises[end - 1]),
            exercises: exercises.sublist(i, end),
          ),
        );
      } else {
        children.add(
          _ExerciseRow(
            exercise: exercises[i],
            rest: plan.restFor(exercises[i]),
          ),
        );
      }
      i = end;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppColors.border.withValues(alpha: 0.7),
    );
  }
}

String _setsLabel(PlanExercise exercise) {
  final count = exercise.sets.length;
  if (exercise.exercise.tracking.isCardio) {
    return '$count ${polishPlural(count, 'odcinek', 'odcinki', 'odcinków')}';
  }
  final reps = {
    for (final set in exercise.sets) ?int.tryParse(set.reps.trim()),
  }.toList()..sort();
  if (reps.isEmpty) {
    return '$count ${polishPlural(count, 'seria', 'serie', 'serii')}';
  }
  final range = reps.length == 1
      ? '${reps.first}'
      : '${reps.first}–${reps.last}';
  return '$count × $range';
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise, this.rest});

  final PlanExercise exercise;

  /// Przerwa po ćwiczeniu; `null` w superserii (przerwa po rundzie).
  final int? rest;

  @override
  Widget build(BuildContext context) {
    final rest = this.rest;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          ExerciseThumbnail(
            imageUrl: exercise.exercise.imageUrl,
            size: 40,
            borderRadius: 10,
            backgroundColor: AppColors.surfaceVariant,
            placeholder: const Icon(
              Icons.fitness_center_rounded,
              color: AppColors.textMuted,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.exercise.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _setsLabel(exercise),
                  style: AppTextStyles.tabular(AppTextStyles.caption),
                ),
              ],
            ),
          ),
          if (rest != null)
            Text(
              'przerwa ${formatRestRemaining(Duration(seconds: rest))}',
              style: AppTextStyles.tabular(
                AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _SupersetBlock extends StatelessWidget {
  const _SupersetBlock({
    required this.label,
    required this.rest,
    required this.exercises,
  });

  final String label;
  final int rest;
  final List<PlanExercise> exercises;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.superset;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'SUPERSERIA $label',
                style: const TextStyle(
                  color: accent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Text(
                'po rundzie ${formatRestRemaining(Duration(seconds: rest))}',
                style: AppTextStyles.tabular(
                  AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: accent.withValues(alpha: 0.7),
                  width: 3,
                ),
              ),
            ),
            child: Column(
              children: [
                for (final exercise in exercises)
                  _ExerciseRow(exercise: exercise),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
