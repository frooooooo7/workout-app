# Rejestracja: onboarding profilu (zdjęcie, nick, dane ciała, cel)

Data: 2026-09-23
Status: zatwierdzony przez użytkownika
Zakres: `gym_backend` (migracja, `PATCH /profile/me`, flaga onboardingu) + `gym_frontend` (nowy feature `onboarding`, routing, ustawienia)

## Cel

Po założeniu konta użytkownik od razu ustawia zdjęcie profilowe, nick i bio, podaje podstawowe dane o sobie (płeć, data urodzenia, wzrost, waga) oraz cel treningowy. Dziś rejestracja kończy się na imieniu, nazwisku, e-mailu i haśle, a nick jest losowy i nieedytowalny.

## Podjęte decyzje

- **Konto powstaje po kroku 2** (jak dziś). Kolejne kroki to onboarding po zalogowaniu, zapisywany krok po kroku przez endpointy profilu — nieudany upload zdjęcia nie blokuje założenia konta, a przerwany onboarding wznawia się przy następnym starcie.
- **Kroki 3–5 są opcjonalne** — każdy ma „Pomiń”.
- **Dane ciała i cele są prywatne** — zwraca je wyłącznie `/profile/me*`; cudzy profil, feed i wyszukiwarka ich nie zawierają. Brak przełącznika „pokaż publicznie”.
- **Waga to jedna aktualna wartość.** Historia pomiarów — później (osobna tabela).
- **Minimalny wiek: 16 lat** (próg zgody RODO w Polsce), maksymalny: 100.
- **Jednostki: tylko kg i cm.**
- **Nick (`handle`) edytowalny** — w onboardingu i w edycji profilu.

## Flow

| # | Ekran | Pola | Wymagane |
|---|---|---|---|
| 1 | Jak masz na imię? | imię, nazwisko | tak (bez zmian) |
| 2 | Ustaw dostęp | e-mail, hasło → `POST /auth/register` | tak (bez zmian) |
| 3 | Twój profil | zdjęcie (galeria/aparat), nick, bio | „Pomiń” |
| 4 | O Tobie | płeć, data urodzenia (+ wiek), wzrost, waga | „Pomiń” |
| 5 | Twój cel | cel, poziom zaawansowania, dni treningowe w tygodniu | „Pomiń” |
| → | Gotowe | podsumowanie → „Zaczynamy” → `/app/training` | — |

Onboarding (`/onboarding`) ma własny pasek postępu 1–3. Wstecz cofa tylko między krokami 3–5 (konto już istnieje).

## Zakresy i słowniki (wspólne dla API i aplikacji)

| Pole API | Kolumna | Wartości |
|---|---|---|
| `handle` | `handle` | `^[a-z0-9][a-z0-9._]{2,29}$` (3–30 znaków, małe litery), unikalny |
| `birthDate` | `birth_date DATE` | `YYYY-MM-DD`, wiek 16–100 |
| `gender` | `gender TEXT` | `male`, `female`, `other` |
| `heightCm` | `height_cm SMALLINT` | 100–250, liczba całkowita |
| `weightKg` | `weight_kg NUMERIC(4,1)` | 30–300, zaokrąglane do 0,1 |
| `trainingGoal` | `training_goal TEXT` | `strength`, `muscle`, `fat_loss`, `general` |
| `experienceLevel` | `experience_level TEXT` | `beginner`, `intermediate`, `advanced` |
| `weeklyTrainingDays` | `weekly_training_days SMALLINT` | 1–7 |

Każde pole może być `null` (= „nie podano”; wysłanie `null` czyści wartość).

## Backend

- Migracja `016_users_profile_details`: powyższe kolumny + `onboarding_completed_at TIMESTAMPTZ`; istniejące konta dostają `onboarding_completed_at = created_at`.
- `PATCH /profile/me` przyjmuje nowe pola. Kody błędów: `invalid_handle`, `handle_taken` (409), `invalid_birth_date`, `invalid_gender`, `invalid_height`, `invalid_weight`, `invalid_training_goal`, `invalid_experience_level`, `invalid_weekly_training_days`.
- `POST /profile/me/onboarding/complete` — ustawia `onboarding_completed_at` (idempotentnie), zwraca własny profil.
- Odpowiedzi `/profile/me*` zawierają `onboardingCompleted` i `details: { birthDate, gender, heightCm, weightKg, trainingGoal, experienceLevel, weeklyTrainingDays }`.
- `user` w register/login/`/auth/me` (i pozostałych odpowiedziach auth) zawiera `onboardingCompleted`.

## Frontend

- `AuthUser.onboardingCompleted` (brak pola w starym cache → `true`).
- `ProfileDetails` + enumy `Gender`, `TrainingGoal`, `ExperienceLevel` z polskimi etykietami; `UserProfile.details` i `onboardingCompleted`.
- `ProfileRepository.updateProfile` z nowymi polami (możliwość wyczyszczenia), `completeOnboarding()`.
- `lib/features/onboarding/`: `OnboardingCubit` (zapis per krok, „Pomiń”, zakończenie), `OnboardingScreen` na klockach auth (`AuthGlowBackground`, `AuthCard`, `AuthFormTopBar`, `RegisterStepProgress`).
- Wspólny `AvatarPickerField` (wydzielony z `EditProfileScreen`), wybór z galerii lub aparatu.
- Routing: `/onboarding`; po rejestracji `go('/onboarding')`; zalogowany bez ukończonego onboardingu na `/app/**` → `/onboarding`.
- Ustawienia: pozycja „Dane i cele” (edycja kroków 4–5); nick w „Edytuj profil”.

## Poza zakresem (później)

- Historia wagi z wykresem.
- Płeć użytkownika w mapie mięśni (`BodyGender`, assets `female_*` już są).
- Sprawdzanie dostępności nicku podczas pisania (dziś: błąd `handle_taken` przy zapisie).
