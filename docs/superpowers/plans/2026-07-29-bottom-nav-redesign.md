# Bottom Nav Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Przebudować dolną nawigację: Historia · Plany · (duży okrągły Trening w notchu) · Aktywność · Profil; Plany jako zakładka, Home usuwany, start na Treningu.

**Architecture:** Własny widget `AppBottomNav` (Stack + CustomPainter notch) w `AppShell`; współdzielony `TrainingSessionCubit` na poziomie shella zasila „smart" środkowy przycisk (aktywna sesja → ongoing workout, brak → branch Trening). Routing: 5 branchy w nowej kolejności, `/app/plans`, redirect `/app/training/plans`, usunięcie `/app/home`.

**Tech Stack:** Flutter, go_router (`StatefulShellRoute.indexedStack`), flutter_bloc (Cubit), flutter_test.

**Spec:** `docs/superpowers/specs/2026-07-29-bottom-nav-redesign-design.md`

**Uwaga o komendach:** zgodnie z regułą projektu (`PROJECT.md` / `PROJECT_CONTEXT.md` §6) komendy Flutter/Dart uruchamia **użytkownik**. Kroki „Run" opisują komendę i oczekiwany wynik — agent ich nie wykonuje.

---

## File Structure

| Plik | Odpowiedzialność |
|------|------------------|
| Create: `lib/core/navigation/app_bottom_nav.dart` | Custom belka z notchem + środkowym kółkiem (prezentacja, zero logiki routingu) |
| Modify: `lib/core/navigation/app_shell.dart` | Podpięcie `AppBottomNav`, smart tap, `BlocBuilder` po sesji |
| Modify: `lib/core/navigation/app_router.dart` | Branchy, `/app/plans`, redirect, splash, shell-level `BlocProvider<TrainingSessionCubit>` |
| Modify: `lib/core/services/service_locator.dart` | Test seam `debugSetUserScopedRepositories` |
| Modify: `lib/features/training/presentation/screens/training_screen.dart` | Usunięcie lokalnego `TrainingSessionCubit` i `onPlansTap` |
| Modify: `lib/features/training/presentation/screens/plans_screen.dart` | Zakładka: bez Wstecz, bez lokalnego `TrainingSessionCubit` |
| Modify: `lib/features/training/presentation/widgets/training_header.dart` | Usunięcie `onPlansTap` |
| Modify: `lib/features/auth/presentation/screens/login_form_screen.dart` | Redirect `/app/home` → `/app/training` |
| Modify: `lib/features/auth/presentation/screens/register_screen.dart` | Redirect `/app/home` → `/app/training` |
| Delete: `lib/features/home/` | Martwy kod (mocki) |
| Create: `test/app_bottom_nav_test.dart` | Testy widgetu belki |
| Modify: `test/app_router_test.dart` | Fake repos + nowe testy (redirect, smart tap) |
| Modify: `test/training_header_test.dart` | Aktualizacja po usunięciu `onPlansTap` |
| Modify: `PROJECT_CONTEXT.md` (workspace root) | Sekcje 4.2, 4.3, 7 — nowa nawigacja |

---

### Task 1: Test seam w ServiceLocator + scaffolding w app_router_test

`AppShell` po zmianach będzie czytał `TrainingSessionCubit` przy każdym buildzie shella — istniejące testy routera nie inicjalizują user-scoped repozytoriów. Dodajemy szw testowy i fake'i (bez zmiany zachowania produkcyjnego).

**Files:**
- Modify: `lib/core/services/service_locator.dart` (po metodzie `init()`, ~linia 117)
- Modify: `test/app_router_test.dart`

- [ ] **Step 1: Dodaj seam do ServiceLocator**

W `lib/core/services/service_locator.dart`, bezpośrednio po metodzie `init()`:

```dart
  /// Test seam: podmienia user-scoped repozytoria bez otwierania bazy.
  @visibleForTesting
  static void debugSetUserScopedRepositories({
    ExerciseRepository? exerciseRepository,
    TrainingPlanRepository? trainingPlanRepository,
    TrainingHistoryRepository? trainingHistoryRepository,
    TrainingSessionRepository? trainingSessionRepository,
  }) {
    _exerciseRepository = exerciseRepository;
    _trainingPlanRepository = trainingPlanRepository;
    _trainingHistoryRepository = trainingHistoryRepository;
    _trainingSessionRepository = trainingSessionRepository;
  }
```

`visibleForTesting` jest już dostępne (plik importuje `package:flutter/foundation.dart`).

- [ ] **Step 2: Rozszerz app_router_test o setUp/tearDown i fake'i**

Podmień początek `main()` w `test/app_router_test.dart`:

