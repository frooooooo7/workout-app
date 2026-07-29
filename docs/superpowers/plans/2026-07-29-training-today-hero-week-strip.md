# Training Today Hero + Week Strip Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Przebudować sekcję „Na dziś” na ekranie Trening: koło statusu (hero) + poziomy pasek 7 dni z mockupu; usunąć segmentowany dial.

**Architecture:** `TrainingTodayPlanSection` orkiestruje dwa prezentacyjne widgety: `TrainingDayHero` (treść rest/trening + tap) oraz `TrainingWeekStrip` (wybór dnia). Model `selectedDay` (weekday 1–7) i callbacki parenta bez zmian. `onStartPlan` zostaje w API sekcji, ale hero go nie wywołuje.

**Tech Stack:** Flutter, flutter_test, istniejące `AppColors`, asset `assets/images/monk_rest.png`.

**Spec:** `docs/superpowers/specs/2026-07-29-training-today-hero-week-strip-design.md`

**Uwaga o komendach:** zgodnie z `PROJECT_CONTEXT.md` komendy Flutter/Dart uruchamia **użytkownik**. Kroki „Run" opisują komendę i oczekiwany wynik — agent ich nie wykonuje.

**Stan working tree (przed startem):** w WIP jest usunięty stary `training_week_strip.dart`, dodany `training_day_dial.dart` i zmodyfikowana sekcja/testy pod dial. Ten plan **zastępuje** dial hero+stripem. Na starcie Task 1 upewnij się, że budujesz pod ten spec (nie zostawiaj diala w finalnym UI).

---

## File Structure

| Plik | Odpowiedzialność |
|------|------------------|
| Create: `lib/features/training/presentation/widgets/training_day_status.dart` | Czyste helpery: etykieta dnia, porównanie dat (testowalne bez widgetów) |
| Create: `lib/features/training/presentation/widgets/training_day_hero.dart` | Koło statusu (rest / trening / loading) |
| Create: `lib/features/training/presentation/widgets/training_week_strip.dart` | 7 kart bieżącego tygodnia + wskaźniki ✓ / kropka / ramka |
| Modify: `lib/features/training/presentation/widgets/training_today_plan_section.dart` | Orkiestracja hero + strip; usunięcie diala i nazwy dnia pod spodem |
| Delete: `lib/features/training/presentation/widgets/training_day_dial.dart` | Segmentowany ring — poza zakresem nowego UI |
| Keep/add: `assets/images/monk_rest.png` | Ikona rest (już w `pubspec.yaml` → `assets/images/`) |
| Modify: `test/training_today_plan_section_test.dart` | Asercje pod hero + strip |
| Create: `test/training_day_status_test.dart` | Unit testy helperów etykiety / past-future |
| Create: `test/training_week_strip_test.dart` | Widget testy wskaźników i tapów |
| Parent bez zmian: `training_session_tab.dart` | Nadal przekazuje te same callbacki |

---

### Task 1: Helpery statusu dnia (TDD)

**Files:**
- Create: `lib/features/training/presentation/widgets/training_day_status.dart`
- Create: `test/training_day_status_test.dart`

- [ ] **Step 1: Napisz failing unit testy**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/presentation/widgets/training_day_status.dart';

void main() {
  // Fixed "today": Wednesday 2026-07-29
  final today = DateTime(2026, 7, 29);

  group('trainingDayHeroLabel', () {
    test('returns Na dziś for today', () {
      expect(
        trainingDayHeroLabel(DateTime(2026, 7, 29), today: today),
        'Na dziś',
      );
    });

    test('returns Wczoraj for yesterday', () {
      expect(
        trainingDayHeroLabel(DateTime(2026, 7, 28), today: today),
        'Wczoraj',
      );
    });

    test('returns capitalized weekday name otherwise', () {
      expect(
        trainingDayHeroLabel(DateTime(2026, 7, 30), today: today),
        'Czwartek',
      );
      expect(
        trainingDayHeroLabel(DateTime(2026, 7, 27), today: today),
        'Poniedziałek',
      );
    });
  });

  group('isCalendarDateBefore', () {
    test('true for yesterday, false for today and tomorrow', () {
      expect(isCalendarDateBefore(DateTime(2026, 7, 28), today), isTrue);
      expect(isCalendarDateBefore(DateTime(2026, 7, 29), today), isFalse);
      expect(isCalendarDateBefore(DateTime(2026, 7, 30), today), isFalse);
    });
  });

  group('isCalendarDateAfter', () {
    test('true for tomorrow, false for today and yesterday', () {
      expect(isCalendarDateAfter(DateTime(2026, 7, 30), today), isTrue);
      expect(isCalendarDateAfter(DateTime(2026, 7, 29), today), isFalse);
      expect(isCalendarDateAfter(DateTime(2026, 7, 28), today), isFalse);
    });
  });
}
```

- [ ] **Step 2: Poproś użytkownika o run**

Run: `flutter test test/training_day_status_test.dart`  
Expected: FAIL (library / functions not found)

- [ ] **Step 3: Zaimplementuj helpery**

```dart
// lib/features/training/presentation/widgets/training_day_status.dart
const List<String> kTrainingWeekdayFullNames = [
  'Poniedziałek',
  'Wtorek',
  'Środa',
  'Czwartek',
  'Piątek',
  'Sobota',
  'Niedziela',
];

