# GYM — kontekst projektu

> Dokument orientacyjny dla agentów AI i developerów: co jest gdzie, z czego się składa, jakie technologie i jak to wszystko się łączy.
> Data ostatniej aktualizacji: 2026-09-16 (faza 5: API `/api/v1`, testy E2E z backendem, `integration_test`, CI; zakres produktu: dziennik treningowy siłowego + social, bez GPS/cardio).
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
├── gym_backend/                  <- API REST (Node.js + Express + PostgreSQL), własne CI
└── gym_frontend/                 <- aplikacja kliencka (Flutter); ten plik: gym_frontend/PROJECT_CONTEXT.md
```

Każde z repo (`gym_backend`, `gym_frontend`) jest osobnym repozytorium git z własnymi branchami.

---

## 3. Backend (`gym_backend`)

### 3.1 Stack

| Obszar | Technologia |
|--------|-------------|
| Język | TypeScript (ES2022, ESM `"type": "module"`, NodeNext) |
| Runtime | Node.js >= 20 (Docker: Node 22 Alpine) |
| Framework | Express 4 |
| Baza | PostgreSQL 16 (obraz `postgres:16-alpine`; potrzebne tylko `pgcrypto` i `pg_trgm`) |
| Dostęp do bazy | surowy `pg` (pool) — **bez ORM-a** |
| Walidacja | Zod 4 |
| Auth | JWT (`jsonwebtoken`) + bcryptjs (12 rund, hash/compare w `worker_threads`) |
| Uploady | multer (dysk, `uploads/exercise-images/`, max 5 MB, jpg/png/webp) |
| Bezpieczeństwo | helmet, cors, compression, express-rate-limit |
| Testy | Vitest + supertest (testy obok modułów, `*.test.ts`) |
| Dev runner | tsx / tsx watch |

### 3.2 Struktura katalogów

```
gym_backend/
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
├── docker-compose.yml          <- postgres:16-alpine + api z healthcheckami
├── .env.example
├── .github/workflows/ci.yml    <- typecheck, Vitest, build, smoke E2E na Postgresie
└── README.md                   <- przegląd API (tabela ścieżek /api/v1), kontrakt training-history
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
| `PG_POOL_MAX` | max połączeń puli `pg` (domyślnie 10) |
| `POSTGRES_PORT` / `API_PORT` | porty hosta dla compose |

### 3.4 API — przegląd endpointów

Wszystko poza `/health` i `/ready` wymaga `Authorization: Bearer <jwt>`. **Wszystkie endpointy są pod `/api/v1`** (w tabeli ścieżki bez prefiksu). Stare ścieżki bez prefiksu nadal działają, ale zwracają `Deprecation: true` + `Link: </api/v1/...>` — **klient używa wyłącznie `/api/v1`**. Pliki `/uploads/*` są serwowane bez prefiksu.

