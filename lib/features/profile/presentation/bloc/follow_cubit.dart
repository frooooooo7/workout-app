import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/models/follow_result.dart';
import '../../domain/models/following_user.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import 'follow_state.dart';

/// Przełączanie obserwowania: optymistycznie, z blokadą na czas żądania
/// i cofnięciem zmiany przy błędzie.
class FollowCubit extends Cubit<FollowState> {
  FollowCubit(this._repository, {this.onFollowChanged})
      : super(const FollowState());

  final ProfileRepository _repository;

  /// Wołane po udanej zmianie (np. odświeżenie własnego profilu).
  final void Function()? onFollowChanged;

  int _failureSeq = 0;

  /// Zasiewa stan z danych serwera. Nie nadpisuje użytkowników z żądaniem
  /// w toku — ich wynik przyjdzie z odpowiedzi.
  void seedUsers(Iterable<FollowingUser> users) {
    if (isClosed) return;
    final following = Map<String, bool>.of(state.following);
    var changed = false;
    for (final user in users) {
      if (state.isPending(user.id)) continue;
      if (following[user.id] != user.isFollowing) {
        following[user.id] = user.isFollowing;
        changed = true;
      }
    }
    if (changed) emit(state.copyWith(following: following));
  }

  void seedProfile(UserProfile profile) {
    if (isClosed || state.isPending(profile.id)) return;
    emit(
      state.copyWith(
        following: {...state.following, profile.id: profile.isFollowing},
        followersCounts: {
          ...state.followersCounts,
          profile.id: profile.stats.followersCount,
        },
      ),
    );
  }

  Future<void> toggle(String userId) async {
    if (isClosed || state.isPending(userId)) return;

    final wasFollowing = state.isFollowing(userId);
    final previousCount = state.followersCountOf(userId);

    emit(
      state.copyWith(
        following: {...state.following, userId: !wasFollowing},
        pending: {...state.pending, userId},
        followersCounts: previousCount == null
            ? null
            : {
                ...state.followersCounts,
                userId: wasFollowing
                    ? (previousCount > 0 ? previousCount - 1 : 0)
                    : previousCount + 1,
              },
        clearFailure: true,
      ),
    );

    try {
      final FollowResult result = wasFollowing
          ? await _repository.unfollow(userId)
          : await _repository.follow(userId);
      if (isClosed) return;
      emit(
        state.copyWith(
          following: {...state.following, userId: result.isFollowing},
          pending: {...state.pending}..remove(userId),
          followersCounts: {
            ...state.followersCounts,
            userId: result.followersCount,
          },
        ),
      );
      onFollowChanged?.call();
    } catch (error) {
      if (isClosed) return;
      final counts = Map<String, int>.of(state.followersCounts);
      if (previousCount == null) {
        counts.remove(userId);
      } else {
        counts[userId] = previousCount;
      }
      emit(
        state.copyWith(
          following: {...state.following, userId: wasFollowing},
          pending: {...state.pending}..remove(userId),
          followersCounts: counts,
          failure: FollowFailure(
            id: ++_failureSeq,
            userId: userId,
            message: followFailureMessage(error, unfollow: wasFollowing),
          ),
        ),
      );
    }
  }

  static String followFailureMessage(Object error, {required bool unfollow}) {
    final action = unfollow
        ? 'przestać obserwować tej osoby'
        : 'zaobserwować tej osoby';
    if (error is ApiException) {
      if (error.statusCode == null) {
        return 'Nie udało się $action — brak połączenia z internetem.';
      }
      if (error.statusCode == 429) {
        return 'Nie udało się $action — zbyt wiele prób. Spróbuj za chwilę.';
      }
      switch (error.message) {
        case 'user_not_found':
        case 'invalid_uuid':
          return 'Nie udało się $action — użytkownik nie istnieje.';
        case 'cannot_follow_self':
          return 'Nie możesz obserwować samego siebie.';
      }
    }
    return 'Nie udało się $action. Spróbuj ponownie.';
  }
}
