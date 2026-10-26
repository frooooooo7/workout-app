import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/keyboard.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/plan_colors.dart';
import '../../../../core/theme/plan_icons.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../library/domain/models/exercise.dart';
import '../../domain/models/custom_training_plan.dart';
import '../../domain/models/training_session.dart';
import '../../domain/services/rest_history.dart';
import '../../domain/services/superset_groups.dart';
import '../bloc/training_plans_cubit.dart';
import '../widgets/editable_exercise_card.dart';
import '../widgets/ongoing_workout/exercise_thumb.dart';
import '../widgets/ongoing_workout/rest_timer_controls.dart'
    show formatRestRemaining;
import '../widgets/ongoing_workout/superset_block_card.dart' show SupersetChip;
import '../widgets/plan_editor/plan_rest_sheet.dart';
import '../widgets/plan_editor/rest_chip.dart';
import 'plan_appearance_screen.dart';
import 'plan_settings_screen.dart';

class CreatePlanArgs {
  final TrainingPlansCubit cubit;
  final CustomTrainingPlan? existingPlan;
  final List<int> initialSelectedDays;

  const CreatePlanArgs({
    required this.cubit,
    this.existingPlan,
    this.initialSelectedDays = const [],
  });
}

class CreatePlanScreen extends StatefulWidget {
  const CreatePlanScreen({
    super.key,
    this.existingPlan,
    this.initialSelectedDays = const [],
    this.loadHistory,
  });

  final CustomTrainingPlan? existingPlan;
  final List<int> initialSelectedDays;

  /// Ukończone treningi do podpowiedzi przerwy; domyślnie lokalna historia.
  final Future<List<TrainingSession>> Function()? loadHistory;

