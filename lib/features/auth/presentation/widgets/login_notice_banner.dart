import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

const loginNoticeBannerKey = Key('login-notice-banner');

/// Informacja nad kartą logowania, np. „Konto zostało usunięte.”.
class LoginNoticeBanner extends StatelessWidget {
  const LoginNoticeBanner({super.key, required this.notice});

  final ValueNotifier<String?> notice;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: notice,
      builder: (context, message, _) {
        if (message == null || message.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            key: loginNoticeBannerKey,
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primaryVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.primaryVariant,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Zamknij',
                  onPressed: () => notice.value = null,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textMuted,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
