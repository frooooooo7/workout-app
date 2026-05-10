import 'package:flutter/material.dart';
import '../widgets/create_plan_stats_card.dart';
import '../widgets/editable_exercise_card.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../library/domain/models/exercise.dart';
import '../../domain/models/custom_training_plan.dart';
import '../bloc/training_plans_cubit.dart';

class CreatePlanArgs {
  final TrainingPlansCubit cubit;
  final CustomTrainingPlan? existingPlan;

  const CreatePlanArgs({required this.cubit, this.existingPlan});
}

class CreatePlanScreen extends StatefulWidget {
  const CreatePlanScreen({super.key, this.existingPlan});

  final CustomTrainingPlan? existingPlan;

  @override
  State<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends State<CreatePlanScreen> {
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  List<PlanExercise> _exercises = [];
  List<int> _selectedDays = [];
  bool _showNotes = false;

  static const List<String> _weekDays = ['Pn', 'Wt', 'Śr', 'Cz', 'Pt', 'So', 'Nd'];

  @override
  void initState() {
    super.initState();
    if (widget.existingPlan != null) {
      _nameController.text = widget.existingPlan!.name;
      _noteController.text = widget.existingPlan!.note ?? '';
      _showNotes = widget.existingPlan!.note?.isNotEmpty == true;
      _exercises = List.from(widget.existingPlan!.exercises);
      _selectedDays = List.from(widget.existingPlan!.selectedDays);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _addExercise(Exercise exercise) {
    setState(() {
      _exercises.add(PlanExercise(exercise: exercise, isExpanded: true));
    });
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _exercises.removeAt(oldIndex);
      _exercises.insert(newIndex, item);
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

  Future<void> _savePlan() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podaj nazwę planu')),
      );
      return;
    }
    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dodaj przynajmniej jedno ćwiczenie')),
      );
      return;
    }

    final plan = CustomTrainingPlan(
      id: widget.existingPlan?.id,
      name: name,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      exercises: _exercises,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.existingPlan != null ? 'Edytuj plan' : 'Nowy plan',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _savePlan,
            child: const Text(
              'Zapisz',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(
                'Nazwa planu',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: TextField(
                controller: _nameController,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration(
                  hintText: 'np. Trening FBW',
                  hintStyle: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            if (_showNotes) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Text(
                  'Notatki',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: TextField(
                  controller: _noteController,
                  maxLines: 2,
                  minLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showNotes = true),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Dodaj notatkę'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Dni treningowe',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (index) {
                  final isSelected = _selectedDays.contains(index + 1);
                  return GestureDetector(
                    onTap: () => _toggleDay(index),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _weekDays[index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),
            CreatePlanStatsCard(
              totalExercises: _exercises.length,
              totalSets: _exercises.fold<int>(0, (sum, ex) => sum + ex.sets.length),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Ćwiczenia',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        final expand = _exercises.any((e) => !e.isExpanded);
                        _exercises = _exercises.map((e) => e.copyWith(isExpanded: expand)).toList();
                      });
                    },
                    child: Row(
                      children: const [
                        Text(
                          'Rozwiń wszystko',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down, color: AppColors.primary, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: Colors.transparent,
                ),
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                  itemCount: _exercises.length,
                  onReorder: _onReorder,
                  buildDefaultDragHandles: false, // Usunięcie domyślnego uchwytu
                  itemBuilder: (context, index) {
                    final planExercise = _exercises[index];
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey(planExercise.id),
                      index: index,
                      child: EditableExerciseCard(
                        index: index,
                        planExercise: planExercise,
                        onChanged: (newExercise) {
                          setState(() {
                            _exercises[index] = newExercise;
                          });
                        },
                        onRemove: () => _removeExercise(index),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final exercise = await context.push<Exercise>('/app/training/create-plan/pick-exercise');
          if (exercise != null) {
            _addExercise(exercise);
          }
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Dodaj ćwiczenie',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
