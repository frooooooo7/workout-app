import 'package:flutter/material.dart';

class AuthFormTopBar extends StatelessWidget {
  const AuthFormTopBar({super.key, required this.onBack, this.child});

  final VoidCallback onBack;

  /// Opcjonalna zawartość na prawo od przycisku wstecz (np. pasek postępu).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 24, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
            padding: EdgeInsets.zero,
          ),
          if (child != null) ...[
            const SizedBox(width: 12),
            Expanded(child: child!),
          ],
        ],
      ),
    );
  }
}
