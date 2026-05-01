import 'package:flutter/material.dart';
import '../../domain/onboarding_data.dart';
import '../widgets/onboarding_scaffold.dart';
import '../../../../core/theme/app_colors.dart';
import 'onboarding_welcome_screen.dart';

class OnboardingDaysScreen extends StatefulWidget {
  const OnboardingDaysScreen({super.key, required this.data});

  final OnboardingData data;

  @override
  State<OnboardingDaysScreen> createState() => _OnboardingDaysScreenState();
}

class _OnboardingDaysScreenState extends State<OnboardingDaysScreen> {
  late Set<int> _selected;

  static const List<String> _dayLabels = ['Pn', 'Wt', 'Śr', 'Cz', 'Pt', 'Sb', 'Nd'];
  static const List<String> _dayFull = [
    'Poniedziałek', 'Wtorek', 'Środa', 'Czwartek', 'Piątek', 'Sobota', 'Niedziela'
  ];

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.data.trainingDays);
  }

  void _handleToggle(int day) {
    setState(() {
      if (_selected.contains(day)) {
        _selected.remove(day);
      } else {
        _selected.add(day);
      }
    });
  }

  void _handleNext() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OnboardingWelcomeScreen(
        data: widget.data.copyWith(trainingDays: Set.from(_selected)),
      ),
    ));
  }

  String get _summaryLabel {
    final count = _selected.length;
    if (count == 0) return 'Wybierz dni treningowe';
    if (count == 7) return 'Trenujesz codziennie 🔥';
    final sorted = _selected.toList()..sort();
    final names = sorted.map((d) => _dayFull[d]).join(', ');
    return '$count ${_dniLabel(count)}: $names';
  }

  String _dniLabel(int count) {
    if (count == 1) return 'dzień';
    if (count < 5) return 'dni';
    return 'dni';
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 6,
      totalSteps: 6,
      title: 'Kiedy trenujesz?',
      subtitle: 'Wybierz dni, w które planujesz być aktywny.',
      onBack: () => Navigator.of(context).pop(),
      onSkip: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OnboardingWelcomeScreen(data: widget.data),
      )),
      onNext: _handleNext,
      nextEnabled: _selected.isNotEmpty,
      child: Column(
        children: [
          _DayGrid(
            selected: _selected,
            dayLabels: _dayLabels,
            onToggle: _handleToggle,
          ),
          const SizedBox(height: 24),
          _SummaryBadge(
            count: _selected.length,
            label: _summaryLabel,
          ),
          const SizedBox(height: 20),
          _PresetRow(onSelect: (days) {
            setState(() => _selected = Set.from(days));
          }),
        ],
      ),
    );
  }
}

class _DayGrid extends StatelessWidget {
  const _DayGrid({
    required this.selected,
    required this.dayLabels,
    required this.onToggle,
  });

  final Set<int> selected;
  final List<String> dayLabels;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final isSel = selected.contains(i);
        return GestureDetector(
          onTap: () => onToggle(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 40,
            height: 56,
            decoration: BoxDecoration(
              color: isSel
                  ? AppColors.primary
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSel ? AppColors.primary : AppColors.border,
                width: isSel ? 2 : 1,
              ),
              boxShadow: isSel
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              dayLabels[i],
              style: TextStyle(
                color: isSel ? Colors.white : AppColors.textMuted,
                fontSize: 13,
                fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _SummaryBadge extends StatelessWidget {
  const _SummaryBadge({required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: count > 0
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: count > 0 ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            count > 0 ? Icons.event_available_rounded : Icons.event_outlined,
            color: count > 0 ? AppColors.primary : AppColors.textMuted,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: count > 0 ? Colors.white : AppColors.textMuted,
                fontSize: 13,
                fontWeight: count > 0 ? FontWeight.w600 : FontWeight.w400,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({required this.onSelect});

  final ValueChanged<List<int>> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Szybki wybór',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PresetChip(label: '3× tydz.', onTap: () => onSelect([0, 2, 4])),
            _PresetChip(label: '4× tydz.', onTap: () => onSelect([0, 1, 3, 4])),
            _PresetChip(label: '5× tydz.', onTap: () => onSelect([0, 1, 2, 3, 4])),
            _PresetChip(label: 'Pn–Sb', onTap: () => onSelect([0, 1, 2, 3, 4, 5])),
          ],
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