| Grupa | Endpointy |
|-------|-----------|
| Health | `GET /health`, `GET /ready` (publiczne) |
| Auth | `POST /auth/register`, `POST /auth/login`, `GET /auth/me`, `POST /auth/change-password` `{currentPassword, newPassword}` → `{token, user}` (`invalid_credentials`, `password_too_short`, `password_too_weak`, `password_unchanged`, `missing_fields`, `429`), `POST /auth/logout-all` → `{token, user}`, `POST /auth/delete-account` (alias `DELETE /auth/me`) `{password}` → 204 (`invalid_credentials`, `missing_fields`, `429`). Po zmianie hasła / wylogowaniu wszędzie **wszystkie starsze tokeny są unieważnione** (także użyty do wywołania); każdy chroniony endpoint może zwrócić `401 token_revoked` / `invalid_token` |
| Exercises | `GET/POST /exercises` (`GET` stronicowany: `limit` ≤ 100, `offset`; zwraca `clientId` własnych ćwiczeń; `muscles` przyjmuje tylko 8 grup: `chest, back, legs, shoulders, biceps, triceps, abs, glutes` — klient mapuje grupy granularne przez `MuscleGroup.apiGroup`), `PUT/DELETE /exercises/:id` (usunięcie ćwiczenia użytego w planie → **409 `exercise_in_use`**), `POST /exercises/:id/favourite`, `POST /exercises/:id/image` (multipart) |
| Pliki statyczne | `GET /uploads/exercise-images/*` (`Cache-Control: 365d, immutable`) |
| Training plans | `GET/POST /training-plans`, `PUT/DELETE /training-plans/:id` (zagnieżdżone ćwiczenia i serie, `clientId` do sync) |
| Training sessions (zapis) | `POST /training-sessions` (upsert po `clientId`), `PUT /training-sessions/:id` (także edycja zakończonej sesji), `DELETE /training-sessions/:id` i `DELETE /training-sessions/by-client-id/:clientId` (204, nagrobek), `GET /training-sessions/active`, `GET /training-sessions/history` (keyset: `limit` ≤ 100, `cursor`, `updatedSince` → `{ items, nextCursor, hasMore, deleted[] }`; `deleted` tylko na 1. stronie z `updatedSince`). Zapis usuniętej sesji → **410 `session_deleted`**. Niewidoczne już `exerciseId` / `planId` (usunięte, zanim sesja offline dotarła) zapisywane są jako `NULL` — snapshot nazw zostaje, zapis nie jest odrzucany |
| Training history (odczyt) | `GET /training-history`, `GET /training-history/:sessionId` + aliasy tylko w v1: `GET /api/v1/training-sessions[/:sessionId]` (router zapisu ma pierwszeństwo, więc `/training-sessions/history` i `/active` trafiają do zapisu); paginacja kursorem, filtry, ETag / If-None-Match → 304 (klient nie wysyła `If-None-Match` — ma własny cache SWR) |
| Profile / social | `GET/PATCH /profile/me` (`firstName`, `lastName` 1–50, `bio` ≤ 120, pusty → `null`, `handle` 3–30 `[a-z0-9._]` → `409 handle_taken`; prywatne `details`: `birthDate` (wiek 16–100), `gender`, `heightCm` 100–250, `weightKg` 30–300, `trainingGoal`, `experienceLevel`, `weeklyTrainingDays` 1–7 — `null` czyści; odpowiedź z `onboardingCompleted` i `details` tylko w `/profile/me*`), `POST /profile/me/onboarding/complete` (idempotentne), `POST/DELETE /profile/me/avatar` (multipart, pole `avatar`, jpg/png/webp ≤ 5 MB → profil; błędy `missing_image`, `invalid_file`), `GET /profile/following|followers`, `GET /users/search`, `GET /users/:userId/profile` (+ `isFollowing`, `isFollowedBy`), `GET /users/:userId/following|followers` (`limit`, `offset`; pozycje z `isFollowing`), `POST/DELETE /users/:userId/follow` → `{ isFollowing, followersCount }` (`cannot_follow_self`, `user_not_found`, `429`), `GET /users/:userId/posts` (oś czasu profilu w formacie feedu, `limit`, `cursor`) |
| Feed / kudosy / komentarze | `GET /feed?limit&cursor` → `{ items: FeedPost[], nextCursor, hasMore }` (posty moje + obserwowanych, `invalid_cursor`), `GET /posts/:sessionId` (post + `exercises` jak w training-history, `post_not_found`), `POST/DELETE /posts/:id/kudos` → `{ hasKudoed, kudosCount }` (`cannot_kudo_own_post`), `GET /posts/:id/kudos?limit&offset` (lista jak obserwujący), `GET /posts/:id/comments?limit&cursor` (najstarsze najpierw), `POST /posts/:id/comments` `{ body }` (1–500 punktów kodowych, `invalid_comment_body`, `429`), `DELETE /posts/:id/comments/:commentId` → 204 (`forbidden`, `comment_not_found`), `GET /users/suggested?limit`. Aktywności profilu mają realne `kudosCount`, `commentCount`, `hasKudoed` (id = id sesji = id posta) |
| Pliki statyczne (awatary) | `GET /uploads/avatars/*` — `avatarUrl` to ścieżka względna, klient dokleja base URL (`core/network/api_asset_uri.dart`) |

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
- Handle użytkowników: generowany przy rejestracji (`profile.handle.ts`), migracja `009` backfilluje; od `016` edytowalny.
- Migracja `016`: prywatne dane profilu w `users` (`birth_date`, `gender`, `height_cm`, `weight_kg`, `training_goal`, `experience_level`, `weekly_training_days`) + `onboarding_completed_at` (istniejące konta = ukończony).
- Migracja `011`: indeksy pod historię (`user_id, started_at DESC, id DESC`), FK (`plan_id`, `exercise_id`) oraz `pg_trgm` na `users.handle` / imię+nazwisko / `exercises.name`.

### 3.6 Skrypty npm

| Komenda | Działanie |
|---------|-----------|
| `npm run dev` | tsx watch (dev serwer) |
| `npm run build` / `start` | tsc → `node dist/index.js` |
| `npm run typecheck` | `tsc --noEmit` |
| `npm run migrate` | ręczne migracje |
| `npm test` | Vitest |

CI backendu: GitHub Actions (typecheck, Vitest, build, smoke E2E na Postgresie). Brak websocketów, maili, płatności, kolejek, Redisa, S3.

---

## 4. Frontend (`gym_frontend`)

### 4.1 Stack

| Obszar | Technologia |
|--------|-------------|
| Flutter / Dart | Flutter 3.47.2 (przypięty w CI), Dart `^3.11.5` |
| Stan | **flutter_bloc (Cubit)** — spójnie w całym projekcie |
| Nawigacja | **go_router** (`StatefulShellRoute.indexedStack`) |
| HTTP | `http` (własny wrapper `ApiClient`) — bez Dio |
| Token JWT | `flutter_secure_storage` |
| Offline DB | **sqflite** (+ `sqflite_common_ffi_web` na weba, `sqflite_common_ffi` w testach) |
| DI | własny statyczny `ServiceLocator` (nie get_it) |
| Inne | image_picker, flutter_svg, uuid, shared_preferences, flutter_local_notifications + timezone (timer odpoczynku), connectivity_plus (sync po powrocie sieci) |
| Lint | flutter_lints ^6 |

