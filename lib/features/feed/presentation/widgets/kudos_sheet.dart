import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../profile/domain/models/following_user.dart';
import '../../../profile/presentation/bloc/follow_cubit.dart';
import '../../../profile/presentation/utils/paged_users.dart';
import '../../../profile/presentation/widgets/follow_button.dart';
import '../../../profile/presentation/widgets/paged_list_footer.dart';
import '../../../profile/presentation/widgets/user_list_tile.dart';
import '../../domain/repositories/feed_repository.dart';
import '../utils/feed_navigation.dart';

/// Lista osób, które dały kudosa, z przyciskami obserwowania.
/// `FollowCubit` z kontekstu wywołującego jest przekazywany do arkusza.
Future<void> showKudosSheet({
  required BuildContext context,
  required String postId,
  required FeedRepository repository,
  String? currentUserId,
}) {
  FollowCubit? followCubit;
  try {
    followCubit = context.read<FollowCubit>();
  } catch (_) {
    followCubit = null;
  }

  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) {
      final sheet = KudosSheet(
        postId: postId,
        repository: repository,
        currentUserId: currentUserId,
        followCubit: followCubit,
        onUserTap: (user) {
          Navigator.of(sheetContext).pop();
          if (context.mounted) {
            openAuthorProfile(
              context,
              user.id,
              isOwn: user.id == currentUserId,
            );
          }
        },
      );
      final cubit = followCubit;
      if (cubit == null) return sheet;
      return BlocProvider.value(
        value: cubit,
        child: FollowFailureListener(child: sheet),
      );
    },
  );
}

class KudosSheet extends StatefulWidget {
  const KudosSheet({
    super.key,
    required this.postId,
    required this.repository,
    required this.onUserTap,
    this.currentUserId,
    this.followCubit,
  });

  final String postId;
  final FeedRepository repository;
  final ValueChanged<FollowingUser> onUserTap;
  final String? currentUserId;
  final FollowCubit? followCubit;

  @override
  State<KudosSheet> createState() => _KudosSheetState();
}

class _KudosSheetState extends State<KudosSheet> {
  late final PagedUsers _pager = PagedUsers(
    pageSize: 50,
    fetchPage: (limit, offset) =>
        widget.repository.getKudos(widget.postId, limit: limit, offset: offset),
    onPage: widget.followCubit?.seedUsers,
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
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text(
                'Kudosy',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Flexible(
              child: ListenableBuilder(
                listenable: _pager,
                builder: (context, _) {
                  final pager = _pager;
                  if (pager.loadingFirst) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  }
                  if (pager.firstFailed) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Nie udało się wczytać listy kudosów.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: pager.refresh,
                            child: const Text('Spróbuj ponownie'),
                          ),
                        ],
                      ),
                    );
                  }
                  final users = pager.users;
                  if (users.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.fromLTRB(24, 8, 24, 28),
                      child: Text(
                        'Nikt jeszcze nie dał kudosa.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount:
                        users.length +
                        (pager.hasMore || pager.moreFailed ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == users.length) {
                        return PagedListFooter(pager: pager);
                      }
                      final user = users[index];
                      final showFollow = widget.followCubit != null &&
                          user.id != widget.currentUserId;
                      return UserListTile(
                        user: user,
                        onTap: () => widget.onUserTap(user),
                        trailing: showFollow
                            ? FollowToggleButton(userId: user.id)
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
