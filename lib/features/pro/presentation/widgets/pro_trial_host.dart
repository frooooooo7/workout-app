import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/service_locator.dart';
import '../../../auth/domain/models/auth_models.dart';
import '../../data/pro_trial_seen_store.dart';
import '../../domain/pro_trial.dart';
import 'pro_trial_strip.dart';

/// Pokazuje ekrany PRO na ekranie Trening: powitanie (raz, w trakcie
/// miesiąca), koniec trialu (raz, po nim) i pasek w ostatnim tygodniu.
/// Konta bez daty założenia (starsze API) są pomijane.
class ProTrialHost extends StatefulWidget {
  const ProTrialHost({
    super.key,
    this.store = const SharedPreferencesProTrialSeenStore(),
    this.clock = DateTime.now,
  });

  final ProTrialSeenStore store;

  /// Test seam.
  final DateTime Function() clock;

  @override
  State<ProTrialHost> createState() => _ProTrialHostState();
}

class _ProTrialHostState extends State<ProTrialHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowScreen());
  }

  Future<void> _maybeShowScreen() async {
    final user = ServiceLocator.currentUser.value;
    final createdAt = user?.createdAt;
    if (user == null || createdAt == null || !user.onboardingCompleted) return;

    final trial = ProTrial.of(createdAt, now: widget.clock());
    String? route;
    if (trial.isActive) {
      if (!await widget.store.welcomeSeen(user.id)) {
        await widget.store.markWelcomeSeen(user.id);
        // Konto założone dawno (np. po aktualizacji aplikacji) nie dostaje
        // powitania „30 dni”, tylko ewentualnie pasek na koniec.
        if (trial.isFresh) route = '/pro/welcome';
      }
    } else if (!await widget.store.endSeen(user.id)) {
      await widget.store.markEndSeen(user.id);
      route = '/pro/trial-end';
    }
    if (route == null || !mounted) return;
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AuthUser?>(
      valueListenable: ServiceLocator.currentUser,
      builder: (context, user, _) {
        final createdAt = user?.createdAt;
        if (createdAt == null) return const SizedBox.shrink();
        final trial = ProTrial.of(createdAt, now: widget.clock());
        if (!trial.isEnding) return const SizedBox.shrink();
        return ProTrialStrip(
          trial: trial,
          onTap: () => context.push('/pro/welcome?info=1'),
        );
      },
    );
  }
}