Stack docelowy w `PROJECT.md` (push, Sentry) może się rozszerzać — **bez** map, GPS i aktywności cardio.

### 4.2 Struktura `lib/`

Architektura **feature-first + warstwy** (`data` / `domain` / `presentation` w każdym feature):

```
lib/
├── main.dart                       <- entry: ServiceLocator.init() -> runApp(GymApp)
├── core/
│   ├── constants/api_constants.dart<- kApiOrigin (origin serwera) + kApiBaseUrl = <origin>/api/v1
│   ├── navigation/
│   │   ├── app_router.dart         <- go_router + redirect auth
│   │   └── app_shell.dart          <- bottom nav: Główna/Trening/Aktywność/Biblioteka/Profil
│   ├── images/offline_network_image.dart <- obrazki z cache na dysku (offline)
│   ├── network/api_client.dart     <- HTTP wrapper + Bearer token (timeout 15s/60s multipart)
│   ├── network/api_asset_uri.dart  <- /uploads/... → pełny adres względem kApiOrigin (bez /api/v1)
│   ├── services/service_locator.dart <- DI + repozytoria offline per-user + syncStatus / *DataChanges
│   ├── session/app_user_bootstrap.dart <- odtworzenie sesji (offline-first)
│   ├── session/session_manager.dart <- wymuszone wylogowanie (401 token_revoked/invalid_token), podmiana tokenu, koniec sesji po usunięciu konta
│   ├── storage/token_storage.dart  <- secure storage: auth_token, auth_user
│   ├── sync/                       <- SyncEngineBase, SyncCoordinator, SyncStatus, klasyfikacja błędów
│   ├── theme/                      <- dark-only, fiolet #6C47FF na #0B0B14
│   ├── utils/polish_plural.dart
│   └── widgets/                    <- user_avatar (xxs…lg), app_header, sync_status_indicator (ikonka synchronizacji)
└── features/
    ├── auth/       <- login/register (data + domain models + presentation); bez logowania społecznościowego
    ├── onboarding/ <- po rejestracji: zdjęcie + nick + bio → dane o sobie → cel (każdy krok „Pomiń”)
    ├── account/    <- zmiana hasła, wyloguj wszędzie, usunięcie konta, ustawienia powiadomień, pomoc (FAQ)
    ├── feed/       <- zakładka Aktywność: feed społecznościowy (posty, kudosy, komentarze, cache 1. strony)
    ├── library/    <- katalog ćwiczeń, offline-first + sync
    ├── training/   <- plany, sesja na żywo (timer), historia, statystyki
    └── profile/    <- profil social: bio, follow, search, feed aktywności
```

Konwencja w feature: `domain/models/` + `domain/repositories/` (kontrakty), `data/` (remote DS, lokalna baza, repozytoria offline-first, `sync/`), `presentation/screens|widgets|bloc/`.

### 4.3 Routing (go_router)

| Ścieżka | Ekran |
|---------|-------|
| `/splash` | rozwiązanie sesji → `/app/training` lub login |
| `/login`, `/login/form`, `/login/register` | auth; po rejestracji → `/onboarding` |
| `/onboarding` | OnboardingScreen (`OnboardingCubit`): 3 kroki zapisywane osobno + „Gotowe”; „Dokończ później” przy błędzie wczytania |
| `/app/training` (+ nested) | hub: Sesja / Plany / Historia; ongoing workout, create plan, `stats` (wejście: „Zobacz statystyki” na karcie miesiąca w Historii), `history/:sessionId` (szczegóły: menu Edytuj / Powtórz / Usuń), `history/:sessionId/edit` (EditWorkoutScreen) |
| `/app/activity` | ActivityFeedScreen — feed (pull-to-refresh, doładowanie kursorem, pusty stan z propozycjami osób) |
| `/app/library` | LibraryScreen, pick exercise |
| `/app/profile` (+ nested) | profil, `settings`, `edit` (EditProfileScreen: awatar z galerii/aparatu, imię, nazwisko, nick, bio), `details` (ProfileDetailsScreen — „Dane i cele”, prywatne), `following` / `followers`, `find-people` |
| `/app/profile/settings/change-password` | ChangePasswordScreen (`ChangePasswordCubit`; walidacja jak przy rejestracji + powtórzenie + inne niż obecne) |
| `/app/profile/settings/notifications` | NotificationSettingsScreen — przełącznik „Powiadomienie o końcu przerwy” (`shared_preferences`, klucz `rest_timer_notifications_enabled`) |
| `/app/profile/settings/help` | HelpScreen — statyczne FAQ |
| `/app/profile/settings/delete-account` | DeleteAccountScreen (`DeleteAccountCubit`: hasło + checkbox, ostrzeżenie o niewysłanych zmianach) |
| `/app/users/:userId` | profil innego użytkownika (przycisk Obserwuj, „Obserwuje Cię”) |
| `/app/users/:userId/following`, `/app/users/:userId/followers` | listy innego użytkownika (te same ekrany co własne, z `userId`) |
| `/app/posts/:sessionId` (`?comment=1` → fokus na polu komentarza) | PostDetailsScreen — szczegóły posta (metryki, mapa mięśni, ćwiczenia z widgetów `session_details`), kudosy, komentarze; otwierane z feedu i z aktywności na profilach |

