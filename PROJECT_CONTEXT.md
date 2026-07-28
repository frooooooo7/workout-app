# GYM — kontekst projektu

> Dokument orientacyjny dla agentów AI i developerów: co jest gdzie, z czego się składa, jakie technologie i jak to wszystko się łączy.
> Data ostatniej aktualizacji: 2026-07-28 (zakres produktu: dziennik treningowy siłowego + social, bez GPS/cardio).
>
> **Utrzymanie:** ten plik musi być aktualizowany na bieżąco przy istotnych zmianach architektury, API, struktury katalogów, stacku lub infrastruktury — zgodnie z regułą `.cursor/rules/project-context.mdc`.

---

## 1. Produkt

**Dziennik treningowy siłowego** z warstwą **społecznościową**:

- plany treningowe, sesje na żywo (serie, ciężary, timer odpoczynku), historia,
- biblioteka ćwiczeń (systemowe + własne, offline sync),
- statystyki i notatki z treningów,
- profile, obserwowanie, wyszukiwanie, feed aktywności treningowych.

**Poza zakresem:** bieganie, rower, GPS, mapy tras, tętno, prędkość, przewyższenia i inne aktywności cardio/outdoor. Nie planuj ani nie implementuj tych funkcji bez zmiany zakresu produktu.

Aplikacja nazywa się **Stronger** (tytuł w `MaterialApp`), pakiet pub: `gym`. UI jest **po polsku**, wyłącznie w **trybie ciemnym**.

---

## 2. Struktura workspace

```
gym/                              <- root workspace (NIE jest osobnym repo)
├── gym-backend/                  <- API REST (Node.js + Express + PostgreSQL)
├── gym-flutter/                  <- aplikacja kliencka (Flutter)
├── gym-backend.worktrees/        <- worktree'y agentów (np. agents-api-training-sessions-mvp-implementation)
├── gym-flutter.worktrees/        <- worktree'y agentów (np. agents-ui-ux-training-history-plan)
├── create-worktree.bat           <- skrypt tworzący worktree dla gym-flutter
└── PROJECT_CONTEXT.md            <- ten plik
```

Każde z repo (`gym-backend`, `gym-flutter`) jest osobnym repozytorium git z własnymi branchami.

---

## 3. Backend (`gym-backend`)

### 3.1 Stack

| Obszar | Technologia |
|--------|-------------|
| Język | TypeScript (ES2022, ESM `"type": "module"`, NodeNext) |
| Runtime | Node.js >= 20 (Docker: Node 22 Alpine) |
| Framework | Express 4 |
| Baza | PostgreSQL 16 (obraz Docker PostGIS — rozszerzenie **nieużywane**, poza zakresem produktu) |
| Dostęp do bazy | surowy `pg` (pool) — **bez ORM-a** |
| Walidacja | Zod 4 |
| Auth | JWT (`jsonwebtoken`) + bcryptjs (12 rund) |
| Uploady | multer (dysk, `uploads/exercise-images/`, max 5 MB, jpg/png/webp) |
| Bezpieczeństwo | helmet, cors, compression, express-rate-limit |
| Testy | Vitest + supertest (testy obok modułów, `*.test.ts`) |
| Dev runner | tsx / tsx watch |

### 3.2 Struktura katalogów

```
gym-backend/
├── src/
│   ├── index.ts                <- entry: migracje -> listen -> graceful shutdown
│   ├── app.ts                  <- createApp(): middleware + montowanie routerów
│   ├── config/env.ts           <- wczytanie i walidacja zmiennych środowiskowych
│   ├── db/
│   │   ├── migrate.ts          <- WSZYSTKIE migracje inline (tabela _migrations, advisory lock)
│   │   ├── pool.ts             <- pg Pool
│   │   └── require-pool.ts
│   ├── middleware/
│   │   ├── auth.ts             <- requireAuth (JWT Bearer -> req.auth)
│   │   ├── rate-limit.ts       <- limity: register 10/h, login 10/15min, exercises 300/min
│   │   └── validation.ts       <- validateRequest (Zod)
│   ├── common/                 <- AppError, asyncHandler, wspólne schematy Zod
│   └── modules/                <- moduły domenowe (feature folders)
│       ├── auth/               <- register / login / me
│       ├── exercises/          <- katalog ćwiczeń + upload obrazków + ulubione
│       ├── health/             <- /health, /ready
│       ├── profile/            <- profil, bio, follow-read, aktywności, search
│       ├── training-plans/     <- CRUD planów (plan -> ćwiczenia -> serie)
│       ├── training-sessions/  <- zapis/sync sesji (upsert po clientId)
│       └── training-history/   <- timeline odczyt (cursor, ETag) + openapi.yaml
├── uploads/exercise-images/    <- pliki z multera (gitignored)
├── Dockerfile                  <- multi-stage; USER node; port 3000
├── docker-compose.yml          <- postgres (PostGIS) + api z healthcheckami
├── .env.example
└── README.md                   <- kontrakt API training-history
```

