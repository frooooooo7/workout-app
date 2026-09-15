import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../bloc/follow_cubit.dart';
import '../bloc/follow_state.dart';

/// Przycisk „Obserwuj” (wypełniony) / „Obserwujesz” (obrysowany).
/// Podczas żądania [busy] blokuje klik, ale zachowuje wygląd stanu.
class FollowButton extends StatelessWidget {
  const FollowButton({
    super.key,
    required this.isFollowing,
    required this.onPressed,
    this.busy = false,
    this.expanded = false,
  });

  final bool isFollowing;
  final VoidCallback? onPressed;
  final bool busy;

  /// Pełna szerokość (profil) zamiast kompaktowego przycisku w wierszu listy.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final handler = busy ? null : onPressed;
    final minimumSize = expanded ? const Size.fromHeight(44) : const Size(112, 36);
    const padding = EdgeInsets.symmetric(horizontal: 14);
    const textStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);

    final Widget button;
    if (isFollowing) {
      button = OutlinedButton(
        onPressed: handler,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          disabledForegroundColor: AppColors.textPrimary.withValues(alpha: 0.7),
          side: const BorderSide(color: AppColors.border),
          minimumSize: minimumSize,
          padding: padding,
          textStyle: textStyle,
        ),
        child: const Text('Obserwujesz'),
      );
    } else {
      button = FilledButton(
        onPressed: handler,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.7),
          disabledForegroundColor: AppColors.onPrimary.withValues(alpha: 0.85),
          minimumSize: minimumSize,
          padding: padding,
          textStyle: textStyle,
        ),
        child: const Text('Obserwuj'),
      );
    }

    return Semantics(
      toggled: isFollowing,
      child: button,
    );
  }
}

/// [FollowButton] podłączony do [FollowCubit] z kontekstu.
class FollowToggleButton extends StatelessWidget {
  const FollowToggleButton({
    super.key,
    required this.userId,
    this.expanded = false,
  });

  final String userId;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FollowCubit, FollowState>(
      buildWhen: (previous, current) =>
          previous.isFollowing(userId) != current.isFollowing(userId) ||
          previous.isPending(userId) != current.isPending(userId),
      builder: (context, state) => FollowButton(
        isFollowing: state.isFollowing(userId),
        busy: state.isPending(userId),
        expanded: expanded,
        onPressed: () => context.read<FollowCubit>().toggle(userId),
      ),
    );
  }
}

/// Pokazuje SnackBar, gdy zmiana obserwowania się nie uda.
class FollowFailureListener extends StatelessWidget {
  const FollowFailureListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<FollowCubit, FollowState>(
      listenWhen: (previous, current) =>
          current.failure != null && previous.failure?.id != current.failure!.id,
      listener: (context, state) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger == null) return;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(state.failure!.message),
              behavior: SnackBarBehavior.floating,
            ),
          );
      },
      child: child,
    );
  }
}

/// Mały znacznik „Obserwuje Cię”.
class FollowsYouChip extends StatelessWidget {
  const FollowsYouChip({super.key});

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
        'Obserwuje Cię',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
