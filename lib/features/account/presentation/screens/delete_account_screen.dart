import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/polish_plural.dart';
import '../../../auth/presentation/widgets/auth_error_banner.dart';
import '../bloc/delete_account_cubit.dart';
import '../widgets/account_password_field.dart';

const deleteAccountPasswordFieldKey = Key('delete-account-password');
const deleteAccountConfirmCheckboxKey = Key('delete-account-confirm');
const deleteAccountSubmitButtonKey = Key('delete-account-submit');
const deleteAccountUnsyncedWarningKey = Key('delete-account-unsynced');

/// Wymaga [DeleteAccountCubit] w kontekście. Po udanym usunięciu sesja się
/// kończy, a router przenosi na ekran logowania.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  @override
  void initState() {
    super.initState();
    context.read<DeleteAccountCubit>().loadUnsyncedChanges();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('USUŃ KONTO')),
      body: SafeArea(
        child: BlocBuilder<DeleteAccountCubit, DeleteAccountState>(
          builder: (context, state) {
            final cubit = context.read<DeleteAccountCubit>();
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _ConsequencesCard(),
                  if (state.unsyncedChanges > 0) ...[
                    const SizedBox(height: 14),
                    _UnsyncedWarning(count: state.unsyncedChanges),
                  ],
                  const SizedBox(height: 24),
                  AccountPasswordField(
                    key: deleteAccountPasswordFieldKey,
                    label: 'Hasło',
                    enabled: !state.deleting,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onChanged: cubit.passwordChanged,
                  ),
                  const SizedBox(height: 14),
                  Material(
                    color: Colors.transparent,
                    child: CheckboxListTile(
                      key: deleteAccountConfirmCheckboxKey,
                      value: state.confirmed,
                      onChanged: state.deleting
                          ? null
                          : (value) => cubit.confirmationChanged(value ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.strengthWeak,
                      title: const Text(
                        'Rozumiem, że usunięcia konta nie można cofnąć, '
                        'a moje dane zostaną trwale usunięte.',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                  if (state.error != null) ...[
                    const SizedBox(height: 12),
                    AuthErrorBanner(message: state.error!),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    key: deleteAccountSubmitButtonKey,
                    onPressed: state.canSubmit ? cubit.submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.strengthWeak,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.strengthWeak
                          .withValues(alpha: 0.25),
                      disabledForegroundColor: Colors.white54,
                    ),
                    icon: state.deleting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.delete_forever_rounded, size: 20),
                    label: Text(
                      state.deleting ? 'Usuwanie konta…' : 'Usuń konto na zawsze',
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ConsequencesCard extends StatelessWidget {
  const _ConsequencesCard();

  static const _items = [
    'wszystkie treningi i ich historia,',
    'plany treningowe i własne ćwiczenia,',
    'posty w feedzie, kudosy i komentarze,',
    'obserwowani i obserwujący.',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.strengthWeak.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.strengthWeak.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.strengthWeak,
                size: 22,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tej operacji nie można cofnąć',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Usunięcie konta trwale skasuje z serwera:',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 8),
          for (final item in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '•  ',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          const Text(
            'Dane zapisane na tym telefonie również zostaną usunięte. '
            'Aby potwierdzić, podaj swoje hasło.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnsyncedWarning extends StatelessWidget {
  const _UnsyncedWarning({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final noun = polishPlural(count, 'zmianę', 'zmiany', 'zmian');
    return Container(
      key: deleteAccountUnsyncedWarningKey,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.strengthMedium.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.strengthMedium.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: AppColors.strengthMedium,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Masz $count $noun, których nie ma jeszcze na serwerze. '
              'Przepadną razem z kontem.',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