Feed (`features/feed/`): `FeedCubit` (cache pierwszej strony w `shared_preferences` per user → baner „Brak połączenia — pokazuję zapisany feed”, jedno żądanie pierwszej strony naraz, doładowanie odrzucane po odświeżeniu, optymistyczne kudosy), `PostDetailsCubit`, `PostCommentsCubit` (optymistyczne dodanie/usunięcie z cofnięciem). Zmiany kudosów/komentarzy między ekranami: `ServiceLocator.feedPostEvents`; odświeżenie feedu po udostępnieniu treningu i zmianie obserwowania: `ServiceLocator.requestFeedRefresh()` (`feedRefreshSignal`).

Obserwowanie: `FollowCubit` (optymistyczny toggle + cofnięcie przy błędzie) dostarczany w routerze dla list, wyszukiwarki i profilu użytkownika; wspólny widget `FollowButton` / `FollowToggleButton`. Edycja profilu: `EditProfileCubit`; zmiana imienia/nazwiska aktualizuje `ServiceLocator.currentUser` + cache w `TokenStorage` (`ServiceLocator.updateCurrentUserNames`) — id się nie zmienia, więc baza per-user nie jest przebudowywana. `UserAvatar` wczytuje zdjęcie z API (cache offline) z fallbackiem na inicjały.

Wszystko pod `/app/` jest chronione — redirect na `/login`, gdy brak użytkownika. Konto z `AuthUser.onboardingCompleted == false` trafia z `/app/**` na `/onboarding` (chyba że w tej sesji odłożyło go przez „Dokończ później” — `ServiceLocator.deferOnboarding`); po zakończeniu `ServiceLocator.markOnboardingCompleted` zapisuje flagę w sesji i cache. Wspólne pola danych o sobie/celu: `profile/presentation/widgets/profile_details_fields.dart` (płeć jako przełącznik, data urodzenia w arkuszu z kołami `birth_date_sheet.dart`, wzrost/waga na przewijanej linijce `ruler_picker.dart`, cele jako kafelki z ilustracjami `assets/images/goal_*.webp` — bez pliku pokazują ikonę) + `ProfileDetailsDraft` + mixin `ProfileDetailsDraftEditor` (cubity onboardingu i „Dane i cele”). Onboarding ma układ zakładek (`AppTabBackground`, dolny pasek z akcją nad treścią, przejścia kroków w osi poziomej).

Konto i sesja (`features/account/`, `core/session/session_manager.dart`): podtrasy ustawień rejestruje `buildAccountSettingsRoutes()`. Ustawienia: sekcje Konto / Bezpieczeństwo (zmiana hasła, „Wyloguj ze wszystkich urządzeń” z potwierdzeniem — `LogoutAllDevicesCubit`) / Ustawienia (powiadomienia, pomoc) oraz wydzielona „Strefa niebezpieczna” z „Usuń konto”. Operacje idą przez `AccountRepository` (`ServiceLocator.accountRepository`).

### 4.4 Komunikacja z backendem

