import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/models/auth_models.dart';
import '../../domain/models/user_profile.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({
    super.key,
    required this.user,
    this.initialProfile,
  });

  final AuthUser user;
  final UserProfile? initialProfile;

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late UserProfile? _profile = widget.initialProfile;

  Future<void> _handleEditProfile(BuildContext context) async {
    final updated = await context.push<UserProfile>(
      AppRoutes.editProfile,
      extra: _profile,
    );
    if (!context.mounted || updated == null) return;
    setState(() => _profile = updated);
  }

  Future<void> _handleLogout(BuildContext context) async {
    await ServiceLocator.tokenStorage.clear();
    if (!context.mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('USTAWIENIA'),
      ),
      body: SafeArea(
        child: ValueListenableBuilder<AuthUser?>(
          valueListenable: ServiceLocator.currentUser,
          builder: (context, currentUser, _) {
            final displayUser = currentUser ?? widget.user;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SectionLabel(label: 'Konto'),
                  const SizedBox(height: 12),
                  _MenuRow(
                    icon: Icons.edit_outlined,
                    label: 'Edytuj profil',
                    onTap: () => _handleEditProfile(context),
                  ),
                  const SizedBox(height: 10),
                  _InfoCard(
                    icon: Icons.person_outline_rounded,
                    label: 'Imię i nazwisko',
                    value: displayUser.fullName,
                  ),
                  const SizedBox(height: 10),
                  _InfoCard(
                    icon: Icons.mail_outline_rounded,
                    label: 'Adres e-mail',
                    value: displayUser.email,
                  ),
                  const SizedBox(height: 32),
                  const _SectionLabel(label: 'Ustawienia'),
                  const SizedBox(height: 12),
                  _MenuRow(
                    icon: Icons.notifications_outlined,
                    label: 'Powiadomienia',
                    onTap: () {},
                    trailing: const _ComingSoon(),
                  ),
                  const SizedBox(height: 10),
                  _MenuRow(
                    icon: Icons.lock_outline_rounded,
                    label: 'Zmiana hasła',
                    onTap: () {},
                    trailing: const _ComingSoon(),
                  ),
                  const SizedBox(height: 10),
                  _MenuRow(
                    icon: Icons.help_outline_rounded,
                    label: 'Pomoc',
                    onTap: () {},
                    trailing: const _ComingSoon(),
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
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textMuted,
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
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
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

class _ComingSoon extends StatelessWidget {
  const _ComingSoon();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'Wkrótce',
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
