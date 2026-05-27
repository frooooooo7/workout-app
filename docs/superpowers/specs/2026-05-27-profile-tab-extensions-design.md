# Spec: Rozszerzenia zakładki Profil

**Data:** 2026-05-27  
**Ostatnia aktualizacja:** 2026-05-27  
**Status:** Fazy 0 i 1 zrealizowane — następna: Faza 2 (Social)  
**Repozytoria:** `gym` (Flutter), `gym-backend` (Node/Express)

---

## Cel dokumentu

Research i roadmap funkcjonalności dla zakładki **Profil**. Dokument opisuje stan obecny, zrealizowane fazy, luki oraz plan dalszego rozwoju.

---

## Postęp implementacji

| Faza | Status | Uwagi |
|------|--------|-------|
| **Faza 0** — Quick wins | ✅ Zrobione | Wejście „Znajdź osoby” w AppBar ekranu Obserwowani (nie na głównym profilu) |
| **Faza 1** — Edycja profilu | ✅ Zrobione | Avatar, imię, nazwisko, handle, bio + ekran edycji |
| **Faza 2** — Social | ⏳ Do zrobienia | Follow, kudos, komentarze |
| **Faza 3** — Statystyki | ⏳ Do zrobienia | PR, streak, wykresy |
| **Faza 4** — Ustawienia konta | ⏳ Do zrobienia | Hasło, powiadomienia, prywatność |
| **Faza 5** — Nice-to-have | ⏳ Do zrobienia | Cele, zdjęcia z treningu, itd. |

### Infrastruktura (poza fazami)

| Element | Status |
|---------|--------|
| CORS dla `/uploads/*` (Flutter Web) | ✅ Naprawione — statyczne pliki za middleware `cors()` + `crossOriginResourcePolicy` |
| Docker volume `uploads_data` → `/app/uploads` | ✅ Pliki avatara/ćwiczeń przetrwają rebuild kontenera |
| `docker-entrypoint.sh` | ✅ Tworzy katalogi uploadów i ustawia uprawnienia `node` |

---

## Faza 0 — Zrealizowane

### Zakres (po decyzji produktowej)

| Zrobione | Szczegóły |
|----------|-----------|
| **Wejście „Znajdź osoby”** | Ikona `person_add_outlined` w AppBar ekranu **Obserwowani** → `/app/profile/find-people` |
| **Margines ikony** | `padding: EdgeInsets.only(right: 12)` — ikona nie przyklejona do krawędzi |

### Świadomie NIE zrobione (Faza 0)

| Wykluczone | Powód |
|------------|-------|
| `FollowingAvatarStrip` na głównym profilu | Decyzja UX — pasek nie na ekranie głównym |
| Ujednolicenie danych Profil ↔ Home | Home będzie przebudowane osobno |
| Spięcie stat „Treningi” z prawdziwymi danymi | Poza zakresem |

**Pliki:** `following_list_screen.dart`, test `FollowingListScreen shows find people action in app bar`

---

## Faza 1 — Zrealizowane

### Backend

| Endpoint / element | Opis |
|--------------------|------|
| `PATCH /profile/me` | `bio`, `firstName`, `lastName`, `handle` (walidacja + normalizacja, `handle_taken` → 409) |
| `POST /profile/me/avatar` | Multipart upload, max 5 MB, JPG/PNG/WEBP |
| Storage | Pliki na dysku: `uploads/avatar-images/<uuid>.ext` |
| DB | Tylko ścieżka w `users.avatar_url` (TEXT) — **nie** binarny blob |
| Serwowanie | `GET /uploads/avatar-images/...` via `express.static` |

**Pliki:** `profile.schemas.ts`, `profile.repository.ts`, `profile.service.ts`, `profile.controller.ts`, `profile.routes.ts`, `profile.avatar-upload.ts`, `profile.handle.ts`

### Frontend

