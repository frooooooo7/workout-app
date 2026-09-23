import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/polish_plural.dart';
import '../../../account/domain/repositories/account_repository.dart';
import '../../../account/presentation/account_settings_routes.dart';
import '../../../account/presentation/bloc/logout_all_devices_cubit.dart';
import '../../../auth/domain/models/auth_models.dart';
import 'profile_details_screen.dart';

const settingsProfileDetailsRowKey = Key('settings-profile-details');
const settingsChangePasswordRowKey = Key('settings-change-password');
const settingsLogoutAllRowKey = Key('settings-logout-all');
const settingsNotificationsRowKey = Key('settings-notifications');
const settingsHelpRowKey = Key('settings-help');
const settingsDeleteAccountRowKey = Key('settings-delete-account');

class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({
    super.key,
    required this.user,
    required this.accountRepository,
  });

  final AuthUser user;
  final AccountRepository accountRepository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LogoutAllDevicesCubit(accountRepository),
      child: _ProfileSettingsView(user: user),
    );
  }
}

class _ProfileSettingsView extends StatelessWidget {
  const _ProfileSettingsView({required this.user});

  final AuthUser user;

  Future<void> _handleLogout(BuildContext context) async {
    final unsynced = await ServiceLocator.countUnsyncedChanges();
    if (!context.mounted) return;
    if (unsynced > 0) {
      final confirmed = await _confirmLogoutWithUnsyncedChanges(
        context,
        unsynced,
      );
      if (confirmed != true || !context.mounted) return;
    }

    await ServiceLocator.tokenStorage.clear();
    if (!context.mounted) return;
    context.go('/login');
    // Zamyka bazę i zatrzymuje synchronizację tego konta. Bez tego ochrona
    // tras /app/* nadal przepuszczała, a dane poprzedniego konta były
    // dostępne np. przyciskiem „wstecz” w przeglądarce.
    ServiceLocator.currentUser.value = null;
  }

  Future<bool?> _confirmLogoutWithUnsyncedChanges(
    BuildContext context,
    int unsynced,
  ) {
    final noun = polishPlural(unsynced, 'zmianę', 'zmiany', 'zmian');
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Niewysłane zmiany',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Masz $unsynced $noun, których nie ma jeszcze na serwerze. '
          'Zostaną na tym telefonie i wyślemy je, gdy znów zalogujesz się '
          'na to konto.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Anuluj',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Wyloguj',
              style: TextStyle(color: AppColors.strengthWeak),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogoutAll(BuildContext context) async {
    final cubit = context.read<LogoutAllDevicesCubit>();
    if (cubit.state.inProgress) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Wylogować ze wszystkich urządzeń?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Zakończymy sesje na wszystkich pozostałych urządzeniach, na których '
          'jesteś zalogowany. Na tym telefonie pozostaniesz zalogowany.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Anuluj',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Wyloguj wszędzie',
              style: TextStyle(color: AppColors.strengthWeak),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await cubit.logoutAllDevices();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LogoutAllDevicesCubit, LogoutAllDevicesState>(
      listenWhen: (previous, current) =>
          current.result != null && previous.result?.id != current.result!.id,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.result!.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('USTAWIENIA'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionLabel(label: 'Konto'),
                const SizedBox(height: 12),
                // Imię i nazwisko mogą się zmienić na ekranie edycji profilu.
                ValueListenableBuilder<AuthUser?>(
                  valueListenable: ServiceLocator.currentUser,
                  builder: (context, current, _) {
                    final shown = current ?? user;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _InfoCard(
                          icon: Icons.person_outline_rounded,
                          label: 'Imię i nazwisko',
                          value: shown.fullName,
                        ),
                        const SizedBox(height: 10),
                        _InfoCard(
                          icon: Icons.mail_outline_rounded,
                          label: 'Adres e-mail',
                          value: shown.email,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                _MenuRow(
                  icon: Icons.edit_outlined,
                  label: 'Edytuj profil',
                  onTap: () => context.push('/app/profile/edit'),
                ),
                const SizedBox(height: 10),
                _MenuRow(
                  key: settingsProfileDetailsRowKey,
                  icon: Icons.monitor_weight_outlined,
                  label: 'Dane i cele',
                  onTap: () => context.push(kProfileDetailsRoute),
                ),
                const SizedBox(height: 32),
                const _SectionLabel(label: 'Bezpieczeństwo'),
                const SizedBox(height: 12),
                _MenuRow(
                  key: settingsChangePasswordRowKey,
                  icon: Icons.lock_outline_rounded,
                  label: 'Zmiana hasła',
                  onTap: () => context.push(kChangePasswordRoute),
                ),
                const SizedBox(height: 10),
                BlocBuilder<LogoutAllDevicesCubit, LogoutAllDevicesState>(
                  buildWhen: (previous, current) =>
                      previous.inProgress != current.inProgress,
                  builder: (context, state) => _MenuRow(
                    key: settingsLogoutAllRowKey,
                    icon: Icons.devices_other_rounded,
                    label: 'Wyloguj ze wszystkich urządzeń',
                    onTap: () => _handleLogoutAll(context),
                    trailing: state.inProgress
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textSecondary,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 32),
                const _SectionLabel(label: 'Ustawienia'),
                const SizedBox(height: 12),
                _MenuRow(
                  key: settingsNotificationsRowKey,
                  icon: Icons.notifications_outlined,
                  label: 'Powiadomienia',
                  onTap: () => context.push(kNotificationSettingsRoute),
                ),
                const SizedBox(height: 10),
                _MenuRow(
                  key: settingsHelpRowKey,
                  icon: Icons.help_outline_rounded,
                  label: 'Pomoc',
                  onTap: () => context.push(kHelpRoute),
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () => _handleLogout(context),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Wyloguj się'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.strengthWeak,
                    side: BorderSide(
                      color: AppColors.strengthWeak.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                const _DangerZone(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DangerZone extends StatelessWidget {
  const _DangerZone();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel(
          label: 'Strefa niebezpieczna',
          color: AppColors.strengthWeak,
        ),
        const SizedBox(height: 12),
        Material(
          color: AppColors.strengthWeak.withValues(alpha: 0.06),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: AppColors.strengthWeak.withValues(alpha: 0.45),
            ),
          ),
          child: InkWell(
            key: settingsDeleteAccountRowKey,
            onTap: () => context.push(kDeleteAccountRoute),
            borderRadius: BorderRadius.circular(14),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.delete_forever_outlined,
                    color: AppColors.strengthWeak,
                    size: 22,
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Usuń konto',
                          style: TextStyle(
                            color: AppColors.strengthWeak,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Trwale usuwa konto i wszystkie Twoje dane.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.strengthWeak,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.color = AppColors.textMuted});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 18),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing = const Icon(
      Icons.chevron_right_rounded,
      color: AppColors.textMuted,
    ),
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