```dart
void main() {
  Future<void> setDesktopViewport(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    tester.view.devicePixelRatio = 1;
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.view.resetDevicePixelRatio();
    });
  }

  setUp(() {
    ServiceLocator.debugSetUserScopedRepositories(
      trainingPlanRepository: _FakeTrainingPlanRepository(),
      trainingHistoryRepository: _FakeTrainingHistoryRepository(),
      trainingSessionRepository: _FakeTrainingSessionRepository(),
    );
  });

  tearDown(() {
    ServiceLocator.debugSetUserScopedRepositories();
    ServiceLocator.currentUser.value = null;
  });
```

Na końcu pliku dodaj fake'i:

```dart
class _FakeTrainingPlanRepository implements TrainingPlanRepository {
  @override
  Future<List<CustomTrainingPlan>> getAll() async => const [];

  @override
  Future<CustomTrainingPlan> create(CustomTrainingPlan plan) async => plan;

  @override
  Future<CustomTrainingPlan> update(CustomTrainingPlan plan) async => plan;

  @override
  Future<void> delete(String id) async {}
}

class _FakeTrainingHistoryRepository implements TrainingHistoryRepository {
  @override
  Future<TrainingSessionPage> getSessions({
    String? cursor,
    int limit = 20,
    TrainingSessionStatus? status,
    String? planId,
    String? query,
    DateTime? from,
    DateTime? to,
  }) async {
    return const TrainingSessionPage(
      items: [],
      nextCursor: null,
      hasMore: false,
      isFromCache: false,
    );
  }

  @override
  Future<TrainingSessionDetail> getSessionDetail(String sessionId) {
    throw UnimplementedError();
  }
}

class _FakeTrainingSessionRepository implements TrainingSessionRepository {
  _FakeTrainingSessionRepository({this.active});

  TrainingSession? active;

  @override
  Future<TrainingSession?> getActive() async => active;

  @override
  Future<TrainingSession> startFromPlan(CustomTrainingPlan plan) async {
    throw UnimplementedError();
  }

  @override
  Future<TrainingSession> startCustom({
    String planName = TrainingSession.defaultCustomName,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<TrainingSession> save(TrainingSession session) async => session;

  @override
  Future<TrainingSession> finish(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<TrainingSession> cancel(String sessionId) {
    throw UnimplementedError();
  }
}
```

Nowe importy w `test/app_router_test.dart`:

```dart
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/models/training_history_models.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/repositories/training_history_repository.dart';
import 'package:gym/features/training/domain/repositories/training_plan_repository.dart';
import 'package:gym/features/training/domain/repositories/training_session_repository.dart';
```

- [ ] **Step 3: Run — użytkownik uruchamia**

Run: `cd gym-flutter; flutter test test/app_router_test.dart`
Expected: PASS (2 istniejące testy — brak zmiany zachowania).

- [ ] **Step 4: Commit**

```bash
git add lib/core/services/service_locator.dart test/app_router_test.dart
git commit -m "test(navigation): add user-scoped repository seam for router tests"
```

---

### Task 2: Widget AppBottomNav (TDD)

Czysto prezentacyjny widget: kolejność Historia / Plany / [Trening] / Aktywność / Profil, notch rysowany `CustomPainter`em, stany selected i zielona kropka sesji. Bez zależności od go_router/bloc — łatwo testować.

**Files:**
- Create: `test/app_bottom_nav_test.dart`
- Create: `lib/core/navigation/app_bottom_nav.dart`

- [ ] **Step 1: Napisz padający test**

