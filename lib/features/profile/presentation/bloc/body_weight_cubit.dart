import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/models/body_weight_entry.dart';
import '../../domain/repositories/body_weight_repository.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/services/body_weight_trend.dart';
import '../utils/profile_details_labels.dart';

class BodyWeightState {
  const BodyWeightState({
    this.entries,
    this.loading = false,
    this.loadError,
    this.offline = false,
    this.range = BodyWeightRange.days90,
    this.saving = false,
    this.goalLoaded = false,
    this.goalKg,
    this.savingGoal = false,
    this.message,
    this.messageId = 0,
  });

  /// Od najstarszego; `null` — jeszcze nie wczytano.
  final List<BodyWeightEntry>? entries;
  final bool loading;
  final String? loadError;

  /// Ostatnie wczytanie nie powiodło się z braku sieci.
  final bool offline;
  final BodyWeightRange range;
  final bool saving;

  /// Cel jest znany (profil wczytany). Bez sieci zostaje `false` — ekran
  /// wtedy nie pokazuje ani celu, ani zachęty do jego ustawienia.
  final bool goalLoaded;

  /// Cel masy ciała z profilu; `null` — bez celu.
  final double? goalKg;
  final bool savingGoal;

  /// Komunikat do pokazania raz (snackbar) — nowy przy każdej zmianie [messageId].
  final String? message;
  final int messageId;

  BodyWeightEntry? get latest =>
      (entries == null || entries!.isEmpty) ? null : entries!.last;

  BodyWeightState copyWith({
    List<BodyWeightEntry>? entries,
    bool? loading,
    String? loadError,
    bool clearLoadError = false,
    bool? offline,
    BodyWeightRange? range,
    bool? saving,
    bool? goalLoaded,
    double? goalKg,
    bool clearGoal = false,
    bool? savingGoal,
    String? message,
  }) {
    return BodyWeightState(
      entries: entries ?? this.entries,
      loading: loading ?? this.loading,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
      offline: offline ?? this.offline,
      range: range ?? this.range,
      saving: saving ?? this.saving,
      goalLoaded: goalLoaded ?? this.goalLoaded,
      goalKg: clearGoal ? null : (goalKg ?? this.goalKg),
      savingGoal: savingGoal ?? this.savingGoal,
      message: message ?? this.message,
      messageId: message == null ? messageId : messageId + 1,
    );
  }
}

/// Dziennik masy ciała: lista pomiarów, zakres wykresu, dodawanie,
/// edycja i usuwanie oraz cel masy ciała z profilu.
class BodyWeightCubit extends Cubit<BodyWeightState> {
  /// [dataChanges] — sygnał synchronizacji; pomiary z innych urządzeń
  /// pojawiają się bez ponownego wchodzenia na ekran. Bez [profile] ekran
  /// nie pokazuje celu.
  BodyWeightCubit(
    this._repository, {
    ProfileRepository? profile,
    this.onChanged,
    Listenable? dataChanges,
  }) : _profile = profile,
       _dataChanges = dataChanges,
       super(const BodyWeightState(loading: true)) {
    _dataChanges?.addListener(_onDataChanged);
  }

  final BodyWeightRepository _repository;
  final ProfileRepository? _profile;
  final Listenable? _dataChanges;

  @override
  Future<void> close() {
    _dataChanges?.removeListener(_onDataChanged);
    return super.close();
  }

  void _onDataChanged() {
    if (isClosed || state.saving) return;
    unawaited(_reload());
  }

  Future<void> _reload() async {
    try {
      final entries = await _repository.list();
      if (isClosed) return;
      emit(
        state.copyWith(
          entries: entries,
          loading: false,
          offline: false,
          clearLoadError: true,
        ),
      );
    } catch (_) {
      /* zostaje poprzednia lista */
    }
  }

