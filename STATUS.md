# Gym Tracker — Project Status

> **Version: 0.0.0** (Initial Working Version)
>
> **Status: ✅ Working — Start Workout, Exercises, History, and Profile tabs functional**
>
> The app builds, passes `flutter analyze` (2 info lints only), passes tests, and Windows build succeeds. All core features for v0 are implemented: Start Workout flow, exercise management with training style filtering, session history, body stats recording.

> **Web/Edge Deprecated:** Web/Edge support has been deprecated due to persistent
> database loading issues with `sqflite_common_ffi_web`. Files archived to `/edge_archive`.

---

## 1. Project Overview

A Flutter-based fitness tracking app (see [`README.md`](README.md)) targeting both strength and hypertrophy training. It uses a pre-existing SQLite database (`kris_gym.db`) bundled as an asset, with a clean architecture / repository pattern and the `provider` package for state management.

| Area | Technology |
|------|-----------|
| Framework | Flutter / Dart (SDK `^3.11.1`) |
| Database | SQLite via `sqflite` (+ `sqflite_common_ffi` for desktop) |
| State management | `provider` (`^6.1.1`) |
| Location / GPS | `geolocator` — **removed** (will re-add for GPS feature) |
| Health data | `health` (`13.3.1`) — **declared but unused** |
| Utilities | `intl` (`^0.19.0`) |
| Web/Edge | **Deprecated** — files in `/edge_archive` |

---

## 2. Database Structure

All date columns use `YYYY/MM/DD` text format. Dart models normalise slashes to dashes when parsing.

### 2.1 SESSIONS — Workout Session Records
| Column | Type | Constraints |
|--------|------|------------|
| ID | INTEGER | PRIMARY KEY AUTOINCREMENT |
| Date | TEXT | NOT NULL UNIQUE (`YYYY/MM/DD`) |
| BodyPart | TEXT | Selected body part(s), comma-separated |
| RunDuration | REAL | Run distance in km |
| RunTime | INTEGER | Run time in minutes (added via ALTER TABLE in v0) |
| SaunaDuration | INTEGER | Sauna duration in minutes |
| BodyWeight | REAL | Body weight in kg |
| TrainingStyle | TEXT | 'Hypertrophy' or 'Strength' |
| Other | TEXT | Free-text notes |

### 2.2 BODY_STATS — Body Measurements
| Column | Type | Constraints |
|--------|------|------------|
| ID | INTEGER | PRIMARY KEY AUTOINCREMENT |
| Date | TEXT | NOT NULL UNIQUE (`YYYY/MM/DD`) |
| Weight_kg | REAL | |
| Waist_inches | REAL | |
| Neck_inches | REAL | |
| Notes | TEXT | |

### 2.3 BODY_PARTS — Muscle Group Catalog
| Column | Type | Constraints |
|--------|------|------------|
| ID | INTEGER | PRIMARY KEY AUTOINCREMENT |
| Name | TEXT | NOT NULL UNIQUE |

Pre-populated: Legs, Chest, Arms, Back, Shoulders

### 2.4 EXERCISE_BODY_PARTS — Exercise-to-BodyPart Mapping
| Column | Type | Constraints |
|--------|------|------------|
| Exercise | TEXT | Composite PK |
| BodyPart | TEXT | CHECK (IN ('Legs', 'Chest', 'Arms', 'Back', 'Shoulders')), Composite PK |

Many-to-many, style-independent. Adding an exercise with N body parts creates N rows.

### 2.5 WEIGHT_TRAINING — Weight Training Records
| Column | Type | Constraints |
|--------|------|------------|
| ID | INTEGER | PRIMARY KEY AUTOINCREMENT |
| Date | TEXT | `YYYY/MM/DD` |
| TrainingStyle | TEXT | CHECK (IN ('Hypertrophy', 'Strength')) |
| Exercises | TEXT | Exercise name |
| Weight | TEXT | Can be a range like "20-30" or single like "40" |
| Reps | INTEGER | |
| Sets | INTEGER | |

### Training Style Independence
Hypertrophy and Strength entries for the same exercise coexist as separate rows. `getLatestWeightForExercise(exercise, trainingStyle)` filters by style.

### Table Relationships
```
BODY_PARTS (1) ──< EXERCISE_BODY_PARTS (M) >── (1) EXERCISE_NAME
                                                        |
                                                        └──< WEIGHT_TRAINING (M)
                                                             (filtered by TrainingStyle)
```

---

## 3. What Works (v0 Features)

