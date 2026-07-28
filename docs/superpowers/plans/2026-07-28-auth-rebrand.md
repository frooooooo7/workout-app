# Auth Rebrand (Ember + Karta) — Plan implementacji

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Przebudowa UI logowania i rejestracji w `gym-flutter`: paleta „Ember” (pomarańcz na ciepłej czerni) globalnie w `AppColors`, układ „Karta” dla ekranów auth, dwuetapowa rejestracja.

**Architecture:** Zmiana tokenów w `AppColors` (reszta aplikacji dziedziczy kolory automatycznie). Nowe wspólne widgety auth: `AuthCard`, `AuthGlowBackground`, `RegisterStepProgress`. Ekrany auth komponują te bloki; stare widgety hero/dym/benefity są usuwane. Logika logowania/rejestracji, walidatory i routing bez zmian.

**Tech Stack:** Flutter/Dart (`^3.11.5`), go_router, flutter_test. Pakiet pub: `gym`. Shell: PowerShell (używaj `;` zamiast `&&`).

**Spec:** `docs/superpowers/specs/2026-07-28-auth-rebrand-design.md`

**Katalog roboczy:** wszystkie komendy uruchamiane w `gym-flutter/` (chyba że zaznaczono inaczej).

---

### Task 1: Paleta „Ember” w AppColors

**Files:**
- Modify: `lib/core/theme/app_colors.dart`
- Test: `test/app_colors_test.dart` (nowy)

- [ ] **Step 1: Napisz test, który się wywala**

Utwórz `test/app_colors_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/theme/app_colors.dart';

void main() {
  group('AppColors — paleta Ember', () {
    test('primary to pomarańcz ember', () {
      expect(AppColors.primary, const Color(0xFFFF5A1F));
    });
    test('primaryVariant to jaśniejszy pomarańcz', () {
      expect(AppColors.primaryVariant, const Color(0xFFFF8A50));
    });
    test('onPrimary to ciemny (kontrast na pomarańczu)', () {
      expect(AppColors.onPrimary, const Color(0xFF1A0F08));
    });
    test('background to ciepła czerń', () {
      expect(AppColors.background, const Color(0xFF131110));
    });
    test('surface i surfaceVariant są ciepłe', () {
      expect(AppColors.surface, const Color(0xFF1B1713));
      expect(AppColors.surfaceVariant, const Color(0xFF241E19));
    });
    test('teksty i border w ciepłych odcieniach', () {
      expect(AppColors.textPrimary, const Color(0xFFFFF7F2));
      expect(AppColors.textSecondary, const Color(0xFFA89A8E));
      expect(AppColors.textMuted, const Color(0xFF6B5F56));
      expect(AppColors.border, const Color(0xFF2E2721));
    });
    test('gradienty bez fioletu', () {
      expect(AppColors.gradientTop, const Color(0xFF131110));
      expect(AppColors.gradientHero, const Color(0xFF2A1408));
    });
  });
}
```

- [ ] **Step 2: Uruchom test — ma się wywalić**

Run: `flutter test test/app_colors_test.dart`
Expected: FAIL — `Expected: Color(0xffff5a1f) Actual: Color(0xff6c47ff)` (itd.)

- [ ] **Step 3: Podmień tokeny**

Cała zawartość `lib/core/theme/app_colors.dart`:

```dart
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF131110);
  static const surface = Color(0xFF1B1713);
  static const surfaceVariant = Color(0xFF241E19);
  static const primary = Color(0xFFFF5A1F);
  static const primaryVariant = Color(0xFFFF8A50);
  static const onPrimary = Color(0xFF1A0F08);
  static const textPrimary = Color(0xFFFFF7F2);
  static const textSecondary = Color(0xFFA89A8E);
  static const textMuted = Color(0xFF6B5F56);
  static const border = Color(0xFF2E2721);
  static const success = Color(0xFF22C55E);
  static const strengthWeak = Color(0xFFEF4444);
  static const strengthMedium = Color(0xFFF59E0B);
  static const strengthStrong = Color(0xFF22C55E);

  static const gradientTop = Color(0xFF131110);
  static const gradientHero = Color(0xFF2A1408);
}
```

- [ ] **Step 4: Uruchom test — ma przejść**

Run: `flutter test test/app_colors_test.dart`
Expected: PASS (`All tests passed!`)

- [ ] **Step 5: Commit**

```powershell
git add test/app_colors_test.dart lib/core/theme/app_colors.dart
git commit -m "feat(theme): replace purple palette with ember"
```

