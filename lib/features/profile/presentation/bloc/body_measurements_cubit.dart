import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/models/body_measurement_entry.dart';
import '../../domain/repositories/body_measurements_repository.dart';

class BodyMeasurementsState {
  const BodyMeasurementsState({
    this.entries,
    this.loading = false,
    this.loadError,
    this.selectedField = BodyMeasurementField.waist,
    this.saving = false,
    this.message,
    this.messageId = 0,
  });

  /// Od najstarszego; `null` — jeszcze nie wczytano.
  final List<BodyMeasurementEntry>? entries;
  final bool loading;
  final String? loadError;

  /// Pomiar pokazany na wykresie.
  final BodyMeasurementField selectedField;
  final bool saving;

  /// Komunikat do pokazania raz (snackbar) — nowy przy każdej zmianie [messageId].
  final String? message;
  final int messageId;

  BodyMeasurementsState copyWith({
    List<BodyMeasurementEntry>? entries,
    bool? loading,
    String? loadError,
    bool clearLoadError = false,
    BodyMeasurementField? selectedField,
    bool? saving,
    String? message,
  }) {
    return BodyMeasurementsState(
      entries: entries ?? this.entries,
      loading: loading ?? this.loading,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
      selectedField: selectedField ?? this.selectedField,
      saving: saving ?? this.saving,
      message: message ?? this.message,
      messageId: message == null ? messageId : messageId + 1,
    );
  }
}

/// Dziennik pomiarów ciała: lista wpisów, pomiar na wykresie, dodawanie,
/// edycja i usuwanie.
class BodyMeasurementsCubit extends Cubit<BodyMeasurementsState> {
  /// [dataChanges] — sygnał synchronizacji; wpisy z innych urządzeń
  /// pojawiają się bez ponownego wchodzenia na ekran.
  BodyMeasurementsCubit(this._repository, {Listenable? dataChanges})
    : _dataChanges = dataChanges,
      super(const BodyMeasurementsState(loading: true)) {
    _dataChanges?.addListener(_onDataChanged);
  }

  final BodyMeasurementsRepository _repository;
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
        state.copyWith(entries: entries, loading: false, clearLoadError: true),
      );
    } catch (_) {
      /* zostaje poprzednia lista */
    }
  }

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearLoadError: true));
    try {
      final entries = await _repository.list();
      if (isClosed) return;
      final selected = _initialField(entries);
      emit(
        state.copyWith(
          entries: entries,
          loading: false,
          selectedField: selected,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          loading: false,
          loadError: _isOffline(error)
              ? 'Brak połączenia z internetem. Spróbuj ponownie.'
              : 'Nie udało się wczytać pomiarów. Spróbuj ponownie.',
        ),
      );
    }
  }

  /// Przy pierwszym wczytaniu wykres pokazuje pomiar, który ma dane —
  /// wybrany wcześniej, jeśli go mierzono.
  BodyMeasurementField _initialField(List<BodyMeasurementEntry> entries) {
    final current = state.selectedField;
    if (entries.any((e) => e[current] != null)) return current;
    for (final field in BodyMeasurementField.values) {
      if (entries.any((e) => e[field] != null)) return field;
    }
    return current;
  }

  void selectField(BodyMeasurementField field) =>
      emit(state.copyWith(selectedField: field));

  /// Zapisuje wpis (nowy albo zastępujący ten z tego dnia).
  Future<bool> save(BodyMeasurementEntry entry) async {
    if (state.saving) return false;
    emit(state.copyWith(saving: true));
    try {
      final saved = await _repository.save(entry);
      if (isClosed) return true;
      final entries = [
        for (final e in state.entries ?? const <BodyMeasurementEntry>[])
          if (e.date != saved.date) e,
        saved,
      ]..sort((a, b) => a.date.compareTo(b.date));
      final selected =
          saved[state.selectedField] == null &&
              !entries.any((e) => e[state.selectedField] != null)
          ? saved.values.keys.first
          : state.selectedField;
      emit(
        state.copyWith(
          entries: entries,
          saving: false,
          selectedField: selected,
          message: 'Zapisano pomiary.',
        ),
      );
      return true;
    } catch (error) {
      if (isClosed) return false;
      emit(state.copyWith(saving: false, message: _saveError(error)));
      return false;
    }
  }

  /// Usuwa od razu z listy; przy błędzie przywraca wpis.
  Future<bool> delete(BodyMeasurementEntry entry) async {
    final before = state.entries ?? const <BodyMeasurementEntry>[];
    emit(
      state.copyWith(
        entries: [
          for (final e in before)
            if (e.date != entry.date) e,
        ],
      ),
    );
    try {
      await _repository.delete(entry.date);
      if (isClosed) return true;
      emit(state.copyWith(message: 'Usunięto pomiary.'));
      return true;
    } catch (error) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          entries: before,
          message: 'Nie udało się usunąć pomiarów.',
        ),
      );
      return false;
    }
  }

  static bool _isOffline(Object error) =>
      error is ApiException && error.statusCode == null;

  static String _saveError(Object error) {
    if (error is ApiException) {
      switch (error.message) {
        case 'no_measurements':
          return 'Wpisz co najmniej jeden pomiar.';
        case 'invalid_measurement':
          return 'Obwody: 10–300 cm, tkanka tłuszczowa: 2–75%.';
        case 'invalid_date':
          return 'Nie można zapisać pomiaru z przyszłości.';
      }
    }
    return 'Nie udało się zapisać pomiarów.';
  }
}
