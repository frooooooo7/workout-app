import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/training_header.dart';
import '../widgets/training_session_tab.dart';
import '../widgets/training_plans_tab.dart';
import '../widgets/training_history_tab.dart';

enum _TrainingTab { sesja, plany, historia }

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  _TrainingTab _activeTab = _TrainingTab.sesja;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TrainingHeader(
                    onAddTap: () => context.push('/app/training/pick-activity-type'),
                  ),
                  const SizedBox(height: 20),
                  _TrainingTabBar(
                    active: _activeTab,
                    onTabSelected: (tab) => setState(() => _activeTab = tab),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: switch (_activeTab) {
                _TrainingTab.sesja => const TrainingSessionTab(),
                _TrainingTab.plany => const TrainingPlansTab(),
                _TrainingTab.historia => const TrainingHistoryTab(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainingTabBar extends StatelessWidget {
  const _TrainingTabBar({
    required this.active,
    required this.onTabSelected,
  });

  final _TrainingTab active;
  final ValueChanged<_TrainingTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: _TrainingTab.values
            .map((tab) => _TrainingTabItem(
                  tab: tab,
                  isActive: tab == active,
                  onTap: () => onTabSelected(tab),
                ))
            .toList(),
      ),
    );
  }
}

class _TrainingTabItem extends StatelessWidget {
  const _TrainingTabItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  final _TrainingTab tab;
  final bool isActive;
  final VoidCallback onTap;

  String get _label => switch (tab) {
        _TrainingTab.sesja => 'Sesja',
        _TrainingTab.plany => 'Plany',
        _TrainingTab.historia => 'Historia',
      };

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isActive ? AppColors.surfaceVariant : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: isActive ? Colors.white : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
            child: Text(_label),
          ),
        ),
      ),
    );
  }
}