| Element | Opis |
|---------|------|
| **Ekran edycji** | `/app/profile/edit` — `EditProfileScreen` |
| **Pola** | Avatar (galeria), imię, nazwisko, `@handle`, bio, email (read-only) |
| **Wejścia** | Ustawienia → „Edytuj profil”; tap na avatarze na własnym profilu |
| **Po zapisie** | `requestProfileRefresh()` + sync `ServiceLocator.currentUser` (imię/nazwisko) |
| **URL avatara** | `resolveApiAssetUrl()` — relative path → pełny URL API |
| **Błędy API** | Polskie komunikaty w `profile_form_utils.dart` |

**Pliki:** `edit_profile_screen.dart`, `api_profile_repository.dart`, `profile_update_input.dart`, `api_asset_uri.dart`, `app_routes.dart`, `profile_settings_screen.dart`, `profile_hero_header.dart`

### Testy

- Backend: `profile.routes.test.ts` (PATCH rozszerzone, handle conflict, avatar schema)
- Flutter: `profile_form_utils_test.dart`, `profile_screen_test.dart`

---

## Stan obecny (po Fazach 0 + 1)

### Co działa

| Element | Szczegóły |
|---------|-----------|
| Hero header | Avatar (upload lub inicjały), imię, `@handle`, edytowalne bio, tap avatar → edycja |
| Statystyki | Obserwowani / Obserwujący / Treningi (Treningi → mockowa Aktywność) |
| Feed aktywności | Z API, highlight + lista |
| Listy social | Following (+ ikona Znajdź osoby), followers, wyszukiwanie |
| Edycja profilu | Pełny ekran + upload avatara |
| Ustawienia | Edytuj profil, read-only imię/email, wylogowanie |
| Odświeżanie | Po treningu + po edycji profilu |

### Co jest tylko „na pokaz” / do zrobienia

| Element | Status |
|---------|--------|
| `FollowingAvatarStrip` | Widget gotowy, **nieużywany** na głównym profilu |
| Follow/unfollow | SnackBar „wkrótce” |
| Kudos, komentarze, share | Puste handlery |
| Powiadomienia, zmiana hasła, pomoc | **Wkrótce** w ustawieniach |
| Home + Aktywność | Mocki — nie spięte z profilem |

### Endpointy API (profil)

| Method | Path | Opis |
|--------|------|------|
| GET | `/profile/me` | Własny profil + stats |
| PATCH | `/profile/me` | `bio`, `firstName`, `lastName`, `handle` |
| POST | `/profile/me/avatar` | Upload avatara (multipart) |
| GET | `/profile/following` | Lista obserwowanych |
| GET | `/profile/followers` | Lista obserwujących |
| GET | `/profile/activities` | Ostatnie treningi |
| GET | `/users/search` | Wyszukiwanie |
| GET | `/users/:userId/profile` | Profil innego użytkownika |
| GET | `/users/:userId/activities` | Aktywność innego użytkownika |
| GET | `/uploads/avatar-images/:file` | Statyczny plik avatara |

**Brak:** follow/unfollow, kudos, komentarze, zmiana hasła, powiadomienia.

### Przechowywanie zdjęć

```
Upload → dysk (uploads/avatar-images/) → w DB tylko TEXT (ścieżka)
Docker: volume uploads_data montowany w /app/uploads
```

---

## Proponowany układ docelowy ekranu profilu

```
┌─────────────────────────────────────┐
│  [Avatar]  Imię Nazwisko     ⚙️     │  ← tap avatar → edycja (Faza 1 ✅)
│  @handle                            │
│  Bio (tap to edit)                  │
│  [Obserwujący] [Obserwowani] [🏋️]   │  ← Obserwowani → lista + Znajdź (Faza 0 ✅)
├─────────────────────────────────────┤
│  📊 Ten tydzień / PR / streak       │  ← Faza 3
├─────────────────────────────────────┤
│  ⭐ Ostatni trening (highlight)     │
├─────────────────────────────────────┤
│  Twoja aktywność          Zobacz →  │
│  [karty z kudos/komentarzami]       │  ← Faza 2
└─────────────────────────────────────┘
```