const List<String> kTrainingWeekdayShortLabels = [
  'Pon',
  'Wt',
  'Śr',
  'Czw',
  'Pt',
  'Sob',
  'Ndz',
];

DateTime calendarDateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isCalendarDateBefore(DateTime date, DateTime today) =>
    calendarDateOnly(date).isBefore(calendarDateOnly(today));

bool isCalendarDateAfter(DateTime date, DateTime today) =>
    calendarDateOnly(date).isAfter(calendarDateOnly(today));

/// [selectedDate] = data karty w bieżącym tygodniu; [today] wstrzykiwalne w testach.
String trainingDayHeroLabel(DateTime selectedDate, {DateTime? today}) {
  final now = calendarDateOnly(today ?? DateTime.now());
  final selected = calendarDateOnly(selectedDate);
  if (selected == now) return 'Na dziś';
  if (selected == now.subtract(const Duration(days: 1))) return 'Wczoraj';
  return kTrainingWeekdayFullNames[selected.weekday - 1];
}

/// Poniedziałek bieżącego tygodnia (date-only) względem [today].
DateTime startOfWeekContaining(DateTime today) {
  final d = calendarDateOnly(today);
  return d.subtract(Duration(days: d.weekday - 1));
}
```

- [ ] **Step 4: Poproś użytkownika o run**

Run: `flutter test test/training_day_status_test.dart`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/training/presentation/widgets/training_day_status.dart test/training_day_status_test.dart
git commit -m "feat(training): add day status label helpers"
```

---

### Task 2: `TrainingWeekStrip` pod mockup

**Files:**
- Create: `lib/features/training/presentation/widgets/training_week_strip.dart`
- Create: `test/training_week_strip_test.dart`

- [ ] **Step 1: Napisz failing widget testy**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/presentation/widgets/training_week_strip.dart';

