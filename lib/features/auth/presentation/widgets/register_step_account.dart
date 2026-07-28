import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../utils/auth_validators.dart';
import 'auth_error_banner.dart';
import 'auth_text_field.dart';
import 'password_strength_widgets.dart';

class RegisterStepAccount extends StatelessWidget {
  const RegisterStepAccount({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.passwordVisible,
    required this.password,
    required this.strength,
    required this.hasMinLength,
    required this.hasUpperCase,
    required this.hasDigit,
    required this.errorMessage,
    required this.isLoading,
    required this.onPasswordChanged,
    required this.onTogglePasswordVisibility,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool passwordVisible;
  final String password;
  final PasswordStrength strength;
  final bool hasMinLength;
  final bool hasUpperCase;
  final bool hasDigit;
  final String? errorMessage;
  final bool isLoading;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ustaw dostęp',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Krok 2 z 2 — e-mail i hasło do logowania.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          AuthTextField(
            hint: 'E-mail',
            prefixIcon: Icons.mail_outline_rounded,
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: validateAuthEmail,
          ),
          const SizedBox(height: 12),
          AuthTextField(
            hint: 'Hasło',
            prefixIcon: Icons.lock_outline_rounded,
            controller: passwordController,
            obscureText: !passwordVisible,
            onChanged: onPasswordChanged,
            textInputAction: TextInputAction.done,
            suffixIcon: IconButton(
              icon: Icon(
                passwordVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textMuted,
                size: 20,
              ),
              onPressed: onTogglePasswordVisibility,
            ),
            validator: validateRegisterPassword,
          ),
          if (password.isNotEmpty) ...[
            const SizedBox(height: 10),
            PasswordStrengthBar(strength: strength),
            const SizedBox(height: 12),
            PasswordRequirementsCard(
              hasMinLength: hasMinLength,
              hasUpperCase: hasUpperCase,
              hasDigit: hasDigit,
            ),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            AuthErrorBanner(message: errorMessage!),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: isLoading ? null : onSubmit,
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onPrimary,
                    ),
                  )
                : const Text('Utwórz konto'),
          ),
        ],
      ),
    );
  }
}
