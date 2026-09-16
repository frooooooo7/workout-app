# Stronger (GYM) — aplikacja Flutter

**Dziennik treningu siłowego** z warstwą społecznościową w stylu Stravy. Planujesz i zapisujesz
treningi (serie, ciężary, powtórzenia, timer przerwy), śledzisz postępy, a ukończone treningi
udostępniasz w feedzie, gdzie obserwujący dają kudosy i komentują. Aplikacja działa
**offline-first** — trening zapiszesz bez internetu, a synchronizacja nadrobi zaległości.

Poza zakresem produktu: bieganie, rower, GPS, mapy tras, tętno, prędkość, przewyższenia.

Backend (Node.js + Express + PostgreSQL) jest w osobnym repozytorium `gym_backend`.

## Funkcje

- **Trening na żywo** — sesja z planu lub od zera, serie (planowane i wykonane: ciężar, powtórzenia,
  RIR, tempo), timer przerwy z lokalnym powiadomieniem (wyłączalnym), podsumowanie po treningu.
- **Plany treningowe** — dni tygodnia, ćwiczenia i serie; „Dzisiejszy trening” na ekranie głównym.
- **Historia** — oś czasu z filtrami, kalendarz/heatmapa, szczegóły z mapą mięśni; edycja,
  powtórzenie i usunięcie zakończonego treningu.
- **Statystyki** tygodnia i miesiąca liczone lokalnie (treningi, czas, serie, powtórzenia, objętość).
- **Biblioteka ćwiczeń** — ćwiczenia systemowe i własne (zdjęcia, ulubione).
- **Społeczność** — profile (bio, awatar), obserwowanie, wyszukiwarka i propozycje osób,
  feed aktywności z kudosami i komentarzami, szczegóły posta.
- **Konto** — zmiana hasła, wylogowanie ze wszystkich urządzeń, usunięcie konta, obsługa
  unieważnionej sesji.
- **Offline-first** — lokalna baza SQLite per użytkownik, kolejka zmian, synchronizacja po
  powrocie sieci, wskaźnik stanu synchronizacji.

UI jest po polsku i wyłącznie w trybie ciemnym.

## Architektura

```
lib/
├── main.dart                 # ServiceLocator.init() → GymApp (MaterialApp.router)
├── core/
│   ├── constants/            # api_constants.dart: origin serwera + /api/v1
│   ├── network/              # ApiClient (http + Bearer JWT), api_asset_uri (pliki /uploads)
│   ├── navigation/           # go_router (StatefulShellRoute), bottom nav
│   ├── services/             # ServiceLocator — prosty DI + repozytoria per użytkownik
│   ├── session/              # AppUserBootstrap, SessionManager
│   ├── sync/                 # SyncEngineBase, SyncCoordinator, SyncStatus
│   ├── images/               # OfflineNetworkImage — cache obrazków na dysku
│   └── theme/, widgets/, utils/
└── features/                 # feature-first: data / domain / presentation
    ├── auth/  account/  feed/  library/  profile/  training/  body_highlighter/
```

- **Stan:** `flutter_bloc` (Cubit) w całej aplikacji; **nawigacja:** `go_router`;
  **HTTP:** `http` + własny `ApiClient`; **DI:** statyczny `ServiceLocator`.
- **Offline-first:** po zalogowaniu otwierana jest baza `gym_library_<userId>.db` (sqflite).
  Repozytoria `OfflineFirst*Repository` zapisują lokalnie i kolejkują operacje (`pending_op`),
  a silniki synchronizacji (ćwiczenia → plany → sesje) wysyłają je z `clientId` (idempotentny
  upsert na serwerze) i pobierają zmiany (`/training-sessions/history?updatedSince`, nagrobki
  usuniętych treningów). `SyncCoordinator` synchronizuje po powrocie sieci/aplikacji
  i ponawia z backoffem.
- **SessionManager:** jedno wymuszone wylogowanie przy `401 token_revoked`/`invalid_token`,
  bezpieczna podmiana tokenu po zmianie hasła / „wyloguj wszędzie”, sprzątanie danych lokalnych
  po usunięciu konta.
