import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../utils/handle_availability.dart';

/// Podpowiedź pod polem nicku; zajęty nick pokazuje się jako `errorText`.
String? handleAvailabilityHelperText(HandleAvailability status) =>
    switch (status) {
      HandleAvailability.checking => 'Sprawdzam dostępność…',
      HandleAvailability.available => 'Nick jest wolny',
      HandleAvailability.taken || HandleAvailability.unknown => null,
    };

Color? handleAvailabilityHelperColor(HandleAvailability status) =>
    status == HandleAvailability.available ? AppColors.success : null;

/// Ikona na końcu pola nicku: kółko podczas sprawdzania, ptaszek gdy wolny.
Widget? handleAvailabilitySuffix(HandleAvailability status) => switch (status) {
  HandleAvailability.checking => const Padding(
    padding: EdgeInsets.all(14),
    child: SizedBox.square(
      dimension: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: AppColors.textMuted,
      ),
    ),
  ),
  HandleAvailability.available => const Icon(
    Icons.check_circle_rounded,
    color: AppColors.success,
    size: 20,
  ),
  HandleAvailability.taken || HandleAvailability.unknown => null,
};
