# Spec: Rozszerzenia zakładki Profil

**Data:** 2026-05-27  
**Status:** Zatwierdzony do planowania implementacji  
**Repozytoria:** `gym` (Flutter), `gym-backend` (Node/Express)

---

## Cel dokumentu

Research i roadmap funkcjonalności dla zakładki **Profil**. Dokument opisuje stan obecny, luki, proponowane fazy rozwoju oraz **zakres Fazy 0** przekazany do osobnego agenta implementacyjnego.

### Wyłączenia z Fazy 0 (decyzja produktowa)

Następujące pozycje z pierwotnej Fazy 0 **nie wchodzą** w bieżący zakres implementacji:

| Wykluczone | Powód |
|------------|-------|
| Ujednolicenie danych Profil ↔ Home | Zakładka Home będzie przebudowana osobno |
| Spięcie statystyki „Treningi” z prawdziwymi danymi / podmiana mockowej zakładki Aktywność | Poza zakresem Fazy 0 |

---

## Stan obecny

Profil jest zaprojektowany jako **społecznościowy profil treningowy**: hero, statystyki, feed aktywności z prawdziwych sesji treningowych. Sporo elementów jest gotowych w UI, ale niepodpiętych lub oznaczonych jako „Wkrótce”.

### Co działa

| Element | Szczegóły |
|---------|-----------|
| Hero header | Avatar (inicjały lub `avatarUrl`), imię, `@handle`, edytowalne bio, ikona ustawień |
| Statystyki | Obserwowani → `/app/profile/following`, Obserwujący → `/app/profile/followers`, Treningi → `/app/activity` |
| Feed aktywności | Z API (`training_sessions`), highlight + lista, tap → `/app/training/history/:sessionId` |
| Listy social | Following, followers, wyszukiwanie użytkowników |
| Ustawienia | Read-only imię/email, wylogowanie |
| Odświeżanie | Po zakończeniu treningu via `ServiceLocator.profileRefreshTick` |

### Kluczowe pliki (frontend)

| Plik | Rola |
|------|------|
| `lib/features/profile/presentation/screens/profile_screen.dart` | Główna zakładka Profil |
| `lib/features/profile/presentation/bloc/profile_cubit.dart` | Stan + wywołania API |
| `lib/features/profile/presentation/widgets/following_avatar_strip.dart` | Pasek obserwowanych — **gotowy, nieużywany na ekranie** |
| `lib/features/profile/presentation/screens/find_people_screen.dart` | Wyszukiwanie — route istnieje, brak wejścia z UI |
| `lib/features/profile/presentation/screens/profile_settings_screen.dart` | Ustawienia (stuby „Wkrótce”) |
| `lib/features/profile/data/api_profile_repository.dart` | Mapowanie HTTP |

### Kluczowe pliki (backend)

| Plik | Rola |
|------|------|
| `src/modules/profile/profile.routes.ts` | Endpointy profilu |
| `src/modules/profile/profile.service.ts` | Logika + formatowanie |
| `src/db/migrate.ts` | Tabele `users`, `user_follows` |

### Co jest tylko „na pokaz”

| Element | Status |
|---------|--------|
| `FollowingAvatarStrip` | Zbudowany, testowany, **nie renderowany** w `ProfileScreen` |
| `ProfileCubit` ładuje `following` | Dane pobierane, **nieużywane w UI** |
| `/app/profile/find-people` | Route bez CTA na żywym profilu |
| Follow/unfollow | SnackBar „wkrótce” na `user_profile_screen`, `find_people_screen` |
| Kudos, komentarze, share | Puste handlery w `profile_activity_post_card.dart` |
| Powiadomienia, zmiana hasła, pomoc | `profile_settings_screen.dart` — **Wkrótce** |
| `avatarUrl` | W DB/modelu, brak uploadu |
| `handle` | Generowany przy rejestracji, brak edycji |
| Home + Aktywność | Mocki (86.4 km, 6752 kcal) — **nie spięte z profilem** |

### Model danych

**Frontend — `UserProfile`:** `id`, `firstName`, `lastName`, `handle`, `bio?`, `avatarUrl?`, `stats`, `isOwnProfile`  
**Frontend — `ProfileStats`:** `followingCount`, `followersCount`, `workoutsCount`  
**Backend — `users`:** core auth + `handle`, `bio`, `avatar_url`  
**Backend — `user_follows`:** istnieje, brak write API

