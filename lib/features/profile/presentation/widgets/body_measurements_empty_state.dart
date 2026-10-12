import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../body_highlighter/models/body_gender.dart';
import 'body_measurement_silhouette.dart';

const bodyMeasurementsEmptyAddKey = Key('body-measurements-empty-add');

/// Brak pomiarów: sama sylwetka, krótka wskazówka, jak mierzyć, i przycisk
/// pierwszego wpisu. Lista, żeby pull-to-refresh działał też tutaj.
class BodyMeasurementsEmptyState extends StatelessWidget {
  const BodyMeasurementsEmptyState({
    super.key,
    required this.gender,
    required this.onAdd,
  });

  /// `null`, dopóki płeć z profilu się wczytuje.
  final BodyGender? gender;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pageGutter,
        AppSpacing.xs,
        AppSpacing.pageGutter,
        AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Opacity(
          opacity: 0.6,
          child: gender == null
              ? const SizedBox(height: BodyMeasurementSilhouette.height)
              : BodyMeasurementSilhouette(gender: gender!, deltas: const {}),
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Brak pomiarów',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            'Mierz obwody co kilka tygodni, rano i w tym samym miejscu — '
            'tutaj zobaczysz, jak zmienia się sylwetka.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: FilledButton.icon(
            key: bodyMeasurementsEmptyAddKey,
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Dodaj pierwsze pomiary'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
