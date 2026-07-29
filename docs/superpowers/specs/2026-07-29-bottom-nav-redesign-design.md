# Przebudowa dolnej nawigacji — specyfikacja

> Data: 2026-07-29
> Status: zatwierdzona przez użytkownika (brainstorming + makiety)
> Zakres: `gym-flutter` (Flutter, go_router, flutter_bloc)

## 1. Cel

Nowa dolna nawigacja z centralnie wyeksponowanym przyciskiem **Trening**:

```
Historia · Plany · ( TRENING ) · Aktywność · Profil
```

- Środek: duży, okrągły przycisk **Trening** wpuszczony w belkę (dock z wcięciem — wariant A z makiety).
- Lewa strona: **Historia**, **Plany** (Plany stają się zakładką — rezygnujemy z wejścia do planów przez ekran Trening).
- Prawa strona: **Aktywność**, **Profil** (normalne, mniejsze pozycje).
- Zakładka **Główna** (Home) znika z aplikacji; po zalogowaniu lądujemy na **Treningu**.

## 2. Decyzje produktowe (z brainstormingu)

| Temat | Decyzja |
|-------|---------|
| Ekran Home (`/app/home`) | Usuwany całkowicie (był głównie mockiem); start aplikacji na `/app/training` |
| Środkowy przycisk | „Inteligentny": trwa sesja → otwiera trwający trening; brak sesji → zakładka Trening |
| Wariant wizualny | A — dock z wcięciem (notch), jak BottomAppBar + FAB, rysowany custom |
| Stan „Trening wybrany" | Biały ring 2 px na kole + etykieta „Trening" niebieska (`primaryVariant`), pogrubiona |
| Wskaźnik trwającej sesji | Zielona kropka w prawym górnym rogu koła (opcja 1 z makiety) |
| Podejście implementacyjne | 1 — własny widget `AppBottomNav` (Stack + CustomPainter), współdzielony `TrainingSessionCubit` na poziomie shella; zero nowych zależności |

Makiety źródłowe: `.superpowers/brainstorm/bottom-nav-001/content/` (workspace root; katalog `.superpowers/` nie jest w repo).

## 3. Routing (`lib/core/navigation/app_router.dart`)

Nowa kolejność branchy `StatefulShellRoute.indexedStack`:

| Index | Branch | Ścieżka root |
|-------|--------|--------------|
| 0 | Historia | `/app/history` |
| 1 | Plany | `/app/plans` → `PlansScreen` |
| 2 | Trening | `/app/training` → `TrainingScreen` |
| 3 | Aktywność | `/app/activity` |
| 4 | Profil | `/app/profile` (+ nested) |

Zmiany:

- **Usunięty branch Home** (`/app/home`) wraz z importem `HomeScreen`.
- **Nowy branch Plany**: `GoRoute(path: '/app/plans')` → `PlansScreen` (bez nested — szczegóły/tworzenie planu zostają pushami na root navigatorze).
- Pod `/app/training`: trasa `plans` (name `training-plans`) zamieniana na **redirect** `/app/training/plans` → `/app/plans` (ochrona przed starymi linkami). Pozostałe nested bez zmian: `pick-activity-type`, `ongoing-workout`, `pick-plan`, `library`, `create-plan` (+ `pick-exercise`), `plan-details`, `stats`, `history/:sessionId`.
- **Redirecty startowe**: `_SplashRoute`, `login_form_screen.dart`, `register_screen.dart` — `context.go('/app/home')` → `context.go('/app/training')`.
- Builder shella owija `AppShell` w `BlocProvider<TrainingSessionCubit>` (`create` z `ServiceLocator.trainingSessionRepository`, `autoRefresh: true`) — jedna współdzielona instancja na całą sesję użytkownika.

## 4. Współdzielony `TrainingSessionCubit`

Dziś cubit jest tworzony osobno w `TrainingScreen` i `PlansScreen`. Przenosimy go na poziom shella:

- `TrainingScreen` i `PlansScreen` **nie tworzą** własnych instancji — korzystają z cubitu z kontekstu (powyżej branchy).
- `TrainingPlansCubit` zostaje lokalny w obu ekranach (jest przekazywany przez `CreatePlanArgs.extra` — wzorzec bez zmian).
- Listener zmian tras w `_TrainingShellContentState` refreshuje współdzielony cubit po powrocie na `/app/training` — bez zmian w logice.
- Po powrocie z `ongoing-workout` (push z belki lub z headera) — `cubit.refresh()` (istniejący wzorzec z `.then`).

Efekt: zielona kropka w belki i banner „Trwa" w headerze zawsze pokazują ten sam stan; zakończenie/anulowanie sesji natychmiast aktualizuje belkę.

## 5. Widget `AppBottomNav` (nowy, `lib/core/navigation/`)

Zastępuje `NavigationBar` w `AppShell`. Własny widget, brak nowych zależności.

**Struktura:**

