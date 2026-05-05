import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class AuthSocialButtonsRow extends StatelessWidget {
  const AuthSocialButtonsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: AuthSocialOutlineIconButton(icon: Icons.apple)),
        const SizedBox(width: 12),
        Expanded(
          child:
              AuthSocialOutlineIconButton(icon: Icons.g_mobiledata_rounded),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AuthSocialOutlineIconButton(icon: Icons.facebook_rounded),
        ),
      ],
    );
  }
}

class AuthSocialOutlineIconButton extends StatelessWidget {
  const AuthSocialOutlineIconButton({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Icon(icon, color: AppColors.textPrimary, size: 26),
    );
  }
}
