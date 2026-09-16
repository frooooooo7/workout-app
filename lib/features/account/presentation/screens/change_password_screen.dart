import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/widgets/auth_error_banner.dart';
import '../../../auth/presentation/widgets/password_strength_widgets.dart';
import '../bloc/change_password_cubit.dart';
import '../bloc/change_password_state.dart';
import '../widgets/account_password_field.dart';

const changePasswordCurrentFieldKey = Key('change-password-current');
const changePasswordNewFieldKey = Key('change-password-new');
const changePasswordConfirmFieldKey = Key('change-password-confirm');
const changePasswordSubmitButtonKey = Key('change-password-submit');

const kChangePasswordSuccessMessage =
    'Hasło zostało zmienione. Pozostałe urządzenia zostały wylogowane.';

/// Wymaga [ChangePasswordCubit] w kontekście. Po sukcesie pokazuje SnackBar
/// i zamyka się.
class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChangePasswordCubit, ChangePasswordState>(
      listenWhen: (previous, current) =>
          !previous.succeeded && current.succeeded,
      listener: (context, _) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).maybePop();
        messenger.showSnackBar(
          const SnackBar(
            content: Text(kChangePasswordSuccessMessage),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('ZMIANA HASŁA')),
        body: SafeArea(
          child: BlocBuilder<ChangePasswordCubit, ChangePasswordState>(
            builder: (context, state) {
              final cubit = context.read<ChangePasswordCubit>();
              final newPassword = state.newPassword;
              return AutofillGroup(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Po zmianie hasła zostaniesz wylogowany na wszystkich '
                        'pozostałych urządzeniach. Na tym telefonie sesja '
                        'pozostanie aktywna.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      AccountPasswordField(
                        key: changePasswordCurrentFieldKey,
                        label: 'Obecne hasło',
                        enabled: !state.submitting,
                        autofillHints: const [AutofillHints.password],
                        onChanged: cubit.currentPasswordChanged,
                      ),
                      const SizedBox(height: 18),
                      AccountPasswordField(
                        key: changePasswordNewFieldKey,
                        label: 'Nowe hasło',
                        enabled: !state.submitting,
                        autofillHints: const [AutofillHints.newPassword],
                        errorText: state.newPasswordError,
                        onChanged: cubit.newPasswordChanged,
                      ),
                      if (newPassword.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        PasswordStrengthBar(
                          strength: passwordStrengthFor(newPassword),
                        ),
                        const SizedBox(height: 12),
                        PasswordRequirementsCard(
                          hasMinLength: newPassword.length >= 8,
                          hasUpperCase: newPassword.contains(RegExp(r'[A-Z]')),
                          hasDigit: newPassword.contains(RegExp(r'[0-9]')),
                        ),
                      ],
                      const SizedBox(height: 18),
                      AccountPasswordField(
                        key: changePasswordConfirmFieldKey,
                        label: 'Powtórz nowe hasło',
                        enabled: !state.submitting,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        errorText: state.confirmPasswordError,
                        onChanged: cubit.confirmPasswordChanged,
                        onSubmitted: (_) => cubit.submit(),
                      ),
                      if (state.error != null) ...[
                        const SizedBox(height: 20),
                        AuthErrorBanner(message: state.error!),
                      ],
                      const SizedBox(height: 28),
                      ElevatedButton(
                        key: changePasswordSubmitButtonKey,
                        onPressed: state.canSubmit ? cubit.submit : null,
                        child: state.submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.onPrimary,
                                ),
                              )
                            : const Text('Zmień hasło'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
