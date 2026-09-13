import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/service_locator.dart';
import '../sync/sync_status.dart';
import '../theme/app_colors.dart';
import '../utils/polish_plural.dart';

/// Stan synchronizacji w prawym górnym rogu ekranu.
///
/// * kręcąca się ikona — trwa wysyłanie lub pobieranie danych,
/// * zielona chmurka (na chwilę) — wszystko zapisane na serwerze,
/// * pomarańczowa kropka — zmiany czekają na wysłanie (np. brak internetu),
/// * czerwona — serwer odrzucił część zmian.
///
/// Stuknięcie otwiera szczegóły z przyciskiem „Synchronizuj teraz”.
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({
    super.key,
    this.size = 42,
    this.status,
    this.onSyncRequested,
  });

  final double size;

  /// Test seam; domyślnie [ServiceLocator.syncStatus].
  final ValueListenable<SyncStatus>? status;

  /// Test seam; domyślnie pełna synchronizacja z ponowieniem odrzuconych.
  final VoidCallback? onSyncRequested;

  @override
  Widget build(BuildContext context) {
    final listenable = status ?? ServiceLocator.syncStatus;
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: listenable,
      builder: (context, value, _) {
        return _SyncStatusButton(
          status: value,
          size: size,
          onTap: () => showSyncStatusSheet(
            context,
            status: listenable,
            onSyncRequested: onSyncRequested ?? _requestSync,
          ),
        );
      },
    );
  }

  static void _requestSync() {
    unawaited(ServiceLocator.requestSync(retryRejected: true));
  }
}

enum _Visual { idle, syncing, done, pending, offline, error }

class _VisualSpec {
  const _VisualSpec({
    required this.icon,
    required this.color,
    required this.tooltip,
    this.highlight = false,
    this.badgeColor,
  });

  final IconData icon;
  final Color color;
  final String tooltip;

  /// Podbarwione tło i obramowanie w kolorze stanu.
  final bool highlight;
  final Color? badgeColor;
}

_VisualSpec _specFor(_Visual visual, SyncStatus status) {
  return switch (visual) {
    _Visual.idle => const _VisualSpec(
      icon: Icons.cloud_done_outlined,
      color: AppColors.textMuted,
      tooltip: 'Wszystko zsynchronizowane',
    ),
    _Visual.syncing => const _VisualSpec(
      icon: Icons.sync_rounded,
      color: AppColors.primaryVariant,
      tooltip: 'Synchronizacja…',
      highlight: true,
    ),
    _Visual.done => const _VisualSpec(
      icon: Icons.cloud_done_rounded,
      color: AppColors.success,
      tooltip: 'Zsynchronizowano',
      highlight: true,
    ),
    _Visual.pending => _VisualSpec(
      icon: Icons.cloud_upload_outlined,
      color: AppColors.strengthMedium,
      tooltip: status.pendingCount > 0
          ? 'Do wysłania: ${status.pendingCount}'
          : 'Zmiany czekają na wysłanie',
      badgeColor: AppColors.strengthMedium,
    ),
    _Visual.offline => const _VisualSpec(
      icon: Icons.cloud_off_rounded,
      color: AppColors.textSecondary,
      tooltip: 'Offline — zmiany zapisane na telefonie',
      badgeColor: AppColors.strengthMedium,
    ),
    _Visual.error => const _VisualSpec(
      icon: Icons.sync_problem_rounded,
      color: AppColors.strengthWeak,
      tooltip: 'Część zmian nie została zapisana',
      highlight: true,
      badgeColor: AppColors.strengthWeak,
    ),
  };
}

_Visual _visualForPhase(SyncPhase phase) => switch (phase) {
  SyncPhase.idle => _Visual.idle,
  SyncPhase.syncing => _Visual.syncing,
  SyncPhase.pending => _Visual.pending,
  SyncPhase.offline => _Visual.offline,
  SyncPhase.error => _Visual.error,
};

class _SyncStatusButton extends StatefulWidget {
  const _SyncStatusButton({
    required this.status,
    required this.size,
    required this.onTap,
  });

