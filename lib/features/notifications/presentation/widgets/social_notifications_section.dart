import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../account/presentation/widgets/workout_reminder_section.dart'
    show NotificationSectionLabel;
import '../../domain/models/app_notification.dart';
import '../bloc/social_notification_settings_cubit.dart';

const socialKudosSwitchKey = Key('social-kudos-switch');
const socialFollowsSwitchKey = Key('social-follows-switch');
const socialPlanCopiesSwitchKey = Key('social-plan-copies-switch');
const socialRecordsSwitchKey = Key('social-records-switch');
const quietHoursSwitchKey = Key('quiet-hours-switch');
const quietHoursFromKey = Key('quiet-hours-from');
const quietHoursToKey = Key('quiet-hours-to');

/// `07:00` → `7:00`.
String formatQuietHour(String value) =>
    value.startsWith('0') && value.length == 5 ? value.substring(1) : value;

/// „Społeczność” i „Ciche godziny” w ustawieniach powiadomień.
/// Wymaga [SocialNotificationSettingsCubit] w kontekście.
class SocialNotificationsSection extends StatelessWidget {
  const SocialNotificationsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<
      SocialNotificationSettingsCubit,
      SocialNotificationSettingsState
    >(
      listenWhen: (previous, current) =>
          current.error != null && previous.errorSeq != current.errorSeq,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(state.error!),
              behavior: SnackBarBehavior.floating,
            ),
          );
      },
      builder: (context, state) {
        final cubit = context.read<SocialNotificationSettingsCubit>();
        final settings = state.settings ?? const NotificationSettings();
        final enabled = state.settings != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const NotificationSectionLabel('Społeczność'),
            _Card(
              children: [
                _SwitchRow(
                  key: socialKudosSwitchKey,
                  title: 'Kudosy',
                  subtitle: 'grupowane, jedno na trening',
                  value: settings.kudos,
                  onChanged: enabled ? cubit.setKudos : null,
                ),
                _SwitchRow(
                  key: socialFollowsSwitchKey,
                  title: 'Nowi obserwujący',
                  value: settings.follows,
                  onChanged: enabled ? cubit.setFollows : null,
                ),
                _SwitchRow(
                  key: socialPlanCopiesSwitchKey,
                  title: 'Ktoś kopiuje mój plan',
                  value: settings.planCopies,
                  onChanged: enabled ? cubit.setPlanCopies : null,
                ),
                _SwitchRow(
                  key: socialRecordsSwitchKey,
                  title: 'Rekordy obserwowanych',
                  subtitle: 'tylko w aplikacji, bez powiadomień push',
                  value: settings.records,
                  onChanged: enabled ? cubit.setRecords : null,
                ),
              ],
            ),
            if (state.loadFailed) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Nie udało się wczytać ustawień społeczności.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                  TextButton(onPressed: cubit.load, child: const Text('Ponów')),
                ],
              ),
            ],
            const SizedBox(height: 14),
            _QuietHoursCard(
              quietHours: settings.quietHours,
              onChanged: enabled ? cubit.setQuietHours : null,
            ),
          ],
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: AppColors.surfaceVariant,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.primaryVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      secondary: icon == null
          ? null
          : Icon(icon, color: const Color(0xFFA78BFA)),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}

class _QuietHoursCard extends StatelessWidget {
  const _QuietHoursCard({required this.quietHours, required this.onChanged});

  final QuietHours quietHours;
  final ValueChanged<QuietHours>? onChanged;

  Future<void> _pick(BuildContext context, {required bool from}) async {
    final current = from ? quietHours.from : quietHours.to;
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 22,
        minute: int.tryParse(parts.last) ?? 0,
      ),
      helpText: from ? 'Cisza od' : 'Cisza do',
    );
    if (picked == null) return;
    final value =
        '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    onChanged?.call(
      from ? quietHours.copyWith(from: value) : quietHours.copyWith(to: value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final range =
        '${formatQuietHour(quietHours.from)}–${formatQuietHour(quietHours.to)}';
    return _Card(
      children: [
        _SwitchRow(
          key: quietHoursSwitchKey,
          icon: Icons.bedtime_outlined,
          title: 'Ciche godziny',
          subtitle: quietHours.enabled
              ? 'społeczność wyciszona $range'
              : 'wyłączone',
          value: quietHours.enabled,
          onChanged: onChanged == null
              ? null
              : (enabled) => onChanged!(quietHours.copyWith(enabled: enabled)),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: quietHours.enabled
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TimeChip(
                          key: quietHoursFromKey,
                          label: 'Od',
                          value: formatQuietHour(quietHours.from),
                          onTap: onChanged == null
                              ? null
                              : () => _pick(context, from: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TimeChip(
                          key: quietHoursToKey,
                          label: 'Do',
                          value: formatQuietHour(quietHours.to),
                          onTap: onChanged == null
                              ? null
                              : () => _pick(context, from: false),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
