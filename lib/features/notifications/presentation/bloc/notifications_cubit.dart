import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/app_notification.dart';
import '../../domain/repositories/notifications_repository.dart';
import 'notifications_state.dart';

/// Centrum powiadomień: lista, filtry, oznaczanie i usuwanie. Zmiany są
/// optymistyczne — przy błędzie wracają, a [onUnreadChanged] trzyma licznik
/// na dzwonku w zgodzie z listą.
class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit({
    required NotificationsRepository repository,
    void Function(int unread)? onUnreadChanged,
  }) : _repository = repository,
       _onUnreadChanged = onUnreadChanged,
       super(const NotificationsState());

  final NotificationsRepository _repository;
  final void Function(int unread)? _onUnreadChanged;
  int _noticeSeq = 0;

  Future<void> load() => _fetch(initial: true);

  Future<void> refresh() => _fetch(initial: false);

  Future<void> _fetch({required bool initial}) async {
    if (state.refreshing) return;
    if (initial) {
      emit(state.copyWith(status: NotificationsStatus.loading));
    } else {
      emit(state.copyWith(refreshing: true));
    }
    try {
      final page = await _repository.list();
      if (isClosed) return;
      emit(
        state.copyWith(
          status: NotificationsStatus.ready,
          items: page.items,
          newIds: {
            for (final item in page.items)
              if (!item.read) item.id,
          },
          refreshing: false,
        ),
      );
      _onUnreadChanged?.call(page.unreadCount);
    } catch (_) {
      if (isClosed) return;
      if (state.status == NotificationsStatus.ready) {
        emit(
          state.copyWith(
            refreshing: false,
            notice: _notice('Nie udało się odświeżyć powiadomień.'),
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: NotificationsStatus.failure,
            refreshing: false,
          ),
        );
      }
    }
  }

  void setFilter(NotificationFilter filter) {
    if (filter != state.filter) emit(state.copyWith(filter: filter));
  }

  Future<void> markAllRead() async {
    final before = state.items;
    if (before.every((item) => item.read)) return;
    _emitItems([for (final item in before) item.copyWith(read: true)]);
    try {
      await _repository.markAllRead();
    } catch (_) {
      if (isClosed) return;
      _emitItems(
        before,
        notice: _notice('Nie udało się oznaczyć powiadomień.'),
      );
    }
  }

  /// Otwarcie wpisu oznacza go jako przeczytany. Błąd nie wraca kropki —
  /// wpis i tak został obejrzany, a serwer dostanie to przy „Oznacz
  /// wszystkie”.
  Future<void> markRead(AppNotification notification) async {
    final index = state.items.indexWhere((i) => i.id == notification.id);
    if (index < 0 || state.items[index].read) return;
    _emitItems([...state.items]..[index] = notification.copyWith(read: true));
    try {
      await _repository.markRead(notification.id);
    } catch (_) {
      /* best-effort */
    }
  }

  Future<void> dismiss(AppNotification notification) async {
    final before = state.items;
    final index = before.indexWhere((i) => i.id == notification.id);
    if (index < 0) return;
    _emitItems([...before]..removeAt(index));
    try {
      await _repository.dismiss(notification.id);
    } catch (_) {
      if (isClosed) return;
      // Przywrócenie w tym samym miejscu, nawet jeśli w międzyczasie
      // zniknął inny wpis.
      final restored = [...state.items];
      restored.insert(index.clamp(0, restored.length), before[index]);
      _emitItems(
        restored,
        notice: _notice('Nie udało się usunąć powiadomienia.'),
      );
    }
  }

  void _emitItems(List<AppNotification> items, {NotificationsNotice? notice}) {
    if (isClosed) return;
    emit(state.copyWith(items: items, notice: notice));
    _onUnreadChanged?.call(state.unreadCount);
  }

  NotificationsNotice _notice(String message) =>
      NotificationsNotice(++_noticeSeq, message);
}
