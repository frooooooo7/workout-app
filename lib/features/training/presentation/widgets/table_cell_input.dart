import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/units/weight_unit.dart';
import '../../../library/domain/models/exercise_tracking.dart';

/// Pole ciężaru serii. W bazie ciężar leży jako tekst w kilogramach; pole
/// pokazuje go i przyjmuje w aktualnej jednostce ([WeightUnits.current]),
/// a [onChanged] dostaje już tekst w kilogramach. W kg tekst przechodzi bez
/// zmian.
class WeightCellInput extends StatelessWidget {
  const WeightCellInput({
    super.key,
    required this.valueKg,
    required this.onChanged,
    this.hintKg,
    this.fallbackHint = '',
    this.suffixText,
    this.look = TableCellInputLook.compact,
  });

  final String? valueKg;

  /// Podpowiedź (np. ciężar z planu) w kilogramach.
  final String? hintKg;

  /// Podpowiedź, gdy [hintKg] jest pusty.
  final String fallbackHint;
  final String? suffixText;
  final TableCellInputLook look;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final unit = WeightUnits.current;
    final hint = weightTextForInput(hintKg, unit: unit);
    return TableCellInput(
      value: weightTextForInput(valueKg, unit: unit),
      hint: hint.isEmpty ? fallbackHint : hint,
      suffixText: suffixText,
      look: look,
      onChanged: (text) => onChanged(weightTextFromInput(text, unit: unit)),
      // Przeliczenie w obie strony gubi to, co jest w trakcie pisania
      // („22.” → „22,”), więc pole nadpisujemy tylko przy innej liczbie.
      sameValue: _sameNumber,
    );
  }

  static bool _sameNumber(String a, String b) {
    final x = parseWeightNumber(a);
    final y = parseWeightNumber(b);
    if (x == null || y == null) return x == y && a.trim() == b.trim();
    return (x - y).abs() < 0.05;
  }
}

/// Pole czasu serii (`12:47`, albo same minuty: `15`). [onChanged] dostaje
/// sekundy; `null` — puste albo nieczytelne.
class DurationCellInput extends StatelessWidget {
  const DurationCellInput({
    super.key,
    required this.seconds,
    required this.onChanged,
    this.hintSeconds,
    this.look = TableCellInputLook.compact,
  });

  final int? seconds;
  final int? hintSeconds;
  final TableCellInputLook look;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final hint = hintSeconds;
    return TableCellInput(
      value: seconds == null ? '' : formatSetDuration(seconds!),
      hint: hint == null ? '0:00' : formatSetDuration(hint),
      // Dwukropek jest na klawiaturze daty i godziny.
      keyboardType: TextInputType.datetime,
      look: look,
      onChanged: (text) => onChanged(parseSetDuration(text)),
      // „12:4” w trakcie pisania to już 12:04 — nie przepisujemy pola.
      sameValue: (text, value) =>
          parseSetDuration(text) == parseSetDuration(value),
    );
  }
}

/// Pole dystansu w jednostce ćwiczenia; [onChanged] dostaje metry.
class DistanceCellInput extends StatelessWidget {
  const DistanceCellInput({
    super.key,
    required this.meters,
    required this.unit,
    required this.onChanged,
    this.hintMeters,
    this.look = TableCellInputLook.compact,
  });

  final int? meters;
  final int? hintMeters;
  final DistanceUnit unit;
  final TableCellInputLook look;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final hint = hintMeters;
    return TableCellInput(
      value: meters == null ? '' : unit.format(meters!),
      hint: hint == null ? '–' : unit.format(hint),
      keyboardType: unit == DistanceUnit.km
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      look: look,
      onChanged: (text) => onChanged(unit.parse(text)),
      sameValue: (text, value) => unit.parse(text) == unit.parse(value),
    );
  }
}

/// Wygląd pola tabeli serii. [compact] to zwarta tabela edycji planu i
/// treningu; ekran treningu na żywo podaje własny, większy wygląd.
class TableCellInputLook {
  const TableCellInputLook({
    required this.textStyle,
    required this.hintStyle,
    required this.fillColor,
    this.borderColor,
    this.radius = 8,
    this.verticalPadding = 8,
  });

  static const compact = TableCellInputLook(
    textStyle: TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
    hintStyle: TextStyle(
      color: AppColors.textMuted,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
    fillColor: AppColors.surfaceVariant,
  );

  final TextStyle textStyle;
  final TextStyle hintStyle;
  final Color fillColor;

  /// Krawędź pola; `null` — bez krawędzi.
  final Color? borderColor;
  final double radius;
  final double verticalPadding;
}

class TableCellInput extends StatefulWidget {
  const TableCellInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint = '',
    this.suffixText,
    this.keyboardType = const TextInputType.numberWithOptions(decimal: true),
    this.sameValue,
    this.look = TableCellInputLook.compact,
  });

  final String value;
  final String hint;
  final String? suffixText;
  final TextInputType keyboardType;
  final ValueChanged<String> onChanged;

  /// Czy tekst w polu i nowe [value] znaczą to samo — wtedy pole zostaje
  /// nietknięte. Domyślnie porównanie dosłowne.
  final bool Function(String text, String value)? sameValue;
  final TableCellInputLook look;

  @override
  State<TableCellInput> createState() => _TableCellInputState();
}

class _TableCellInputState extends State<TableCellInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant TableCellInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        _controller.text != widget.value &&
        !(widget.sameValue?.call(_controller.text, widget.value) ?? false)) {
      // Maintain cursor position if possible, but safely update text
      final selection = _controller.selection;
      _controller.text = widget.value;
      if (selection.isValid && selection.end <= _controller.text.length) {
        _controller.selection = selection;
      } else {
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length,
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = widget.look;
    final radius = BorderRadius.circular(look.radius);
    final borderColor = look.borderColor;
    OutlineInputBorder outline(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      keyboardType: widget.keyboardType,
      textAlign: TextAlign.center,
      style: look.textStyle,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: look.hintStyle,
        suffixText: widget.suffixText,
        suffixStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: look.verticalPadding),
        filled: true,
        fillColor: look.fillColor,
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        // Bez własnej krawędzi pole bierze krawędzie (spoczynek / fokus)
        // z motywu.
        enabledBorder: borderColor == null ? null : outline(borderColor),
        focusedBorder: borderColor == null
            ? null
            : outline(AppColors.primaryVariant, 1.5),
      ),
    );
  }
}
