# GYM — opis projektu dla agentów

Ten dokument opisuje produkt i stack techniczny, nad którym pracujemy w tym repozytorium. Agent AI powinien traktować go jako kontekst nadrzędny przy implementacji — razem z regułami w `.cursor/rules` (jeśli istnieją), `PROJECT_CONTEXT.md` w korzeniu workspace oraz skillami w `.agents/skills/`.

## Cel aplikacji

**Dziennik treningowy siłowego** z warstwą **społecznościową**.

Użytkownik:
- planuje i wykonuje treningi (plany, sesje na żywo, historia, biblioteka ćwiczeń),
- śledzi postępy (serie, ciężary, objętość, notatki),
- dzieli się wynikami w profilu i feedzie,
- obserwuje innych użytkowników i przegląda ich aktywności.

**Poza zakresem produktu:** bieganie, rower, GPS, mapy tras, tętno, prędkość, przewyższenia i inne aktywności cardio/outdoor. Nie implementuj tych funkcji ani nie planuj ich w backlogu, chyba że maintainer wyraźnie zmieni ten zakres.

## Zakres funkcjonalny (wysoki poziom)

- **Trening:** plany, sesje na żywo (serie, timer odpoczynku), historia, statystyki, własna biblioteka ćwiczeń.
- **Offline-first:** zapis lokalny i synchronizacja z API po `clientId`.
- **Społeczność:** profile, bio, obserwowanie, wyszukiwanie użytkowników, feed aktywności treningowych.
- **W backlogu (opcjonalnie):** wspólne sesje, zaproszenia, push — bez map i GPS.

## Frontend — Flutter

| Obszar | Wybór / narzędzia |
|--------|-------------------|
| Stan | **`flutter_bloc` (Cubit)** — utrzymuj spójność w całym projekcie. |
| Nawigacja | `go_router` — głębokie linkowanie (np. powiadomienie → szczegóły sesji). |
| HTTP | `http` + własny `ApiClient` (Bearer JWT). |
| Offline / cache | **`sqflite`** — sesje, plany, ćwiczenia; sync engine per user. |
| Token | `flutter_secure_storage`. |
| UI | dark-only, język polski (hardcoded; brak l10n). |

**Architektura:** feature-first + warstwy `data` / `domain` / `presentation`. Wskazówki: `.agents/skills/flutter-apply-architecture-best-practices/`.

## Backend — Node.js + PostgreSQL

Backend w **`gym-backend/`** (osobne repo w workspace).

| Obszar | Technologia |
|--------|-------------|
| Runtime / API | **Node.js** + **Express** (REST, JWT). |
| Baza | **PostgreSQL** (obraz Docker z PostGIS — rozszerzenie **nie jest używane** w produkcie; nie dodawaj funkcji geolokalizacji). |
| Pliki | upload obrazków ćwiczeń (multer → dysk lokalny). |

Reguły dostępu do danych społecznościowych implementuj w **warstwie API** (`requireAuth`, repozytoria per `user_id`).

## Integracje i jakość (docelowo, niekoniecznie w MVP)

- **Powiadomienia push:** ewentualnie `firebase_messaging` (np. wspólne sesje, przypomnienia).
- **Błędy:** ewentualnie Sentry po stronie klienta.

Nie dodawaj zależności map/GPS (`google_maps_flutter`, `geolocator`, itp.) bez zmiany zakresu produktu.

## Wskazówki dla agentów

1. Przed większymi zmianami w UI / nawigacji sprawdź skill `flutter-setup-declarative-routing` (jeśli dotyczy).
2. Przy layoutach: `flutter-build-responsive-layout`, `flutter-fix-layout-issues`.
3. Przy testach: odpowiednie skille `flutter-add-widget-test`, `flutter-add-integration-test`, `dart-add-unit-test`.
4. **Nie rozszerzaj** produktu o cardio/GPS — trzymaj się dziennika treningowego siłowego + social.
5. Po istotnych zmianach architektury zaktualizuj `PROJECT_CONTEXT.md` (reguła `.cursor/rules/project-context.mdc`).
6. **Komendy Flutter/Dart uruchamia użytkownik.** Agent nie powinien sam wykonywać komend typu `flutter test`, `flutter analyze`, `flutter run`, `flutter pub ...`, `dart ...`. Jeśli weryfikacja jest potrzebna, podaj komendę użytkownikowi i poproś o output.

## Nazewnictwo

- **Produkt:** GYM / **Stronger** (tytuł aplikacji w UI).
- Pakiet pub: `gym`.
- Historyczna nazwa `workout-app` w starym README — nie używać jako opisu produktu.
