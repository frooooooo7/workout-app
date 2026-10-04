import 'package:flutter/foundation.dart';

import '../../domain/models/following_user.dart';

/// Lista osób doładowywana stronami (`limit` / `offset`): obserwowani,
/// obserwujący, kudosy. Strona krótsza niż [pageSize] kończy listę.
///
/// Gdy lista na serwerze zmieni się między stronami (ktoś zaobserwuje),
/// przesunięty `offset` może zwrócić osobę drugi raz — duplikaty pomijamy.
class PagedUsers extends ChangeNotifier {
  PagedUsers({required this.fetchPage, this.pageSize = 20, this.onPage});

  final Future<List<FollowingUser>> Function(int limit, int offset) fetchPage;
  final int pageSize;

  /// Każda wczytana strona — np. stan przycisków obserwowania.
  final ValueChanged<List<FollowingUser>>? onPage;

  final List<FollowingUser> _users = [];
  final Set<String> _ids = {};
  int _offset = 0;

  /// Numer wczytania od zera — odpowiedź na starsze odrzucamy.
  int _generation = 0;
  bool _disposed = false;

  List<FollowingUser> get users => List.unmodifiable(_users);

  /// Pierwsza strona jeszcze się wczytuje.
  bool loadingFirst = true;

  /// Pierwsza strona się nie wczytała — nie ma czego pokazać.
  bool firstFailed = false;

  bool loadingMore = false;

  /// Kolejna strona się nie wczytała; [loadMore] ponawia.
  bool moreFailed = false;

  bool hasMore = false;

  /// Wczytuje listę od początku.
  Future<void> refresh() async {
    final generation = ++_generation;
    loadingFirst = true;
    firstFailed = false;
    loadingMore = false;
    moreFailed = false;
    _notify();
    try {
      final page = await fetchPage(pageSize, 0);
      if (generation != _generation || _disposed) return;
      _users.clear();
      _ids.clear();
      _offset = 0;
      _append(page);
      loadingFirst = false;
    } catch (_) {
      if (generation != _generation || _disposed) return;
      loadingFirst = false;
      firstFailed = true;
    }
    _notify();
  }

  /// Dokłada kolejną stronę; nic nie robi w trakcie innego wczytywania
  /// albo na końcu listy.
  Future<void> loadMore() async {
    if (loadingFirst || loadingMore || !hasMore || firstFailed) return;
    final generation = _generation;
    loadingMore = true;
    moreFailed = false;
    _notify();
    try {
      final page = await fetchPage(pageSize, _offset);
      if (generation != _generation || _disposed) return;
      _append(page);
    } catch (_) {
      if (generation != _generation || _disposed) return;
      moreFailed = true;
    }
    loadingMore = false;
    _notify();
  }

  void _append(List<FollowingUser> page) {
    _offset += page.length;
    hasMore = page.length >= pageSize;
    final fresh = [
      for (final user in page)
        if (_ids.add(user.id)) user,
    ];
    _users.addAll(fresh);
    onPage?.call(fresh);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