### Data layer
- **`DatabaseHelper`** — singleton, copies bundled DB from assets, FFI for desktop, ALTER TABLE migration for RunTime column ✅
- **`GymRepository`** — full CRUD for all 5 tables + `getLatestWeightForExercise(exercise, [trainingStyle])`, `getExerciseNamesByBodyParts()`, `getLatestBodyWeight()`, `addExercise()`, `deleteExercise()`, `deleteBodyStat()` ✅

### Models
All 5 models with `YYYY/MM/DD` date format: `Session` (with runTime), `BodyStat`, `BodyPart`, `ExerciseBodyPart`, `WeightTraining` ✅

### State management
- **`TrainingState`** — Hypertrophy/strength toggle (ChangeNotifier) ✅

### UI (4-tab shell)
- **`MainScreen`** — 4-tab BottomNavigationBar (Workout, Exercises, History, Profile) ✅
- **`ActiveWorkoutScreen`** — Start Workout form: mode toggle, date picker, body part multi-select, auto-loaded exercises with style-filtered pre-filled weights, run distance/time, sauna, notes, save ✅
- **`ExercisesScreen`** — Browse by body part, style-filtered latest weights, modify weight, weight history, add exercise with multi-body-part selection ✅
- **`HistoryScreen`** — Reverse chronological, compact, delete with confirmation ✅
- **`ProfileScreen`** — Body stats add/edit/delete, settings toggles ✅

### Training Style Filtering
- Exercises and Workout screens filter weights by current training style ✅
- Hypertrophy and Strength entries coexist (no overwriting) ✅

---

## 4. What's Not Yet Implemented

| Feature | Status |
|---------|--------|
| **Session detail view** | HistoryScreen Modify shows placeholder |
| **GPS running tracking** | Not started; geolocator removed |
| **Health Connect sync** | Not started; health package unused |
| **Personal Best tracking** | Not implemented |
| **Settings persistence** | Toggles don't persist (no SharedPreferences) |
| **Data export / import** | SnackBar stub |
| **Analytics / charts** | Not implemented |
| **Web/Edge** | Deprecated — files in `/edge_archive` |

---

## 5. Roadmap

### v0 ✅ DONE — Initial Working Version
- Start Workout flow (session setup, exercises, cardio, notes, save)
- Exercises tab (browse, modify weight, add exercise, weight history)
- History tab (reverse chronological, delete)
- Profile tab (body stats add/edit/delete)
- Training style filtering (Hypertrophy/Strength independent)
- RunTime column migration
- Run label fix (km not min)

### v1 (Next) — Session Detail & Polish
- [ ] Session detail screen showing all WeightTraining rows
- [ ] Edit/delete individual sets or entire sessions
- [ ] Date-range filter and search in History
- [ ] BMI display in Profile
- [ ] Persist settings (SharedPreferences)

### v2 — GPS Running
- [ ] Re-add geolocator dependency
- [ ] Request location permissions
- [ ] Live run screen: distance, duration, pace
- [ ] Save run as Session

### v3 — Health Connect
- [ ] Wire up health package with permission flows
- [ ] Import body weight/metrics into BODY_STATS

### v4 — Analytics & Enhancements
- [ ] Personal Best tracking per exercise per training style
- [ ] Analytics dashboard with charts
- [ ] Data export/import (JSON / CSV)
- [ ] Full test suite
- [ ] Cloud synchronization

---

## 6. File Inventory

```
lib/
├── main.dart                          # ✅ Entry point (Provider for GymRepository)
├── database/
│   └── database_helper.dart           # ✅ SQLite helper (singleton + FFI + ALTER TABLE)
├── models/
│   ├── body_part.dart                 # ✅
│   ├── body_stat.dart                 # ✅ (YYYY/MM/DD dates)
│   ├── exercise_body_part.dart        # ✅
│   ├── session.dart                   # ✅ (YYYY/MM/DD + runTime field)
│   └── weight_training.dart           # ✅ (YYYY/MM/DD dates)
├── repositories/
│   └── gym_repository.dart            # ✅ Full CRUD + style-filtered queries
├── screens/
│   ├── active_workout_screen.dart     # ✅ Start Workout form
│   ├── exercises_screen.dart          # ✅ Browse/modify/add with style filtering
│   ├── history_screen.dart            # ✅ Reverse chronological, delete
│   ├── main_screen.dart               # ✅ 4-tab shell
│   └── profile_screen.dart            # ✅ Body stats add/edit/delete
└── state/
    └── training_state.dart            # ✅ Hypertrophy/strength toggle

edge_archive/                          # Archived web/Edge files (deprecated)
└── web/
```

---

## 7. Quick Start

```bash
flutter clean
flutter pub get
flutter run -d windows
```

> **Important:** Always run `flutter clean` before `flutter run` if you get CMake cache errors about missing `cpp_client_wrapper` files.