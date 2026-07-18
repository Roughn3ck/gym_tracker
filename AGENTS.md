# AGENTS.md — Gym Tracker

> **Instructions for AI coding agents (Forge, Cline, Claude Code, etc.) working on this repository.**

## Project Overview

Flutter-based fitness tracking app for logging strength and hypertrophy workouts, body stats, and session history. SQLite persistence with a clean repository pattern and Provider state management.

**Current version:** `0.1.1+1` (pubspec.yaml) — DB schema `v3`

## Tech Stack

| Area | Technology |
|------|-----------|
| Framework | Flutter / Dart (SDK `^3.11.1`) |
| Database | SQLite via `sqflite` + `sqflite_common_ffi` (desktop FFI) |
| State management | `provider` (`^6.1.1`) |
| Cross-screen refresh | `DataRefreshNotifier` (ChangeNotifier) |
| Utilities | `intl` (`^0.19.0`) |
| File sharing | `share_plus` (`^10.1.2`) + `path_provider` (`^2.1.4`) |
| Key-value storage | `shared_preferences` (`^2.3.0`) — external DB path |
| File picker | `file_picker` (`^8.0.6`) |

## Architecture

```
lib/
├── main.dart                          # Entry point — MultiProvider (GymRepository, TrainingState, DataRefreshNotifier)
├── database/
│   └── database_helper.dart           # SQLite singleton — internal/external DB modes, v3 validation, FFI init
├── models/
│   ├── body_part.dart                 # Muscle group (10 canonical)
│   ├── body_stat.dart                 # Body measurements (weight, waist, neck)
│   ├── exercise_body_part.dart        # Exercise → body part mapping
│   ├── session.dart                   # Workout session (Workout text + BodyParts JSON + cardio + body weight)
│   └── weight_training.dart           # Weight logging (per exercise, per training style)
├── repositories/
│   └── gym_repository.dart           # Full CRUD — thin wrapper over DatabaseHelper
├── screens/
│   ├── active_workout_screen.dart     # Tab 1: Log a session (Train-to-Expand pattern)
│   ├── exercises_screen.dart          # Tab 2: Browse/manage exercises, style-filtered
│   ├── history_screen.dart            # Tab 3: Session history (reverse chronological)
│   ├── main_screen.dart               # 4-tab shell (IndexedStack — tabs persist in memory)
│   └── profile_screen.dart            # Tab 4: Body stats, DB source, export/import
└── state/
    ├── training_state.dart            # Hypertrophy/strength toggle
    └── data_refresh_notifier.dart     # Broadcast signal — all screens reload on change
```

## Database Schema (v3)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `SESSIONS` | Workout session records | `ID`, `Date` (TEXT `YYYY/MM/DD`), `Workout` (TEXT), `BodyParts` (JSON array TEXT), `RunDistance` (REAL km), `RunTime` (INTEGER min), `SaunaDuration` (INTEGER min), `BodyWeight` (REAL kg), `TrainingStyle` (TEXT), `Other` (TEXT) |
| `BODY_STATS` | Body measurements | `ID`, `Date`, `Weight_kg`, `Waist_inches`, `Neck_inches`, `Notes` |
| `BODY_PARTS` | 10 canonical muscle groups | `ID`, `Name` |
| `EXERCISE_BODY_PARTS` | Exercise → body part mapping | `Exercise` (TEXT), `BodyPart` (TEXT) — composite PK, CHECK constraint enforces 10 canonical names |
| `WEIGHT_TRAINING` | Weight logging | `ID`, `Date`, `TrainingStyle`, `Exercises`, `Weight`, `Reps`, `Sets` |

### Critical Database Conventions

- **Dates are `YYYY/MM/DD` text** — NOT ISO 8601. `toMap()` outputs `YYYY/MM/DD`; `fromMap()` normalises slashes to dashes via `_parseDate()`.
- **`BodyParts` is a JSON array string** — e.g. `["Chest","Biceps","Triceps"]`. Parsed with `jsonDecode` for display.
- **Training styles are independent** — `WEIGHT_TRAINING` stores separate rows for Hypertrophy vs Strength. Adding the same exercise with a different style = INSERT (never UPDATE). `EXERCISE_BODY_PARTS` is style-independent.
- **`DatabaseHelper` is a singleton** — `_database` is cached. External DB mode persists the path in `SharedPreferences` under key `external_db_path`.
- **`getDatabasePath()` always returns the internal path** — export/import/share always target the internal DB, never the external one.
- **External DB validation** — `_validateV3Database()` checks required tables, SESSIONS columns (Workout + BodyParts signature), and exact 10 canonical body part names before switching.

