import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/following_user.dart';
import '../../domain/repositories/profile_repository.dart';
import '../bloc/follow_cubit.dart';
import '../utils/paged_users.dart';
import '../widgets/follow_button.dart';
import '../widgets/paged_list_footer.dart';
import '../widgets/user_list_tile.dart';

/// Obserwowani — własni (bez [userId]) albo innego użytkownika.
/// Wymaga [FollowCubit] w kontekście.
class FollowingListScreen extends StatelessWidget {
  const FollowingListScreen({
    super.key,
    required this.repository,
    this.userId,
    this.currentUserId,
  });

  final ProfileRepository repository;
  final String? userId;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return _UserConnectionsScreen(
      title: 'OBSERWOWANI',
      emptyMessage: userId == null
          ? 'Nie obserwujesz jeszcze nikogo.'
          : 'Ten użytkownik nikogo jeszcze nie obserwuje.',
      currentUserId: currentUserId,
      fetchPage: (limit, offset) => userId == null
          ? repository.getFollowing(limit: limit, offset: offset)
          : repository.getUserFollowing(
              userId!,
              limit: limit,
              offset: offset,
            ),
    );
  }
}

/// Obserwujący — własni (bez [userId]) albo innego użytkownika.
/// Wymaga [FollowCubit] w kontekście.
class FollowersListScreen extends StatelessWidget {
  const FollowersListScreen({
    super.key,
    required this.repository,
    this.userId,
    this.currentUserId,
  });

  final ProfileRepository repository;
  final String? userId;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return _UserConnectionsScreen(
      title: 'OBSERWUJĄCY',
      emptyMessage: userId == null
          ? 'Brak obserwujących.'
          : 'Tego użytkownika nikt jeszcze nie obserwuje.',
      currentUserId: currentUserId,
      fetchPage: (limit, offset) => userId == null
          ? repository.getFollowers(limit: limit, offset: offset)
          : repository.getUserFollowers(
              userId!,
              limit: limit,
              offset: offset,
            ),
    );
  }
}

class _UserConnectionsScreen extends StatefulWidget {
  const _UserConnectionsScreen({
    required this.title,
    required this.emptyMessage,
    required this.fetchPage,
    required this.currentUserId,
  });

  final String title;
  final String emptyMessage;
  final Future<List<FollowingUser>> Function(int limit, int offset) fetchPage;
  final String? currentUserId;

  @override
  State<_UserConnectionsScreen> createState() => _UserConnectionsScreenState();
}

class _UserConnectionsScreenState extends State<_UserConnectionsScreen> {
  late final PagedUsers _pager = PagedUsers(
    fetchPage: widget.fetchPage,
    onPage: context.read<FollowCubit>().seedUsers,
  );

  @override
  void initState() {
    super.initState();
    _pager.refresh();
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.title)),
      body: FollowFailureListener(
        child: ListenableBuilder(
          listenable: _pager,
          builder: (context, _) {
            final pager = _pager;
            if (pager.loadingFirst) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            if (pager.firstFailed) {
              return _ListError(onRetry: pager.refresh);
            }
            final users = pager.users;
            if (users.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    widget.emptyMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }
            final showFooter = pager.hasMore || pager.moreFailed;
            return ListView.separated(
              itemCount: users.length + (showFooter ? 1 : 0),
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppColors.border, indent: 90),
              itemBuilder: (_, i) => i == users.length
                  ? PagedListFooter(pager: pager)
                  : FollowableUserListTile(
                      user: users[i],
                      currentUserId: widget.currentUserId,
                    ),
            );
          },
        ),
      ),
    );
  }
}

/// Wiersz osoby z przyciskiem obserwowania (bez przycisku dla samego siebie
/// — tap otwiera wtedy własny profil).
class FollowableUserListTile extends StatelessWidget {
  const FollowableUserListTile({
    super.key,
    required this.user,
    required this.currentUserId,
  });

  final FollowingUser user;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final isMe = currentUserId != null && user.id == currentUserId;
    return UserListTile(
      user: user,
      onTap: isMe ? () => context.go('/app/profile') : null,
      trailing: isMe ? null : FollowToggleButton(userId: user.id),
    );
  }
}

class _ListError extends StatelessWidget {
  const _ListError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Nie udało się wczytać listy.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Spróbuj ponownie'),
            ),
          ],
        ),
      ),
    );
  }
}