  /// Po udanym zapisie lub usunięciu (np. odświeżenie profilu).
  final void Function()? onChanged;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearLoadError: true));
    unawaited(_loadGoal());
    try {
      final entries = await _repository.list();
      if (isClosed) return;
      emit(state.copyWith(entries: entries, loading: false, offline: false));
    } catch (error) {
      if (isClosed) return;
      final offline = _isOffline(error);
      emit(
        state.copyWith(
          loading: false,
          offline: offline,
          loadError: offline
              ? 'Brak połączenia z internetem. Spróbuj ponownie.'
              : 'Nie udało się wczytać pomiarów. Spróbuj ponownie.',
        ),
      );
    }
  }

  /// Cel jest w `/profile/me`, jak pozostałe dane profilu — bez sieci
  /// po prostu go nie znamy.
  Future<void> _loadGoal() async {
    final profile = _profile;
    if (profile == null) return;
    try {
      final own = await profile.getOwnProfile();
      if (isClosed) return;
      final goal = own.details?.targetWeightKg;
      emit(
        state.copyWith(goalLoaded: true, goalKg: goal, clearGoal: goal == null),
      );
    } catch (_) {
      /* zostaje poprzedni stan celu */
    }
  }

  /// Ustawia cel; `null` usuwa go.
  Future<bool> saveGoal(double? kg) async {
    final profile = _profile;
    if (profile == null || state.savingGoal) return false;
    emit(state.copyWith(savingGoal: true));
    try {
      final updated = await profile.updateTargetWeight(kg);
      if (isClosed) return true;
      final goal = updated.details?.targetWeightKg;
      emit(
        state.copyWith(
          goalLoaded: true,
          goalKg: goal,
          clearGoal: goal == null,
          savingGoal: false,
          message: goal == null ? 'Usunięto cel.' : 'Zapisano cel.',
        ),
      );
      return true;
    } catch (error) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          savingGoal: false,
          message: _isOffline(error)
              ? 'Brak połączenia — cel nie został zapisany.'
              : 'Nie udało się zapisać celu.',
        ),
      );
      return false;
    }
  }

  void selectRange(BodyWeightRange range) => emit(state.copyWith(range: range));

  /// Zapisuje pomiar (nowy albo zastępujący ten z tego dnia).
  Future<bool> save(DateTime date, double weightKg) async {
    if (state.saving) return false;
    emit(state.copyWith(saving: true));
    try {
      final saved = await _repository.save(date, weightKg);
      if (isClosed) return true;
      final entries = [
        for (final e in state.entries ?? const <BodyWeightEntry>[])
          if (e.date != saved.date) e,
        saved,
      ]..sort((a, b) => a.date.compareTo(b.date));
      emit(
        state.copyWith(
          entries: entries,
          saving: false,
          message: 'Zapisano pomiar.',
        ),
      );
      onChanged?.call();
      return true;
    } catch (error) {
      if (isClosed) return false;
      emit(state.copyWith(saving: false, message: _saveError(error)));
      return false;
    }
  }

  /// Usuwa od razu z listy; przy błędzie przywraca pomiar.
  Future<bool> delete(BodyWeightEntry entry) async {
    final before = state.entries ?? const <BodyWeightEntry>[];
    emit(
      state.copyWith(
        entries: [
          for (final e in before)
            if (e != entry) e,
        ],
      ),
    );
    try {
      await _repository.delete(entry.date);
      if (isClosed) return true;
      emit(state.copyWith(message: 'Usunięto pomiar.'));
      onChanged?.call();
      return true;
    } catch (error) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          entries: before,
          message: _isOffline(error)
              ? 'Brak połączenia — pomiar nie został usunięty.'
              : 'Nie udało się usunąć pomiaru.',
        ),
      );
      return false;
    }
  }

  static bool _isOffline(Object error) =>
      error is ApiException && error.statusCode == null;

  static String _saveError(Object error) {
    if (_isOffline(error)) {
      return 'Brak połączenia — pomiar nie został zapisany.';
    }
    if (error is ApiException && error.message == 'invalid_weight') {
      return 'Waga musi mieścić się w zakresie ${formatWeightRange()}.';
    }
    if (error is ApiException && error.message == 'invalid_date') {
      return 'Nie można zapisać pomiaru z przyszłości.';
    }
    return 'Nie udało się zapisać pomiaru.';
  }
}
