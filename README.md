# GYM (Stronger)

**Dziennik treningowy siłowego** z funkcjami społecznościowymi — planowanie treningów, rejestrowanie sesji, historia postępów oraz dzielenie się wynikami z innymi użytkownikami.

## Key Features

- **Training diary**: Custom plans, live workout sessions (sets, reps, weight, rest timer), workout history and stats.
- **Exercise library**: Built-in and custom exercises with offline sync.
- **Social**: User profiles, follow lists, activity feed, search.
- **Offline-first**: Local SQLite storage with background sync to the backend API.

Out of scope: running, cycling, GPS routes, maps, heart rate, speed, or elevation tracking.

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Dart SDK
- Android SDK / Xcode (for mobile emulation/builds)

### Setup

1. Clone the repository:
   ```bash
   git clone <repository-url>
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run
   ```

## Project Structure

The project follows a layered feature-first architecture:
- **Presentation**: UI widgets, state management (BLoC/Cubit), pages.
- **Domain**: Entities, use cases, repository contracts.
- **Data**: Data sources (local/remote API), models, repository implementations.

See also `PROJECT.md` (Polish, agent-oriented) and `../PROJECT_CONTEXT.md` in the workspace root.