  final SyncStatus status;
  final double size;
  final VoidCallback onTap;

  @override
  State<_SyncStatusButton> createState() => _SyncStatusButtonState();
}

class _SyncStatusButtonState extends State<_SyncStatusButton>
    with SingleTickerProviderStateMixin {
  /// Krótkie wysyłki (np. zapis serii online) nie mrugają ikoną.
  static const _showSyncingAfter = Duration(milliseconds: 250);

  /// Gdy już się kręci — niech kręci się na tyle długo, żeby było to czytelne.
  static const _minSyncingVisible = Duration(milliseconds: 700);
  static const _doneVisible = Duration(milliseconds: 1500);

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  late _Visual _visual = _visualForPhase(widget.status.phase);
  DateTime? _syncingShownAt;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_visual == _Visual.syncing) _syncingShownAt = DateTime.now();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSpin();
  }

  @override
  void didUpdateWidget(_SyncStatusButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status.phase != widget.status.phase) {
      _onPhaseChanged(widget.status.phase);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _spin.dispose();
    super.dispose();
  }

  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  void _onPhaseChanged(SyncPhase phase) {
    _timer?.cancel();
    _timer = null;

    if (phase == SyncPhase.syncing) {
      if (_visual != _Visual.syncing) {
        _timer = Timer(_showSyncingAfter, () => _show(_Visual.syncing));
      }
      return;
    }

    final hadSomethingToSync = _visual == _Visual.syncing ||
        _visual == _Visual.pending ||
        _visual == _Visual.offline ||
        _visual == _Visual.error;
    final target = phase == SyncPhase.idle && hadSomethingToSync
        ? _Visual.done
        : _visualForPhase(phase);

    final shownAt = _syncingShownAt;
    if (_visual == _Visual.syncing && shownAt != null) {
      final remaining =
          _minSyncingVisible - DateTime.now().difference(shownAt);
      if (remaining > Duration.zero) {
        _timer = Timer(remaining, () => _settle(target));
        return;
      }
    }
    _settle(target);
  }

  void _settle(_Visual target) {
    _show(target);
    if (target == _Visual.done) {
      _timer = Timer(_doneVisible, () {
        final current = _visualForPhase(widget.status.phase);
        _show(current == _Visual.syncing ? _Visual.idle : current);
      });
    }
  }

  void _show(_Visual visual) {
    if (!mounted) return;
    setState(() {
      if (visual == _Visual.syncing && _visual != _Visual.syncing) {
        _syncingShownAt = DateTime.now();
      }
      _visual = visual;
    });
    _syncSpin();
  }

  void _syncSpin() {
    if (_visual == _Visual.syncing && !_reduceMotion) {
      if (!_spin.isAnimating) _spin.repeat();
    } else if (_spin.isAnimating || _spin.value != 0) {
      _spin
        ..stop()
        ..value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = _specFor(_visual, widget.status);
    final duration = _reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 280);
    final iconSize = widget.size * 0.48;
    final radius = BorderRadius.circular(12);

    final Widget glyph = _visual == _Visual.syncing
        ? RotationTransition(
            key: const ValueKey(_Visual.syncing),
            turns: _spin,
            child: Icon(spec.icon, size: iconSize, color: spec.color),
          )
        : Icon(
            spec.icon,
            key: ValueKey(_visual),
            size: iconSize,
            color: spec.color,
          );

    return Semantics(
      button: true,
      child: Tooltip(
        message: spec.tooltip,
        child: Material(
          color: AppColors.surface,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: duration,
              curve: Curves.easeOut,
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: spec.highlight
                    ? spec.color.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: radius,
                border: Border.all(
                  color: spec.highlight
                      ? spec.color.withValues(alpha: 0.55)
                      : AppColors.border,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: duration,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.55,
                          end: 1,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: glyph,
                  ),
                  Positioned(
                    top: widget.size * 0.2,
                    right: widget.size * 0.2,
                    child: AnimatedScale(
                      scale: spec.badgeColor == null ? 0 : 1,
                      duration: duration,
                      curve: Curves.easeOutBack,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: spec.badgeColor ?? AppColors.strengthMedium,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Szczegóły synchronizacji — na żywo, bo sync może trwać przy otwartym arkuszu.
Future<void> showSyncStatusSheet(
  BuildContext context, {
  required ValueListenable<SyncStatus> status,
  required VoidCallback onSyncRequested,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => ValueListenableBuilder<SyncStatus>(
      valueListenable: status,
      builder: (context, value, _) => _SyncStatusSheet(
        status: value,
        onSyncRequested: onSyncRequested,
      ),
    ),
  );
}

class _SheetCopy {
  const _SheetCopy({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

_SheetCopy _sheetCopyFor(SyncPhase phase) => switch (phase) {
  SyncPhase.idle => const _SheetCopy(
    icon: Icons.cloud_done_rounded,
    color: AppColors.success,
    title: 'Wszystko zsynchronizowane',
    body: 'Treningi, plany i ćwiczenia są zapisane na serwerze.',
  ),
  SyncPhase.syncing => const _SheetCopy(
    icon: Icons.sync_rounded,
    color: AppColors.primaryVariant,
    title: 'Trwa synchronizacja',
    body: 'Wysyłamy Twoje zmiany i pobieramy nowości z serwera.',
  ),
  SyncPhase.pending => const _SheetCopy(
    icon: Icons.cloud_upload_outlined,
    color: AppColors.strengthMedium,
    title: 'Zmiany czekają na wysłanie',
    body: 'Wyślemy je automatycznie za chwilę. Możesz dalej korzystać '
        'z aplikacji.',
  ),
  SyncPhase.offline => const _SheetCopy(
    icon: Icons.cloud_off_rounded,
    color: AppColors.textSecondary,
    title: 'Brak połączenia z serwerem',
    body: 'Możesz normalnie trenować — wszystko zapisuje się na telefonie. '
        'Wyślemy zmiany, gdy wróci internet.',
  ),
  SyncPhase.error => const _SheetCopy(
    icon: Icons.sync_problem_rounded,
    color: AppColors.strengthWeak,
    title: 'Część zmian nie przeszła',
    body: 'Serwer odrzucił niektóre zmiany. Spróbuj ponownie — jeśli błąd '
        'wróci, edytuj element, którego dotyczy.',
  ),
};

class _SyncStatusSheet extends StatelessWidget {
  const _SyncStatusSheet({
    required this.status,
    required this.onSyncRequested,
  });

  final SyncStatus status;
  final VoidCallback onSyncRequested;

  String _changes(int count) =>
      '$count ${polishPlural(count, 'zmiana', 'zmiany', 'zmian')}';

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final isToday = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (isToday) return 'dziś, $hh:$mm';
    final dd = local.day.toString().padLeft(2, '0');
    final mo = local.month.toString().padLeft(2, '0');
    return '$dd.$mo, $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final copy = _sheetCopyFor(status.phase);
    final lastSyncedAt = status.lastSyncedAt;
    final rows = <Widget>[
      if (status.pendingCount > 0)
        _SheetRow(label: 'Do wysłania', value: _changes(status.pendingCount)),
      if (status.failedCount > 0)
        _SheetRow(
          label: 'Odrzucone przez serwer',
          value: _changes(status.failedCount),
          valueColor: AppColors.strengthWeak,
        ),
      if (lastSyncedAt != null)
        _SheetRow(
          label: 'Ostatnia synchronizacja',
          value: _formatTime(lastSyncedAt),
        ),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(copy.icon, color: copy.color, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    copy.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              copy.body,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (rows.isNotEmpty) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(children: rows),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: status.isSyncing ? null : onSyncRequested,
                icon: status.isSyncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      )
                    : const Icon(Icons.sync_rounded, size: 20),
                label: Text(
                  status.isSyncing ? 'Synchronizuję…' : 'Synchronizuj teraz',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.35,
                  ),
                  disabledForegroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