Uwaga: po tym commicie cała aplikacja zmienia kolory na ember przy jeszcze starym layoucie auth — to zamierzony stan pośredni.

---

### Task 2: Wspólne bloki — AuthCard i AuthGlowBackground

**Files:**
- Create: `lib/features/auth/presentation/widgets/auth_card.dart`
- Create: `lib/features/auth/presentation/widgets/auth_glow_background.dart`
- Test: `test/auth_card_test.dart` (nowy)

- [ ] **Step 1: Napisz testy, które się nie kompilują**

Utwórz `test/auth_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/theme/app_colors.dart';
import 'package:gym/features/auth/presentation/widgets/auth_card.dart';
import 'package:gym/features/auth/presentation/widgets/auth_glow_background.dart';

void main() {
  testWidgets('AuthCard rysuje dziecko w kontenerze surface z ramką', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AuthCard(child: Text('inside'))),
      ),
    );

    expect(find.text('inside'), findsOneWidget);

    final container = tester.widget<Container>(
      find
          .ancestor(of: find.text('inside'), matching: find.byType(Container))
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.surface);
    expect(decoration.borderRadius, BorderRadius.circular(20));
  });

  testWidgets('AuthGlowBackground rysuje poświatę i dziecko', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AuthGlowBackground(child: Text('content'))),
      ),
    );

    expect(find.text('content'), findsOneWidget);

    final glowContainers = tester
        .widgetList<Container>(find.byType(Container))
        .where(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration! as BoxDecoration).gradient is RadialGradient,
        );
    expect(glowContainers.length, 1);
  });
}
```

- [ ] **Step 2: Uruchom testy — błąd kompilacji**

Run: `flutter test test/auth_card_test.dart`
Expected: FAIL kompilacji — `Target of URI doesn't exist: 'package:gym/features/auth/presentation/widgets/auth_card.dart'`

- [ ] **Step 3: Implementacja AuthCard**

Utwórz `lib/features/auth/presentation/widgets/auth_card.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
```

- [ ] **Step 4: Implementacja AuthGlowBackground**

Utwórz `lib/features/auth/presentation/widgets/auth_glow_background.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Ciemne tło ekranów auth z subtelną pomarańczową poświatą
/// w prawym dolnym rogu.
class AuthGlowBackground extends StatelessWidget {
  const AuthGlowBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: AppColors.background)),
        Positioned(
          right: -120,
          bottom: -120,
          child: IgnorePointer(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.14),
                    AppColors.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}
```

- [ ] **Step 5: Uruchom testy — mają przejść**

Run: `flutter test test/auth_card_test.dart`
Expected: PASS (2 testy)

- [ ] **Step 6: Commit**

```powershell
git add test/auth_card_test.dart lib/features/auth/presentation/widgets/auth_card.dart lib/features/auth/presentation/widgets/auth_glow_background.dart
git commit -m "feat(auth): add auth card and glow background widgets"
```

---

### Task 3: RegisterStepProgress — pasek postępu kroków

**Files:**
- Create: `lib/features/auth/presentation/widgets/register_step_progress.dart`
- Test: `test/register_step_progress_test.dart` (nowy)

- [ ] **Step 1: Napisz testy**

Utwórz `test/register_step_progress_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/theme/app_colors.dart';
import 'package:gym/features/auth/presentation/widgets/register_step_progress.dart';

void main() {
  testWidgets('krok 1: aktywny tylko pierwszy segment', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RegisterStepProgress(currentStep: 0)),
      ),
    );

    final colors = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => (c.decoration as BoxDecoration?)?.color)
        .toList();

    expect(colors.where((c) => c == AppColors.primary).length, 1);
    expect(colors.where((c) => c == AppColors.border).length, 1);
  });

  testWidgets('krok 2: oba segmenty aktywne', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RegisterStepProgress(currentStep: 1)),
      ),
    );

    final colors = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => (c.decoration as BoxDecoration?)?.color)
        .toList();

    expect(colors.where((c) => c == AppColors.primary).length, 2);
  });
}
```

- [ ] **Step 2: Uruchom — błąd kompilacji**

Run: `flutter test test/register_step_progress_test.dart`
Expected: FAIL kompilacji — brak pliku `register_step_progress.dart`

- [ ] **Step 3: Implementacja**

