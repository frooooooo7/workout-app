import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../feed/presentation/widgets/post_author_row.dart';
import '../../../profile/domain/models/profile_details.dart';
import '../../../profile/domain/models/user_profile.dart';
import '../../../profile/presentation/utils/profile_details_labels.dart';
import 'onboarding_step_parts.dart';

const onboardingStartButtonKey = Key('onboarding-start');

/// Podsumowanie po zakończeniu: awatar „wskakuje” z rozchodzącą się
/// poświatą (jak znacznik ukończonego treningu), a pod nim pojawia się to,
/// co udało się ustawić.
class OnboardingStepDone extends StatefulWidget {
  const OnboardingStepDone({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<OnboardingStepDone> createState() => _OnboardingStepDoneState();
}

class _OnboardingStepDoneState extends State<OnboardingStepDone>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animation<double> _interval(
    double begin,
    double end, [
    Curve curve = Curves.easeOutCubic,
  ]) => CurvedAnimation(
    parent: _controller,
    curve: Interval(begin, end, curve: curve),
  );

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final details = profile.details ?? ProfileDetails.empty;
    final stats = _stats(details);
    final chips = _chips(details);

    const padding = EdgeInsets.fromLTRB(
      kOnboardingGutter,
      AppSpacing.lg,
      kOnboardingGutter,
      kOnboardingBottomSpace,
    );
    // Podsumowanie stoi na środku, a gdy się nie mieści — przewija się.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight - padding.vertical,
          ),
          child: Center(child: _content(profile, stats, chips)),
        ),
      ),
    );
  }

  Widget _content(
    UserProfile profile,
    List<({String value, String label})> stats,
    List<Widget> chips,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CelebrationAvatar(
          profile: profile,
          pop: _interval(0, 0.6, Curves.elasticOut),
          halo: _interval(0.2, 1),
          badge: _interval(0.45, 0.75, Curves.easeOutBack),
        ),
        const SizedBox(height: AppSpacing.xl),
        _Reveal(
          animation: _interval(0.3, 0.7),
          child: Column(
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Gotowe, ${profile.firstName}!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                profile.displayHandle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (stats.isNotEmpty || chips.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _Reveal(
            animation: _interval(0.45, 0.85),
            child: Column(
              children: [
                if (stats.isNotEmpty) _SummaryStats(items: stats),
                if (stats.isNotEmpty && chips.isNotEmpty)
                  const SizedBox(height: AppSpacing.sm),
                if (chips.isNotEmpty)
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [for (final chip in chips) chip],
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        _Reveal(
          animation: _interval(0.55, 0.95),
          child: const Text(
            'Zmienisz to w Ustawieniach, w sekcji „Dane i cele”.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }

  static List<({String value, String label})> _stats(ProfileDetails d) {
    final age = d.ageOn(DateTime.now());
    return [
      if (age != null) (value: '$age', label: 'Wiek'),
      if (d.heightCm != null)
        (value: formatHeightCm(d.heightCm!), label: 'Wzrost'),
      if (d.weightKg != null)
        (value: formatWeightKg(d.weightKg!), label: 'Waga'),
    ];
  }

  static List<Widget> _chips(ProfileDetails d) => [
    if (d.trainingGoal != null)
      _SummaryChip(icon: d.trainingGoal!.icon, label: d.trainingGoal!.label),
    if (d.experienceLevel != null)
      _SummaryChip(
        icon: Icons.signal_cellular_alt_rounded,
        label: d.experienceLevel!.label,
      ),
    if (d.weeklyTrainingDays != null)
      _SummaryChip(
        icon: Icons.calendar_month_outlined,
        label: formatWeeklyTrainingDays(d.weeklyTrainingDays!),
      ),
  ];
}

class _CelebrationAvatar extends StatelessWidget {
  const _CelebrationAvatar({
    required this.profile,
    required this.pop,
    required this.halo,
    required this.badge,
  });

  final UserProfile profile;
  final Animation<double> pop;
  final Animation<double> halo;
  final Animation<double> badge;

  static const _size = 140.0;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: _size,
        height: _size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            FadeTransition(
              opacity: Tween<double>(begin: 0.6, end: 0).animate(halo),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.7, end: 1.35).animate(halo),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryVariant.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  child: const SizedBox.square(dimension: _size),
                ),
              ),
            ),
            ScaleTransition(
              scale: pop,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(48),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 32,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: GradientAvatarRing(
                      radius: 46,
                      child: UserAvatar.fromNames(
                        firstName: profile.firstName,
                        lastName: profile.lastName,
                        imageUrl: profile.avatarUrl,
                        size: UserAvatarSize.lg,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: ScaleTransition(
                      scale: badge,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.background,
                            width: 3,
                          ),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Łagodne pojawienie się (przezroczystość + lekkie uniesienie).
class _Reveal extends StatelessWidget {
  const _Reveal({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

/// Jak liczniki na profilu: wartość nad etykietą, kolumny z separatorami.
class _SummaryStats extends StatelessWidget {
  const _SummaryStats({required this.items});

  final List<({String value, String label})> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.border,
                ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      items[i].value,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      items[i].label,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