  @override
  State<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends State<CreatePlanScreen> {
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  List<PlanExercise> _exercises = [];
  List<int> _selectedDays = [];
  bool _showNotes = false;

  /// Wygląd i ustawienia planu (bez nazwy, notatki, dni i ćwiczeń).
  late CustomTrainingPlan _settings;

  Future<List<TrainingSession>?>? _history;

  static const List<String> _weekDays = [
    'Pn',
    'Wt',
    'Śr',
    'Cz',
    'Pt',
    'So',
    'Nd',
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existingPlan;
    if (existing != null) {
      _nameController.text = existing.name;
      _noteController.text = existing.note ?? '';
      _showNotes = existing.note?.isNotEmpty == true;
      _exercises = List.from(existing.exercises);
      _selectedDays = List.from(existing.selectedDays);
      _settings = existing;
    } else {
      _selectedDays = List.from(widget.initialSelectedDays);
      _settings = CustomTrainingPlan(name: '');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _addExercise(Exercise exercise) {
    final goal = _settings.goal;
    setState(() {
      _exercises.add(
        PlanExercise(
          exercise: exercise,
          isExpanded: true,
          sets: goal == null
              ? null
              : [ExerciseSet(reps: goal.repRange.replaceAll('–', '-'))],
        ),
      );
    });
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
      _exercises = SupersetGroups.normalize(_exercises);
    });
  }

  /// `onReorderItem` podaje już [newIndex] po usunięciu elementu z [oldIndex]
  /// — ręczne `newIndex -= 1` (potrzebne przy starym `onReorder`) przesuwałoby
  /// ćwiczenie o jedną pozycję za wysoko. Ćwiczenie wyciągnięte z superserii
  /// z niej wypada (grupa zostaje tylko ze stykających się ćwiczeń).
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final item = _exercises.removeAt(oldIndex);
      _exercises.insert(newIndex, item);
      _exercises = SupersetGroups.normalize(_exercises);
    });
  }

  void _toggleDay(int dayIndex) {
    setState(() {
      final actualDay = dayIndex + 1; // 1 to 7
      if (_selectedDays.contains(actualDay)) {
        _selectedDays.remove(actualDay);
      } else {
        _selectedDays.add(actualDay);
      }
    });
  }

  void _link(int index) {
    HapticFeedback.mediumImpact();
    setState(() {
      _exercises = SupersetGroups.linkWithNext(_exercises, index);
    });
  }

  void _unlink(String group) {
    HapticFeedback.selectionClick();
    setState(() {
      _exercises = SupersetGroups.unlink(_exercises, group);
    });
  }

  Future<List<TrainingSession>?> _loadHistory() async {
    try {
      final load = widget.loadHistory;
      if (load != null) return await load();
      return await ServiceLocator.trainingStatsRepository
          .allCompletedSessions();
    } catch (_) {
      // Bez historii (albo bez zalogowanego użytkownika) — bez podpowiedzi.
      return null;
    }
  }

  Future<RestAverage?> _averageFor(PlanExercise exercise) async {
    // Pierwsze wczytanie historii (mapowanie wierszy na modele) rusza po
    // wjeździe arkusza — nie dzieli klatek z jego animacją.
    if (_history == null) {
      await Future<void>.delayed(const Duration(milliseconds: 320));
    }
    final history = await (_history ??= _loadHistory());
    if (history == null) return null;
    return RestHistory.average(
      history,
      exerciseId: exercise.exercise.id,
      exerciseName: exercise.exercise.name,
    );
  }

  Future<void> _editRest(int index) async {
    final exercise = _exercises[index];
    final group = exercise.supersetGroup;
    final defaultRest = _settings.defaultRestSeconds;
    final choice = await showPlanRestSheet(
      context,
      title: group == null ? 'Przerwa po serii' : 'Przerwa po rundzie',
      subtitle: group == null ? exercise.exercise.name : 'Superseria $group',
      initialSeconds: exercise.restSeconds ?? defaultRest,
      showDefaultButton: true,
      leading: ExerciseThumb(
        imageUrl: exercise.exercise.imageUrl,
        size: 44,
        radius: 12,
      ),
      average: _averageFor(exercise),
    );
    if (choice == null || !mounted) return;
    final seconds = choice.seconds;
    setState(() {
      final current = _exercises[index];
      if (seconds != null && choice.asPlanDefault) {
        _settings = _settings.copyWith(defaultRestSeconds: seconds);
        _exercises[index] = current.copyWith(clearRestSeconds: true);
      } else if (seconds == null || seconds == defaultRest) {
        _exercises[index] = current.copyWith(clearRestSeconds: true);
      } else {
        _exercises[index] = current.copyWith(restSeconds: seconds);
      }
    });
  }

  Future<void> _editDefaultRest() async {
    final choice = await showPlanRestSheet(
      context,
      title: 'Domyślna przerwa',
      subtitle: 'Dla ćwiczeń bez własnej przerwy',
      initialSeconds: _settings.defaultRestSeconds,
      showDefaultButton: false,
    );
    final seconds = choice?.seconds;
    if (seconds == null || !mounted) return;
    setState(() {
      _settings = _settings.copyWith(defaultRestSeconds: seconds);
      // Ćwiczenia z przerwą równą nowej domyślnej nie potrzebują własnej.
      _exercises = [
        for (final exercise in _exercises)
          exercise.restSeconds == seconds
              ? exercise.copyWith(clearRestSeconds: true)
              : exercise,
      ];
    });
  }

  Future<void> _openAppearance() async {
    final result = await Navigator.of(context)
        .push<({String? colorKey, String? iconKey})>(
          MaterialPageRoute(
            builder: (_) => PlanAppearanceScreen(
              planName: _nameController.text,
              subtitle: _musclesSummary(),
              selectedDays: _selectedDays,
              colorKey: _settings.colorKey,
              iconKey: _settings.iconKey,
            ),
          ),
        );
    if (result == null || !mounted) return;
    setState(() {
      _settings = _settings.copyWith(
        colorKey: result.colorKey,
        clearColorKey: result.colorKey == null,
        iconKey: result.iconKey,
        clearIconKey: result.iconKey == null,
      );
    });
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<PlanSettingsResult>(
      MaterialPageRoute(
        builder: (_) => PlanSettingsScreen(
          plan: _settings.copyWith(name: _nameController.text),
        ),
      ),
    );
    if (result == null || !mounted) return;
    final goal = result.goal;
    setState(() {
      _settings = _settings.copyWith(
        goal: goal,
        clearGoal: goal == null,
        progressionStepKg: result.progressionStepKg,
        clearProgressionStep: result.progressionStepKg == null,
        highlightPlanColor: result.highlightPlanColor,
        showRir: result.showRir,
        showTempo: result.showTempo,
        isPublic: result.isPublic,
        // Nowy cel ustawia przerwę planu; ćwiczenia z własną ją zachowują.
        defaultRestSeconds: goal != null && goal != _settings.goal
            ? goal.restSeconds
            : null,
      );
    });
  }

  /// „Klatka · Barki · Ramiona” — pierwsze partie ćwiczeń planu.
  String _musclesSummary() {
    final names = <String>[];
    for (final exercise in _exercises) {
      for (final muscle in exercise.exercise.muscles) {
        final label = muscle.label;
        if (!names.contains(label)) names.add(label);
      }
      if (names.length >= 3) break;
    }
    return names.take(3).join(' · ');
  }

  Future<void> _savePlan() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Podaj nazwę planu')));
      return;
    }
    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dodaj przynajmniej jedno ćwiczenie')),
      );
      return;
    }

    final note = _noteController.text.trim();
    final plan = _settings.copyWith(
      id: widget.existingPlan?.id,
      name: name,
      note: note.isEmpty ? null : note,
      clearNote: note.isEmpty,
      exercises: SupersetGroups.normalize(_exercises),
      selectedDays: _selectedDays,
    );

    if (widget.existingPlan != null) {
      await context.read<TrainingPlansCubit>().updatePlan(plan);
    } else {
      await context.read<TrainingPlansCubit>().addPlan(plan);
    }
    if (!mounted) return;
    context.pop();
  }

  Color _planColor(String name) => _settings.colorKey == null
      ? PlanColors.automatic(name)
      : PlanColors.choices[_settings.colorKey]!;

  @override
  Widget build(BuildContext context) {
    final reorderTheme = Theme.of(
      context,
    ).copyWith(canvasColor: Colors.transparent);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppHeader(
              title: widget.existingPlan != null ? 'Edytuj plan' : 'Nowy plan',
              onBack: () => Navigator.of(context).maybePop(),
              actions: [_SaveButton(onTap: _savePlan)],
            ),
            Expanded(
              child: Theme(
                data: reorderTheme,
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                  header: _buildHeader(context),
                  footer: _exercises.isEmpty ? null : const _HintCard(),
                  itemCount: _exercises.length,
                  onReorderItem: _onReorder,
                  buildDefaultDragHandles: false,
                  itemBuilder: _buildExercise,
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          hideKeyboard();
          final exercise = await context.push<Exercise>(
            '/app/training/create-plan/pick-exercise',
          );
          if (exercise != null) {
            _addExercise(exercise);
          }
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Dodaj ćwiczenie',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _nameController,
                    builder: (context, value, _) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _planColor(value.text),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      onTapOutside: hideKeyboardOnTapOutside,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Nazwa planu',
                        hintStyle: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
              if (_showNotes) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _noteController,
                  onTapOutside: hideKeyboardOnTapOutside,
                  maxLines: 2,
                  minLines: 1,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Dodaj krótki opis...',
                    hintStyle: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ] else
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showNotes = true),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Dodaj notatkę'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryVariant,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (index) {
                  final actualDay = index + 1;
                  final isSelected = _selectedDays.contains(actualDay);
                  return GestureDetector(
                    onTap: () => _toggleDay(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      key: ValueKey(
                        'create-plan-day-$actualDay-${isSelected ? 'selected' : 'idle'}',
                      ),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.surfaceVariant,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _weekDays[index],
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 14),
              _SettingRow(
                key: const ValueKey('plan-default-rest-row'),
                icon: Icons.timer_outlined,
                title: 'Domyślna przerwa',
                value: Text(
                  formatRestRemaining(
                    Duration(seconds: _settings.defaultRestSeconds),
                  ),
                  style: AppTextStyles.number(size: 20),
                ),
                onTap: _editDefaultRest,
              ),
              _SettingRow(
                key: const ValueKey('plan-appearance-row'),
                icon: Icons.palette_outlined,
                title: 'Wygląd',
                value: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _nameController,
                  builder: (context, value, _) => PlanBadge(
                    name: value.text.trim().isEmpty ? '?' : value.text,
                    color: _planColor(value.text),
                    iconKey: _settings.iconKey,
                    size: 30,
                    radius: 9,
                  ),
                ),
                onTap: _openAppearance,
              ),
              _SettingRow(
                key: const ValueKey('plan-settings-row'),
                icon: Icons.tune_rounded,
                title: 'Ustawienia',
                value: Text(
                  _settings.goal?.label ?? 'Cel, progresja',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: _openSettings,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              const Text('ĆWICZENIA', style: AppTextStyles.eyebrow),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _summary(),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// „4 ćwiczenia · 13 serii · ~55 min”.
  String _summary() {
    if (_exercises.isEmpty) return '';
    final sets = _exercises.fold<int>(0, (sum, e) => sum + e.sets.length);
    final minutes = _settings.copyWith(exercises: _exercises).estimatedMinutes;
    return '${_exercises.length} ${_plural(_exercises.length, 'ćwiczenie', 'ćwiczenia', 'ćwiczeń')}'
        ' · $sets ${_plural(sets, 'seria', 'serie', 'serii')} · ~$minutes min';
  }

  int _roundsOf(String group) {
    var rounds = 0;
    for (final exercise in _exercises) {
      if (exercise.supersetGroup == group && exercise.sets.length > rounds) {
        rounds = exercise.sets.length;
      }
    }
    return rounds;
  }

  Widget _buildExercise(BuildContext context, int index) {
    final exercise = _exercises[index];
    final group = exercise.supersetGroup;
    final prevGroup = index > 0 ? _exercises[index - 1].supersetGroup : null;
    final nextGroup = index + 1 < _exercises.length
        ? _exercises[index + 1].supersetGroup
        : null;
    final isFirst = group != null && prevGroup != group;
    final isLast = group != null && nextGroup != group;
    final segment = group == null
        ? SupersetSegment.none
        : isFirst
        ? SupersetSegment.first
        : isLast
        ? SupersetSegment.last
        : SupersetSegment.middle;
    var position = 1;
    for (
      var i = index - 1;
      i >= 0 && _exercises[i].supersetGroup == group;
      i--
    ) {
      if (group == null) break;
      position++;
    }
    final canLink =
        index + 1 < _exercises.length && (group == null || group != nextGroup);
    final restChip = RestChip(
      key: ValueKey('plan-rest-chip-$index'),
      seconds: _settings.restFor(exercise),
      isDefault: exercise.restSeconds == null,
      onTap: () => unawaited(_editRest(index)),
    );

    final card = EditableExerciseCard(
      index: index,
      planExercise: exercise,
      onChanged: (newExercise) {
        final previous = _exercises[index];
        _exercises[index] = newExercise;
        if (previous.sets.length != newExercise.sets.length) {
          setState(() {});
        }
      },
      onRemove: () => _removeExercise(index),
      restChip: group == null ? restChip : null,
      supersetLabel: group == null ? null : '$group$position',
      segment: segment,
      bottomMargin: canLink && (group == null || isLast) ? 0 : null,
      header: isFirst
          ? _SupersetHeader(
              group: group,
              rounds: _roundsOf(group),
              onUnlink: () => _unlink(group),
            )
          : null,
      footer: isLast
          ? Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 12, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Przerwa po rundzie',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  restChip,
                ],
              ),
            )
          : null,
    );

    return ReorderableDelayedDragStartListener(
      key: ValueKey(exercise.id),
      index: index,
      child: canLink && (group == null || isLast)
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                card,
                _LinkButton(
                  key: ValueKey('plan-link-$index'),
                  onTap: () => _link(index),
                ),
              ],
            )
          : card,
    );
  }
}