void main() {
  testWidgets('renders 7 short labels and selects by tap', (tester) async {
    int? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingWeekStrip(
            selectedDay: 3,
            today: DateTime(2026, 7, 29), // Środa
            onDaySelected: (day) => selected = day,
          ),
        ),
      ),
    );

    expect(find.text('Pon'), findsOneWidget);
    expect(find.text('Śr'), findsOneWidget);
    expect(find.text('Ndz'), findsOneWidget);
    expect(find.text('29'), findsOneWidget); // dziś

    await tester.tap(find.text('Czw'));
    await tester.pump();
    expect(selected, 4);
  });

  testWidgets('past days show check, future show grey marker key', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingWeekStrip(
            selectedDay: 3,
            today: DateTime(2026, 7, 29),
            onDaySelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('week-indicator-1-past')), findsOneWidget);
    expect(find.byKey(const ValueKey('week-indicator-2-past')), findsOneWidget);
    expect(find.byKey(const ValueKey('week-indicator-3-selected')), findsOneWidget);
    expect(find.byKey(const ValueKey('week-indicator-4-future')), findsOneWidget);
    expect(find.byKey(const ValueKey('week-indicator-7-future')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Poproś użytkownika o run**

Run: `flutter test test/training_week_strip_test.dart`  
Expected: FAIL (widget missing)

- [ ] **Step 3: Zaimplementuj strip zgodny z mockupem**

Wymagania wizualne (nie stary chip-container):

- `Row` z 7 **osobnymi kartami** (`Expanded` + `GestureDetector`), zaokrąglone, tło `AppColors.surfaceVariant` / semi-transparent dark
- Góra: skrót z `kTrainingWeekdayShortLabels`
- Środek: numer dnia z `startOfWeekContaining(today).add(Duration(days: i))`
- Dół wskaźnik:
  - selected → niebieska kropka + niebieska ramka karty (`AppColors.primary`), key `week-indicator-$weekday-selected`
  - past (`isCalendarDateBefore`) → `Icons.check` białe, key `…-past`
  - else (dziś niewybrane lub przyszłość) → szara kropka, key `…-future`
- Parametr `today` opcjonalny (`DateTime? today`) — w produkcji `DateTime.now()`, w testach wstrzyknięty
- **Nie** używaj `workoutDays` do wskaźników (spec: ✓ = przeszłość, kropka = przyszłość)

Szkic API:

```dart
class TrainingWeekStrip extends StatelessWidget {
  const TrainingWeekStrip({
    super.key,
    required this.selectedDay,
    required this.onDaySelected,
    this.today,
  });

  final int selectedDay; // 1–7
  final ValueChanged<int> onDaySelected;
  final DateTime? today;
  // ...
}
```

Karty: wysokość ~64–72, padding pionowy, borderRadius ~12, selected `Border.all(color: AppColors.primary, width: 1.5)`.

- [ ] **Step 4: Poproś użytkownika o run**

Run: `flutter test test/training_week_strip_test.dart`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/training/presentation/widgets/training_week_strip.dart test/training_week_strip_test.dart
git commit -m "feat(training): add week strip with past/future markers"
```

---

### Task 3: `TrainingDayHero`

**Files:**
- Create: `lib/features/training/presentation/widgets/training_day_hero.dart`
- Modify: `test/training_today_plan_section_test.dart` (tymczasowo można dodać osobny `test/training_day_hero_test.dart` — preferowane)

- [ ] **Step 1: Napisz failing testy hero**

Utwórz `test/training_day_hero_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/presentation/widgets/training_day_hero.dart';

void main() {
  testWidgets('rest day shows copy and fires onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingDayHero(
            label: 'Na dziś',
            isLoading: false,
            isRestDay: true,
            title: 'Dzień odpoczynku',
            subtitle: 'Regeneracja to postęp.',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Na dziś'), findsOneWidget);
    expect(find.text('Dzień odpoczynku'), findsOneWidget);
    expect(find.text('Regeneracja to postęp.'), findsOneWidget);
    expect(find.byKey(const ValueKey('monk-rest-icon')), findsOneWidget);

    await tester.tap(find.byType(TrainingDayHero));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('training day shows title, plan name, no monk, fires onTap', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingDayHero(
            label: 'Poniedziałek',
            isLoading: false,
            isRestDay: false,
            title: 'Dzień treningowy',
            subtitle: 'Push Power',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Dzień treningowy'), findsOneWidget);
    expect(find.text('Push Power'), findsOneWidget);
    expect(find.byKey(const ValueKey('monk-rest-icon')), findsNothing);
    expect(find.byKey(const ValueKey('training-day-icon')), findsOneWidget);

    await tester.tap(find.byType(TrainingDayHero));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('loading shows spinner only', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingDayHero(
            label: 'Na dziś',
            isLoading: true,
            isRestDay: true,
            title: '',
            subtitle: '',
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('monk-rest-icon')), findsNothing);
  });
}
```

- [ ] **Step 2: Poproś użytkownika o run**

Run: `flutter test test/training_day_hero_test.dart`  
Expected: FAIL

- [ ] **Step 3: Zaimplementuj hero**

```dart
class TrainingDayHero extends StatelessWidget {
  const TrainingDayHero({
    super.key,
    required this.label,
    required this.isLoading,
    required this.isRestDay,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  static const double diameter = 232;

  final String label;
  final bool isLoading;
  final bool isRestDay;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  // ...
}
```

UI:
- `SizedBox(diameter)` + `DecoratedBox` / `Container` z `BoxDecoration(shape: circle, color: AppColors.surface, border: Border.all(color: primary.withValues(alpha: 0.45), width: 1.5), boxShadow: delikatny glow primary)`
- W środku `Column`: label 13px `textSecondary` → ikona (monk 72–90px / `Icons.fitness_center` key `training-day-icon`) → title 20–22 bold white → subtitle 13 `textSecondary`
- `Semantics(button: true, label: '$title. $subtitle')` + `GestureDetector` / `InkWell` na całe koło
- Loading: tylko spinner, bez tekstów/ikon

Upewnij się, że `assets/images/monk_rest.png` jest w repo (dodaj do gita jeśli nadal untracked).

- [ ] **Step 4: Poproś użytkownika o run**

Run: `flutter test test/training_day_hero_test.dart`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/training/presentation/widgets/training_day_hero.dart test/training_day_hero_test.dart assets/images/monk_rest.png
git commit -m "feat(training): add day status hero circle"
```

---

### Task 4: Orkiestracja w `TrainingTodayPlanSection` + usunięcie diala

**Files:**
- Modify: `lib/features/training/presentation/widgets/training_today_plan_section.dart`
- Delete: `lib/features/training/presentation/widgets/training_day_dial.dart` (jeśli istnieje)
- Modify: `test/training_today_plan_section_test.dart`

- [ ] **Step 1: Przepis failujące / zaktualizowane testy sekcji**

Zastąp zawartość `test/training_today_plan_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/presentation/widgets/training_today_plan_section.dart';
import 'package:gym/features/training/presentation/widgets/training_week_strip.dart';

void main() {
  CustomTrainingPlan plan(
    String name,
    List<int> days, {
    int exercisesCount = 1,
  }) {
    return CustomTrainingPlan(
      name: name,
      selectedDays: days,
      exercises: [
        for (var i = 0; i < exercisesCount; i++)
          PlanExercise(exercise: mockExercises[i]),
      ],
    );
  }

  testWidgets('rest day: copy, monk, create-plan on tap', (tester) async {
    int? requestedDay;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingTodayPlanSection(
            selectedDay: 2,
            plans: [plan('Push Power', const [1])],
            isLoading: false,
            onDaySelected: (_) {},
            onOpenPlan: (_) {},
            onStartPlan: (_) async {},
            onCreatePlanForDay: (day) => requestedDay = day,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('monk-rest-icon')), findsOneWidget);
    expect(find.text('Dzień odpoczynku'), findsOneWidget);
    expect(find.text('Regeneracja to postęp.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('monk-rest-icon')));
    await tester.pump();
    expect(requestedDay, 2);
  });

  testWidgets('training day: opens plan on tap, no play button', (tester) async {
    final scheduled = plan('Push Power', const [1, 3]);
    CustomTrainingPlan? opened;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingTodayPlanSection(
            selectedDay: 1,
            plans: [scheduled],
            isLoading: false,
            onDaySelected: (_) {},
            onOpenPlan: (p) => opened = p,
            onStartPlan: (_) async {},
            onCreatePlanForDay: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Dzień treningowy'), findsOneWidget);
    expect(find.text('Push Power'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);

    await tester.tap(find.text('Dzień treningowy'));
    await tester.pump();
    expect(opened, same(scheduled));
  });

  testWidgets('summarizes additional plans with +N', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingTodayPlanSection(
            selectedDay: 1,
            plans: [
              plan('Push Power', const [1]),
              plan('Pull Volume', const [1, 3]),
            ],
            isLoading: false,
            onDaySelected: (_) {},
            onOpenPlan: (_) {},
            onStartPlan: (_) async {},
            onCreatePlanForDay: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Push Power +1'), findsOneWidget);
  });

  testWidgets('selects day from week strip', (tester) async {
    int? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingTodayPlanSection(
            selectedDay: 2,
            plans: const [],
            isLoading: false,
            onDaySelected: (day) => selected = day,
            onOpenPlan: (_) {},
            onStartPlan: (_) async {},
            onCreatePlanForDay: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(TrainingWeekStrip), findsOneWidget);
    await tester.tap(find.text('Czw'));
    await tester.pump();
    expect(selected, 4);
  });

  testWidgets('shows loader while plans load', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingTodayPlanSection(
            selectedDay: 3,
            plans: const [],
            isLoading: true,
            onDaySelected: (_) {},
            onOpenPlan: (_) {},
            onStartPlan: (_) async {},
            onCreatePlanForDay: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('monk-rest-icon')), findsNothing);
  });
}
```

- [ ] **Step 2: Poproś użytkownika o run**

Run: `flutter test test/training_today_plan_section_test.dart`  
Expected: FAIL względem starego dial UI

- [ ] **Step 3: Przepisz `TrainingTodayPlanSection`**

Zachowaj **tę samą** sygnaturę konstruktora (w tym `onStartPlan`).

```dart
@override
Widget build(BuildContext context) {
  final scheduledPlans = plans
      .where((plan) => plan.selectedDays.contains(selectedDay))
      .toList();
  final scheduledPlan = scheduledPlans.isEmpty ? null : scheduledPlans.first;
  final today = DateTime.now();
  final selectedDate =
      startOfWeekContaining(today).add(Duration(days: selectedDay - 1));
  final isRest = scheduledPlan == null;
  final subtitle = isRest
      ? 'Regeneracja to postęp.'
      : '${scheduledPlan.name}${scheduledPlans.length > 1 ? ' +${scheduledPlans.length - 1}' : ''}';

  return Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      TrainingDayHero(
        label: trainingDayHeroLabel(selectedDate, today: today),
        isLoading: isLoading,
        isRestDay: isRest,
        title: isRest ? 'Dzień odpoczynku' : 'Dzień treningowy',
        subtitle: subtitle,
        onTap: () {
          if (isLoading) return;
          final plan = scheduledPlan;
          if (plan == null) {
            onCreatePlanForDay(selectedDay);
          } else {
            onOpenPlan(plan);
          }
        },
      ),
      const SizedBox(height: 18),
      TrainingWeekStrip(
        selectedDay: selectedDay,
        onDaySelected: onDaySelected,
      ),
    ],
  );
}
```

Usuń import/użycie `TrainingDayDial`, `_DialCenter`, `_DayStatusLine`, pełną nazwę dnia pod kołem.

Usuń plik `training_day_dial.dart`. Sprawdź `rg TrainingDayDial` — zero trafień.

- [ ] **Step 4: Poproś użytkownika o run**

Run: `flutter test test/training_today_plan_section_test.dart test/training_day_hero_test.dart test/training_week_strip_test.dart test/training_day_status_test.dart`  
Expected: all PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/training/presentation/widgets/training_today_plan_section.dart test/training_today_plan_section_test.dart
git rm -f lib/features/training/presentation/widgets/training_day_dial.dart 2>nul
# jeśli dial był tylko untracked:
# Remove-Item lib/features/training/presentation/widgets/training_day_dial.dart -ErrorAction SilentlyContinue
git commit -m "feat(training): wire hero + week strip, remove day dial"
```

---

### Task 5: Smoke manual + porządki WIP

**Files:**
- Sprawdź, czy martwe pliki z WIP (`training_plan_card.dart`, `training_rest_day_card.dart`) są celowo usunięte wcześniej — **nie przywracaj** ich w tym PR, o ile nie są importowane. Jeśli `git status` pokazuje ich usunięcie jako niezwiązane z tym taskiem, zostaw je poza commitami tego planu albo dopytaj użytkownika przed stage’owaniem.

- [ ] **Step 1: `rg` sanity**

```bash
rg "TrainingDayDial|training_day_dial|play_arrow_rounded" lib/features/training test
```

Expected: brak diala; `play_arrow_rounded` nie w today section (może istnieć gdzie indziej w appce).

- [ ] **Step 2: Poproś użytkownika o pełny test pakietu sekcji**

Run: `flutter test test/training_today_plan_section_test.dart test/training_day_hero_test.dart test/training_week_strip_test.dart test/training_day_status_test.dart`  
Expected: PASS

- [ ] **Step 3: Manual checklist (użytkownik na urządzeniu/emulatorze)**

1. Dzień bez planu → monk, „Dzień odpoczynku”, „Regeneracja to postęp.”
2. Dzień z planem → „Dzień treningowy” + nazwa; tap → plan details
3. Pasek: przeszłe ✓, wybrany niebieska ramka, przyszłe szara kropka
4. Etykieta: dziś / wczoraj / nazwa dnia
5. Loading planów → spinner w kole

- [ ] **Step 4: Commit tylko jeśli zostały drobne poprawki wizualne**

```bash
git add -u lib/features/training/presentation/widgets
git commit -m "fix(training): polish today hero/week strip visuals"
```

(Pomiń jeśli nie było zmian.)

---

## Spec coverage (self-review)

| Spec § | Task |
|--------|------|
| Hero + week strip layout | 2, 3, 4 |
| Rest / trening copy + ikony | 3, 4 |
| Tap rest → create, tap trening → open | 4 |
| Brak play / start z hero | 4 (test) |
| Dynamiczna etykieta | 1, 4 |
| ✓ past / kropka future / ramka selected | 2 |
| Bieżący tydzień + daty | 2 |
| `selectedDay` 1–7, parent bez zmian | 4 |
| Usunięcie diala | 4 |
| Testy | 1–4 |
| `onStartPlan` w API nieużywane w hero | 4 |
| PROJECT_CONTEXT | Nie wymagany (brak mapy tych widgetów w kontekście) |

**Placeholder scan:** brak TBD.  
**Type consistency:** `selectedDay` int 1–7, `TrainingWeekStrip.today` opcjonalne, helpers w `training_day_status.dart` współdzielone.
