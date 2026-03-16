# Gym Tracker - Fitness Application

A comprehensive Flutter-based fitness tracking application with advanced features for both strength and hypertrophy training, GPS running tracking, and health data integration.

## Tech Stack

- **Framework**: Flutter / Dart
- **Database**: SQLite with sqflite package
- **Location**: Geolocator package for GPS tracking
- **Health Data**: Android Health Connect integration
- **Architecture**: Clean Architecture with Repository Pattern

## Core Features

### 1. Training Mode Toggle
- **Hypertrophy Mode**: ~12 reps, 3 sets (lighter weights)
- **Strength Mode**: ~6 reps, 5 sets (heavier weights)
- Real-time switching between training styles

### 2. GPS Running Tracking
- Distance tracking in kilometers (Km)
- Route mapping and pace calculation
- Session duration recording

### 3. Health Data Integration
- Android Health Connect synchronization
- Body metrics tracking (weight, measurements)
- Workout data export/import

### 4. Weight Management System
- Machine/exercise catalog by body parts
- Previous weight tracking for quick reference
- Personal Best (PB) tracking per training style
- Session-based weight recording

## Database Schema

The application uses an existing SQLite database (`kris_gym.db`) with the following tables:

### Tables:
1. **SESSIONS** - Workout session records
2. **BODY_STATS** - Body measurements and metrics
3. **BODY_PARTS** - Catalog of muscle groups
4. **EXERCISE_BODY_PARTS** - Exercise-to-body-part mapping
5. **WEIGHT_TRAINING** - Weight training session details

## Project Structure

```
lib/
├── main.dart              # Application entry point
├── database/             # Database layer
│   └── database_helper.dart
├── models/              # Data models
│   ├── session.dart
│   ├── body_stat.dart
│   ├── body_part.dart
│   ├── exercise_body_part.dart
│   └── weight_training.dart
├── repositories/        # Data access layer
│   ├── session_repository.dart
│   ├── body_stat_repository.dart
│   ├── body_part_repository.dart
│   ├── exercise_repository.dart
│   └── weight_training_repository.dart
├── services/           # Business logic
│   └── training_service.dart
└── utils/              # Utilities
    └── constants.dart
```

## Setup Instructions

1. **Clone the repository**
2. **Install dependencies**:
   ```bash
   flutter pub get
   ```
3. **Run the application**:
   ```bash
   flutter run
   ```

## Dependencies

- `sqflite`: SQLite database operations
- `path`: File path utilities
- `geolocator`: GPS location services
- `health_connect`: Android Health Connect integration
- `flutter_riverpod`: State management (optional)

## Development Notes

- All measurements use metric system (Kg for weight, Km for distance)
- Database is pre-populated with existing workout data
- Focus on backend/data layer first, UI to follow
- Strict type safety with Dart null safety

## Future Enhancements

- Progressive Web App (PWA) support
- Cloud synchronization
- Advanced analytics and charts
- Social features and sharing
- Custom workout plans