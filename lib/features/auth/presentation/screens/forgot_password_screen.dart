import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/repositories/password_reset_repository.dart';
import '../utils/auth_error_messages.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_form_top_bar.dart';
import '../widgets/auth_glow_background.dart';
import '../widgets/auth_text_field.dart';

/// „Zapomniałeś hasła?”: formularz e-maila, a po wysyłce potwierdzenie
/// z ponowną wysyłką po odliczaniu.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.initialEmail,
    this.repository,
    this.resendCooldown = const Duration(seconds: 30),
  });

  /// E-mail wpisany już na ekranie logowania.
  final String? initialEmail;

  /// `null` — [ServiceLocator.passwordResetRepository].
  final PasswordResetRepository? repository;

  final Duration resendCooldown;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(
    text: widget.initialEmail?.trim() ?? '',
  );

  bool _isLoading = false;
  String? _errorMessage;

  /// Adres, na który poszła prośba — `null` pokazuje formularz.
  String? _sentTo;

  Timer? _cooldownTimer;
  int _cooldownLeft = 0;

  PasswordResetRepository get _repository =>
      widget.repository ?? ServiceLocator.passwordResetRepository;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownLeft = widget.resendCooldown.inSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _cooldownLeft--);
      if (_cooldownLeft <= 0) timer.cancel();
    });
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _request(_emailController.text.trim());
  }

  Future<void> _request(String email) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _repository.requestReset(email: email);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _sentTo = email;
      });
      _startCooldown();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = authErrorMessage('network_error');
      });
    }
  }

  void _changeEmail() {
    _cooldownTimer?.cancel();
    setState(() {
      _sentTo = null;
      _cooldownLeft = 0;
      _errorMessage = null;
    });
  }

  void _backToLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login/form');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sentTo = _sentTo;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AuthGlowBackground(
        child: SafeArea(
          child: Column(
            children: [
              AuthFormTopBar(onBack: _backToLogin),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                    child: AuthCard(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeOutCubic,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween(
                                    begin: const Offset(0, 0.03),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: sentTo == null
                              ? _buildForm()
                              : _buildSent(sentTo),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _IconBadge(icon: Icons.lock_reset_rounded),
          const SizedBox(height: 20),
          const Text(
            'Nie pamiętasz hasła?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Podaj e-mail powiązany z kontem. Wyślemy na niego link '
            'do ustawienia nowego hasła.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          AuthTextField(
            hint: 'E-mail',
            prefixIcon: Icons.mail_outline_rounded,
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.send,
            validator: validateAuthEmail,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            AuthErrorBanner(message: _errorMessage!),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _send,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onPrimary,
                    ),
                  )
                : const Text('Wyślij link'),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: _backToLogin,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Wróć do logowania'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSent(String email) {
    final canResend = _cooldownLeft <= 0 && !_isLoading;
    return Column(
      key: const ValueKey('sent'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _IconBadge(
          icon: Icons.mark_email_read_rounded,
          color: AppColors.success,
        ),
        const SizedBox(height: 20),
        const Text(
          'Sprawdź skrzynkę',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Jeśli istnieje konto dla '),
              TextSpan(
                text: email,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(
                text: ', wyślemy na nie link do ustawienia nowego hasła.',
              ),
            ],
          ),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        const _Step(number: 1, text: 'Otwórz wiadomość od Stronger'),
        const _Step(number: 2, text: 'Kliknij link „Ustaw nowe hasło”'),
        const _Step(number: 3, text: 'Zaloguj się nowym hasłem'),
        if (!_repository.isLive) ...[
          const SizedBox(height: 16),
          const _InfoNote(
            text:
                'Wysyłka wiadomości zostanie uruchomiona wkrótce — '
                'na razie e-mail nie dotrze.',
          ),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          AuthErrorBanner(message: _errorMessage!),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _backToLogin,
          child: const Text('Wróć do logowania'),
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            TextButton(
              onPressed: canResend ? () => _request(email) : null,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryVariant,
                disabledForegroundColor: AppColors.textMuted,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryVariant,
                      ),
                    )
                  : Text(
                      _cooldownLeft > 0
                          ? 'Wyślij ponownie (0:${_cooldownLeft.toString().padLeft(2, '0')})'
                          : 'Wyślij ponownie',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
            ),
            TextButton(
              onPressed: _isLoading ? null : _changeEmail,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              child: const Text('Zmień e-mail'),
            ),
          ],
        ),
      ],
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, this.color = AppColors.primary});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 24),
          ],
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.strengthMedium.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.strengthMedium.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.strengthMedium,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.strengthMedium,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