Utwórz `test/app_bottom_nav_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/navigation/app_bottom_nav.dart';

void main() {
  Widget buildSubject({
    int currentIndex = 2,
    bool hasActiveSession = false,
    ValueChanged<int>? onDestinationSelected,
    VoidCallback? onCenterTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        bottomNavigationBar: AppBottomNav(
          currentIndex: currentIndex,
          hasActiveSession: hasActiveSession,
          onDestinationSelected: onDestinationSelected ?? (_) {},
          onCenterTap: onCenterTap ?? () {},
        ),
      ),
    );
  }

  testWidgets('renders five destinations in order', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Historia'), findsOneWidget);
    expect(find.text('Plany'), findsOneWidget);
    expect(find.text('Trening'), findsOneWidget);
    expect(find.text('Aktywność'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);

    final historiaX = tester.getCenter(find.text('Historia')).dx;
    final planyX = tester.getCenter(find.text('Plany')).dx;
    final treningX = tester.getCenter(find.text('Trening')).dx;
    final aktywnoscX = tester.getCenter(find.text('Aktywność')).dx;
    final profilX = tester.getCenter(find.text('Profil')).dx;
    expect(historiaX < planyX, isTrue);
    expect(planyX < treningX, isTrue);
    expect(treningX < aktywnoscX, isTrue);
    expect(aktywnoscX < profilX, isTrue);
  });

  testWidgets('delegates small destination taps with branch index', (
    tester,
  ) async {
    int? tappedIndex;
    await tester.pumpWidget(
      buildSubject(onDestinationSelected: (index) => tappedIndex = index),
    );

    await tester.tap(find.text('Historia'));
    expect(tappedIndex, 0);

    await tester.tap(find.text('Aktywność'));
    expect(tappedIndex, 3);

    await tester.tap(find.text('Profil'));
    expect(tappedIndex, 4);
  });

  testWidgets('center circle and label call onCenterTap', (tester) async {
    var centerTaps = 0;
    await tester.pumpWidget(
      buildSubject(onCenterTap: () => centerTaps += 1),
    );

    await tester.tap(find.byKey(const Key('app-bottom-nav-center')));
    expect(centerTaps, 1);

    await tester.tap(find.text('Trening'));
    expect(centerTaps, 2);
  });

  testWidgets('shows active-session dot only when session is active', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(hasActiveSession: true));
    expect(find.byKey(const Key('app-bottom-nav-active-dot')), findsOneWidget);

    await tester.pumpWidget(buildSubject(hasActiveSession: false));
    expect(find.byKey(const Key('app-bottom-nav-active-dot')), findsNothing);
  });

  testWidgets('selected center shows white ring, unselected does not', (
    tester,
  ) async {
    BoxDecoration decorationOf(WidgetTester tester) {
      final container = tester.widget<Container>(
        find.byKey(const Key('app-bottom-nav-center')),
      );
      return container.decoration! as BoxDecoration;
    }

    await tester.pumpWidget(buildSubject(currentIndex: 2));
    expect(decorationOf(tester).border, isNotNull);

    await tester.pumpWidget(buildSubject(currentIndex: 0));
    expect(decorationOf(tester).border, isNull);
  });
}
```

- [ ] **Step 2: Run — użytkownik uruchamia**

Run: `cd gym-flutter; flutter test test/app_bottom_nav_test.dart`
Expected: FAIL — kompilacja, `AppBottomNav` nie istnieje.

- [ ] **Step 3: Implementacja**

Utwórz `lib/core/navigation/app_bottom_nav.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Bottom navigation with a notched, docked center "Trening" button.
///
/// Order: Historia (0), Plany (1), [Trening (2)], Aktywność (3), Profil (4).
/// Purely presentational — the parent resolves taps.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.hasActiveSession,
    required this.onDestinationSelected,
    required this.onCenterTap,
  });

  static const double barHeight = 64;
  static const double centerDiameter = 56;
  static const double _centerOverlap = centerDiameter / 2;

  final int currentIndex;
  final bool hasActiveSession;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onCenterTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        // Extra height on top so the circle stays inside hit-test bounds.
        height: barHeight + _centerOverlap,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: _centerOverlap,
              bottom: 0,
              child: const CustomPaint(
                painter: _NotchedBarPainter(notchDepth: 30, notchMargin: 40),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: _centerOverlap,
              bottom: 0,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _NavItem(
                    index: 0,
                    label: 'Historia',
                    icon: Icons.history_outlined,
                    selectedIcon: Icons.history_rounded,
                    selected: currentIndex == 0,
                    onTap: onDestinationSelected,
                  ),
                  _NavItem(
                    index: 1,
                    label: 'Plany',
                    icon: Icons.format_list_bulleted_rounded,
                    selectedIcon: Icons.format_list_bulleted_rounded,
                    selected: currentIndex == 1,
                    onTap: onDestinationSelected,
                  ),
                  _CenterLabelSlot(
                    label: 'Trening',
                    selected: currentIndex == 2,
                    onTap: onCenterTap,
                  ),
                  _NavItem(
                    index: 3,
                    label: 'Aktywność',
                    icon: Icons.timeline_outlined,
                    selectedIcon: Icons.timeline_rounded,
                    selected: currentIndex == 3,
                    onTap: onDestinationSelected,
                  ),
                  _NavItem(
                    index: 4,
                    label: 'Profil',
                    icon: Icons.person_outline_rounded,
                    selectedIcon: Icons.person_rounded,
                    selected: currentIndex == 4,
                    onTap: onDestinationSelected,
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: _CenterButton(
                  selected: currentIndex == 2,
                  hasActiveSession: hasActiveSession,
                  onTap: onCenterTap,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterButton extends StatelessWidget {
  const _CenterButton({
    required this.selected,
    required this.hasActiveSession,
    required this.onTap,
  });

  final bool selected;
  final bool hasActiveSession;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Trening',
      hint: hasActiveSession ? 'Trwa sesja — wróć do treningu' : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            key: const Key('app-bottom-nav-center'),
            width: AppBottomNav.centerDiameter,
            height: AppBottomNav.centerDiameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              border: selected
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                const Center(
                  child: Icon(
                    Icons.fitness_center_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                if (hasActiveSession)
                  Positioned(
                    top: 1,
                    right: 1,
                    child: Container(
                      key: const Key('app-bottom-nav-active-dot'),
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success,
                        border: Border.all(
                          color: AppColors.background,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryVariant : AppColors.textSecondary;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: () => onTap(index),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryVariant.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  selected ? selectedIcon : icon,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterLabelSlot extends StatelessWidget {
  const _CenterLabelSlot({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? AppColors.primaryVariant
                      : AppColors.textSecondary,
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotchedBarPainter extends CustomPainter {
  const _NotchedBarPainter({
    required this.notchDepth,
    required this.notchMargin,
  });

  final double notchDepth;
  final double notchMargin;

  Path _topEdge(Size size) {
    final centerX = size.width / 2;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(centerX - notchMargin, 0)
      ..cubicTo(
        centerX - notchMargin + 8,
        0,
        centerX - 14,
        notchDepth,
        centerX,
        notchDepth,
      )
      ..cubicTo(
        centerX + 14,
        notchDepth,
        centerX + notchMargin - 8,
        0,
        centerX + notchMargin,
        0,
      )
      ..lineTo(size.width, 0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final edge = _topEdge(size);
    final fill = Path.from(edge)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = AppColors.surface);
    canvas.drawPath(
      edge,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_NotchedBarPainter oldDelegate) =>
      oldDelegate.notchDepth != notchDepth ||
      oldDelegate.notchMargin != notchMargin;
}
```

