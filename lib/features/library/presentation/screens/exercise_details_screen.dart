import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../training/presentation/widgets/session_details/session_section_card.dart';
import '../../domain/models/exercise.dart';
import '../bloc/exercise_details_cubit.dart';
import '../widgets/exercise_actions_sheet.dart';
import '../widgets/exercise_category_badge.dart';
import '../widgets/exercise_details/exercise_details_hero.dart';
import '../widgets/exercise_details/exercise_muscle_map.dart';
import '../widgets/exercise_details/exercise_stats_section.dart';
import '../widgets/library_add_exercise_sheet.dart';

/// Wynik zamknięcia karty ćwiczenia — lista wie, czy coś zmieniono.
enum ExerciseDetailsResult { changed, deleted }

/// Karta ćwiczenia: ilustracja, zaangażowane mięśnie, Twoje rekordy
/// i opis techniki. Własne ćwiczenia można tu edytować i usuwać.
class ExerciseDetailsScreen extends StatefulWidget {
  const ExerciseDetailsScreen({super.key});

  @override
  State<ExerciseDetailsScreen> createState() => _ExerciseDetailsScreenState();
}

class _ExerciseDetailsScreenState extends State<ExerciseDetailsScreen> {
  final _scrollController = ScrollController();
  final _collapsed = ValueNotifier<bool>(false);
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _collapsed.dispose();
    super.dispose();
  }

  double _heroHeight(BuildContext context) =>
      (MediaQuery.sizeOf(context).width * 0.78).clamp(260.0, 420.0);

  void _onScroll() {
    final threshold = _heroHeight(context) - kToolbarHeight - 24;
    _collapsed.value = _scrollController.offset > threshold;
  }

  void _close() {
    context.pop(_changed ? ExerciseDetailsResult.changed : null);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _toggleFavourite() async {
    final cubit = context.read<ExerciseDetailsCubit>();
    try {
      await cubit.toggleFavourite();
      _changed = true;
    } catch (_) {
      if (!mounted) return;
      _showMessage('Nie udało się zaktualizować ulubionych.');
    }
  }

  Future<void> _edit(Exercise exercise) async {
    final cubit = context.read<ExerciseDetailsCubit>();
    final updated = await showLibraryEditExerciseSheet(
      context,
      exercise: exercise,
      onSubmit: cubit.update,
    );
    if (!mounted || updated == null) return;
    _changed = true;
    _showMessage('Zapisano zmiany.');
  }

  Future<void> _delete(Exercise exercise) async {
    final cubit = context.read<ExerciseDetailsCubit>();
    final confirmed = await confirmDeleteExercise(context, exercise);
    if (!confirmed || !mounted) return;
    try {
      await cubit.delete();
      if (!mounted) return;
      context.pop(ExerciseDetailsResult.deleted);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Nie udało się usunąć ćwiczenia.');
    }
  }

  Future<void> _showActions(Exercise exercise) async {
    final action = await showExerciseActionsSheet(
      context,
      exercise: exercise,
      includeDetails: false,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case ExerciseAction.details:
        break;
      case ExerciseAction.favourite:
        await _toggleFavourite();
      case ExerciseAction.edit:
        await _edit(exercise);
      case ExerciseAction.delete:
        await _delete(exercise);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: BlocBuilder<ExerciseDetailsCubit, ExerciseDetailsState>(
          builder: (context, state) {
            final exercise = state.exercise;
            if (exercise == null) {
              return _MissingExercise(loading: state.loading, onBack: _close);
            }
            return _buildContent(context, exercise, state);
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Exercise exercise,
    ExerciseDetailsState state,
  ) {
    final heroHeight = _heroHeight(context);

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverAppBar(
          pinned: true,
          stretch: true,
          expandedHeight: heroHeight,
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          leadingWidth: 60,
          leading: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: Center(
              child: ExerciseHeroButton(
                icon: Icons.arrow_back_ios_new_rounded,
                tooltip: 'Wstecz',
                onPressed: _close,
              ),
            ),
          ),
          title: ValueListenableBuilder<bool>(
            valueListenable: _collapsed,
            builder: (context, collapsed, _) => AnimatedOpacity(
              opacity: collapsed ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: Text(
                exercise.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          actions: [
            ExerciseHeroButton(
              icon: exercise.isFavourite
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              color: exercise.isFavourite
                  ? AppColors.primaryVariant
                  : AppColors.textPrimary,
              tooltip: exercise.isFavourite
                  ? 'Usuń z ulubionych'
                  : 'Dodaj do ulubionych',
              onPressed: _toggleFavourite,
            ),
            const SizedBox(width: AppSpacing.xs),
            ExerciseHeroButton(
              icon: Icons.more_horiz_rounded,
              tooltip: 'Więcej',
              onPressed: () => _showActions(exercise),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            stretchModes: const [StretchMode.zoomBackground],
            background: ExerciseDetailsHero(exercise: exercise),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageGutter,
              0,
              AppSpacing.pageGutter,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TitleBlock(exercise: exercise),
                const SizedBox(height: AppSpacing.xl),
                SessionSectionCard(
                  icon: Icons.accessibility_new_rounded,
                  title: 'Zaangażowane mięśnie',
                  child: ExerciseMuscleMap(muscles: exercise.workingMuscles),
                ),
                const SizedBox(height: AppSpacing.sm),
                SessionSectionCard(
                  icon: Icons.insights_rounded,
                  title: 'Twoje wyniki',
                  child: ExerciseStatsSection(stats: state.stats),
                ),
                const SizedBox(height: AppSpacing.sm),
                SessionSectionCard(
                  icon: Icons.menu_book_rounded,
                  title: 'Technika i wskazówki',
                  child: _DescriptionBody(
                    exercise: exercise,
                    onAddDescription: exercise.isMine
                        ? () => _edit(exercise)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final muscles = exercise.workingMuscles;
    final secondaryCount = muscles.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ExerciseCategoryBadge(category: exercise.category),
            if (exercise.isMine)
              const _Pill(
                icon: Icons.person_rounded,
                label: 'Twoje',
                color: AppColors.primaryVariant,
              ),
            if (exercise.isPendingSync)
              const _Pill(
                icon: Icons.cloud_sync_outlined,
                label: 'Synchronizacja',
                color: AppColors.textSecondary,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          exercise.name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
            height: 1.15,
          ),
        ),
        if (muscles.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: muscles.first.label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (secondaryCount > 0)
                  TextSpan(
                    text:
                        '  ·  ${muscles.skip(1).map((m) => m.shortLabel).join(', ')}',
                  ),
              ],
            ),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DescriptionBody extends StatelessWidget {
  const _DescriptionBody({required this.exercise, this.onAddDescription});

  final Exercise exercise;
  final VoidCallback? onAddDescription;

  @override
  Widget build(BuildContext context) {
    final description = exercise.description.trim();
    if (description.isNotEmpty) {
      return Text(
        description,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          height: 1.55,
        ),
      );
    }
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Brak opisu techniki dla tego ćwiczenia.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13.5),
          ),
        ),
        if (onAddDescription != null)
          TextButton.icon(
            onPressed: onAddDescription,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Dodaj opis'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryVariant,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

class _MissingExercise extends StatelessWidget {
  const _MissingExercise({required this.loading, required this.onBack});

  final bool loading;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ExerciseHeroButton(
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: 'Wstecz',
              onPressed: onBack,
            ),
          ),
          Expanded(
            child: Center(
              child: loading
                  ? const CircularProgressIndicator(color: AppColors.primary)
                  : const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Nie znaleziono ćwiczenia. Mogło zostać usunięte.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Otwiera kartę ćwiczenia. Przekazany obiekt pokazuje się od razu, bez
/// czekania na bazę.
Future<ExerciseDetailsResult?> openExerciseDetails(
  BuildContext context,
  Exercise exercise,
) {
  return context.push<ExerciseDetailsResult>(
    '/app/exercises/${Uri.encodeComponent(exercise.id)}',
    extra: exercise,
  );
}