**Konwencja modułu:** `*.routes.ts` → `*.controller.ts` → `*.service.ts` → `*.repository.ts` + `*.schemas.ts` (+ `*.test.ts`, opcjonalnie `*.openapi.yaml`).

### 3.3 Boot i zmienne środowiskowe

Start (`npm run dev` = `tsx watch src/index.ts`):

1. `config/env.ts` ładuje `.env` (dotenv),
2. `runMigrations()` — migracje odpalają się **przy każdym starcie procesu**,
3. `app.listen(PORT)` (domyślnie **3000**),
4. SIGINT/SIGTERM → zamknięcie serwera i poola (10 s twardy limit).

| Zmienna | Rola |
|---------|------|
| `NODE_ENV` | development / production (CORS, wymóg JWT_SECRET) |
| `PORT` | port HTTP (domyślnie 3000) |
| `DATABASE_URL` | connection string Postgresa |
| `POSTGRES_PASSWORD` | hasło (compose + .env) |
| `JWT_SECRET` | klucz JWT — **wymagany w produkcji**, min. 32 znaki |
| `CORS_ORIGIN` | whitelist originów po przecinku (wymagana w produkcji) |
| `POSTGRES_PORT` / `API_PORT` | porty hosta dla compose |

### 3.4 API — przegląd endpointów

Wszystko poza `/health` i `/ready` wymaga `Authorization: Bearer <jwt>`. **Brak globalnego prefiksu `/api`** — wyjątek: training-history pod `/api/v1/`.

| Grupa | Endpointy |
|-------|-----------|
| Health | `GET /health`, `GET /ready` (publiczne) |
| Auth | `POST /auth/register`, `POST /auth/login`, `GET /auth/me` |
| Exercises | `GET/POST /exercises`, `PUT/DELETE /exercises/:id`, `POST /exercises/:id/favourite`, `POST /exercises/:id/image` (multipart) |
| Pliki statyczne | `GET /uploads/exercise-images/*` |
| Training plans | `GET/POST /training-plans`, `PUT/DELETE /training-plans/:id` (zagnieżdżone ćwiczenia i serie, `clientId` do sync) |
| Training sessions (zapis) | `POST /training-sessions` (upsert po `clientId`), `PUT /training-sessions/:id`, `GET /training-sessions/active`, `GET /training-sessions/history` |
| Training history (odczyt) | `GET /api/v1/training-history`, `GET /api/v1/training-history/:sessionId` + aliasy `/api/v1/training-sessions[/:sessionId]`; paginacja kursorem, filtry, **ETag / If-None-Match → 304** |
| Profile / social | `GET/PATCH /profile/me` (tylko `bio`), `GET /profile/following|followers|activities`, `GET /users/search`, `GET /users/:userId/profile`, `GET /users/:userId/activities` |

### 3.5 Baza danych

Migracje wyłącznie w `src/db/migrate.ts`. Tabele:

```
users ─┬─< exercises (created_by, SET NULL)
       ├─< user_favourite_exercises (M:N z exercises)
       ├─< training_plans >─ training_plan_exercises >─ training_plan_sets
       ├─< training_sessions >─ training_session_exercises >─ training_session_sets
       └─< user_follows (follower_id / following_id, M:N self)
```

- `training_sessions`: status `active|completed|cancelled`, **jedna aktywna sesja na usera** (unique partial index).
- `training_session_exercises` denormalizuje snapshot ćwiczenia (nazwa, mięśnie, kategoria, obrazek).
- `training_session_sets`: `planned_*` + `actual_*` + `completed`.
- **Offline-first:** unikalne indeksy `(user_id, client_id)` na exercises/plans/sessions → klient robi upsert po `clientId`.
- Seed: migracja `003` wstawia ~14 systemowych ćwiczeń (polskie nazwy, stałe UUID).
- Handle użytkowników: generowany przy rejestracji (`profile.handle.ts`), migracja `009` backfilluje.

### 3.6 Skrypty npm

| Komenda | Działanie |
|---------|-----------|
| `npm run dev` | tsx watch (dev serwer) |
| `npm run build` / `start` | tsc → `node dist/index.js` |
| `npm run typecheck` | `tsc --noEmit` |
| `npm run migrate` | ręczne migracje |
| `npm test` | Vitest |

Brak CI (`.github/workflows` nie istnieje). Brak websocketów, maili, płatności, kolejek, Redisa, S3.

---

## 4. Frontend (`gym-flutter`)

### 4.1 Stack

