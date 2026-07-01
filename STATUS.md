# Gym Tracker — Project Status

> **Version: 0.0.0** (Initial Public Release)
>
> **Status: ✅ Working — All four tabs functional, blank database with pre-populated exercise catalogue**
>
> The app builds, passes `flutter analyze` (4 info lints only), passes tests, and the Windows release build succeeds. Ships with a blank `gym_tracker.db` containing 5 body parts and 31 exercise mappings — no personal data. Users can start tracking immediately.

> **Web/Edge Deprecated:** Web/Edge support has been deprecated due to persistent database loading issues with `sqflite_common_ffi_web`. Files archived to `/edge_archive`.

---

## 1. Project Overview

A Flutter-based fitness tracking app targeting both strength and hypertrophy training. It uses a SQLite database (`gym_tracker.db`) bundled as an asset, with a clean architecture / repository pattern and the `provider` package for state management. The database ships with pre-populated body parts and exercise mappings — no personal data included.

| Area | Technology |
|------|-----------|
| Framework | Flutter / Dart (SDK `^3.11.1`) |
| Database | SQLite via `sqflite` (+ `sqflite_common_ffi` for desktop) |
| State management | `provider` (`^6.1.1`) |
| Utilities | `intl` (`^0.19.0`) |
| File sharing | `share_plus` (`^10.1.2`) + `path_provider` (`^2.1.4`) |
| Location / GPS | `geolocator` — **removed** (will re-add for GPS feature) |
| Health data | `health` — **removed** (will re-add for Health Connect feature) |
| Web/Edge | **Deprecated** — files in `/edge_archive` |

---

## 2. Current Capabilities

### Tab 1 — Workout (Log a Session) ✅
- Training mode toggle (Hypertrophy / Strength) with visual indicators
- Date picker (defaults to today)
- Body part multi-select via FilterChips — auto-loads relevant exercises
- Exercise cards with pre-filled weight/reps/sets from last session (style-filtered)
- Body weight field (auto-filled from last session)
- Cardio fields: run distance (km), run time (min), sauna duration (min)
- Free-text notes field
- Save session (creates SESSIONS row + WEIGHT_TRAINING rows for each exercise with weight)
- Reset form button

### Tab 2 — Exercises (Browse & Manage) ✅
- Exercises grouped by body part in ExpansionTiles
- Latest weight/reps/sets displayed per exercise (style-filtered)
- Modify weight via dialog (creates new WEIGHT_TRAINING row — preserves history)
- Weight history dialog (all past entries, newest first)
- Add new exercise via dialog (name, training style, multi-body-part selection, optional initial weight/reps/sets)
- Pull-to-refresh

### Tab 3 — History (Review Sessions) ✅
- All sessions listed in reverse chronological order (Date DESC)
- Each card shows: session ID, date, body parts, training style, run distance/time, sauna, body weight, notes
- Empty state: "No workout history yet"
- Refresh via floating action button
- Session detail view: **not yet implemented** (placeholder)

### Tab 4 — Profile (Body Stats & Settings) ✅
- Body stats add/edit/delete via dialog (date, weight kg, waist in, neck in, notes)
- Body stats listed in reverse chronological order
- Empty state: "No body statistics recorded yet"
- Settings toggles (Notifications, GPS, Health Connect, Auto Backup) — **UI only, not functional**
- Export database button (copies `gym_tracker.db` and shares via system share sheet)
- Refresh data button

### Training Style Independence ✅
- Hypertrophy and Strength weight entries coexist as separate rows
- `getLatestWeightForExercise(exercise, trainingStyle)` filters by style
- Adding a weight with a different style = INSERT (never UPDATE)

### Pre-Populated Seed Data ✅
- **BODY_PARTS:** 5 entries (Legs, Chest, Arms, Back, Shoulders)
- **EXERCISE_BODY_PARTS:** 31 exercise→body-part mappings (including multi-body-part exercises like Tricep dips and Rear delt)
- **SESSIONS, BODY_STATS, WEIGHT_TRAINING:** Empty — no personal data

---

## 3. Database Structure

All date columns use `YYYY/MM/DD` text format. Dart models normalise slashes to dashes when parsing.

### 3.1 SESSIONS — Workout Session Records
| Column | Type | Constraints |
|--------|------|------------|
| ID | INTEGER | PRIMARY KEY AUTOINCREMENT |
| Date | TEXT | NOT NULL (`YYYY/MM/DD`) |
| BodyPart | TEXT | Comma-separated body parts |
| RunDuration | REAL | Run distance in km |
| RunTime | INTEGER | Run time in minutes |
| SaunaDuration | INTEGER | Sauna duration in minutes |
| BodyWeight | REAL | Body weight in kg |
| TrainingStyle | TEXT | 'Hypertrophy' or 'Strength' |
| Other | TEXT | Free-text notes |

### 3.2 BODY_STATS — Body Measurements
| Column | Type | Constraints |
|--------|------|------------|
| ID | INTEGER | PRIMARY KEY AUTOINCREMENT |
| Date | TEXT | NOT NULL (`YYYY/MM/DD`) |
| Weight_kg | REAL | |
| Waist_inches | REAL | |
| Neck_inches | REAL | |
| Notes | TEXT | |

### 3.3 BODY_PARTS — Muscle Group Catalog (pre-populated)
| Column | Type | Constraints |
|--------|------|------------|
| ID | INTEGER | PRIMARY KEY AUTOINCREMENT |
| Name | TEXT | NOT NULL |

