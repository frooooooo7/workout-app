import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class LoginTermsFooter extends StatelessWidget {
  const LoginTermsFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: const TextSpan(
        style:
            TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.5),
        children: [
          TextSpan(text: 'Kontynuując, akceptujesz nasz '),
          TextSpan(
            text: 'Regulamin',
            style: TextStyle(color: AppColors.primary),
          ),
          TextSpan(text: '\noraz '),
          TextSpan(
            text: 'Politykę prywatności',
            style: TextStyle(color: AppColors.primary),
          ),
          TextSpan(text: '.'),
        ],
      ),
    );
  }
}