Utwórz `lib/features/auth/presentation/widgets/register_step_progress.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class RegisterStepProgress extends StatelessWidget {
  const RegisterStepProgress({
    super.key,
    required this.currentStep,
    this.stepCount = 2,
  });

  final int currentStep;
  final int stepCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(stepCount, (index) {
        final isActive = index <= currentStep;
        return Expanded(
          child: Container(
            height: 3,
            margin: EdgeInsets.only(right: index < stepCount - 1 ? 6 : 0),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
```

- [ ] **Step 4: Uruchom — mają przejść**

Run: `flutter test test/register_step_progress_test.dart`
Expected: PASS (2 testy)

- [ ] **Step 5: Commit**

```powershell
git add test/register_step_progress_test.dart lib/features/auth/presentation/widgets/register_step_progress.dart
git commit -m "feat(auth): add register step progress bar"
```

---

### Task 4: Ekran powitalny logowania jako karta

**Files:**
- Create: `lib/features/auth/presentation/widgets/login_welcome_card.dart`
- Modify: `lib/features/auth/presentation/screens/login_screen.dart`
- Delete: `lib/features/auth/presentation/widgets/login_hero_section.dart`, `login_smoke_animation.dart`, `login_hero_text.dart`, `login_feature_row.dart`, `login_logo_badge.dart`, `login_bottom_section.dart`
- Test: `test/login_screen_test.dart` (nowy)

**Uwaga:** `assets/images/login-hero.png` NIE jest usuwany z projektu — używa go jeszcze `activity_type_selection_screen.dart`. Usuwamy tylko użycie w auth (razem z plikami widgetów hero).

- [ ] **Step 1: Napisz test (RED — obecny ekran ma hero zamiast karty)**

Utwórz `test/login_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/auth/presentation/screens/login_screen.dart';
import 'package:gym/features/auth/presentation/widgets/auth_card.dart';

void main() {
  testWidgets('ekran powitalny pokazuje kartę z marką i akcjami', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.byType(AuthCard), findsOneWidget);
    expect(find.text('STRONGER'), findsOneWidget);
    expect(find.text('Trenuj mądrze.'), findsOneWidget);
    expect(find.text('Osiągaj więcej.'), findsOneWidget);
    expect(find.text('Zaloguj się'), findsOneWidget);
    expect(find.text('Utwórz konto'), findsOneWidget);
    expect(find.text('lub kontynuuj z'), findsOneWidget);
    // Tylko logo — bez zdjęcia hero:
    expect(find.byType(Image), findsOneWidget);
  });
}
```

- [ ] **Step 2: Uruchom — ma się wywalić**

Run: `flutter test test/login_screen_test.dart`
Expected: FAIL — `findsOneWidget` dla `AuthCard` dostaje 0; `find.byType(Image)` znajduje 2 (hero + logo)

- [ ] **Step 3: Implementacja LoginWelcomeCard**

Utwórz `lib/features/auth/presentation/widgets/login_welcome_card.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'auth_social_buttons_row.dart';
import 'auth_social_divider.dart';
import 'login_terms_footer.dart';

class LoginWelcomeCard extends StatelessWidget {
  const LoginWelcomeCard({
    super.key,
    required this.onLoginPressed,
    required this.onRegisterPressed,
  });

  final VoidCallback onLoginPressed;
  final VoidCallback onRegisterPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Image.asset(
            'assets/images/logo.png',
            width: 48,
            height: 48,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'STRONGER',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'TRAIN. TRACK. EVOLVE.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 9,
            letterSpacing: 2,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Trenuj mądrze.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const Text(
          'Osiągaj więcej.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Śledź swoje treningi, analizuj progres\ni osiągaj kolejne cele.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: onLoginPressed,
          child: const Text('Zaloguj się'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onRegisterPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
          ),
          child: const Text('Utwórz konto'),
        ),
        const SizedBox(height: 24),
        const AuthSocialDivider(),
        const SizedBox(height: 20),
        const AuthSocialButtonsRow(),
        const SizedBox(height: 24),
        const LoginTermsFooter(),
      ],
    );
  }
}
```

- [ ] **Step 4: Przebuduj LoginScreen**