- **API v1:** wszystkie wywołania idą na `<origin>/api/v1/...` — `kApiBaseUrl` w
  `lib/core/constants/api_constants.dart` to jedyne miejsce z prefiksem. Ścieżki plików
  (`/uploads/...` z `imageUrl`/`avatarUrl`) są rozwijane względem samego originu (`kApiOrigin`).

Szczegóły (routing, sync, modele): `PROJECT_CONTEXT.md`. Zasady dla agentów: `PROJECT.md`.

## Wymagania

- Flutter **3.47.2** (stable), Dart `^3.11.5` — ta wersja jest przypięta w CI.
- Backend `gym_backend` (Node.js ≥ 20 + PostgreSQL 16, najprościej przez Docker).
- Opcjonalnie: Android SDK / Xcode (mobile), Chrome/Edge (web), Visual Studio z „Desktop
  development with C++” (Windows desktop).

## Uruchomienie

### 1. Backend

```bash
cd gym_backend
docker compose up -d --build      # PostgreSQL + API na http://localhost:3000
# albo API na hoście:
cp .env.example .env
docker compose up -d postgres
npm ci
npm run dev                       # http://localhost:3000, migracje wykonują się same
```

### 2. Aplikacja

```bash
flutter pub get
flutter run -d chrome             # web: API domyślnie http://localhost:3000
flutter run                       # emulator Androida: API domyślnie http://10.0.2.2:3000
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000   # fizyczne urządzenie
```

`API_BASE_URL` to **origin** serwera (bez `/api/v1` — prefiks dokleja aplikacja).

## Testy

### Jednostkowe i widgetowe

```bash
flutter analyze
flutter test                      # test/ — testy E2E są tu pomijane
```

### E2E: kontrakt z prawdziwym backendem (`test/e2e/`)

Prawdziwy `ApiClient`, remote data sources, repozytoria API oraz silniki synchronizacji na
sqflite (dwa „urządzenia”) przeciwko działającemu `gym_backend`. Sprawdzają m.in. rejestrację,
ćwiczenia, plany, sesje i udostępnianie, obserwowanie, feed (`FeedPost` z `topExercises`,
`bestSet`, mięśniami), kudosy, komentarze, profil i aktywności, wyszukiwarkę, historię,
usuwanie (`deleted[]`, `410 session_deleted`), uploady (awatar i zdjęcie ćwiczenia pod
originem), zmianę hasła (`token_revoked`), wylogowanie wszędzie i usunięcie konta.

```bash
# w gym_backend — osobna baza, żeby nie ruszać danych deweloperskich:
docker compose up -d postgres
docker compose exec postgres createdb -U gym gym_smoke
PORT=3102 NODE_ENV=development \
  DATABASE_URL=postgresql://gym:gym@localhost:5432/gym_smoke npx tsx src/index.ts

# w gym_frontend:
flutter test test/e2e --dart-define=E2E_BASE_URL=http://localhost:3102
```

Bez `E2E_BASE_URL` (define albo zmienna środowiskowa) testy są pomijane. Każde uruchomienie
tworzy 3 konta testowe (i je usuwa). Backend limituje rejestrację do **10 na godzinę z jednego
IP** (limiter w pamięci) — przy częstym powtarzaniu zrestartuj serwer.

### Integracyjne UI (`integration_test/`)

Prawdziwe drzewo aplikacji (router, ekrany, cubity, repozytoria offline-first na SQLite) bez
backendu: logowanie → start treningu z planu → ukończenie serii → zakończenie → historia →
menu szczegółów.

```bash
flutter test integration_test -d flutter-tester   # bez urządzenia (tak działa w CI)
flutter test integration_test -d windows          # wymaga Visual Studio (C++)
```

## CI

`.github/workflows/ci.yml` (push i pull request):

- **analyze-test** — `flutter pub get`, `flutter analyze`, `flutter test`,
  `flutter test integration_test -d flutter-tester`,
- **build-web** — `flutter build web --release`,
- **e2e** — `flutter test test/e2e` tylko, gdy w repozytorium ustawiona jest zmienna
  (Settings → Variables) `E2E_BASE_URL` wskazująca na dostępny backend; inaczej job jest pomijany.