- **Base URL** (`core/constants/api_constants.dart`): `API_BASE_URL` to **origin** serwera — web `http://localhost:3000`, mobilnie domyślnie `http://10.0.2.2:3000` (emulator Androida); nadpisywalne przez `--dart-define=API_BASE_URL=...`. `ApiClient` dostaje `kApiBaseUrl = <origin>/api/v1` (jedyne miejsce z prefiksem; ścieżki w data sources są bez prefiksu, np. `/training-sessions/history`). Obrazki i awatary (`/uploads/...`) rozwija `apiAssetUri` względem `kApiOrigin`.
- **Auth flow:** login/register → JWT do secure storage → `AppUserBootstrap` przy starcie: cached user od razu + weryfikacja `GET /auth/me` w tle; 401 czyści storage.
- **Unieważniona sesja:** `ApiClient.onUnauthorized` zgłasza każdy `401` na żądanie z tokenem (z tokenem użytym w nagłówku) do `SessionManager.handleUnauthorized`. Tylko `token_revoked` / `invalid_token` i tylko gdy token żądania == bieżący token → **jedno** wymuszone wylogowanie (równoległe 401 są ignorowane): czyszczenie tokenu i cache użytkownika, `onSessionEnded` (w `main.dart` → `router.go('/login')`), `currentUser = null` (zamknięcie bazy, `SyncCoordinator.stop()` — bez pętli ponowień), komunikat `ServiceLocator.loginNotice` na ekranie logowania (czyszczony przy kolejnym zalogowaniu). Lokalna baza konta **zostaje** (niewysłane zmiany wyślą się po ponownym zalogowaniu). Logowanie/rejestracja (bez tokenu) i `invalid_credentials` nie wywołują wylogowania.
- **Rotacja tokenu:** zmiana hasła i „wyloguj wszędzie” działają w `SessionManager.guardTokenRotation` — 401 na stary token przychodzące w trakcie są oceniane dopiero po zapisaniu nowego tokenu (`applyRefreshedSession`: `TokenStorage` + `currentUser` z tym samym id, bez przebudowy bazy).
- **Usunięcie konta:** `POST /auth/delete-account` `{password}` (klient nie używa `DELETE` z treścią — proxy potrafią ją gubić) → po 204 koniec sesji (komunikat „Konto zostało usunięte.” — baner na `/login` i `/login/form`), zamknięcie i usunięcie pliku `gym_library_<userId>.db` (ćwiczenia, plany, sesje, kolejka sync, cache historii), kluczy `shared_preferences` z sufiksem `_<userId>` (cache feedu) oraz plików awatarów konta w cache obrazków (adresy zapamiętane w tej sesji aplikacji przez `ApiProfileRepository.ownAvatarUrlsFor`) — `LocalAccountDataCleaner`. Ustawienia urządzenia i pozostałe obrazki (ćwiczenia, inne osoby) zostają.
- **Powiadomienie timera:** `ServiceLocator.restTimerScheduler` to `SettingsAwareRestTimerScheduler` — przy wyłączonym ustawieniu nie planuje powiadomienia (timer w aplikacji działa); wyłączenie odwołuje zaplanowane.
- **Offline-first:** po zalogowaniu otwierana jest baza per-user `gym_library_<userId>.db` (schema **v11**). Scope bazy jest przebudowywany tylko przy zmianie **id** użytkownika (odświeżenie `/auth/me` go nie rusza); wylogowanie ustawia `currentUser = null` i zamyka bazę (z ostrzeżeniem o niewysłanych zmianach).
  - Repozytoria `OfflineFirst*Repository` zapisują lokalnie i od razu wołają `flush`; odczyty wołają `pullIfDue` (najwyżej raz na 30 s).
  - Silniki (`ExerciseSyncEngine`, `TrainingPlanSyncEngine`, `TrainingSessionSyncEngine`) dziedziczą po `core/sync/SyncEngineBase` (kolejka, zlewanie zdublowanych żądań, licznik aktywności). Pull **nie nadpisuje** wierszy z `pending_op`; rekordy utworzone offline są parowane po `clientId`; edycja w trakcie żądania zostaje jako `update`.
  - Błędy 4xx (poza 401/408/409/425/429) oznaczają wiersz `sync_error` i nie są ponawiane w pętli; jeden zepsuty wiersz nie blokuje kolejki. Sesja czeka, aż ćwiczenie utworzone offline dostanie `server_id`.
  - `core/sync/SyncCoordinator`: pełny cykl ćwiczenia → plany → sesje, sync ~2 s po powrocie sieci (`connectivity_plus` → `core/sync/network_availability.dart`), sync po `AppLifecycleState.resumed`, a jako zabezpieczenie (sieć jest, internet jeszcze nie) ponawianie z backoffem 15 s → 2 min, dopóki są zaległości. Stan (`SyncStatus`) → `ServiceLocator.syncStatus` → `SyncStatusIndicator` w prawym górnym rogu ekranów (Trening, Plany, Historia, Aktywność, Profil, Biblioteka); tap = szczegóły + „Synchronizuj teraz”.
  - Po zmianach z synchronizacji cubity odświeżają się same (`ServiceLocator.*DataChanges`).
  - Statystyki (`/app/training/stats`): `TrainingSummaryCubit` + czysty `TrainingSummaryCalculator` (tydzień od poniedziałku 00:00, miesiąc kalendarzowy; treningi, czas, ukończone serie, powtórzenia, objętość, różne ćwiczenia — bez kalorii) liczone z lokalnej bazy przez `LocalTrainingStatsRepository` (niewysłane + pobrane z serwera sesje; odczyt woła `pullIfDue` sesji).
  - **Pull sesji** (`TrainingSessionSyncEngine.pull`, w cyklu koordynatora po `sessions.flush`, `pullIfDue` 30 s): `GET /training-sessions/history` stronami po 100. Pierwszy raz bez `updatedSince` = pełna historia + usunięcie lokalnych zsynchronizowanych sesji (bez `pending_op`), których serwer nie ma. Potem `updatedSince = znacznik − 30 s`; znacznik (`sync_state`, klucz `training_sessions.pull_high_water_mark`) = max `updatedAt`/`deletedAt` z odpowiedzi (zegar serwera), zapisywany po pobraniu wszystkich stron. Parowanie po `server_id`, potem `local_id = clientId`; wiersze z `pending_op` nie są nadpisywane; ta sama wersja (`server_updated_at`) jest pomijana. `deleted[]` (po `clientId`, potem id) usuwa wiersz także z niewysłaną edycją (spójnie z 410); wyjątek: aktywny trening.
  - **Usuwanie sesji** (`TrainingSessionRepository.delete`): ćwiczenia/serie znikają od razu, wiersz sesji zostaje jako nagrobek `pending_op = 'delete'` (ukryty w historii, statystykach, `getById`; cache historii czyszczony). Pusta, nigdy niewysłana sesja jest kasowana od razu. Sesja znana tylko z serwera → minimalny nagrobek (`local_id = server_id = id`). Feed (`FeedCubit.hiddenPostIds`) i aktywności własnego profilu (`ProfileCubit.hiddenActivityIds`) ukrywają nagrobki od razu (`ServiceLocator.pendingDeletedSessionIds`) — także przy nieudanym odświeżeniu offline i w zapisanym cache feedu. Flush: `server_id` → `DELETE /:id` (404 → dodatkowo `by-client-id`), brak `server_id` → `by-client-id`; 400/404/410 = sukces. Usunięcie w trakcie POST zostaje usunięciem. `countSyncBacklog` liczy nagrobki.
  - **410 `session_deleted`** (`SyncFailureKind.gone`): create/update w kolejce → usunięcie lokalnej sesji bez `sync_error` i bez PUT→POST; bezpośredni PATCH udostępnienia → `TrainingSessionDeletedException` (szczegóły/podsumowanie pokazują „Ten trening został usunięty.”).
  - **Powtórz trening**: `buildRepeatedSession` (ćwiczenia i serie w kolejności, plan = poprzednie wykonanie lub plan, nieukończone; powiązanie z planem tylko gdy plan istnieje) → `TrainingSessionCubit.startFromSession`; przy trwającym treningu dialog „Wróć do treningu”.
  - **Edycja treningu**: `EditWorkoutCubit` + czyste `validateWorkoutEdit` / `applyWorkoutEdit` (`workout_edit.dart`; `finishedAt = start + minuty`, przesunięcie `completedAt`), zapis `save` → `pending_op = update` → `PUT`. Sesja spoza lokalnej bazy: `loadForEdit` = pull, a potem szukanie w pełnej historii (`fetchFromServer`). Po zmianach: `ServiceLocator.notifyTrainingSessionsChanged()`, flush, odświeżenie profilu i feedu.
  - Historia: serwer + cache (stale-while-revalidate: cache od razu, sieć w tle); treningi zakończone offline (niewysłane) są dokładane z lokalnej bazy (`TrainingSessionLocalHistory`), a bez sieci i cache pokazywane są same lokalne. Identyczne `getSessions` w locie są zlewane do jednego Future.
  - Lokalna baza (sqflite, wersja 11 — tabela `sync_state`, kolumna `training_sessions.server_updated_at`): indeksy na dzieciach planów/sesji (`plan_local_id`, `session_local_id`, …), `pending_op` oraz `(status, started_at)`. Odczyt dzieci: `IN` + grupowanie, nie N+1. Zapis sesji/planu w jednej transakcji + Batch.
  - Obrazki ćwiczeń i awatary: `core/images/offline_network_image.dart` (pliki na dysku, web → `NetworkImage`); miniatury dekodowane przez `ResizeImage` / `exerciseThumbProvider`.
