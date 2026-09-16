import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../bloc/notification_settings_cubit.dart';

const restTimerNotificationSwitchKey = Key('rest-timer-notification-switch');

/// Wymaga [NotificationSettingsCubit] w kontekście.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationSettingsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<NotificationSettingsCubit, NotificationSettingsState>(
      listenWhen: (previous, current) =>
          current.error != null && previous.error != current.error,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.error!),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('POWIADOMIENIA')),
        body: SafeArea(
          child: BlocBuilder<NotificationSettingsCubit, NotificationSettingsState>(
            builder: (context, state) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                children: [
                  Material(
                    color: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SwitchListTile(
                      key: restTimerNotificationSwitchKey,
                      value: state.restTimerNotificationsEnabled,
                      onChanged: state.loading
                          ? null
                          : context
                                .read<NotificationSettingsCubit>()
                                .setRestTimerNotificationsEnabled,
                      activeThumbColor: AppColors.primaryVariant,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      secondary: const Icon(
                        Icons.timer_outlined,
                        color: AppColors.textSecondary,
                      ),
                      title: const Text(
                        'Powiadomienie o końcu przerwy',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Systemowe powiadomienie, gdy skończy się odliczanie '
                          'przerwy w trakcie treningu — także przy '
                          'zablokowanym ekranie.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Po wyłączeniu timer przerwy nadal odlicza czas na ekranie '
                    'treningu, ale telefon nie wyśle powiadomienia.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