Cała zawartość `lib/features/auth/presentation/screens/login_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_glow_background.dart';
import '../widgets/login_welcome_card.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AuthGlowBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: AuthCard(
                child: LoginWelcomeCard(
                  onLoginPressed: () => context.push('/login/form'),
                  onRegisterPressed: () => context.push('/login/register'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Usuń nieużywane widgety hero**

```powershell
Remove-Item lib/features/auth/presentation/widgets/login_hero_section.dart, lib/features/auth/presentation/widgets/login_smoke_animation.dart, lib/features/auth/presentation/widgets/login_hero_text.dart, lib/features/auth/presentation/widgets/login_feature_row.dart, lib/features/auth/presentation/widgets/login_logo_badge.dart, lib/features/auth/presentation/widgets/login_bottom_section.dart
```

Te pliki są referencjonowane wyłącznie przez siebie nawzajem i `login_screen.dart` (zweryfikowane grepem) — po kroku 4 nic ich nie importuje.

- [ ] **Step 6: Uruchom test + analyze**

Run: `flutter test test/login_screen_test.dart`
Expected: PASS

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```powershell
git add -A
git commit -m "feat(auth): rebuild login landing as centered ember card"
```

---

### Task 5: Formularz logowania w karcie

**Files:**
- Modify: `lib/features/auth/presentation/screens/login_form_screen.dart`
- Test: `test/login_form_screen_test.dart` (nowy)

- [ ] **Step 1: Napisz test (RED)**

Utwórz `test/login_form_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/auth/presentation/screens/login_form_screen.dart';
import 'package:gym/features/auth/presentation/widgets/auth_card.dart';

void main() {
  testWidgets('formularz logowania żyje wewnątrz AuthCard', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginFormScreen()));

    expect(find.byType(AuthCard), findsOneWidget);
    expect(find.text('Witaj z powrotem'), findsOneWidget);
    expect(find.text('Zaloguj się'), findsOneWidget);
    expect(find.text('Zarejestruj się'), findsOneWidget);
    expect(find.text('lub kontynuuj z'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Uruchom — ma się wywalić**

Run: `flutter test test/login_form_screen_test.dart`
Expected: FAIL — `AuthCard` znaleziony 0 razy

- [ ] **Step 3: Opakuj formularz kartą**

W `lib/features/auth/presentation/screens/login_form_screen.dart`:

1. Dodaj importy (obok istniejących importów widgetów):

```dart
import '../widgets/auth_card.dart';
import '../widgets/auth_glow_background.dart';
```

2. W spinnerze ładowania zamień `color: Colors.white` na `color: AppColors.onPrimary` (tekst przycisku jest teraz ciemny na pomarańczu).

3. Podmień metodę `build` na:

```dart
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AuthGlowBackground(
        child: SafeArea(
          child: Column(
            children: [
              AuthFormTopBar(onBack: () => context.pop()),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                    child: AuthCard(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const LoginFormHeader(),
                            const SizedBox(height: 32),
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
                              validator: validateLoginPassword,
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () {},
                                child: const Text(
                                  'Zapomniałeś hasła?',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 16),
                              AuthErrorBanner(message: _errorMessage!),
                            ],
                            const SizedBox(height: 28),
                            ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.onPrimary,
                                      ),
                                    )
                                  : const Text('Zaloguj się'),
                            ),
                            const SizedBox(height: 24),
                            const AuthSocialDivider(),
                            const SizedBox(height: 20),
                            const AuthSocialButtonsRow(),
                            const SizedBox(height: 28),
                            LoginFormRegisterLink(
                              onTap: _handleNavigateToRegister,
                            ),
                          ],
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
```

Cała logika (`_handleLogin`, walidatory, kontrolery) zostaje bez zmian.

- [ ] **Step 4: Uruchom test — ma przejść**

Run: `flutter test test/login_form_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```powershell
git add test/login_form_screen_test.dart lib/features/auth/presentation/screens/login_form_screen.dart
git commit -m "feat(auth): wrap login form in auth card"
```

---

### Task 6: Rejestracja dwuetapowa

**Files:**
- Modify: `lib/features/auth/presentation/widgets/auth_form_top_bar.dart` (opcjonalny pasek postępu)
- Create: `lib/features/auth/presentation/widgets/register_step_name.dart`
- Create: `lib/features/auth/presentation/widgets/register_step_account.dart`
- Modify: `lib/features/auth/presentation/screens/register_screen.dart`
- Delete: `lib/features/auth/presentation/widgets/register_benefits_section.dart`, `register_screen_header.dart`
- Test: `test/register_screen_test.dart` (nowy)

- [ ] **Step 1: Napisz testy (RED)**

Utwórz `test/register_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/auth/presentation/screens/register_screen.dart';

void main() {
  Future<void> advanceToAccountStep(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).at(0), 'Jan');
    await tester.enterText(find.byType(TextFormField).at(1), 'Kowalski');
    await tester.tap(find.text('Dalej'));
    await tester.pumpAndSettle();
  }

  testWidgets('startuje na kroku imienia i przechodzi do kroku konta', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));

    expect(find.text('Jak masz na imię?'), findsOneWidget);
    expect(find.text('Krok 1 z 2 — kilka podstawowych danych.'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));

    await advanceToAccountStep(tester);

    expect(find.text('Ustaw dostęp'), findsOneWidget);
    expect(find.text('Krok 2 z 2 — e-mail i hasło do logowania.'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Hasło'), findsOneWidget);
  });

  testWidgets('wstecz na kroku konta wraca do kroku imienia', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
    await advanceToAccountStep(tester);
    expect(find.text('Ustaw dostęp'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Jak masz na imię?'), findsOneWidget);
    expect(find.text('Ustaw dostęp'), findsNothing);
  });
}
```

Uwaga: „E-mail” i „Hasło” to hinty pól — renderują się jako tekst, gdy pole jest puste.

- [ ] **Step 2: Uruchom — ma się wywalić**

Run: `flutter test test/register_screen_test.dart`
Expected: FAIL — `find.text('Jak masz na imię?')` znalezione 0 razy

- [ ] **Step 3: Rozszerz AuthFormTopBar o opcjonalną zawartość**

Cała zawartość `lib/features/auth/presentation/widgets/auth_form_top_bar.dart`:

```dart
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
```

Bez `child` zachowuje się jak dotychczas (użycie w `login_form_screen.dart` bez zmian).

- [ ] **Step 4: Implementacja RegisterStepName**

Utwórz `lib/features/auth/presentation/widgets/register_step_name.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'auth_text_field.dart';