### Istniejące endpointy API

| Method | Path | Opis |
|--------|------|------|
| GET | `/profile/me` | Własny profil + stats |
| PATCH | `/profile/me` | Aktualizacja `bio` |
| GET | `/profile/following` | Lista obserwowanych |
| GET | `/profile/followers` | Lista obserwujących |
| GET | `/profile/activities` | Ostatnie treningi |
| GET | `/users/search` | Wyszukiwanie |
| GET | `/users/:userId/profile` | Profil innego użytkownika |
| GET | `/users/:userId/activities` | Aktywność innego użytkownika |

**Brak:** follow/unfollow, avatar upload, kudos, komentarze, zmiana hasła, powiadomienia.

---

## Proponowany układ docelowy ekranu profilu

```
┌─────────────────────────────────────┐
│  [Avatar]  Imię Nazwisko     ⚙️     │
│  @handle                            │
│  Bio (tap to edit)                  │
│  [Obserwujący] [Obserwowani] [🏋️]   │
├─────────────────────────────────────┤
│  👥 Pasek obserwowanych → Znajdź    │  ← Faza 0
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

## Roadmap faz

### Faza 0 — Quick wins (zakres implementacji)

**W zakresie** (plan implementacji — osobny agent):

| Funkcja | Opis | Uwagi |
|---------|------|-------|
| **Pasek obserwowanych** | Integracja `FollowingAvatarStrip` w `ProfileScreen` | `ProfileCubit` już ładuje `following` |
| **Wejście „Znajdź osoby”** | CTA do `/app/profile/find-people` | Pasek + empty state już to wspierają |

**Poza zakresem Fazy 0:**

- Ujednolicenie danych Profil ↔ Home
- Spięcie stat „Treningi” z prawdziwymi danymi / podmiana mockowej zakładki Aktywność

**Szacunek:** ~1 dzień frontend, bez nowych endpointów backendowych.

---

### Faza 1 — Edycja profilu

| Funkcja | Backend |
|---------|---------|
| Upload avatara | `POST /profile/me/avatar` + storage |
| Edycja imienia / nazwiska | `PATCH /profile/me` |
| Edycja handle | Walidacja unikalności |
| Ekran „Edytuj profil” | Flutter settings + hero |

**Szacunek:** 3–5 dni.

---

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

## Priorytetyzacja

| Priorytet | Pakiet | ROI |
|-----------|--------|-----|
| **P0** | Faza 0 (pasek + find people) + follow/unfollow | Domyka obiecany social UX |
| **P1** | Avatar + edycja profilu + zmiana hasła | Solidne konto |
| **P2** | Kudos + statystyki (PR, streak) | Engagement |
| **P3** | Komentarze, prywatność, powiadomienia | Skala social |
| **P4** | Osiągnięcia, cele, zdjęcia | Retencja |

---

## Zależności techniczne (backend — przyszłe fazy)

```
users (+ privacy fields)
user_follows          ← istnieje, brak write API
activity_kudos        ← Faza 2
activity_comments     ← Faza 2
user_achievements     ← Faza 3
user_notification_prefs ← Faza 4
avatar storage        ← Faza 1
/stats/summary        ← Faza 3
```

---

## Ryzyka i uwagi

1. **Niespójność danych Home ↔ Profil** — świadomie odroczone do przebudowy Home.
2. **Stat „Treningi” → mockowa Aktywność** — pozostaje do czasu osobnej decyzji produktowej.
3. **Social bez follow** — kudosy i komentarze sensowne dopiero po Fazie 2.
4. **Avatar** — wymaga storage/CDN; osobna infrastruktura w Fazie 1.
5. **Podział profil vs ustawienia** — statystyki i feed na profilu; konto i prywatność w ustawieniach.

---

## Następny krok

**Implementacja Fazy 0** — osobny agent tworzy plan implementacji (`writing-plans`) dla:

- integracji `FollowingAvatarStrip` w `ProfileScreen`
- wejścia do `/app/profile/find-people`

**Bez:** ujednolicenia z Home, spięcia stat Treningi z prawdziwymi danymi.
