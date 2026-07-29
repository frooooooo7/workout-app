import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../utils/auth_error_messages.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_form_top_bar.dart';
import '../widgets/auth_glow_background.dart';
import '../widgets/password_strength_widgets.dart';
import '../widgets/register_login_prompt.dart';
import '../widgets/register_step_account.dart';
import '../widgets/register_step_name.dart';
import '../widgets/register_step_progress.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameFormKey = GlobalKey<FormState>();
  final _accountFormKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  int _step = 0;
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

  void _handleNextStep() {
    if (!(_nameFormKey.currentState?.validate() ?? false)) return;
    setState(() => _step = 1);
  }

  void _handleBack() {
    if (_step == 1) {
      setState(() => _step = 0);
      return;
    }
    context.pop();
  }

  Future<void> _handleSubmit() async {
    if (!(_accountFormKey.currentState?.validate() ?? false)) return;

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
      context.go('/app/training');
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
      body: AuthGlowBackground(
        child: SafeArea(
          child: Column(
            children: [
              AuthFormTopBar(
                onBack: _handleBack,
                child: RegisterStepProgress(currentStep: _step),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                    child: Column(
                      children: [
                        AuthCard(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: _step == 0
                                ? RegisterStepName(
                                    key: const ValueKey('register-step-name'),
                                    formKey: _nameFormKey,
                                    firstNameController: _firstNameController,
                                    lastNameController: _lastNameController,
                                    onNext: _handleNextStep,
                                  )
                                : RegisterStepAccount(
                                    key: const ValueKey(
                                      'register-step-account',
                                    ),
                                    formKey: _accountFormKey,
                                    emailController: _emailController,
                                    passwordController: _passwordController,
                                    passwordVisible: _passwordVisible,
                                    password: _password,
                                    strength: _strength,
                                    hasMinLength: _hasMinLength,
                                    hasUpperCase: _hasUpperCase,
                                    hasDigit: _hasDigit,
                                    errorMessage: _errorMessage,
                                    isLoading: _isLoading,
                                    onPasswordChanged: _handlePasswordChanged,
                                    onTogglePasswordVisibility:
                                        _handleTogglePasswordVisibility,
                                    onSubmit: _handleSubmit,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const RegisterLoginPrompt(),
                      ],
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
}
