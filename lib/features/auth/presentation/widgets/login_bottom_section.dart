import 'package:flutter/material.dart';
import 'auth_social_buttons_row.dart';
import 'auth_social_divider.dart';
import 'login_terms_footer.dart';

class LoginBottomSection extends StatelessWidget {
  const LoginBottomSection({
    super.key,
    required this.onPrimaryPressed,
    required this.onSecondaryPressed,
  });

  final VoidCallback onPrimaryPressed;
  final VoidCallback onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: onPrimaryPressed,
            child: const Text('Zaloguj się'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onSecondaryPressed,
            child: const Text('Utwórz konto'),
          ),
          const SizedBox(height: 28),
          const AuthSocialDivider(),
          const SizedBox(height: 20),
          const AuthSocialButtonsRow(),
          const SizedBox(height: 28),
          const LoginTermsFooter(),
        ],
      ),
    );
  }
}
