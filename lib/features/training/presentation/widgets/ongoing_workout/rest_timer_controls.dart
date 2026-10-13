import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import 'rest_timer_controller.dart';

String formatRestDurationOption(Duration duration) {
  if (duration.inSeconds < 90) return '${duration.inSeconds}s';
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Pozostały czas przerwy: `1:24`, `0:05`.
String formatRestRemaining(Duration remaining) {
  final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
  return '${remaining.inMinutes}:$seconds';
}

/// Arkusz wyboru długości przerwy: gotowe czasy, ostatni własny i „Własny”
/// (cyfrowy wybierak). Zwraca wybraną długość albo `null`.
Future<Duration?> showRestDurationPicker(
  BuildContext context, {
  required RestTimerController controller,
}) {
  const options = <Duration>[
    Duration(seconds: 60),
    Duration(seconds: 90),
    Duration(seconds: 120),
    Duration(seconds: 180),
  ];
  final selected = controller.selectedDuration;
  final lastCustom = controller.lastCustomDuration;

  return showModalBottomSheet<Duration>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Czas odpoczynku',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Przerwa startuje sama po odhaczeniu serii.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final option in options)
                    RestDurationOption(
                      key: ValueKey('rest-duration-option-${option.inSeconds}'),
                      label: formatRestDurationOption(option),
                      selected: option == selected,
                      onTap: () => Navigator.of(sheetContext).pop(option),
                    ),
                  if (lastCustom != null)
                    RestDurationOption(
                      key: const ValueKey('rest-duration-last-custom'),
                      label: formatRestDurationOption(lastCustom),
                      eyebrow: 'Ostatni własny',
                      selected: lastCustom == selected,
                      onTap: () => Navigator.of(sheetContext).pop(lastCustom),
                    ),
                  RestDurationOption(
                    key: const ValueKey('rest-duration-custom-option'),
                    label: 'Własny',
                    selected: !options.contains(selected),
                    onTap: () async {
                      final duration = await showDialog<Duration>(
                        context: sheetContext,
                        builder: (_) =>
                            CustomRestDurationDialog(initialDuration: selected),
                      );
                      if (!sheetContext.mounted || duration == null) return;
                      controller.rememberCustomDuration(duration);
                      Navigator.of(sheetContext).pop(duration);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class RestDurationOption extends StatelessWidget {
  const RestDurationOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.eyebrow,
  });

  final String label;
  final String? eyebrow;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.22)
          : AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: eyebrow == null ? 86 : 120,
          height: eyebrow == null ? 48 : 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primaryVariant : AppColors.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.primaryVariant : Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomRestDurationDialog extends StatefulWidget {
  const CustomRestDurationDialog({super.key, required this.initialDuration});

  final Duration initialDuration;

  @override
  State<CustomRestDurationDialog> createState() =>
      _CustomRestDurationDialogState();
}

class _CustomRestDurationDialogState extends State<CustomRestDurationDialog> {
  static const int _minSeconds = 5;
  late int _totalSeconds;

  @override
  void initState() {
    super.initState();
    _totalSeconds = widget.initialDuration.inSeconds;
    if (_totalSeconds < _minSeconds) _totalSeconds = _minSeconds;
  }

  String get _timeLabel {
    final minutes = (_totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _addMinutes(int delta) {
    setState(() {
      _totalSeconds = (_totalSeconds + delta * 60).clamp(_minSeconds, 900);
    });
  }

  void _addSeconds(int delta) {
    setState(() {
      _totalSeconds = (_totalSeconds + delta).clamp(_minSeconds, 900);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Własny odpoczynek'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _DigitalTimeStepper(
                dialKey: const ValueKey('custom-rest-minutes-dial'),
                upKey: const ValueKey('custom-rest-minutes-up'),
                downKey: const ValueKey('custom-rest-minutes-down'),
                label: 'min',
                onUp: () => _addMinutes(1),
                onDown: () => _addMinutes(-1),
              ),
              Container(
                key: const ValueKey('custom-rest-time-display'),
                width: 112,
                height: 64,
                alignment: Alignment.center,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  _timeLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              _DigitalTimeStepper(
                dialKey: const ValueKey('custom-rest-seconds-dial'),
                upKey: const ValueKey('custom-rest-seconds-up'),
                downKey: const ValueKey('custom-rest-seconds-down'),
                label: 'sek',
                onUp: () => _addSeconds(1),
                onDown: () => _addSeconds(-1),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          key: const ValueKey('custom-rest-start-button'),
          onPressed: () {
            Navigator.of(context).pop(Duration(seconds: _totalSeconds));
          },
          child: const Text('Start'),
        ),
      ],
    );
  }
}

class _DigitalTimeStepper extends StatefulWidget {
  const _DigitalTimeStepper({
    required this.dialKey,
    required this.upKey,
    required this.downKey,
    required this.label,
    required this.onUp,
    required this.onDown,
  });

  final Key dialKey;
  final Key upKey;
  final Key downKey;
  final String label;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  State<_DigitalTimeStepper> createState() => _DigitalTimeStepperState();
}

class _DigitalTimeStepperState extends State<_DigitalTimeStepper> {
  static const double _dragStep = 72;
  double _dragOffset = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: widget.dialKey,
      onVerticalDragStart: (_) => _dragOffset = 0,
      onVerticalDragUpdate: (details) {
        _dragOffset += details.delta.dy;
        while (_dragOffset <= -_dragStep) {
          widget.onUp();
          _dragOffset += _dragStep;
        }
        while (_dragOffset >= _dragStep) {
          widget.onDown();
          _dragOffset -= _dragStep;
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: widget.upKey,
            tooltip: '${widget.label} więcej',
            onPressed: widget.onUp,
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
            color: AppColors.primaryVariant,
          ),
          Text(
            widget.label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            key: widget.downKey,
            tooltip: '${widget.label} mniej',
            onPressed: widget.onDown,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            color: AppColors.primaryVariant,
          ),
        ],
      ),
    );
  }
}
