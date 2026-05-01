import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../utils/auth_error_messages.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _passwordVisible = false;
  bool _isLoading = false;
  String _password = '';
  String? _errorMessage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handlePasswordChanged(String value) {
    setState(() => _password = value);
  }

  void _handleTogglePasswordVisibility() {
    setState(() => _passwordVisible = !_passwordVisible);
  }

  bool get _hasMinLength => _password.length >= 8;
  bool get _hasUpperCase => _password.contains(RegExp(r'[A-Z]'));
  bool get _hasDigit => _password.contains(RegExp(r'[0-9]'));

  _PasswordStrength get _strength {
    final score =
        [_hasMinLength, _hasUpperCase, _hasDigit].where((v) => v).length;
    if (score == 3) return _PasswordStrength.strong;
    if (score == 2) return _PasswordStrength.medium;
    if (score == 1) return _PasswordStrength.weak;
    return _PasswordStrength.none;
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ServiceLocator.authRepository.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );
      await ServiceLocator.tokenStorage.saveToken(result.token);
      await ServiceLocator.tokenStorage.saveUser(result.user);
      ServiceLocator.currentUser.value = result.user;

      if (!mounted) return;
      context.go('/app/home');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = authErrorMessage(e.message);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = authErrorMessage('network_error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onBack: () => context.pop()),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(),
                      const SizedBox(height: 28),
                      AuthTextField(
                        hint: 'Imię',
                        prefixIcon: Icons.person_outline_rounded,
                        controller: _firstNameController,
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Imię jest wymagane.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      AuthTextField(
                        hint: 'Nazwisko',
                        prefixIcon: Icons.person_outline_rounded,
                        controller: _lastNameController,
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Nazwisko jest wymagane.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      AuthTextField(
                        hint: 'E-mail',
                        prefixIcon: Icons.mail_outline_rounded,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 12),
                      AuthTextField(
                        hint: 'Hasło',
                        prefixIcon: Icons.lock_outline_rounded,
                        controller: _passwordController,
                        obscureText: !_passwordVisible,
                        onChanged: _handlePasswordChanged,
                        textInputAction: TextInputAction.done,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _passwordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
                          onPressed: _handleTogglePasswordVisibility,
                        ),
                        validator: _validatePassword,
                      ),
                      if (_password.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _PasswordStrengthBar(strength: _strength),
                        const SizedBox(height: 12),
                        _PasswordRequirements(
                          hasMinLength: _hasMinLength,
                          hasUpperCase: _hasUpperCase,
                          hasDigit: _hasDigit,
                        ),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        AuthErrorBanner(message: _errorMessage!),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleSubmit,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Utwórz konto'),
                      ),
                      const SizedBox(height: 16),
                      _LoginLink(),
                      const SizedBox(height: 28),
                      _WhySection(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) return 'E-mail jest wymagany.';
  final regex = RegExp(r'^[\w\-.+]+@[\w\-]+\.[a-zA-Z]{2,}$');
  if (!regex.hasMatch(value.trim())) return 'Podaj prawidłowy adres e-mail.';
  return null;
}

String? _validatePassword(String? value) {
  if (value == null || value.isEmpty) return 'Hasło jest wymagane.';
  if (value.length < 8) return 'Min. 8 znaków.';
  if (!value.contains(RegExp(r'[A-Z]'))) return 'Wymagana wielka litera.';
  if (!value.contains(RegExp(r'[0-9]'))) return 'Wymagana cyfra.';
  return null;
}

// ---------------------------------------------------------------------------
// Enums & sub-widgets
// ---------------------------------------------------------------------------

enum _PasswordStrength { none, weak, medium, strong }

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 24, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Utwórz konto',
          style: TextStyle(
              color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 6),
        Text(
          'Zacznij swoją drogę do lepszej wersji siebie.',
          style: TextStyle(
              color: AppColors.textSecondary, fontSize: 14, height: 1.4),
        ),
      ],
    );
  }
}

class _PasswordStrengthBar extends StatelessWidget {
  const _PasswordStrengthBar({required this.strength});

  final _PasswordStrength strength;

  Color get _color => switch (strength) {
        _PasswordStrength.weak => AppColors.strengthWeak,
        _PasswordStrength.medium => AppColors.strengthMedium,
        _PasswordStrength.strong => AppColors.strengthStrong,
        _PasswordStrength.none => AppColors.border,
      };

  String get _label => switch (strength) {
        _PasswordStrength.weak => 'Słabe',
        _PasswordStrength.medium => 'Średnie',
        _PasswordStrength.strong => 'Silne',
        _PasswordStrength.none => '',
      };

  double get _progress => switch (strength) {
        _PasswordStrength.none => 0.0,
        _PasswordStrength.weak => 0.33,
        _PasswordStrength.medium => 0.66,
        _PasswordStrength.strong => 1.0,
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(_color),
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(_label,
            style: TextStyle(
                color: _color, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _PasswordRequirements extends StatelessWidget {
  const _PasswordRequirements({
    required this.hasMinLength,
    required this.hasUpperCase,
    required this.hasDigit,
  });

  final bool hasMinLength;
  final bool hasUpperCase;
  final bool hasDigit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _Req(label: 'Minimum 8 znaków', met: hasMinLength),
          const SizedBox(height: 8),
          _Req(label: 'Jedna wielka litera', met: hasUpperCase),
          const SizedBox(height: 8),
          _Req(label: 'Jedna cyfra', met: hasDigit),
        ],
      ),
    );
  }
}

class _Req extends StatelessWidget {
  const _Req({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          met
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color: met ? AppColors.success : AppColors.textMuted,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: met ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _LoginLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Masz już konto? ',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        GestureDetector(
          onTap: () => context.pop(),
          child: const Text(
            'Zaloguj się',
            style: TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _WhySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dlaczego warto?',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 16),
          _BenefitItem(
            icon: Icons.trending_up_rounded,
            iconColor: Color(0xFF6C47FF),
            title: 'Pełna analiza progresu',
            description: 'Śledź swoje wyniki i bicie rekordów.',
          ),
          SizedBox(height: 14),
          _BenefitItem(
            icon: Icons.local_fire_department_rounded,
            iconColor: Color(0xFFFF6B35),
            title: 'Motywacja każdego dnia',
            description: 'Osiągaj cele i utrzymuj streaki.',
          ),
          SizedBox(height: 14),
          _BenefitItem(
            icon: Icons.people_outline_rounded,
            iconColor: Color(0xFF22C55E),
            title: 'Społeczność, która napędza',
            description: 'Rywalizuj, dziel się wynikami i inspiruj innych.',
          ),
        ],
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  const _BenefitItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(description,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
