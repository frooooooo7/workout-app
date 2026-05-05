import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../utils/auth_error_messages.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_form_top_bar.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/password_strength_widgets.dart';
import '../widgets/register_benefits_section.dart';
import '../widgets/register_login_prompt.dart';
import '../widgets/register_screen_header.dart';

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

  PasswordStrength get _strength => passwordStrengthFor(_password);

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
            AuthFormTopBar(onBack: () => context.pop()),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const RegisterScreenHeader(),
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
                        validator: validateAuthEmail,
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
                        validator: validateRegisterPassword,
                      ),
                      if (_password.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        PasswordStrengthBar(strength: _strength),
                        const SizedBox(height: 12),
                        PasswordRequirementsCard(
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
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Utwórz konto'),
                      ),
                      const SizedBox(height: 16),
                      const RegisterLoginPrompt(),
                      const SizedBox(height: 28),
                      const RegisterBenefitsSection(),
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
