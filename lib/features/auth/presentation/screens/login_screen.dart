import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/launch/app_launch_controller.dart';
import '../../../../core/launch/launch_ready_signal.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../training/presentation/widgets/training_staggered_entrance.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_hero_background.dart';
import '../widgets/login_notice_banner.dart';
import '../widgets/login_welcome_card.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, this.notice});

  /// Komunikat po zakończeniu sesji (np. wylogowanie na innym urządzeniu,
  /// usunięte konto). Zamknięcie banera czyści wartość.
  final ValueNotifier<String?>? notice;

  @override
  Widget build(BuildContext context) {
    // Start bez konta: nakładka ładowania czeka na zdjęcie i logo (wczytuje
    // je sama), a potem „leci” logo do karty, która wjeżdża po niej.
    return LaunchReadySignal(
      target: LaunchTarget.login,
      ready: true,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: AuthHeroBackground(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (notice != null) LoginNoticeBanner(notice: notice!),
                    TrainingStaggeredEntrance(
                      index: 3,
                      offset: 0,
                      child: AuthCard(
                        glass: true,
                        child: LoginWelcomeCard(
                          onLoginPressed: () => context.push('/login/form'),
                          onRegisterPressed: () =>
                              context.push('/login/register'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