class RegisterStepName extends StatelessWidget {
  const RegisterStepName({
    super.key,
    required this.formKey,
    required this.firstNameController,
    required this.lastNameController,
    required this.onNext,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Jak masz na imię?',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Krok 1 z 2 — kilka podstawowych danych.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          AuthTextField(
            hint: 'Imię',
            prefixIcon: Icons.person_outline_rounded,
            controller: firstNameController,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Imię jest wymagane.' : null,
          ),
          const SizedBox(height: 12),
          AuthTextField(
            hint: 'Nazwisko',
            prefixIcon: Icons.person_outline_rounded,
            controller: lastNameController,
            textInputAction: TextInputAction.done,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Nazwisko jest wymagane.'
                : null,
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: onNext, child: const Text('Dalej')),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Implementacja RegisterStepAccount**

Utwórz `lib/features/auth/presentation/widgets/register_step_account.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../utils/auth_validators.dart';
import 'auth_error_banner.dart';
import 'auth_text_field.dart';
import 'password_strength_widgets.dart';

class RegisterStepAccount extends StatelessWidget {
  const RegisterStepAccount({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.passwordVisible,
    required this.password,
    required this.strength,
    required this.hasMinLength,
    required this.hasUpperCase,
    required this.hasDigit,
    required this.errorMessage,
    required this.isLoading,
    required this.onPasswordChanged,
    required this.onTogglePasswordVisibility,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool passwordVisible;
  final String password;
  final PasswordStrength strength;
  final bool hasMinLength;
  final bool hasUpperCase;
  final bool hasDigit;
  final String? errorMessage;
  final bool isLoading;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ustaw dostęp',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Krok 2 z 2 — e-mail i hasło do logowania.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          AuthTextField(
            hint: 'E-mail',
            prefixIcon: Icons.mail_outline_rounded,
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: validateAuthEmail,
          ),
          const SizedBox(height: 12),
          AuthTextField(
            hint: 'Hasło',
            prefixIcon: Icons.lock_outline_rounded,
            controller: passwordController,
            obscureText: !passwordVisible,
            onChanged: onPasswordChanged,
            textInputAction: TextInputAction.done,
            suffixIcon: IconButton(
              icon: Icon(
                passwordVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textMuted,
                size: 20,
              ),
              onPressed: onTogglePasswordVisibility,
            ),
            validator: validateRegisterPassword,
          ),
          if (password.isNotEmpty) ...[
            const SizedBox(height: 10),
            PasswordStrengthBar(strength: strength),
            const SizedBox(height: 12),
            PasswordRequirementsCard(
              hasMinLength: hasMinLength,
              hasUpperCase: hasUpperCase,
              hasDigit: hasDigit,
            ),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            AuthErrorBanner(message: errorMessage!),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: isLoading ? null : onSubmit,
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onPrimary,
                    ),
                  )
                : const Text('Utwórz konto'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Przebuduj RegisterScreen na dwa kroki**

Cała zawartość `lib/features/auth/presentation/screens/register_screen.dart`:

```dart
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
```

- [ ] **Step 7: Usuń nieużywane widgety rejestracji**

```powershell
Remove-Item lib/features/auth/presentation/widgets/register_benefits_section.dart, lib/features/auth/presentation/widgets/register_screen_header.dart
```

Były importowane wyłącznie przez `register_screen.dart` (zweryfikowane grepem).

- [ ] **Step 8: Uruchom testy + analyze**

Run: `flutter test test/register_screen_test.dart`
Expected: PASS (2 testy)

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 9: Commit**

```powershell
git add -A
git commit -m "feat(auth): turn registration into two-step card flow"
```

---

### Task 7: Ekrany ładowania routera na AppColors

**Files:**
- Modify: `lib/core/navigation/app_router.dart` (import + klasy `_LoadingScreen` i `_SplashRouteState.build`, ok. linie 261-312)

- [ ] **Step 1: Dodaj import**

W `lib/core/navigation/app_router.dart`, obok `import '../services/service_locator.dart';` dodaj:

```dart
import '../theme/app_colors.dart';
```

- [ ] **Step 2: Podmień zahardkodowane kolory (2 miejsca)**

W `_LoadingScreen.build` oraz w `build` klasy `_SplashRouteState` zamień:

```dart
    return const Scaffold(
      backgroundColor: Color(0xFF0B0B14),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF6C47FF)),
      ),
    );