### The 10 Canonical Body Parts

```
Quads, Hamstrings, Calves, Glutes, Chest,
Biceps, Triceps, Back, Shoulders, Abs
```

These are enforced by a CHECK constraint in `EXERCISE_BODY_PARTS` and validated on external DB import.

## UI Patterns

- `Provider.of<GymRepository>(context, listen: false)` for data access in async methods
- `Provider.of<DataRefreshNotifier>(context, listen: true)` in `build()` — screens compare `refreshCount` to their last-seen value and reload via `addPostFrameCallback`
- `IndexedStack` in `MainScreen` — all 4 tabs stay alive in memory (state persists)
- Lists in reverse chronological order (`orderBy: 'Date DESC'`)
- Dialogs for add/edit, `PopupMenuButton` for delete/modify actions
- `FilterChip` for multi-select (body parts), `ExpansionTile` for grouped display
- `SingleChildScrollView` for forms, error states with retry button

### DataRefreshNotifier — Critical Pattern

Any mutation that changes DB data MUST call `context.read<DataRefreshNotifier>().notifyDataChanged()` after the write succeeds. This causes all mounted screens to reload via their `build()` listener.

**Known gotcha:** After switching the database connection itself (`setExternalDatabase` or `useInternalDatabase`), you must also fire `notifyDataChanged()` — the screens don't auto-detect a connection swap.

## Build & Development

### Prerequisites

- Flutter 3.44+ (stable channel)
- For Windows builds: Visual Studio with C++ workload, CMake
- For Linux builds: `clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev`
- For Android builds: Android SDK

### Commands

```bash
# Analyse (must pass with 0 errors/warnings — info lints are acceptable)
flutter analyze

# Get dependencies
flutter pub get

# Windows release build
flutter build windows --release
# Output: build/windows/x64/runner/Release/gym_tracker.exe

# Linux release build
flutter build linux --release

# Android APK
flutter build apk --release
```

### Build Troubleshooting

- `flutter clean` before `flutter build` if CMake cache errors occur
- If platform files are missing (`windows/CMakeLists.txt`, etc.), run `flutter create --platforms=windows .` to regenerate generated files — but do NOT delete the project-level CMakeLists.txt files (they are tracked in git and are NOT auto-generated)

## Code Style

- Zero warnings from `flutter analyze` (info-level lints acceptable)
- Null-safe `fromMap()` factories on all models
- `replace_in_file` for small edits, `write_to_file` for new files
- Always verify with `flutter analyze` after changes

## What NOT To Do

- **Do NOT add web/Edge support** — deprecated, files in `/edge_archive`
- **Do NOT re-add `geolocator`** — removed (blocked Windows builds); will return with GPS feature
- **Do NOT re-add `health` package** — removed (was unused); will return with Health Connect feature
- **Do NOT delete platform scaffolding** (`windows/`, `macos/`, `linux/`, `ios/`, `android/`) — these are tracked in git and required for native builds
- **Do NOT use ISO 8601 dates** — the DB uses `YYYY/MM/DD` text format throughout
- **Do NOT mix training styles in one `WEIGHT_TRAINING` row** — separate rows per style

## Versioning

- Semantic versioning in `pubspec.yaml`: `MAJOR.MINOR.PATCH+BUILD`
- DB schema version tracked in `database_helper.dart` (`_databaseVersion`)
- Update `README.md` and `STATUS.md` when introducing new versions
- Bundled `assets/databases/gym_tracker.db` is always a blank v3 template (no personal data)

## File Inventory

| File | Purpose |
|------|---------|
| `lib/` | Application source (15 Dart files) |
| `assets/databases/gym_tracker.db` | Blank v3 DB template (bundled with app) |
| `android/` | Android platform code |
| `ios/` | iOS platform code |
| `linux/` | Linux platform code |
| `windows/` | Windows platform code (CMakeLists.txt + runner) |
| `macos/` | macOS platform code (Xcode project + runner) |
| `archive/` | Archived v0.0.0 source (excluded from analysis) |
| `edge_archive/` | Deprecated web/Edge files |
| `README.md` | User-facing documentation |
| `STATUS.md` | Detailed project status and capabilities |
| `.clinerules` | Legacy Cline rules (superseded by this file) |
| `analysis_options.yaml` | Flutter analysis config (excludes `archive/**`, `edge_archive/**`) |