- [ ] **Step 4: Run — użytkownik uruchamia**

Run: `cd gym-flutter; flutter test test/app_bottom_nav_test.dart`
Expected: PASS (5 testów).

- [ ] **Step 5: Commit**

```bash
git add lib/core/navigation/app_bottom_nav.dart test/app_bottom_nav_test.dart
git commit -m "feat(navigation): add notched AppBottomNav widget"
```

---

### Task 3: Współdzielony TrainingSessionCubit na poziomie shella

`TrainingScreen` i `PlansScreen` przestają tworzyć własne instancje — jedna instancja w builderze shella. Wszyscy konsumenci w subtree branchy (`training_screen.dart`, `training_session_tab.dart`, `training_plans_tab.dart`) rozwiążą ją przez kontekst; ekrany na root navigatorze mają własne providery lub dostają cubit przez args (bez zmian).

**Files:**
- Modify: `lib/core/navigation/app_router.dart:83-88` (builder shella)
- Modify: `lib/features/training/presentation/screens/training_screen.dart:17-30`
- Modify: `lib/features/training/presentation/screens/plans_screen.dart:17-31`

- [ ] **Step 1: Shell builder owija AppShell w BlocProvider**

W `lib/core/navigation/app_router.dart` podmień builder `StatefulShellRoute.indexedStack`:

```dart
        builder: (context, state, navigationShell) {
          final user = ServiceLocator.currentUser.value;
          if (user == null) return const _LoadingScreen();
          return BlocProvider(
            create: (_) =>
                TrainingSessionCubit(ServiceLocator.trainingSessionRepository),
            child: AppShell(navigationShell: navigationShell, user: user),
          );
        },
```

Dodaj import:

```dart
import '../../features/training/presentation/bloc/training_session_cubit.dart';
```

- [ ] **Step 2: TrainingScreen bez lokalnego TrainingSessionCubit**

W `training_screen.dart` podmień `build` `TrainingScreen`:

```dart
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          TrainingPlansCubit(ServiceLocator.trainingPlanRepository),
      child: const _TrainingShellContent(),
    );
  }
```

Usuń nieużywany już import `flutter_bloc`? — nie, dalej potrzebny (`BlocProvider`, `BlocBuilder`, `context.read`). Import `training_session_cubit.dart` zostaje (listener i `BlocBuilder` go używają).

- [ ] **Step 3: PlansScreen bez lokalnego TrainingSessionCubit**

W `plans_screen.dart` podmień `build` `PlansScreen`:

```dart
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          TrainingPlansCubit(ServiceLocator.trainingPlanRepository),
      child: const _PlansScreenContent(),
    );
  }
```

Usuń import `../bloc/training_session_cubit.dart` z tego pliku.

- [ ] **Step 4: Run — użytkownik uruchamia**

Run: `cd gym-flutter; flutter test`
Expected: PASS (istniejące testy; seam z Task 1 pokrywa router).