- `Stack`:
  - tło belki: wysokość ~64 dp + `SafeArea` (bottom), kolor `AppColors.surface`, na górze divider 1 px `AppColors.border` (jak dziś),
  - `CustomPaint` rysujący wcięcie (łuk) na środku górnej krawędzi belki — promień dopasowany do koła (notch ~62–64 dp szerokości, głębokość ~28–30 dp),
  - koło **56 dp** pozycjonowane `translate(-50%, -50%)` względem środka górnej krawędzi: `AppColors.primary`, ikona `Icons.fitness_center_rounded` biała ~24 dp, cień `BoxShadow` (primary, alpha ~0.45),
  - `Row` z 5 slotami: Historia / Plany / slot środkowy / Aktywność / Profil; slot środkowy zawiera tylko etykietę „Trening" przy dolnej krawędzi belki.
- Małe pozycje: jak dotychczas — ikona outline → filled przy selected, pill (primary ~14–18% alpha) za ikoną, etykieta 10–11 sp; kolory: nieaktywna `textSecondary`, aktywna `primaryVariant`.
- Ikony: Historia `Icons.history_outlined`/`history_rounded`, Aktywność `Icons.timeline_outlined`/`timeline_rounded`, Profil `Icons.person_outline_rounded`/`person_rounded`; Plany `Icons.format_list_bulleted_rounded` w obu stanach (brak wariantu outline — selected pokazujemy kolorem i pillem).

**Stany środkowego przycisku:**

| Stan | Wygląd |
|------|--------|
| Domyślny | koło primary, ikona biała, etykieta `textSecondary` |
| Selected (branch Trening) | ring biały 2 px na kole + etykieta `primaryVariant` bold |
| Trwa sesja (niezależnie od selected) | zielona kropka ~12 dp (`AppColors.success`) w prawym górnym rogu koła, z obwódką ~3 px w kolorze tła ekranu |

**Zachowanie tapnięć:**

- Małe pozycje: `navigationShell.goBranch(index, initialLocation: index == currentIndex)` — jak dziś.
- Środkowy (smart): `BlocBuilder<TrainingSessionCubit, TrainingSessionState>` wokół belki;
  - `activeSession != null` → `context.push('/app/training/ongoing-workout', extra: OngoingWorkoutArgs(initialSession: active, sessionCubit: cubit))`, po powrocie `cubit.refresh()`;
  - `activeSession == null` → `goBranch(2)` (z `initialLocation` gdy już na Treningu).
- Accessibility: każdy slot `Semantics(button: true, selected: ...)`, środkowy z label „Trening" i hintem „Trwa sesja — wróć do treningu" gdy aktywna; tap target min. 48 dp.

`AppShell` pozostaje `StatelessWidget` — stan sesji wyłącznie przez `BlocBuilder`, brak lokalnego state'u nawigacji poza `navigationShell`.

## 6. Zmiany w ekranach

**`TrainingScreen`** — z `MultiBlocProvider` znika `TrainingSessionCubit` (współdzielony); zostaje lokalny `TrainingPlansCubit`. `onPlansTap` przestaje być przekazywane.

**`TrainingHeader`** — usunięty parametr `onPlansTap` i render ikony Planów. Zostają: banner aktywnej sesji, Biblioteka (`onLibraryTap`), Dodaj (`onAddTap`).

**`PlansScreen`** (teraz zakładka):
- znika przycisk „Wstecz" i metoda `_handleBack` (root tab nie ma dokąd wracać),
- z `MultiBlocProvider` znika `TrainingSessionCubit` (współdzielony); `TrainingPlansCubit` zostaje,
- tytuł „Plany treningowe" + akcentowy przycisk „Utwórz plan" (push `/app/training/create-plan` z `CreatePlanArgs(cubit: context.read<TrainingPlansCubit>())`) — bez zmian,
- body `TrainingPlansTab` — bez zmian.

**Usunięcie Home:** katalog `lib/features/home/` do skasowania (same mocki, po zmianach martwy kod).

## 7. Testy

- Istniejące testy routingu/shella w `test/`: aktualizacja (5 branchy w nowej kolejności, brak `/app/home`, splash/login/register → `/app/training`, redirect `/app/training/plans` → `/app/plans`).
- Nowe testy widgetu `AppBottomNav`:
  - render 5 pozycji z etykietami, poprawna kolejność,
  - stan selected małej pozycji i środkowego przycisku (ring + etykieta),
  - smart tap: z aktywną sesją pushuje ongoing-workout; bez sesji przełącza branch,
  - zielona kropka widoczna tylko przy aktywnej sesji.
- Testy `PlansScreen`/`TrainingScreen`: dopasowanie do braku lokalnych `TrainingSessionCubit` (podpięcie współdzielonego w testach).

## 8. Dokumentacja

- `PROJECT_CONTEXT.md` (workspace root): sekcja 4.2 (opis `app_shell.dart` — nowa belka i pozycje), 4.3 (tabela routingu: `/app/plans`, brak `/app/home`, start na `/app/training`), data w nagłówku.
- Zgodnie z regułą `.cursor/rules/project-context.mdc` aktualizacja w tym samym PR co zmiana.

## 9. Poza zakresem

- Zmiany w backendzie (brak).
- Przenoszenie nested routes planów pod `/app/plans` (zostają pod `/app/training` jako pushy na root navigatorze) — ewentualny przyszły cleanup.
- Animacje przejść między zakładkami, pulsowanie zielonej kropki (opcjonalny polish, nie blokuje).
- Nowe funkcje ekranu Plany (np. przypisywanie dni tygodnia) — bez zmian funkcjonalnych, tylko relokacja.
