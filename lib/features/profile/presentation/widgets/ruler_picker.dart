import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

/// Pozioma linijka do wyboru wartości (wzrost, waga) przeciąganiem.
///
/// Wartość zmienia się dopiero, gdy użytkownik ruszy linijkę (albo ją
/// stuknie) — do tego czasu [value] może być `null`, a linijka stoi na
/// [initial]. Kreski co [step], dłuższe co [majorEvery] kresek z podpisem.
class RulerPicker extends StatefulWidget {
  const RulerPicker({
    super.key,
    required this.min,
    required this.max,
    required this.step,
    required this.initial,
    required this.value,
    required this.onChanged,
    required this.semanticsLabel,
    required this.formatValue,
    this.majorEvery = 10,
    this.tickGap = 10,
    this.enabled = true,
  });

  final double min;
  final double max;
  final double step;
  final double initial;
  final double? value;
  final ValueChanged<double> onChanged;
  final String semanticsLabel;

  /// Np. `182 cm` — dla czytników ekranu.
  final String Function(double value) formatValue;
  final int majorEvery;
  final double tickGap;
  final bool enabled;

  @override
  State<RulerPicker> createState() => _RulerPickerState();
}

class _RulerPickerState extends State<RulerPicker> {
  late final ScrollController _controller = ScrollController(
    initialScrollOffset: _offsetFor(widget.value ?? widget.initial),
  );
  bool _userScrolling = false;
  double? _lastEmitted;

  int get _tickCount => ((widget.max - widget.min) / widget.step).round() + 1;

  double _offsetFor(double value) {
    final index = ((value - widget.min) / widget.step).round();
    return index.clamp(0, _tickCount - 1) * widget.tickGap;
  }

  double _valueAt(double offset) {
    final index = (offset / widget.tickGap).round().clamp(0, _tickCount - 1);
    return ((widget.min + index * widget.step) * 10).round() / 10;
  }

  @override
  void didUpdateWidget(RulerPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_userScrolling || !_controller.hasClients) return;
    final target = widget.value ?? widget.initial;
    if (widget.value != null && widget.value == _lastEmitted) return;
    // Wartość z zewnątrz (albo nowy punkt startowy, gdy brak wartości).
    final offset = _offsetFor(target);
    if ((_controller.offset - offset).abs() > 0.5) _controller.jumpTo(offset);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _emit(double value) {
    if (value == _lastEmitted && widget.value != null) return;
    _lastEmitted = value;
    HapticFeedback.selectionClick();
    widget.onChanged(value);
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _userScrolling = true;
    } else if (notification is ScrollUpdateNotification && _userScrolling) {
      _emit(_valueAt(notification.metrics.pixels));
    } else if (notification is ScrollEndNotification && _userScrolling) {
      _userScrolling = false;
      _emit(_valueAt(notification.metrics.pixels));
    }
    return false;
  }

  void _nudge(int ticks) {
    if (!_controller.hasClients) return;
    final current = widget.value ?? _valueAt(_controller.offset);
    final next = (current + ticks * widget.step)
        .clamp(widget.min, widget.max)
        .toDouble();
    final value = (next * 10).round() / 10;
    _controller.animateTo(
      _offsetFor(value),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
    );
    _emit(value);
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final active = value != null;

    return Semantics(
      slider: true,
      enabled: widget.enabled,
      label: widget.semanticsLabel,
      value: active ? widget.formatValue(value) : 'nie podano',
      increasedValue: widget.formatValue(
        ((value ?? widget.initial) + widget.step).clamp(widget.min, widget.max),
      ),
      decreasedValue: widget.formatValue(
        ((value ?? widget.initial) - widget.step).clamp(widget.min, widget.max),
      ),
      onIncrease: widget.enabled ? () => _nudge(1) : null,
      onDecrease: widget.enabled ? () => _nudge(-1) : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          // Stuknięcie w nieustawioną linijkę przyjmuje wartość ze środka.
          onTap: widget.enabled && !active && _controller.hasClients
              ? () => _emit(_valueAt(_controller.offset))
              : null,
          child: SizedBox(
            height: 76,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final sidePadding =
                    constraints.maxWidth / 2 - widget.tickGap / 2;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [0, 0.2, 0.8, 1],
                      ).createShader(bounds),
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _onScroll,
                        child: ListView.builder(
                          controller: _controller,
                          scrollDirection: Axis.horizontal,
                          physics: widget.enabled
                              ? _SnapScrollPhysics(
                                  itemExtent: widget.tickGap,
                                  parent: const ClampingScrollPhysics(),
                                )
                              : const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.symmetric(
                            horizontal: sidePadding,
                          ),
                          itemExtent: widget.tickGap,
                          itemCount: _tickCount,
                          itemBuilder: (context, index) => _Tick(
                            index: index,
                            majorEvery: widget.majorEvery,
                            label: widget.formatValue(
                              ((widget.min + index * widget.step) * 10)
                                      .round() /
                                  10,
                            ),
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(child: _Indicator(active: active)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick({
    required this.index,
    required this.majorEvery,
    required this.label,
  });

  final int index;
  final int majorEvery;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isMajor = index % majorEvery == 0;
    final isMid =
        !isMajor && majorEvery.isEven && index % (majorEvery ~/ 2) == 0;
    final height = isMajor ? 30.0 : (isMid ? 20.0 : 12.0);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Positioned(
          bottom: 6,
          child: Container(
            width: isMajor ? 2 : 1.5,
            height: height,
            decoration: BoxDecoration(
              color: isMajor
                  ? AppColors.textSecondary
                  : AppColors.textMuted.withValues(alpha: isMid ? 0.9 : 0.55),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
        if (isMajor)
          // Podpis wystaje poza wąską kreskę na boki.
          Positioned(
            top: 4,
            left: -30,
            right: -30,
            child: Text(
              // Bez jednostki: `180`, `82`.
              label.split(' ').first,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
      ],
    );
  }
}

/// Wskaźnik środka linijki — świeci, gdy wartość jest ustawiona.
class _Indicator extends StatelessWidget {
  const _Indicator({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primaryVariant : AppColors.textMuted;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 4,
          height: 46,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              if (active)
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.55),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Po puszczeniu linijka dojeżdża do najbliższej kreski.
class _SnapScrollPhysics extends ScrollPhysics {
  const _SnapScrollPhysics({required this.itemExtent, super.parent});

  final double itemExtent;

  @override
  _SnapScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _SnapScrollPhysics(itemExtent: itemExtent, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final free = super.createBallisticSimulation(position, velocity);
    var target = free?.x(double.infinity) ?? position.pixels;
    target = (target / itemExtent).round() * itemExtent;
    target = target
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    final tolerance = toleranceFor(position);
    if ((target - position.pixels).abs() < tolerance.distance &&
        velocity.abs() < tolerance.velocity) {
      return null;
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }
}