---

## Roadmap — pozostałe fazy

### Faza 2 — Social

| Funkcja | Backend |
|---------|---------|
| Follow / unfollow | `POST/DELETE /users/:id/follow` |
| Status relacji | `isFollowing`, `followsYou` w profilu |
| Kudos | Tabela `activity_kudos` |
| Komentarze | Tabela `activity_comments` |
| Udostępnianie | Share sheet (`share_plus`), bez backendu na start |

**Szacunek:** 1–2 tygodnie.

---

### Faza 3 — Statystyki osobiste

| Funkcja | Źródło |
|---------|--------|
| Podsumowanie tygodnia / miesiąca | Agregacja `training_sessions` |
| Seria treningowa (streak) | Daty sesji |
| Rekordy osobiste (PR) | Dane z sesji |
| Ulubione ćwiczenia / plany | Agregacja |
| Wykres objętości | Chart 4–8 tygodni |
| Osiągnięcia / odznaki | Reguły + `achievements` |

**Szacunek:** 2–3 tygodnie.

---

### Faza 4 — Ustawienia konta

| Funkcja | Status |
|---------|--------|
| Zmiana hasła | Wkrótce → `POST /auth/change-password` |
| Powiadomienia | Wkrótce → preferencje |
| Prywatność profilu | Brak |
| Ukrywanie statystyk | Brak |
| Eksport danych (GDPR) | Brak |
| Usunięcie konta | Brak |
| Pomoc / FAQ | Wkrótce |

**Szacunek:** ~1 tydzień na hasło + prywatność.

---

### Faza 5 — Nice-to-have

- Cele treningowe (np. 3 treningi/tydzień)
- Notatka pod treningiem w feedzie
- Zdjęcia z treningu
- Porównanie ze znajomymi
- QR kod profilu
- Motyw / jednostki / i18n
- Integracje (Apple Health, Google Fit)

---

## Priorytetyzacja (zaktualizowana)

| Priorytet | Pakiet | Status |
|-----------|--------|--------|
| ~~**P0**~~ | ~~Faza 0 + find people~~ | ✅ |
| ~~**P1**~~ | ~~Avatar + edycja profilu~~ | ✅ |
| **P0** | Faza 2 — follow/unfollow + kudos | Następny krok |
| **P1** | Faza 3 — statystyki (PR, streak) | |
| **P2** | Faza 4 — hasło, prywatność, powiadomienia | |
| **P3** | Faza 5 — nice-to-have | |

---

## Zależności techniczne (backend)

```
users (+ privacy fields)     ← Faza 4
user_follows                 ← istnieje, brak write API (Faza 2)
activity_kudos               ← Faza 2
activity_comments            ← Faza 2
user_achievements            ← Faza 3
user_notification_prefs      ← Faza 4
avatar storage (filesystem)  ← ✅ Faza 1 (uploads/avatar-images + Docker volume)
/stats/summary               ← Faza 3
```

---

## Ryzyka i uwagi

1. **Niespójność danych Home ↔ Profil** — odroczone do przebudowy Home.
2. **Stat „Treningi” → mockowa Aktywność** — bez zmian.
3. **Social bez follow** — kudosy i komentarze sensowne dopiero w Fazie 2.
4. **Avatar na produkcji** — obecnie lokalny filesystem + Docker volume; na skalę → S3/CDN.
5. **`docker compose down -v`** — usuwa volume `uploads_data` wraz z plikami.
6. **Podział profil vs ustawienia** — edycja profilu w `/app/profile/edit`; hasło/prywatność w ustawieniach (Faza 4).

---

## Następny krok

**Faza 2 — Social:** follow/unfollow, status relacji, kudos (opcjonalnie komentarze).
