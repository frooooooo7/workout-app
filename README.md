# GYM Workout App

A mobile application modeled on the functionalities of Strava, designed for tracking and archiving sports achievements, and sharing them as activity posts.

## Key Features

- **Activity Tracking**: Record and log workouts (including GPS/route mapping).
- **History & Analytics**: Workout archive with analytics (speed, heart rate, elevation).
- **Social Feed**: Share progress and interact with other users.
- **Group Sessions**: Organize joint training sessions with invitations.

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