Pre-populated: Legs, Chest, Arms, Back, Shoulders

### 3.4 EXERCISE_BODY_PARTS — Exercise-to-BodyPart Mapping (pre-populated)
| Column | Type | Constraints |
|--------|------|------------|
| Exercise | TEXT | Composite PK |
| BodyPart | TEXT | Composite PK |

Many-to-many, style-independent. Adding an exercise with N body parts creates N rows.

### 3.5 WEIGHT_TRAINING — Weight Training Records
| Column | Type | Constraints |
|--------|------|------------|
| ID | INTEGER | PRIMARY KEY AUTOINCREMENT |
| Date | TEXT | `YYYY/MM/DD` |
| TrainingStyle | TEXT | 'Hypertrophy' or 'Strength' |
| Exercises | TEXT | Exercise name |
| Weight | TEXT | Supports ranges like "20-30" |
| Reps | INTEGER | |
| Sets | INTEGER | |

### Table Relationships
```
BODY_PARTS (1) ──< EXERCISE_BODY_PARTS (M) >── (1) EXERCISE_NAME
                                                        |
                                                        └──< WEIGHT_TRAINING (M)
                                                             (filtered by TrainingStyle)
```

---

## 4. Data Layer

### DatabaseHelper ✅
- Singleton pattern
- Copies bundled `gym_tracker.db` from assets on first launch
- FFI initialization for desktop (Windows/macOS/Linux)
- `onOpen` migration: `ALTER TABLE SESSIONS ADD COLUMN RunTime INTEGER` (try/catch — harmless if column exists)
- `PRAGMA foreign_keys = ON`
- Generic CRUD helpers + table introspection methods

### GymRepository ✅
- Full CRUD for all 5 tables
- `getLatestWeightForExercise(exercise, [trainingStyle])` — style-filtered latest weight
- `getExerciseNamesByBodyParts(List<String>)` — exercises matching any of the given body parts
- `getLatestBodyWeight()` — most recent body weight from SESSIONS
- `addExercise(name, bodyParts)` — inserts one row per body part
- `deleteExercise(name)` — removes all body part mappings for an exercise
- `getDatabaseStats()` — row counts per table

### Models ✅
All 5 models with `YYYY/MM/DD` date format:
- `Session` (with runTime field)
- `BodyStat`
- `BodyPart`
- `ExerciseBodyPart`
- `WeightTraining`

### State Management ✅
- `TrainingState` — ChangeNotifier with Hypertrophy/Strength toggle, `currentModeName`, `currentModeColor`, `currentModeDescription`

---

## 5. What's Not Yet Implemented

| Feature | Status |
|---------|--------|
| **Session detail view** | HistoryScreen tap shows placeholder (TODO) |
| **Edit/delete individual sets** | Not implemented |
| **Date-range filter & search** | History has no filter |
| **BMI display** | Not in Profile |
| **Settings persistence** | Toggles don't persist (no SharedPreferences) |
| **GPS running tracking** | Not started; geolocator removed |
| **Health Connect sync** | Not started; health package removed |
| **Personal Best tracking** | Not implemented |
| **Analytics / charts** | Not implemented |
| **Data export/import (JSON/CSV)** | Only database file export works |
| **iOS build & deployment** | Not yet built or published |
| **Web/Edge** | Deprecated — files in `/edge_archive` |

---

## 6. Roadmap

### v0 ✅ DONE — Initial Public Release
- Start Workout flow (session setup, exercises, cardio, notes, save)
- Exercises tab (browse, modify weight, add exercise, weight history)
- History tab (reverse chronological, delete)
- Profile tab (body stats add/edit/delete, database export)
- Training style filtering (Hypertrophy/Strength independent)
- RunTime column in schema
- Blank database with pre-populated exercise catalogue (no personal data)
- Windows release build verified

### v1 (Next) — Session Detail & Polish
- [ ] Session detail screen showing all WeightTraining rows for a session
- [ ] Edit/delete individual sets or entire sessions
- [ ] Date-range filter and search in History
- [ ] BMI display in Profile
- [ ] Persist settings (SharedPreferences)
- [ ] iOS build and App Store deployment

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

## 7. File Inventory

```
lib/
├── main.dart                          # ✅ Entry point (Provider for GymRepository + TrainingState)
├── database/
│   └── database_helper.dart           # ✅ SQLite helper (singleton + FFI + asset copy)
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
│   └── profile_screen.dart            # ✅ Body stats add/edit/delete + export
└── state/
    └── training_state.dart            # ✅ Hypertrophy/strength toggle

assets/
└── databases/
    └── gym_tracker.db                 # ✅ Bundled SQLite database (blank + seed data)

edge_archive/                          # Archived web/Edge files (deprecated)
└── web/
```

---

## 8. Build & Verification

### Windows Release Build
```bash
flutter clean
flutter pub get
flutter build windows --release
```
Output: `build\windows\x64\runner\Release\gym_tracker.exe`

### Android Release Build
```bash
flutter build apk --release
```
Output: `build\app\outputs\flutter-apk\app-release.apk`

### Verification
- `flutter analyze` — 4 info lints only (no errors/warnings)
- `flutter test` — All tests pass
- `python analyze_db.py` — Confirms blank database with correct schema and seed data

> **Important:** Always run `flutter clean` before `flutter run` if you get CMake cache errors about missing `cpp_client_wrapper` files.