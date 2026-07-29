# Sekcja „Na dziś” — hero + pasek tygodnia

> Data: 2026-07-29  
> Status: zatwierdzona przez użytkownika (brainstorming)  
> Zakres: `gym-flutter` — UI zakładki Trening (`TrainingTodayPlanSection`)  
> Referencja wizualna: mockup użytkownika (koło statusu + poziomy pasek 7 dni)

## 1. Cel

Przebudować górną sekcję ekranu treningu tak, by odpowiadała mockupowi:

- duże **koło statusu** (hero) z treścią dnia (rest / trening),
- pod spodem **poziomy pasek tygodnia** z kartami dni (wybór dnia),
- usunięcie segmentowanego diala (`TrainingDayDial`).

## 2. Decyzje produktowe

| Temat | Decyzja |
|-------|---------|
| Podejście | Pełna zamiana dial → hero + week strip |
| Źródło „dzień treningowy” | Dni z `CustomTrainingPlan.selectedDays` (1=Pon … 7=Ndz) |
| Treść dnia treningowego | Layout jak rest: etykieta + ikona + „Dzień treningowy” + nazwa planu |
| Treść dnia odpoczynku | „Na dziś” (lub inna etykieta) + monk + „Dzień odpoczynku” + „Regeneracja to postęp.” |
| Tap w koło — trening | Otwiera szczegóły planu (`onOpenPlan`) |
| Tap w koło — rest | Tworzy plan na ten dzień (`onCreatePlanForDay`) — jak dziś |
| Start sesji z koła | Nie — bez play w hero; start ze flow szczegółów planu |
| Etykieta nad ikoną | Dynamiczna: „Na dziś” / „Wczoraj” / pełna nazwa dnia (np. „Czwartek”) |
| ✓ na pasku | Każdy dzień **przeszły** (niezależnie od treningu) |
| Szara kropka | Dzień **przyszły** (może być rest lub trening) |
| Wybrany dzień | Niebieska ramka + niebieska kropka (nadpisuje ✓/szarą kropkę) |
| Zakres paska | Bieżący tydzień kalendarzowy Pon–Ndz z realnymi numerami dni |
| Model wyboru | Nadal `selectedDay` jako weekday 1–7 (bez zmiany parenta) |

## 3. Layout

`TrainingTodayPlanSection` — `Column` wyśrodkowana:

1. **Hero circle** (`TrainingDayHero`)
   - średnica ~ jak obecny dial (~232) lub dopasowana do mockupu,
   - subtelna niebieska obwódka / glow (`AppColors.primary` / `primaryVariant`),
   - wnętrze: etykieta (szara, mała) → ikona → tytuł (biały, bold) → podtytuł (szary),
   - loading: `CircularProgressIndicator` w środku.
2. **Week strip** (`TrainingWeekStrip`)
   - 7 równych kart: skrót dnia (Pon…Ndz), numer daty, wskaźnik na dole,
   - tap karty → `onDaySelected(weekday)`.

Usunięte z UI:

- segmentowany ring / tap po łuku (`TrainingDayDial`),
- osobna linia z pełną nazwą weekday pod kołem (zastąpiona etykietą + paskiem).

## 4. Stany hero

| Warunek | Tytuł | Podtytuł | Ikona | Tap |
|---------|-------|----------|-------|-----|
| `isLoading` | — | — | spinner | — |
| Brak planu na `selectedDay` | Dzień odpoczynku | Regeneracja to postęp. | `monk_rest.png` | `onCreatePlanForDay(selectedDay)` |
| Jest plan | Dzień treningowy | `plan.name` (+ ` +N` jeśli więcej planów) | ikona treningu (Material, spójna z appką) | `onOpenPlan(plan)` |

Etykieta (względem „dziś” i wybranej daty w bieżącym tygodniu):

- wybrana data == dziś → „Na dziś”
- wybrana data == wczoraj → „Wczoraj”
- inaczej → pełna nazwa dnia tygodnia (np. „czwartek” / „Czwartek” — spójnie z lokalizacją PL w appce)

## 5. Stany karty paska

Dla każdego dnia `d` w bieżącym tygodniu (data z kalendarza):

| Stan | Wizual | Wskaźnik |
|------|--------|----------|
| Wybrany (`d.weekday == selectedDay`) | border `AppColors.primary` | niebieska kropka |
| Przeszły (`d` < dziś, nie wybrany) | domyślna karta | ✓ białe |
| Przyszły (`d` > dziś, nie wybrany) | domyślna karta | szara kropka |
| Dziś nie wybrany | domyślna karta | szara kropka (traktowany jak „jeszcze nie minął” poza ✓) — **wyjątek:** jeśli `d == dziś` i nie wybrany, wskaźnik = szara kropka (nie ✓) |

Uwaga: „dziś” niewybrane nie dostaje ✓, bo dzień jeszcze się nie zakończył; ✓ tylko gdy `date.isBefore(today)` (porównanie dat bez czasu).

## 6. Architektura plików

| Plik | Akcja |
|------|--------|
| `training_today_plan_section.dart` | Orkiestracja; logika planu/rest; callbacki bez zmian sygnatur |
| `training_day_hero.dart` | **Nowy** — koło statusu |
| `training_week_strip.dart` | **Nowy** (wcześniej usunięty w repo — przywrócić/przepisać pod ten spec) |
| `training_day_dial.dart` | **Usunąć** po migracji |
| `test/training_today_plan_section_test.dart` | Przepisać asercje pod hero + strip |

### Kontrakt `TrainingTodayPlanSection` (bez zmian dla parenta)

```dart
selectedDay, plans, isLoading,
onDaySelected, onOpenPlan, onStartPlan, onCreatePlanForDay
```

`onStartPlan` pozostaje w API (parent w `TrainingSessionTab` nadal przekazuje), ale hero go **nie wywołuje**.

### Parent

`TrainingSessionTab` — bez zmian poza ewentualnym brakiem zależności od diala; `_selectedDay` jak dziś.

## 7. Kolory i wygląd

- Tło aplikacji: istniejące `AppColors.background`
- Karty paska: ciemne, zaokrąglone (`surface` / `surfaceVariant`), tekst biały/muted
- Akcent wyboru: `AppColors.primary` (~#2563EB, blisko mockupu)
- Hero: wypełnienie `surface`, ring primary z niską opacity / glow

Nie wprowadzamy nowych zależności pakietów.

## 8. Testy

Zaktualizować `training_today_plan_section_test.dart`:

1. Rest: widoczne „Dzień odpoczynku”, monk, tap → `onCreatePlanForDay`
2. Trening: „Dzień treningowy”, nazwa planu, tap → `onOpenPlan` (brak play)
3. `+N` przy wielu planach tego samego dnia
4. Wybór dnia: tap karty paska (np. „Czw”) → `onDaySelected`
5. Loading: spinner, brak monk/tytułu rest
6. Etykieta: przy `selectedDay == DateTime.now().weekday` → „Na dziś”

## 9. Poza zakresem

- Zmiana routingu / bottom nava
- Logika sync planów / historii sesji
- Pasek innych tygodni (scroll historii) — tylko bieżący tydzień
- Start treningu bezpośrednio z hero
- Aktualizacja `PROJECT_CONTEXT.md` tylko jeśli mapa widgetów / opis UI Treningu jest tam wymieniony i rozjeżdża się ze stanem — wtedy krótka korekta w tym samym PR

## 10. Kryteria akceptacji

- UI wizualnie zgodne z mockupem (hero + 7 kart)
- Rest vs trening zależne od planu na wybranym weekday
- ✓ / kropka / ramka zgodnie z §5
- Dial usunięty, testy zielone
)