| Obszar | Technologia |
|--------|-------------|
| Flutter / Dart | Flutter >= 3.38.4, Dart `^3.11.5` |
| Stan | **flutter_bloc (Cubit)** — spójnie w całym projekcie |
| Nawigacja | **go_router** (`StatefulShellRoute.indexedStack`) |
| HTTP | `http` (własny wrapper `ApiClient`) — bez Dio |
| Token JWT | `flutter_secure_storage` |
| Offline DB | **sqflite** (+ `sqflite_common_ffi_web` na weba, `sqflite_common_ffi` w testach) |
| DI | własny statyczny `ServiceLocator` (nie get_it) |
| Inne | image_picker, flutter_svg, uuid, shared_preferences, flutter_local_notifications + timezone (timer odpoczynku) |
| Lint | flutter_lints ^6 |

Stack docelowy w `PROJECT.md` (push, Sentry) może się rozszerzać — **bez** map, GPS i aktywności cardio.

### 4.2 Struktura `lib/`

Architektura **feature-first + warstwy** (`data` / `domain` / `presentation` w każdym feature):

```
lib/
├── main.dart                       <- entry: ServiceLocator.init() -> runApp(GymApp)
├── core/
│   ├── constants/api_constants.dart<- base URL API
│   ├── navigation/
│   │   ├── app_router.dart         <- go_router + redirect auth
│   │   └── app_shell.dart          <- bottom nav: Główna/Trening/Aktywność/Biblioteka/Profil
│   ├── network/api_client.dart     <- HTTP wrapper + Bearer token (timeout 15s/60s multipart)
│   ├── services/service_locator.dart <- DI + repozytoria offline per-user
│   ├── session/app_user_bootstrap.dart <- odtworzenie sesji (offline-first)
│   ├── storage/token_storage.dart  <- secure storage: auth_token, auth_user
│   ├── theme/                      <- dark-only, fiolet #6C47FF na #0B0B14
│   └── widgets/user_avatar.dart
└── features/
    ├── auth/       <- login/register (data + domain models + presentation)
    ├── home/       <- dashboard (GŁÓWNIE MOCKI)
    ├── activity/   <- zakładka Aktywność (tylko presentation, MOCKI)
    ├── library/    <- katalog ćwiczeń, offline-first + sync
    ├── training/   <- plany, sesja na żywo (timer), historia, statystyki
    └── profile/    <- profil social: bio, follow, search, feed aktywności
```

Konwencja w feature: `domain/models/` + `domain/repositories/` (kontrakty), `data/` (remote DS, lokalna baza, repozytoria offline-first, `sync/`), `presentation/screens|widgets|bloc/`.

### 4.3 Routing (go_router)

| Ścieżka | Ekran |
|---------|-------|
| `/splash` | rozwiązanie sesji → home lub login |
| `/login`, `/login/form`, `/login/register` | auth |
| `/app/home` | HomeScreen |
| `/app/training` (+ nested) | hub: Sesja / Plany / Historia; ongoing workout, create plan, stats, szczegóły sesji |
| `/app/activity` | ActivityScreen (mock) |
| `/app/library` | LibraryScreen, pick exercise |
| `/app/profile` (+ nested) | profil, ustawienia, following/followers, find people |
| `/app/users/:userId` | profil innego użytkownika |

Wszystko pod `/app/` jest chronione — redirect na `/login`, gdy brak użytkownika.

### 4.4 Komunikacja z backendem

- **Base URL** (`core/constants/api_constants.dart`): web `http://localhost:3000`, mobilnie domyślnie `http://10.0.2.2:3000` (emulator Androida); nadpisywalne przez `--dart-define=API_BASE_URL=...`.
- **Auth flow:** login/register → JWT do secure storage → `AppUserBootstrap` przy starcie: cached user od razu + weryfikacja `GET /auth/me` w tle; 401 czyści storage.
- **Offline-first:** po zalogowaniu otwierana jest baza per-user `gym_library_<userId>.db` (schema v7) i startują silniki sync: `ExerciseSyncEngine`, `TrainingPlanSyncEngine`, `TrainingSessionSyncEngine`. Repozytoria `OfflineFirst*Repository` najpierw zapisują lokalnie, potem synchronizują (upsert po `clientId`).
- **Serializacja:** ręczne `fromJson` / mappery — **bez** json_serializable/freezed.

### 4.5 Modele domenowe (najważniejsze)

| Model | Plik |
|-------|------|
| `AuthUser`, `AuthResult` | `features/auth/domain/models/auth_models.dart` |
| `Exercise` + enumy | `features/library/domain/models/exercise.dart` |
| `CustomTrainingPlan`, `PlanExercise`, `ExerciseSet` | `features/training/domain/models/custom_training_plan.dart` |
| `TrainingSession*` (sesja na żywo) | `features/training/domain/models/training_session.dart` |
| historia (list/detail/page) | `features/training/domain/models/training_history_models.dart` |
| `UserProfile`, `ProfileStats`, `FollowingUser`, `ProfileActivity*` | `features/profile/domain/models/` |