- **Serializacja:** ręczne `fromJson` / mappery — **bez** json_serializable/freezed.

### 4.5 Modele domenowe (najważniejsze)

| Model | Plik |
|-------|------|
| `AuthUser`, `AuthResult` | `features/auth/domain/models/auth_models.dart` |
| `Exercise` + enumy | `features/library/domain/models/exercise.dart` |
| `CustomTrainingPlan`, `PlanExercise`, `ExerciseSet` | `features/training/domain/models/custom_training_plan.dart` |
| `TrainingSession*` (sesja na żywo) | `features/training/domain/models/training_session.dart` |
| historia (list/detail/page) | `features/training/domain/models/training_history_models.dart` |
| `UserProfile`, `ProfileStats`, `FollowingUser`, `ProfileDetails` (+ `Gender`, `TrainingGoal`, `ExperienceLevel`) | `features/profile/domain/models/` |
| `FeedPost`, `FeedAuthor`, `TopExercise`, `PostComment`, `PostDetail`, `CursorPage` | `features/feed/domain/models/` (JSON: `features/feed/data/feed_json.dart`; ćwiczenia/serie: `training/data/training_history_json.dart`) |
| `TrainingPeriodStats`, `TrainingSummary` | `features/training/domain/models/training_summary_stats.dart` |

Mappery DB↔domain: `exercise_dto.dart`, `training_plan_local_mapper.dart`, `training_session_local_mapper.dart`.

