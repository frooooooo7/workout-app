import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'auth_text_field.dart';

class RegisterStepName extends StatelessWidget {
  const RegisterStepName({
    super.key,
    required this.formKey,
    required this.firstNameController,
    required this.lastNameController,
    required this.onNext,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Jak masz na imię?',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Krok 1 z 2 — kilka podstawowych danych.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          AuthTextField(
            hint: 'Imię',
            prefixIcon: Icons.person_outline_rounded,
            controller: firstNameController,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Imię jest wymagane.' : null,
          ),
          const SizedBox(height: 12),
          AuthTextField(
            hint: 'Nazwisko',
            prefixIcon: Icons.person_outline_rounded,
            controller: lastNameController,
            textInputAction: TextInputAction.done,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Nazwisko jest wymagane.'
                : null,
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: onNext, child: const Text('Dalej')),
        ],
      ),
    );
  }
}
