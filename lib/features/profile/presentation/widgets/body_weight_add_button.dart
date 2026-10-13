import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_pressable.dart';

/// Wysokość pasa z przyciskiem „Dodaj pomiar” (z wygaszeniem treści) —
/// tyle lista musi mieć wolnego miejsca na dole.
const kBodyWeightAddBarHeight = 110.0;

/// Przycisk „Dodaj pomiar” zadokowany na dole ekranu, nad wygaszeniem
/// treści, żeby nie zasłaniał listy.
class BodyWeightAddButton extends StatelessWidget {
  const BodyWeightAddButton({
    super.key,
    required this.onPressed,
    this.saving = false,
  });

  final VoidCallback onPressed;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: kBodyWeightAddBarHeight + bottom,
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      alignment: Alignment.bottomCenter,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.45, 1],
          colors: [
            AppColors.background.withValues(alpha: 0),
            AppColors.background.withValues(alpha: 0.92),
            AppColors.background,
          ],
        ),
      ),
      child: Semantics(
        button: true,
        enabled: !saving,
        child: AppPressable(
          onTap: saving ? null : onPressed,
          pressedScale: 0.97,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (saving)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onPrimary,
                    ),
                  )
                else
                  const Icon(
                    Icons.add_rounded,
                    size: 20,
                    color: AppColors.onPrimary,
                  ),
                const SizedBox(width: 8),
                const Text(
                  'Dodaj pomiar',
                  style: TextStyle(
                    color: AppColors.onPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
