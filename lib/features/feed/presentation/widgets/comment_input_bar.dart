import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../bloc/feed_messages.dart';

/// Pole komentarza przyklejone do dołu ekranu. Wysyłka czyści pole od razu;
/// gdy się nie uda ([onSend] zwraca `false`), tekst wraca do pola.
class CommentInputBar extends StatefulWidget {
  const CommentInputBar({
    super.key,
    required this.onSend,
    required this.sending,
    this.focusNode,
  });

  final Future<bool> Function(String body) onSend;
  final bool sending;
  final FocusNode? focusNode;

  @override
  State<CommentInputBar> createState() => _CommentInputBarState();
}

class _CommentInputBarState extends State<CommentInputBar> {
  final _controller = TextEditingController();

  static const _counterThreshold = kMaxCommentLength - 50;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _canSend(String text) {
    final trimmed = text.trim();
    return !widget.sending &&
        trimmed.isNotEmpty &&
        commentLength(trimmed) <= kMaxCommentLength;
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (!_canSend(text)) return;
    _controller.clear();
    final ok = await widget.onSend(text);
    if (!ok && mounted && _controller.text.isEmpty) {
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.7)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: SafeArea(
        top: false,
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            final length = commentLength(value.text);
            final showCounter = length >= _counterThreshold;
            final overLimit = length > kMaxCommentLength;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        key: const ValueKey('post-comment-input'),
                        controller: _controller,
                        focusNode: widget.focusNode,
                        minLines: 1,
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Dodaj komentarz…',
                          hintStyle: const TextStyle(
                            color: AppColors.textMuted,
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.surfaceVariant,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      if (showCounter)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, right: 6),
                          child: Text(
                            '$length/$kMaxCommentLength',
                            style: TextStyle(
                              color: overLimit
                                  ? AppColors.strengthWeak
                                  : AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: widget.sending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppColors.primary,
                          ),
                        )
                      : IconButton(
                          key: const ValueKey('post-comment-send'),
                          tooltip: 'Wyślij komentarz',
                          onPressed: _canSend(value.text) ? _send : null,
                          icon: const Icon(Icons.send_rounded, size: 21),
                          color: AppColors.primaryVariant,
                          disabledColor: AppColors.textMuted,
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