### 4.6 Platformy i testy

- Platformy: `android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/`.
- Android: uprawnienia pod rest-timer (exact alarm, boot, full-screen intent), package `com.gym.app.gym`, Java 17.
- Web: `sqflite_sw.js` + `sqlite3.wasm` (WASM SQLite).
- Testy konta/sesji: `session_manager_test.dart`, `api_account_repository_test.dart`, `change_password_test.dart`, `delete_account_screen_test.dart`, `profile_settings_screen_test.dart`, `notification_settings_test.dart`, `local_account_data_cleaner_test.dart`.
- **Testy E2E** (`test/e2e/`, pomijane bez `E2E_BASE_URL`): `api_contract_e2e_test.dart` — prawdziwy `ApiClient` + remote data sources / repozytoria API przeciw działającemu backendowi (rejestracja, ćwiczenia, plany, sesje, follow, feed, kudosy, komentarze, profil, search, historia, usuwanie + `deleted[]` + 410, uploady, zmiana hasła / `token_revoked`, logout-all, usunięcie konta); `offline_sync_e2e_test.dart` — dwa „urządzenia” (osobne bazy sqflite) z prawdziwymi silnikami sync. Uruchomienie: `flutter test test/e2e --dart-define=E2E_BASE_URL=http://localhost:3102` (backend na bazie `gym_smoke`; limit rejestracji 10/h na IP, każde uruchomienie tworzy 3 konta).
- **Integracyjny UI** (`integration_test/workout_flow_test.dart`): prawdziwe drzewo aplikacji (router, ekrany, cubity, repozytoria offline-first na sqflite ffi) z podmienionym HTTP: logowanie → start treningu z planu → ukończenie serii → zakończenie → historia → menu szczegółów. `flutter test integration_test -d flutter-tester` (CI) albo `-d windows` (wymaga Visual Studio C++).
- **CI** (`.github/workflows/ci.yml`): `analyze-test` (pub get, analyze, test, integration_test na flutter-tester), `build-web` (`flutter build web --release`), `e2e` tylko przy zmiennej repozytorium `E2E_BASE_URL`.
- Testy: ~60 plików w `test/` (routing, cubity, sync offline, widgety; social: `follow_cubit_test.dart`, `api_profile_repository_test.dart`, `edit_profile_screen_test.dart`, `feed_cubit_test.dart`, `post_comments_cubit_test.dart`, `api_feed_repository_test.dart`, `feed_post_card_test.dart`; statystyki: `training_summary_calculator_test.dart`, `training_stats_screen_test.dart`). Scenariusze offline-first: `offline_sync_*_test.dart` (w tym `offline_sync_conflicts_test.dart` — pull vs niewysłane edycje, duplikaty po `clientId`, odrzucone wiersze; `offline_sync_training_session_delete_pull_test.dart` — usuwanie, 410, pull + `deleted[]`), `offline_first_training_history_repository_test.dart`, `sync_status_indicator_test.dart`; API v1: `api_v1_wiring_test.dart`, `muscle_group_api_mapping_test.dart`.
- UI hardcoded po polsku; brak l10n (skill przygotowany, nieużyty).

---

## 5. Integracja frontend ↔ backend

```mermaid
flowchart LR
  subgraph Flutter["gym_frontend (Stronger)"]
    UI[Screens + Cubits] --> Repos[OfflineFirst*Repository]
    Repos --> Local[(sqflite per-user)]
    Repos --> Sync[Sync engines]
    Sync --> ApiClient[ApiClient + Bearer JWT]
  end
  ApiClient -->|HTTP/JSON /api/v1| Express
  subgraph Backend["gym_backend :3000"]
    Express[Express app] --> Modules[modules/*]
    Modules --> Repo[repositories - raw SQL]
    Repo --> PG[(PostgreSQL 16)]
    Express --> Uploads[/uploads/exercise-images]
  end
```

- Auth: JWT 30 dni, Bearer w każdym requeście chronionym.
- Sync: klient generuje `clientId` (uuid) → serwer upsertuje po `(user_id, client_id)`.
- Wszystkie żądania: `<origin>/api/v1/...`. Historia (timeline) czyta z `GET /api/v1/training-sessions[/:id]` (alias training-history), a synchronizacja sesji z `GET /api/v1/training-sessions/history` (router zapisu ma pierwszeństwo). Cache historii offline to stale-while-revalidate w sqflite (bez `If-None-Match`).
- Kontrakt klient ↔ serwer weryfikują testy `test/e2e/` na prawdziwym backendzie.

---

## 6. Infrastruktura / uruchamianie

### Lokalny dev backendu

```bash
cd gym_backend
docker compose up -d postgres   # PostgreSQL 16 na :5432 (gym/gym)
npm install
npm run dev                     # API na :3000, migracje same się wykonają
```

Całość w kontenerach: `docker compose up -d` (postgres + api, healthchecki, `/health`).