- [ ] **Step 5: Commit**

```bash
git add lib/core/navigation/app_router.dart lib/features/training/presentation/screens/training_screen.dart lib/features/training/presentation/screens/plans_screen.dart
git commit -m "refactor(navigation): share TrainingSessionCubit at shell level"
```

---

### Task 4: TrainingHeader bez ikony Planów

Plany są teraz zakładką — usuwamy wejście do planów z headera Treningu.

**Files:**
- Modify: `test/training_header_test.dart:24-54`
- Modify: `lib/features/training/presentation/widgets/training_header.dart`
- Modify: `lib/features/training/presentation/screens/training_screen.dart:102-104`

- [ ] **Step 1: Zaktualizuj test (TDD — najpierw test)**

W `test/training_header_test.dart` podmień drugi test:

```dart
  testWidgets('shows library button and delegates taps', (tester) async {
    var libraryTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingHeader(
            onLibraryTap: () => libraryTapped = true,
            onAddTap: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.format_list_bulleted_rounded), findsNothing);
    expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu_book_rounded));
    await tester.pump();

    expect(libraryTapped, isTrue);
  });
```

- [ ] **Step 2: Run — użytkownik uruchamia**

Run: `cd gym-flutter; flutter test test/training_header_test.dart`
Expected: FAIL — kompilacja (`onPlansTap` w teardown...) lub asercja `findsNothing` pada (ikona dalej renderowana).

- [ ] **Step 3: Usuń onPlansTap z TrainingHeader**

W `training_header.dart`:
- usuń z konstruktora `this.onPlansTap,`,
- usuń pole `final VoidCallback? onPlansTap;`,
- usuń blok renderujący:

```dart
        if (onPlansTap != null) ...[
          HeaderIconButton(
            tooltip: 'Plany treningowe',
            icon: Icons.format_list_bulleted_rounded,
            onTap: onPlansTap!,
          ),
          const SizedBox(width: 10),
        ],
```

- [ ] **Step 4: Usuń przekazanie onPlansTap w TrainingScreen**

W `training_screen.dart` usuń:

```dart
                    onPlansTap: () {
                      context.push('/app/training/plans');
                    },
```

- [ ] **Step 5: Run — użytkownik uruchamia**

Run: `cd gym-flutter; flutter test test/training_header_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/training/presentation/widgets/training_header.dart lib/features/training/presentation/screens/training_screen.dart test/training_header_test.dart
git commit -m "feat(navigation): drop plans entry from training header"
```

---

### Task 5: Routing — nowa kolejność branchy, /app/plans, koniec Home, AppShell z AppBottomNav

Największy task: przebudowa branchy, PlansScreen jako zakładka, usunięcie feature `home`, podpięcie belki z smart tap.

**Files:**
- Modify: `test/app_router_test.dart` (nowe testy — najpierw)
- Modify: `lib/core/navigation/app_router.dart`
- Modify: `lib/core/navigation/app_shell.dart` (pełna podmiana)
- Modify: `lib/features/training/presentation/screens/plans_screen.dart` (bez Wstecz)
- Modify: `lib/features/auth/presentation/screens/login_form_screen.dart:63`
- Modify: `lib/features/auth/presentation/screens/register_screen.dart:94`
- Delete: `lib/features/home/`

- [ ] **Step 1: Nowe testy routera (TDD — najpierw testy)**

Do `test/app_router_test.dart` (wewnątrz `main()`, po istniejących testach) dodaj:

