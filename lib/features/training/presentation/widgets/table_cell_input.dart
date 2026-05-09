import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class TableCellInput extends StatefulWidget {
  const TableCellInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint = '',
    this.suffixText,
  });

  final String value;
  final String hint;
  final String? suffixText;
  final ValueChanged<String> onChanged;

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
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      // Maintain cursor position if possible, but safely update text
      final selection = _controller.selection;
      _controller.text = widget.value;
      if (selection.isValid && selection.end <= _controller.text.length) {
        _controller.selection = selection;
      } else {
        _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
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
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        suffixText: widget.suffixText,
        suffixStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