String _plural(int n, String one, String few, String many) {
  if (n == 1) return one;
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: AppPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Text(
            'Zapisz',
            style: TextStyle(
              color: Color(0xFF8FB2FF),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

/// Wiersz karty planu: ikona, nazwa, wartość i strzałka.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Widget value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: AppColors.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: [
                Icon(icon, size: 19, color: AppColors.iconOnTile),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                value,
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SupersetHeader extends StatelessWidget {
  const _SupersetHeader({
    required this.group,
    required this.rounds,
    required this.onUnlink,
  });

  final String group;
  final int rounds;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 6, 0),
      child: Row(
        children: [
          SupersetChip(group: group),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$rounds ${_plural(rounds, 'runda', 'rundy', 'rund')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(fontSize: 13),
            ),
          ),
          TextButton(
            key: ValueKey('plan-unlink-$group'),
            onPressed: onUnlink,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Rozdziel'),
          ),
        ],
      ),
    );
  }
}

/// Łącznik między ćwiczeniami: cienka linia i spinacz „Połącz
/// w superserię”.
class _LinkButton extends StatelessWidget {
  const _LinkButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const SizedBox(
            width: 1.5,
            height: 36,
            child: ColoredBox(color: AppColors.borderStrong),
          ),
          Tooltip(
            message: 'Połącz w superserię',
            child: Semantics(
              button: true,
              label: 'Połącz w superserię',
              excludeSemantics: true,
              child: AppPressable(
                onTap: onTap,
                pressedScale: 0.88,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.superset.withValues(alpha: 0.45),
                    ),
                  ),
                  child: const Icon(
                    Icons.link_rounded,
                    size: 16,
                    color: AppColors.superset,
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

/// Podpowiedź pod listą: przeciąganie i szare przerwy.
class _HintCard extends StatelessWidget {
  const _HintCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Przytrzymaj ćwiczenie, żeby zmienić kolejność. Spinacz łączy '
              'sąsiednie ćwiczenia w superserię. Szara przerwa to domyślna '
              'przerwa planu.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