```

na:

```dart
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
```

- [ ] **Step 3: Weryfikacja braku fioletu w kodzie**

Run: `flutter analyze`
Expected: `No issues found!`

Run (PowerShell): `rg "0xFF6C47FF|0xFF8B6BFF|0xFF1A0A3A" lib`
Expected: brak wyników (exit code 1 = nic nie znaleziono)

- [ ] **Step 4: Uruchom istniejące testy routera**

Run: `flutter test test/app_router_test.dart`
Expected: PASS (2 testy — testują redirecty, nie kolory)

- [ ] **Step 5: Commit**

```powershell
git add lib/core/navigation/app_router.dart
git commit -m "refactor(navigation): use AppColors in router loading screens"
```

---

### Task 8: Aktualizacja PROJECT_CONTEXT.md + pełna weryfikacja

**Files:**
- Modify: `../PROJECT_CONTEXT.md` (root workspace — NIE jest w repo git, edycja bez commita)

- [ ] **Step 1: Zaktualizuj opis motywu**

W `../PROJECT_CONTEXT.md`, sekcja 4.2 (linia ~194), zamień:

```
│   ├── theme/                      <- dark-only, fiolet #6C47FF na #0B0B14
```

na:

```
│   ├── theme/                      <- dark-only, „Ember” #FF5A1F na #131110
```

Data w nagłówku pliku (2026-07-28) jest już aktualna — bez zmian. Sekcja 7 mówi o auth tylko w kontekście backendu (JWT) — bez zmian.

- [ ] **Step 2: Pełny analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Pełny zestaw testów**

Run: `flutter test`
Expected: wszystkie testy PASS (16 istniejących plików + 6 nowych: `app_colors_test`, `auth_card_test`, `register_step_progress_test`, `login_screen_test`, `login_form_screen_test`, `register_screen_test`)

Jeśli któryś istniejący test padnie przez zmianę palety (np. asercja koloru), popraw asercję na nowy token i dołącz do commita.

- [ ] **Step 4: Commit**

```powershell
git add -A
git commit -m "test: cover auth rebrand screens and widgets"
```

(Jeśli w Task 1-7 wszystkie testy zostały już zacommitowane i nic nowego nie wyszło w Step 3, pomiń pusty commit.)

---

## Definition of done

- `flutter analyze` — 0 issues
- `flutter test` — wszystko zielone
- Login powitalny: karta na poświacie, bez hero/dymu/feature row
- Login form i rejestracja w kartach; rejestracja dwuetapowa z paskiem postępu i cofaniem do kroku 1
- Żadnych hexów fioletu w `lib/` (`rg "0xFF6C47FF|0xFF8B6BFF|0xFF1A0A3A" lib` — pusto)
- `PROJECT_CONTEXT.md` opisuje paletę Ember
- Ręczny smoke: `flutter run` → splash (pomarańczowy spinner), login, formularz, oba kroki rejestracji
