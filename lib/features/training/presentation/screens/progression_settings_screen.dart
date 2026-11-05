import 'package:flutter/material.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/units/weight_unit.dart';
import '../../../../core/widgets/app_header.dart';
import '../../data/progression_settings_store.dart';
import '../../domain/models/progression_settings.dart';
import '../widgets/progression/progression_picker.dart';

/// Ustawienia → Progresja: jak aplikacja podpowiada ciężar na następny
/// trening. Każda zmiana zapisuje się od razu (offline też).
class ProgressionSettingsScreen extends StatelessWidget {
  const ProgressionSettingsScreen({super.key, this.store});

  /// Testy; domyślnie [ServiceLocator.progressionSettings].
  final ProgressionSettingsStore? store;

  @override
  Widget build(BuildContext context) {
    final store = this.store ?? ServiceLocator.progressionSettings;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Progresja',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: ValueListenableBuilder<WeightUnit>(
                valueListenable: WeightUnits.notifier,
                builder: (context, _, _) =>
                    ValueListenableBuilder<ProgressionSettings>(
                      valueListenable: store.notifier,
                      builder: (context, settings, _) => ListView(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
                        children: [
                          ProgressionPicker(
                            settings: settings,
                            onChanged: store.set,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Każdy plan może mieć własną metodę: Ustawienia '
                            'planu → Progresja.',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
