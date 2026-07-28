# Rebranding auth: paleta „Ember” + układ „Karta”

Data: 2026-07-28
Status: zatwierdzony przez użytkownika
Zakres: `gym-flutter` — ekrany auth (powitalny login, formularz logowania, rejestracja) + globalna podmiana palety kolorów

## Cel

Przebudowa UI logowania i rejestracji: rezygnacja z fioletowych akcentów i dotychczasowego układu (hero image + animacja dymu) na rzecz palety „Ember” (pomarańcz na ciepłej czerni) i układu opartego o wyśrodkowaną kartę.

## Podjęte decyzje

- **Zakres globalny** — nowa paleta trafia do `AppColors`, więc cała aplikacja (nie tylko auth) zmienia kolorystykę. Auth jest pierwszym krokiem rebrandingu.
- **Dark mode pozostaje** jedynym motywem.
- **Paleta Ember** — pomarańczowy akcent `#FF5A1F` na ciepłej czerni `#131110`.
- **Układ logowania: Karta** — bez zdjęcia hero; wyśrodkowana karta z logo, nagłówkiem, przyciskami i logowaniem social.
- **Rejestracja: dwa kroki** — krok 1 (imię/nazwisko), krok 2 (e-mail/hasło), dwusegmentowy pasek postępu.
- Mockupy wybrane przez użytkownika w sesji brainstorm: `.superpowers/brainstorm/auth-redesign-2026-07-28/content/` (root workspace).

## Paleta „Ember” — zmiany w `lib/core/theme/app_colors.dart`

| Token | Obecnie | Nowo |
|---|---|---|
| `primary` | `#6C47FF` | `#FF5A1F` |
| `primaryVariant` | `#8B6BFF` | `#FF8A50` |
| `onPrimary` | `Colors.white` | `#1A0F08` (ciemny tekst na pomarańczu — kontrast ~5,6:1, spełnia WCAG AA) |
| `background` | `#0B0B14` | `#131110` |
| `surface` | `#13131F` | `#1B1713` |
| `surfaceVariant` | `#1A1A2A` | `#241E19` |
| `textPrimary` | `Colors.white` | `#FFF7F2` |
| `textSecondary` | `#8888A0` | `#A89A8E` |
| `textMuted` | `#55556A` | `#6B5F56` |
| `border` | `#252535` | `#2E2721` |
| `gradientTop` | `#0B0B14` | `#131110` |
| `gradientHero` | `#1A0A3A` | `#2A1408` |
| `success`, `strengthWeak/Medium/Strong` | bez zmian | bez zmian |

`AppTheme.dark` (`lib/core/theme/app_theme.dart`) nie wymaga zmian strukturalnych — pobiera kolory z tokenów.

## Ekran powitalny logowania (`login_screen.dart`)

- Tło: `AppColors.background` + subtelna radialna poświata pomarańczu przy dolnym prawym rogu — dekoracja jako `Container` z `RadialGradient`, `primary` z alfą ~0,14 zanikająca do przezroczystości (promień ~60% szerokości ekranu).
- Wyśrodkowana karta: `surface`, ramka `border`, `BorderRadius ~20`, padding 24, max szerokość na tabletach (~420).
- Zawartość karty (od góry): logo `assets/images/logo.png` (~48 px), „STRONGER” + tagline, nagłówek „Trenuj mądrze. / Osiągaj więcej.” (druga linia w `primary`, bez `ShaderMask` — wystarczy kolor), podpis opisowy, `ElevatedButton` „Zaloguj się” → `/login/form`, `OutlinedButton` „Utwórz konto” → `/login/register` — styl nadpisany lokalnie na ekranie auth (ramka i tekst w `primary`); globalny `outlinedButtonTheme` w `AppTheme` pozostaje bez zmian, żeby nie zmieniać przycisków outline na innych ekranach. Dalej: `AuthSocialDivider`, `AuthSocialButtonsRow`, `LoginTermsFooter`.
- Nawigacja i copy pozostają bez zmian.