```dart
  testWidgets('redirects legacy /app/training/plans to /app/plans', (
    tester,
  ) async {
    await setDesktopViewport(tester);

    final user = AuthUser(
      id: 'user-1',
      email: 'test@example.com',
      firstName: 'Test',
      lastName: 'User',
    );
    ServiceLocator.currentUser.value = user;

    final router = buildRouter(
      initialLocation: '/app/training/plans',
      resolveUser: () async => user,
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(router.routeInformationProvider.value.uri.path, '/app/plans');
    expect(find.text('Plany treningowe'), findsOneWidget);
  });

  testWidgets('shows bottom nav destinations and navigates on tap', (
    tester,
  ) async {
    await setDesktopViewport(tester);

    final user = AuthUser(
      id: 'user-1',
      email: 'test@example.com',
      firstName: 'Test',
      lastName: 'User',
    );
    ServiceLocator.currentUser.value = user;

    final router = buildRouter(
      initialLocation: '/app/training',
      resolveUser: () async => user,
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Historia'), findsOneWidget);
    expect(find.text('Plany'), findsWidgets);
    expect(find.text('Aktywność'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);

    await tester.tap(find.text('Historia'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(router.routeInformationProvider.value.uri.path, '/app/history');

    await tester.tap(find.text('Plany').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(router.routeInformationProvider.value.uri.path, '/app/plans');
  });

  testWidgets('center tap without active session switches to training branch',
      (tester) async {
    await setDesktopViewport(tester);

    final user = AuthUser(
      id: 'user-1',
      email: 'test@example.com',
      firstName: 'Test',
      lastName: 'User',
    );
    ServiceLocator.currentUser.value = user;

    final router = buildRouter(
      initialLocation: '/app/history',
      resolveUser: () async => user,
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('app-bottom-nav-center')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(router.routeInformationProvider.value.uri.path, '/app/training');
  });

  testWidgets('center tap with active session opens ongoing workout', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await setDesktopViewport(tester);

    final user = AuthUser(
      id: 'user-1',
      email: 'test@example.com',
      firstName: 'Test',
      lastName: 'User',
    );
    ServiceLocator.currentUser.value = user;
    ServiceLocator.debugSetUserScopedRepositories(
      trainingPlanRepository: _FakeTrainingPlanRepository(),
      trainingHistoryRepository: _FakeTrainingHistoryRepository(),
      trainingSessionRepository: _FakeTrainingSessionRepository(
        active: TrainingSession(
          planName: 'Push',
          startedAt: DateTime.now().toUtc(),
          exercises: const [],
        ),
      ),
    );

    final router = buildRouter(
      initialLocation: '/app/history',
      resolveUser: () async => user,
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('app-bottom-nav-active-dot')), findsOneWidget);

    await tester.tap(find.byKey(const Key('app-bottom-nav-center')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Dodaj pierwsze ćwiczenie'), findsOneWidget);
  });
```

Dodatkowe importy w tym pliku:

```dart
import 'package:shared_preferences/shared_preferences.dart';
```

Uwaga do testu „shows bottom nav…": `find.text('Plany')` może trafić więcej niż raz (etykieta nav + tytuły na ekranach), dlatego `findsWidgets` i tap na `.last` (etykieta belki jest później w drzewie). Jeśli okaże się odwrotnie, zamienić na `.first`.

- [ ] **Step 2: Run — użytkownik uruchamia**

Run: `cd gym-flutter; flutter test test/app_router_test.dart`
Expected: FAIL — nowe testy padają (stary router/belka).

- [ ] **Step 3: Podmień AppShell**

