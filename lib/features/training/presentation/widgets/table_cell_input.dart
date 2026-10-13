import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/units/weight_unit.dart';

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
