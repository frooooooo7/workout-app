import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_tab_header.dart';
import '../../../feed/presentation/utils/feed_navigation.dart';
import '../../../profile/domain/models/following_user.dart';
import '../../../profile/presentation/bloc/follow_cubit.dart';
import '../../../profile/presentation/widgets/follow_button.dart';
import '../../domain/models/app_notification.dart';
import '../bloc/notifications_cubit.dart';
import '../bloc/notifications_state.dart';
import '../widgets/notification_tile.dart';

const kNotificationsRoute = '/app/notifications';
const kNotificationsSettingsRoute = '/app/notifications/settings';

const notificationsMarkAllKey = Key('notifications-mark-all');
Key notificationFilterKey(NotificationFilter filter) =>
    ValueKey('notification-filter-${filter.name}');

/// Centrum powiadomień: „Nowe” i „Wcześniej”, filtry po rodzaju.
/// Wymaga [NotificationsCubit] i [FollowCubit] w kontekście.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.now});

  /// Do testów: stały „teraz” dla względnego czasu.
  final DateTime? now;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  /// Wiersze widoczne zaraz po wczytaniu wjeżdżają kaskadą; te, które
  /// pojawią się później przy przewijaniu, już nie.
  DateTime? _loadedAt;

  @override
  void initState() {
    super.initState();
    context.read<NotificationsCubit>().load();
  }

  void _open(AppNotification n) {
    context.read<NotificationsCubit>().markRead(n);
    switch (n.type) {
      case AppNotificationType.kudos:
      case AppNotificationType.record:
        final sessionId = n.sessionId;
        if (sessionId != null) openPostDetails(context, sessionId);
      case AppNotificationType.follow:
      case AppNotificationType.planCopy:
        openAuthorProfile(context, n.actor.id, isOwn: false);
    }
  }

  void _seedFollows(BuildContext context, NotificationsState state) {
    context.read<FollowCubit>().seedUsers([
      for (final n in state.items)
        if (n.type == AppNotificationType.follow)
          FollowingUser(
            id: n.actor.id,
            firstName: n.actor.firstName,
            lastName: n.actor.lastName,
            handle: n.actor.handle,
            avatarUrl: n.actor.avatarUrl,
            isFollowing: n.isFollowing,
          ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: FollowFailureListener(
          child: MultiBlocListener(
            listeners: [
              BlocListener<NotificationsCubit, NotificationsState>(
                listenWhen: (previous, current) =>
                    current.notice != null &&
                    previous.notice?.id != current.notice!.id,
                listener: (context, state) {
                  ScaffoldMessenger.maybeOf(context)
                    ?..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(state.notice!.message),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                },
              ),
              // Tylko nowa lista z serwera — nie każde oznaczenie.
              BlocListener<NotificationsCubit, NotificationsState>(
                listenWhen: (previous, current) =>
                    !identical(previous.newIds, current.newIds),
                listener: (context, state) {
                  _loadedAt ??= DateTime.now();
                  _seedFollows(context, state);
                },
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTabHeader(
                  title: 'Powiadomienia',
                  showSync: false,
                  leading: AppTabHeaderButton.back(
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go('/app/activity'),
                  ),
                  actions: [
                    AppTabHeaderButton(
                      icon: Icons.tune_rounded,
                      tooltip: 'Ustawienia powiadomień',
                      onPressed: () =>
                          context.push(kNotificationsSettingsRoute),
                    ),
                  ],
                ),
                const _FilterChips(),
                Expanded(
                  child: BlocBuilder<NotificationsCubit, NotificationsState>(
                    buildWhen: (previous, current) =>
                        previous.status != current.status ||
                        previous.items != current.items ||
                        previous.filter != current.filter ||
                        previous.newIds != current.newIds,
                    builder: _buildBody,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, NotificationsState state) {
    final cubit = context.read<NotificationsCubit>();
    final bottom = MediaQuery.paddingOf(context).bottom + 24;

    if (state.status == NotificationsStatus.loading && state.items.isEmpty) {
      return const _LoadingList();
    }
    if (state.status == NotificationsStatus.failure) {
      return _Message(
        icon: Icons.wifi_off_rounded,
        title: 'Nie udało się wczytać powiadomień',
        message: 'Sprawdź połączenie z internetem.',
        actionLabel: 'Spróbuj ponownie',
        onAction: cubit.load,
      );
    }

    final newItems = state.newItems;
    final earlier = state.earlierItems;
    final unreadNew = newItems.where((n) => !n.read).length;
    var row = 0;

    Widget section(List<AppNotification> items, {required bool dividers}) {
      final start = row;
      row += items.length;
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: DecoratedSliver(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          sliver: SliverPadding(
            padding: const EdgeInsets.all(4),
            sliver: SliverList.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => dividers
                  ? const Divider(
                      height: 1,
                      thickness: 1,
                      indent: 10,
                      endIndent: 10,
                      color: AppColors.surfaceVariant,
                    )
                  : const SizedBox.shrink(),
              itemBuilder: (context, index) {
                final n = items[index];
                return _EntranceAnimation(
                  index: start + index,
                  enabled: _animateEntrance(start + index),
                  child: Dismissible(
                    key: ValueKey('dismiss-${n.id}'),
                    direction: DismissDirection.endToStart,
                    background: const _DismissBackground(),
                    onDismissed: (_) {
                      HapticFeedback.lightImpact();
                      cubit.dismiss(n);
                    },
                    child: NotificationTile(
                      notification: n,
                      now: widget.now,
                      onTap: () => _open(n),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () {
        HapticFeedback.lightImpact();
        return cubit.refresh();
      },
      color: AppColors.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (newItems.isEmpty && earlier.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _Message(
                icon: Icons.notifications_none_rounded,
                title: state.filter == NotificationFilter.all
                    ? 'Nic nowego'
                    : 'Brak powiadomień tego rodzaju',
                message:
                    'Tu zobaczysz kudosy, nowych obserwujących, kopie '
                    'Twoich planów i rekordy osób, które obserwujesz.',
              ),
            ),
          if (newItems.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                label: unreadNew > 0 ? 'NOWE · $unreadNew' : 'NOWE',
                action: unreadNew > 0
                    ? TextButton(
                        key: notificationsMarkAllKey,
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          cubit.markAllRead();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF8FB2FF),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 36),
                          textStyle: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: const Text('Oznacz jako przeczytane'),
                      )
                    : null,
              ),
            ),
            section(newItems, dividers: false),
          ],
          if (earlier.isNotEmpty) ...[
            const SliverToBoxAdapter(child: _SectionHeader(label: 'WCZEŚNIEJ')),
            section(earlier, dividers: true),
          ],
          SliverToBoxAdapter(child: SizedBox(height: bottom)),
        ],
      ),
    );
  }

  bool _animateEntrance(int index) {
    final loadedAt = _loadedAt;
    if (loadedAt == null || index > 8) return false;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return false;
    return DateTime.now().difference(loadedAt) <
        const Duration(milliseconds: 700);
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips();

  @override
  Widget build(BuildContext context) {
    final filter = context.select<NotificationsCubit, NotificationFilter>(
      (cubit) => cubit.state.filter,
    );
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        itemCount: NotificationFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final value = NotificationFilter.values[index];
          final selected = value == filter;
          return Semantics(
            button: true,
            selected: selected,
            child: GestureDetector(
              key: notificationFilterKey(value),
              onTap: () {
                if (!selected) HapticFeedback.selectionClick();
                context.read<NotificationsCubit>().setFilter(value);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.chartTrack,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Text(
                  value.label,
                  style: TextStyle(
                    color: selected
                        ? AppColors.background
                        : AppColors.iconOnTile,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.action});

  final String label;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, action == null ? 20 : 12, 6),
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textLabel,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.96,
                ),
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

class _DismissBackground extends StatelessWidget {
  const _DismissBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: AppColors.trendDown.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline_rounded, color: AppColors.trendDown),
          SizedBox(width: 6),
          Text(
            'Usuń',
            style: TextStyle(
              color: AppColors.trendDown,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Wjazd wiersza: przenikanie i 8 px w górę, 30 ms odstępu między wierszami.
class _EntranceAnimation extends StatelessWidget {
  const _EntranceAnimation({
    required this.index,
    required this.enabled,
    required this.child,
  });

  final int index;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final delay = index * 30;
    final total = 260 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
    );
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 50, 12, 0),
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < 5; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceVariant,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            bar(double.infinity, 12),
                            const SizedBox(height: 6),
                            bar(140, 12),
                            const SizedBox(height: 8),
                            bar(60, 9),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(icon, color: AppColors.textSecondary, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