### Frontend

```bash
cd gym_frontend
flutter pub get
flutter run                     # mobile: API pod 10.0.2.2:3000 (emulator)
flutter run -d chrome           # web: API pod localhost:3000
# fizyczne urządzenie: --dart-define=API_BASE_URL=http://<ip-kompa>:3000  (origin, bez /api/v1)
```

### Testy i CI

```bash
flutter analyze && flutter test                                          # E2E pomijane
flutter test integration_test -d flutter-tester                          # przepływ UI
flutter test test/e2e --dart-define=E2E_BASE_URL=http://localhost:3102   # z backendem
```

CI: `.github/workflows/ci.yml` (sekcja 4.6).

> Agent może sam uruchamiać komendy Flutter/Dart (analyze, test, pub) do weryfikacji zmian — zgodnie z `PROJECT.md`.

---

## 7. Stan implementacji vs plany

**Działa (zaimplementowane):**
- auth (register/login/me, JWT), wszystkie wywołania przez `/api/v1`,
- biblioteka ćwiczeń (CRUD, ulubione, upload obrazków, offline sync),
- plany treningowe (CRUD, sync),
- sesje na żywo z timerem odpoczynku (lokalne powiadomienia, wyłączalne w ustawieniach),
- historia treningów (timeline, filtry, paginacja, cache offline) + statystyki tygodnia/miesiąca liczone lokalnie,
- **faza 1** — profil social: edycja profilu (imię, nazwisko, bio, awatar z uploadem), obserwowanie (listy własne i innych użytkowników, wyszukiwarka, profil innej osoby),
- **faza 2** — feed społecznościowy (zakładka Aktywność): posty moje i obserwowanych, kudosy, komentarze, szczegóły posta, propozycje osób,
- **faza 3** — usuwanie, powtarzanie i edycja zakończonych treningów; pull sesji z serwera z nagrobkami (`deleted[]`, 410); usunięty offline trening znika od razu z historii, statystyk, feedu i aktywności profilu,
- **faza 4** — konto: zmiana hasła, wylogowanie ze wszystkich urządzeń, usunięcie konta (z czyszczeniem danych lokalnych i awatarów w cache), globalna obsługa unieważnionej sesji, ekran pomocy,
- **faza 5** — jakość: migracja na `/api/v1`, testy kontraktowe E2E z prawdziwym backendem (`test/e2e/`), test integracyjny UI (`integration_test/`), CI (GitHub Actions), README.
- **onboarding profilu** (spec `docs/superpowers/specs/2026-09-23-registration-onboarding-design.md`) — po rejestracji zdjęcie, nick, bio, prywatne dane o sobie (płeć, data urodzenia, wzrost, waga) i cel; edycja później w „Dane i cele”.

**Mocki / placeholdery:**
- Placeholder: przycisk „Udostępnij” na karcie aktywności profilu (bez akcji), „Zapomniałeś hasła?” na ekranie logowania (bez akcji).

**Braki (gap'e):**
- listy obserwowanych/obserwujących i lista kudosów ładują tylko pierwszą stronę, bez doładowywania,
- cache awatarów usuwanego konta obejmuje tylko adresy widziane w bieżącej sesji aplikacji (po restarcie — dopiero po wejściu na profil),
- test integracyjny nie działa na webie (sqflite ffi) — web weryfikuje job `build-web`; Windows desktop wymaga Visual Studio,
- job E2E w CI wymaga zewnętrznej instancji backendu (`E2E_BASE_URL`),
- brak websocketów, feedu na żywo, wspólnych sesji, push, Sentry,
- waga to jedna bieżąca wartość (bez historii pomiarów); płeć nie wpływa jeszcze na sylwetkę w mapie mięśni; dostępność nicku sprawdzana dopiero przy zapisie.

---

## 8. Skille, reguły agentskie i utrzymanie kontekstu

- **`.cursor/rules/project-context.mdc`** — reguła Cursor: agent aktualizuje ten plik przy istotnych zmianach (moduły, API, stack, struktura, Docker, env).
- `gym_frontend/.agents/skills/` — skille Flutter/Dart (routing, layout, testy, JSON, architektura, code-reviewer).
- `gym_frontend/.cursor_backup/rules/` — backup reguł Cursor (warstwy, UI).
- `gym_frontend/PROJECT.md` — opis produktu i stack dla agentów (dziennik treningowy + social).
- Backend README (`gym_backend/README.md`) — przegląd API `/api/v1`, kontrakt training-history.
- Frontend README (`gym_frontend/README.md`) — uruchomienie, testy (unit, E2E, integracyjne), CI.

---

## 9. Uwagi porządkowe

- Workspace zawiera tylko `gym_backend/` i `gym_frontend/`; worktree'y agentów (jeśli powstaną) sprawdź przed pracą pod kątem niezmergowanych zmian.
- Testy E2E używają wyłącznie osobnej bazy (np. `gym_smoke`), nigdy deweloperskiej `gym`.
