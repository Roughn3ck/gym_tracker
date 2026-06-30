# Gym Tracker - Fitness Application

A comprehensive Flutter-based fitness tracking application with advanced features for both strength and hypertrophy training, GPS running tracking, and health data integration.

## Tech Stack

- **Framework**: Flutter / Dart
- **Database**: SQLite with sqflite package (sqflite_common_ffi for desktop)
- **Health Data**: Android Health Connect integration
- **Architecture**: Clean Architecture with Repository Pattern
- **State Management**: Provider

> **Note:** Web/Edge support has been deprecated due to database loading issues
> with `sqflite_common_ffi_web`. The web-related files have been archived to the
> `/edge_archive` directory. The app now targets desktop (Windows, macOS, Linux)
> and mobile (Android, iOS) platforms only.

## Core Features

### 1. Training Mode Toggle
- **Hypertrophy Mode**: ~12 reps, 3 sets (lighter weights)
- **Strength Mode**: ~6 reps, 5 sets (heavier weights)
- Real-time switching between training styles

### 2. Exercises Tab
- Browse exercises grouped by body part (Legs, Chest, Arms, Back, Shoulders)
- View latest weight, training style, reps, and sets for each exercise
- Modify weight — creates a new `WEIGHT_TRAINING` entry with today's date (preserves history)
- View weight history for any exercise
- Add new exercises with multi-body-part selection and training style

### 3. GPS Running Tracking
- Distance tracking in kilometers (Km)
- Route mapping and pace calculation
- Session duration recording

### 4. Health Data Integration
- Android Health Connect synchronization
- Body metrics tracking (weight, measurements)
- Workout data export/import

### 5. Weight Management System
- Machine/exercise catalog by body parts
- Previous weight tracking for quick reference
- Personal Best (PB) tracking per training style
- Session-based weight recording

## Database Structure

The application uses a SQLite database (`kris_gym.db`) bundled as an asset with the following tables:

### Tables:

#### 1. SESSIONS — Workout Session Records
| Column | Type | Constraints |
|--------|------|------------|
| ID | INTEGER | PRIMARY KEY AUTOINCREMENT |
| Date | TEXT | NOT NULL UNIQUE (format: `YYYY/MM/DD`) |
| BodyPart | TEXT | |
| RunDuration | REAL | Running duration in minutes |
| SaunaDuration | INTEGER | Sauna duration in minutes |
| BodyWeight | REAL | Body weight in kg |
| TrainingStyle | TEXT | |
| Other | TEXT | Free-text notes |

#### 2. BODY_STATS — Body Measurements
| Column | Type | Constraints |
|--------|------|------------|
| ID | INTEGER | PRIMARY KEY AUTOINCREMENT |
| Date | TEXT | NOT NULL UNIQUE (format: `YYYY/MM/DD`) |
| Weight_kg | REAL | Body weight in kilograms |
| Waist_inches | REAL | Waist circumference in inches |
| Neck_inches | REAL | Neck circumference in inches |
| Notes | TEXT | Free-text notes |

#### 3. BODY_PARTS — Muscle Group Catalog
| Column | Type | Constraints |
|--------|------|------------|
| ID | INTEGER | PRIMARY KEY AUTOINCREMENT |
| Name | TEXT | NOT NULL UNIQUE |

**Pre-populated values:** Legs, Chest, Arms, Back, Shoulders

#### 4. EXERCISE_BODY_PARTS — Exercise-to-BodyPart Mapping
| Column | Type | Constraints |
|--------|------|------------|
| Exercise | TEXT | Composite PRIMARY KEY with BodyPart |
| BodyPart | TEXT | CHECK (IN ('Legs', 'Chest', 'Arms', 'Back', 'Shoulders')) |

**Relationship:** Many-to-many — one exercise can target multiple body parts (e.g., "Tricep dips" targets both "Chest" and "Arms"). Adding an exercise with multiple body parts creates multiple rows, one per body part.

#### 5. WEIGHT_TRAINING — Weight Training Records
| Column | Type | Constraints |
|--------|------|------------|
| ID | INTEGER | PRIMARY KEY AUTOINCREMENT |
| Date | TEXT | Format: `YYYY/MM/DD` |
| TrainingStyle | TEXT | CHECK (IN ('Hypertrophy', 'Strength')) |
| Exercises | TEXT | Exercise name (matches Exercise in EXERCISE_BODY_PARTS) |
| Weight | TEXT | Weight value (can be a range like "20-30" or single like "40") |
| Reps | INTEGER | Repetitions per set |
| Sets | INTEGER | Number of sets |

**Note:** The `Weight` column is TEXT (not numeric) to support ranges like "20-30". Each weight change creates a new row with the current date, preserving a full history of weight progression.

### Date Format Convention
All date columns use `YYYY/MM/DD` format (e.g., `2025/06/07`). This is consistent across all tables. The Dart models normalise slashes to dashes when parsing with `DateTime.parse()`.

### Table Relationships
```
BODY_PARTS (1) ──< EXERCISE_BODY_PARTS (M) >── (1) EXERCISE_NAME
                                                        |
                                                        └──< WEIGHT_TRAINING (M)
```
- `BODY_PARTS.Name` lists the 5 muscle groups
- `EXERCISE_BODY_PARTS` maps exercise names to body parts (many-to-many)
- `WEIGHT_TRAINING.Exercises` references the exercise name and stores weight/reps/sets over time

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
│   └── gym_repository.dart
├── screens/            # UI screens
│   ├── main_screen.dart
│   ├── active_workout_screen.dart
│   ├── exercises_screen.dart
│   ├── history_screen.dart
│   └── profile_screen.dart
└── state/              # State management
    └── training_state.dart

edge_archive/            # Archived web/Edge files (deprecated)
└── web/
    ├── index.html
    ├── sqlite3.wasm
    ├── sqflite_sw.js
    └── icons/
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
- `sqflite_common_ffi`: SQLite FFI for desktop (Windows/macOS/Linux)
- `path`: File path utilities
- `health`: Health data integration (Apple Health / Google Fit)
- `intl`: Date/time formatting
- `provider`: State management

> **Note:** `geolocator` was removed from dependencies because it blocked the
> Windows desktop build (NuGet `Microsoft.Windows.CppWinRT` unavailable). It
> will be re-added in Phase 4 (GPS running tracking).

## Development Notes

- All measurements use metric system (Kg for weight, Km for distance)
- Database is pre-populated with existing workout data
- On desktop platforms (Windows/macOS/Linux), sqflite_common_ffi is used
  automatically via `sqfliteFfiInit()` in `DatabaseHelper`
- All dates stored as `YYYY/MM/DD` text format in the database
- Strict type safety with Dart null safety
- Web/Edge platform deprecated — files archived to `/edge_archive`

## Future Enhancements

- Progressive Web App (PWA) support
- Cloud synchronization
- Advanced analytics and charts
- Social features and sharing
- Custom workout plans
- GPS running tracking (geolocator to be re-added)