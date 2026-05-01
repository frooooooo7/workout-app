# GYM — opis projektu dla agentów

Ten dokument opisuje produkt i stack techniczny, nad którym pracujemy w tym repozytorium. Agent AI powinien traktować go jako kontekst nadrzędny przy implementacji — razem z regułami w `.cursor/rules` (jeśli istnieją) oraz skillami w `.agents/skills/`.

## Cel aplikacji

Aplikacja mobilna **wzorowana na funkcjonalnościach Stravy**: śledzenie i archiwizacja osiągnięć sportowych oraz udostępnianie ich w formie **wpisów o aktywności**.

**Wyróżnik:** warstwa **społecznościowa** — dzielenie się postępami z innymi użytkownikami i **organizowanie wspólnych sesji treningowych**.

## Zakres funkcjonalny (wysoki poziom)

- Nagrywanie / rejestrowanie aktywności (w tym trasy na mapie tam, gdzie ma to sens).
- Archiwum treningów i podstawowa analityka (np. prędkość, tętno, przewyższenia — zgodnie z dostępnymi danymi).
- Feed lub tablica społecznościowa (wpisy, interakcje — szczegóły do doprecyzowania w backlogu).
- Wspólne sesje (organizacja, zaproszenia, powiadomienia — szczegóły implementacyjne po stronie backendu Node.js).

## Frontend — Flutter

| Obszar | Wybór / narzędzia |
|--------|-------------------|
| Stan | `flutter_bloc` **lub** `Provider` (do uzgodnienia w kodzie; trzymać spójność w całym projekcie). |
| Nawigacja | `go_router` — m.in. głębokie linkowanie (np. powiadomienie → szczegóły treningu / mapa). |
| Mapy | `google_maps_flutter`. |
| GPS | `geolocator` (także scenariusze w tle — uwaga na uprawnienia i limity OS). |
| Trasa na mapie | `flutter_polyline_points`. |
| Wykresy | `fl_chart` (prędkość, tętno, przewyższenia). |
| Obliczenia na współrzędnych | `latlong2`. |
| Cache lokalny / offline-first | `isar` — m.in. zapis treningu w trakcie (odporność na zamknięcie aplikacji) oraz cache feedu społecznościowego. |

**Architektura:** preferuj warstwowy podział (UI / logika prezentacji / dane); w repozytorium są wskazówki w `.agents/skills/flutter-apply-architecture-best-practices/`.

## Backend — Node.js + PostgreSQL

| Obszar | Technologia |
|--------|-------------|
| Runtime / API | **Node.js** (własny serwis HTTP — REST lub podobny kontrakt; kod backendu zwykle w osobnym repozytorium lub podkatalogu). |
| Baza | **PostgreSQL** (własna instancja / hosting) + rozszerzenie **PostGIS** (geometria tras, zapytania przestrzenne). |
| Autoryzacja | Po stronie API (np. JWT, sesje) — szczegół do uzgodnienia z integracją z klientem Flutter; ewentualnie zewnętrzny IdP. |
| Pliki | Dowolny storage obiektowy (np. **S3‑compatible**). |
| Cięższa logika | Ten sam serwis Node.js lub osobne worker’y / kolejki w razie potrzeby skalowania. |

Reguły dostępu do danych społecznościowych i profili implementuj przede wszystkim **w warstwie API**; opcjonalnie wzmocnij model **RLS** w PostgreSQL (defense in depth), jeśli baza jest dostępna tylko dla backendu z jedną rolą techniczną.

## Integracje i jakość

- **Powiadomienia push:** `firebase_messaging`.
- **Błędy i stabilność:** `sentry_flutter`.

## Wskazówki dla agentów

1. Przed większymi zmianami w UI / nawigacji sprawdź skill `flutter-setup-declarative-routing` (jeśli dotyczy).
2. Przy layoutach: `flutter-build-responsive-layout`, `flutter-fix-layout-issues`.
3. Przy testach: odpowiednie skille `flutter-add-widget-test`, `flutter-add-integration-test`, `dart-add-unit-test`.
4. **Nie zakładaj**, że cały zakres Stravy jest w MVP — implementuj to, co wynika z bieżącego zadania i tego dokumentu; niejasności zapisuj w issue / backlogu lub doprecyzuj z zespołem / maintainerami projektu.

## Nazewnictwo repozytorium

Repozytorium może być historycznie opisane jako `workout-app` w `README.md`; **nazwa produktu dla tego opisu to GYM** (aplikacja GYM).