## Ekran formularza logowania (`login_form_screen.dart`)

- Ta sama karta: `AuthFormTopBar` z powrotem, w karcie nagłówek (istniejący `login_form_header`, bez zmian w copy), pola e-mail/hasło (`AuthTextField`), `AuthErrorBanner`, przycisk „Zaloguj się”, `login_form_register_link`.
- Logika logowania, walidatory i obsługa błędów bez zmian.

## Rejestracja (`register_screen.dart`)

- Jeden ekran ze stanem kroku (`_step` = 0/1), przejście `AnimatedSwitcher` między kartami kroków.
- Top bar: przycisk wstecz (w kroku 2 cofa do kroku 1, w kroku 1 `context.pop()`) + dwusegmentowy pasek postępu (aktywny segment w `primary`).
- Krok 1 — karta: tytuł „Jak masz na imię?”, podpis „Krok 1 z 2 — kilka podstawowych danych.”, pola Imię/Nazwisko, przycisk „Dalej” (waliduje oba pola; bez wywołania API).
- Krok 2 — karta: tytuł „Ustaw dostęp”, pola E-mail/Hasło, istniejące `PasswordStrengthBar` + `PasswordRequirementsCard` (po wpisaniu hasła), `AuthErrorBanner`, przycisk „Utwórz konto” (wykonuje istniejącą logikę `register()`).
- `RegisterLoginPrompt` pozostaje pod kartą.
- Walidatory (`auth_validators.dart`), mapowanie błędów (`auth_error_messages.dart`) i zapis tokenu/użytkownika bez zmian.

## Pliki do usunięcia / refaktoryzacji

**Usuwane (przestają być używane):**
- `login_hero_section.dart`, `login_smoke_animation.dart`, `login_hero_text.dart`, `login_feature_row.dart`, `login_logo_badge.dart` (logo ląduje bezpośrednio w karcie)
- `register_benefits_section.dart`, `register_screen_header.dart`

**Uwaga o assety:** `assets/images/login-hero.png` NIE jest usuwany — jest używany także przez `activity_type_selection_screen.dart` (feature training). Usuwane jest tylko jego użycie w auth. `assets/images/logo.png` pozostaje (użycie w nowej karcie).

**Nowe widgety:** `auth_card.dart` (kontener karty z tłem/poświatą), `register_step_progress.dart` (pasek postępu), wydzielone kroki `register_step_name.dart` / `register_step_account.dart`.

**Globalne poprawki:** `lib/core/navigation/app_router.dart` — zahardkodowane `Color(0xFF0B0B14)` i `Color(0xFF6C47FF)` w ekranach ładowania zastąpić `AppColors.background` / `AppColors.primary`.

## Wpływ globalny

Podmiana tokenów zmienia wygląd całej aplikacji: dolna nawigacja (indicator, ikony), przyciski, inputy, wszystkie widgety używające `AppColors.primary` (home, training, profile, library). To zamierzony efekt (decyzja: rebrand globalny). Ewentualne drobne niedopasowania wizualne poza auth będą poprawiane osobno — poza zakresem tej zmiany.

## Dokumentacja

Po implementacji: aktualizacja `PROJECT_CONTEXT.md` (sekcje o motywie/kolorystyce i strukturze `features/auth`).

## Weryfikacja

- `flutter analyze` bez błędów
- `flutter test` (jeśli istnieją testy auth — zaktualizować przy usuniętych widgetach)
- Ręczny przegląd: ekran powitalny, formularz logowania, oba kroki rejestracji, powrót z kroku 2 do 1, stany błędów, splash/loading w routerze
- Szybki przegląd wizualny głównych ekranów poza auth (home, training) pod kątem rażących niezgodności po podmianie palety

## Poza zakresem

- Motyw jasny (light mode)
- Zmiany w logice social auth, backendzie, walidacji
- Rebranding grafik/assetów (logo pozostaje)
- Poprawki wizualne ekranów poza auth