Cała zawartość `lib/core/navigation/app_shell.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/models/auth_models.dart';
import '../../features/training/presentation/bloc/training_session_cubit.dart';
import '../../features/training/presentation/screens/ongoing_workout_screen.dart';
import '../theme/app_colors.dart';
import 'app_bottom_nav.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.user,
  });

  /// Branch index of the center "Trening" tab.
  static const int trainingBranchIndex = 2;

  final StatefulNavigationShell navigationShell;
  final AuthUser user;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  void _handleCenterTap(
    BuildContext context,
    TrainingSessionState sessionState,
  ) {
    final active = sessionState.activeSession;
    if (active == null) {
      _onDestinationSelected(trainingBranchIndex);
      return;
    }
    final cubit = context.read<TrainingSessionCubit>();
    context
        .push(
          '/app/training/ongoing-workout',
          extra: OngoingWorkoutArgs(
            initialSession: active,
            sessionCubit: cubit,
          ),
        )
        .then((_) => cubit.refresh());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: navigationShell,
      bottomNavigationBar:
          BlocBuilder<TrainingSessionCubit, TrainingSessionState>(
        builder: (context, sessionState) {
          return AppBottomNav(
            currentIndex: navigationShell.currentIndex,
            hasActiveSession: sessionState.activeSession != null,
            onDestinationSelected: _onDestinationSelected,
            onCenterTap: () => _handleCenterTap(context, sessionState),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Branchy w app_router.dart**

a) Usuń import:

```dart
import '../../features/home/presentation/screens/home_screen.dart';
```

b) Podmień całą listę `branches: [` — nowa kolejność (Historia, Plany, Trening, Aktywność, Profil):

```dart
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/history',
                builder: (_, s) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/plans',
                builder: (_, s) => const PlansScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/training',
                builder: (_, s) => const TrainingScreen(),
                routes: [
                  GoRoute(
                    parentNavigatorKey: appRootNavigatorKey,
                    name: 'pick-activity-type',
                    path: 'pick-activity-type',
                    builder: (_, s) => const ActivityTypeSelectionScreen(),
                  ),
                  GoRoute(
                    parentNavigatorKey: appRootNavigatorKey,
                    name: 'ongoing-workout',
                    path: 'ongoing-workout',
                    builder: (_, s) {
                      final args = s.extra as OngoingWorkoutArgs?;
                      return OngoingWorkoutScreen(args: args);
                    },
                  ),
                  GoRoute(
                    parentNavigatorKey: appRootNavigatorKey,
                    name: 'pick-training-plan',
                    path: 'pick-plan',
                    builder: (_, s) => const PickTrainingPlanScreen(),
                  ),
                  GoRoute(
                    name: 'training-plans',
                    path: 'plans',
                    redirect: (_, __) => '/app/plans',
                  ),
                  GoRoute(
                    parentNavigatorKey: appRootNavigatorKey,
                    name: 'training-library',
                    path: 'library',
                    builder: (_, s) => const LibraryScreen(),
                  ),
                  GoRoute(
                    parentNavigatorKey: appRootNavigatorKey,
                    name: 'create-plan',
                    path: 'create-plan',
                    builder: (context, state) {
                      final args = state.extra as CreatePlanArgs;
                      return BlocProvider.value(
                        value: args.cubit,
                        child: CreatePlanScreen(
                          existingPlan: args.existingPlan,
                          initialSelectedDays: args.initialSelectedDays,
                        ),
                      );
                    },
                    routes: [
                      GoRoute(
                        parentNavigatorKey: appRootNavigatorKey,
                        name: 'pick-exercise-for-plan',
                        path: 'pick-exercise',
                        builder: (_, s) => const PickExerciseScreen(),
                      ),
                    ],
                  ),
                  GoRoute(
                    parentNavigatorKey: appRootNavigatorKey,
                    name: 'plan-details',
                    path: 'plan-details',
                    builder: (context, state) {
                      final args = state.extra as PlanDetailsArgs;
                      return PlanDetailsScreen(args: args);
                    },
                  ),
                  GoRoute(
                    parentNavigatorKey: appRootNavigatorKey,
                    name: 'training-stats',
                    path: 'stats',
                    builder: (_, s) => const TrainingStatsScreen(),
                  ),
                  GoRoute(
                    parentNavigatorKey: appRootNavigatorKey,
                    name: 'training-session-details',
                    path: 'history/:sessionId',
                    builder: (context, state) {
                      final sessionId = state.pathParameters['sessionId']!;
                      return TrainingSessionDetailsScreen(
                        sessionId: sessionId,
                        repository: ServiceLocator.trainingHistoryRepository,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/activity',
                builder: (_, s) => const ActivityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/profile',
                builder: (_, s) {
                  final user = ServiceLocator.currentUser.value;
                  if (user == null) return const _LoadingScreen();
                  return BlocProvider(
                    create: (_) =>
                        ProfileCubit(_profileRepositoryForCurrentUser()),
                    child: const ProfileScreen(),
                  );
                },
                routes: [
                  GoRoute(
                    parentNavigatorKey: appRootNavigatorKey,
                    path: 'settings',
                    builder: (_, s) {
                      final user = ServiceLocator.currentUser.value;
                      if (user == null) return const _LoadingScreen();
                      return ProfileSettingsScreen(user: user);
                    },
                  ),
                  GoRoute(
                    parentNavigatorKey: appRootNavigatorKey,
                    path: 'following',
                    builder: (_, s) => FollowingListScreen(
                      repository: _profileRepositoryForCurrentUser(),
                    ),
                  ),
                  GoRoute(
                    parentNavigatorKey: appRootNavigatorKey,
                    path: 'followers',
                    builder: (_, s) => FollowersListScreen(
                      repository: _profileRepositoryForCurrentUser(),
                    ),
                  ),
                  GoRoute(
                    parentNavigatorKey: appRootNavigatorKey,
                    path: 'find-people',
                    builder: (_, s) => FindPeopleScreen(
                      repository: _profileRepositoryForCurrentUser(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
```

c) W `_SplashRouteState._resolve` podmień redirect:

```dart
      context.go('/app/training');
```

- [ ] **Step 5: Redirecty w auth**

`lib/features/auth/presentation/screens/login_form_screen.dart:63` i `register_screen.dart:94`:

```dart
      context.go('/app/training');
```

- [ ] **Step 6: PlansScreen jako zakładka (bez Wstecz)**

W `plans_screen.dart` usuń metodę `_handleBack` oraz z `Row` usuń:

```dart
                  HeaderIconButton(
                    tooltip: 'Wstecz',
                    icon: Icons.arrow_back_rounded,
                    onTap: () => _handleBack(context),
                  ),
                  const SizedBox(width: 14),
```

Usuń też nieużywany import `package:go_router/go_router.dart`? — nie, `context.push` do create-plan zostaje.

- [ ] **Step 7: Usuń feature home**

```powershell
Remove-Item -Recurse -Force "lib/features/home"
```

(run: agent może wykonać przez narzędzie Delete na plikach katalogu)

- [ ] **Step 8: Run — użytkownik uruchamia**

Run: `cd gym-flutter; flutter test`
Expected: PASS (cała suita, w tym nowe testy routera i belki).

- [ ] **Step 9: Commit**

```bash
git add lib/core/navigation lib/features/training/presentation/screens/plans_screen.dart lib/features/auth lib/features/home test/app_router_test.dart
git commit -m "feat(navigation): rebuild bottom nav with center Trening button"
```

---

### Task 6: Aktualizacja PROJECT_CONTEXT.md

Workspace root nie jest repo — edycja bez commita.

**Files:**
- Modify: `PROJECT_CONTEXT.md` (workspace root)

- [ ] **Step 1: Sekcja 4.2 — struktura nawigacji i features**

Podmień w `PROJECT_CONTEXT.md`:

- `│   │   ├── app_router.dart         <- go_router + redirect auth` — bez zmian
- `│   │   └── app_shell.dart          <- bottom nav: Główna/Trening/Aktywność/Historia/Profil`

na:

```
│   │   ├── app_shell.dart          <- shell + współdzielony TrainingSessionCubit, smart środkowy Trening
│   │   └── app_bottom_nav.dart     <- custom belka z notchem: Historia/Plany/[Trening]/Aktywność/Profil
```

oraz usuń linię `│   ├── home/       <- dashboard (GŁÓWNIE MOCKI)`.

- [ ] **Step 2: Sekcja 4.3 — tabela routingu**

- Usuń wiersz `| /app/home | HomeScreen |`.
- Dodaj wiersz `| /app/plans | PlansScreen (zakładka Plany) |`.
- Wiersz `/app/training`: zmień opis na `ekran Sesji bez zakładek (nagłówek: ikony Biblioteka/Dodaj; Plany przeniesione do własnej zakładki); /app/training/plans -> redirect /app/plans`.
- Wiersz `/splash`: zmień na `rozwiązanie sesji -> training lub login`.

- [ ] **Step 3: Sekcja 7 — mocki**

Zmień `Home i Activity (dashboardy) — dane zaszyte na sztywno (tylko trening siłowy),` na `Activity (dashboard) — dane zaszyte na sztywno (tylko trening siłowy),`.

- [ ] **Step 4: Weryfikacja końcowa — użytkownik uruchamia**

Run: `cd gym-flutter; flutter analyze; flutter test; flutter run`
Expected: analyze bez nowych warnings, testy PASS, aplikacja startuje na Treningu z nową belką; tap środkowego bez sesji → Trening, z sesją → ongoing workout; Plany jako zakładka bez przycisku Wstecz; `/app/home` nie istnieje.

---

## Self-Review

**Spec coverage:**

| Wymaganie ze speca | Task |
|---|---|
| Branchy Historia/Plany/Trening/Aktywność/Profil, usunięcie Home | Task 5 |
| Nowy branch /app/plans, redirect /app/training/plans | Task 5 |
| Splash/login/register → /app/training | Task 5 |
| Shell-level BlocProvider<TrainingSessionCubit> | Task 3 |
| AppBottomNav (notch, wymiary, ikony, stany, kropka) | Task 2 |
| AppShell: BlocBuilder + smart tap + goBranch | Task 5 (Step 3) |
| TrainingScreen/PlansScreen bez lokalnego session cubita | Task 3 |
| TrainingHeader bez onPlansTap | Task 4 |
| PlansScreen bez Wstecz | Task 5 (Step 6) |
| Usunięcie lib/features/home | Task 5 (Step 7) |
| Testy: widget belki, router, header | Tasks 1, 2, 4, 5 |
| PROJECT_CONTEXT.md | Task 6 |

**Placeholder scan:** brak TBD/TODO; cały kod kroków jest kompletny.

**Type consistency:**
- `AppBottomNav(currentIndex, hasActiveSession, onDestinationSelected, onCenterTap)` — zgodne w Task 2 (impl), Task 2 (test) i Task 5 (użycie w AppShell).
- Klucze: `app-bottom-nav-center`, `app-bottom-nav-active-dot` — zgodne impl ↔ testy.
- `AppShell.trainingBranchIndex = 2` — zgodne z kolejnością branchy (Historia 0, Plany 1, Trening 2, Aktywność 3, Profil 4).
- `_FakeTrainingSessionRepository({this.active})` — używany w setUp bez `active` oraz w teście smart tap z `active:`.
- `debugSetUserScopedRepositories` — nazwa zgodna w ServiceLocator (Task 1) i testach (Tasks 1, 5).
- `TrainingSession(planName:, startedAt:, exercises: const [])` — sygnatura jak w `ongoing_workout_screen_test.dart`.