Mappery DB↔domain: `exercise_dto.dart`, `training_plan_local_mapper.dart`, `training_session_local_mapper.dart`.

### 4.6 Platformy i testy

- Platformy: `android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/`.
- Android: uprawnienia pod rest-timer (exact alarm, boot, full-screen intent), package `com.gym.app.gym`, Java 17.
- Web: `sqflite_sw.js` + `sqlite3.wasm` (WASM SQLite).
- Testy: 16 plików w `test/` (routing, cubity, sync offline, widgety). Brak `integration_test/`, brak CI.
- UI hardcoded po polsku; brak l10n (skill przygotowany, nieużyty).

---

## 5. Integracja frontend ↔ backend

```mermaid
flowchart LR
  subgraph Flutter["gym-flutter (Stronger)"]
    UI[Screens + Cubits] --> Repos[OfflineFirst*Repository]
    Repos --> Local[(sqflite per-user)]
    Repos --> Sync[Sync engines]
    Sync --> ApiClient[ApiClient + Bearer JWT]
  end
  ApiClient -->|HTTP/JSON| Express
  subgraph Backend["gym-backend :3000"]
    Express[Express app] --> Modules[modules/*]
    Modules --> Repo[repositories - raw SQL]
    Repo --> PG[(PostgreSQL 16 + PostGIS image)]
    Express --> Uploads[/uploads/exercise-images]
  end
```

- Auth: JWT 30 dni, Bearer w każdym requeście chronionym.
- Sync: klient generuje `clientId` (uuid) → serwer upsertuje po `(user_id, client_id)`.
- Historia: klient czyta z `/api/v1/training-sessions` (alias training-history), wspiera ETag/304 do cache'u offline.
- **Znana niespójność:** zapis sesji idzie na `/training-sessions`, a odczyt historii na `/api/v1/training-sessions` — dwa style URL-i (backend ma aliasy, więc działa, ale konwencja nie jest ujednolicona).

---

## 6. Infrastruktura / uruchamianie

### Lokalny dev backendu

```bash
cd gym-backend
docker compose up -d postgres   # baza PostGIS na :5432 (gym/gym)
npm install
npm run dev                     # API na :3000, migracje same się wykonają
```

Całość w kontenerach: `docker compose up -d` (postgres + api, healthchecki, `/health`).

### Frontend

```bash
cd gym-flutter
flutter pub get
flutter run                     # mobile: API pod 10.0.2.2:3000 (emulator)
flutter run -d chrome           # web: API pod localhost:3000
# fizyczne urządzenie: --dart-define=API_BASE_URL=http://<ip-kompa>:3000
```

> Komendy Flutter/Dart uruchamia użytkownik (zgodnie z `PROJECT.md` — agent ich nie odpala).

---

## 7. Stan implementacji vs plany

**Działa (zaimplementowane):**
- auth (register/login/me, JWT),
- biblioteka ćwiczeń (CRUD, ulubione, upload obrazków, offline sync),
- plany treningowe (CRUD, sync),
- sesje na żywo z timerem odpoczynku (lokalne powiadomienia),
- historia treningów (timeline, filtry, paginacja, ETag),
- profil social: bio, listy following/followers, search, feed aktywności (odczyt).

**Mocki / placeholdery:**
- Home i Activity (dashboardy) — dane zaszyte na sztywno (tylko trening siłowy),
- `kudosCount` / `commentCount` w aktywnościach — hardcoded 0.

**Braki (gap'e):**
- brak endpointów zapisu follow/unfollow (tabela `user_follows` istnieje, nic nie zapisuje),
- brak uploadu avatara (kolumna `avatar_url` jest),
- brak websocketów, feed na żywo, wspólnych sesji, push, Sentry, CI,
- nieujednolicone wersjonowanie API (`/api/v1` tylko dla training-history).

---

## 8. Skille, reguły agentskie i utrzymanie kontekstu

- **`.cursor/rules/project-context.mdc`** — reguła Cursor: agent aktualizuje ten plik przy istotnych zmianach (moduły, API, stack, struktura, Docker, env).
- `gym-flutter/.agents/skills/` — skille Flutter/Dart (routing, layout, testy, JSON, architektura, code-reviewer).
- `gym-flutter/.cursor_backup/rules/` — backup reguł Cursor (warstwy, UI).
- `gym-flutter/PROJECT.md` — opis produktu i stack dla agentów (dziennik treningowy + social).
- Backend README — kontrakt training-history.

---

## 9. Uwagi porządkowe

- `gym-*.worktrees/` — worktree'y z eksperymentów agentów; przed pracą sprawdź, czy nie zawierają niezmergowanych zmian.
