# Gym Tracker — Project Status

> **App version: 0.1.0** — DB schema version: **3**
>
> **Status: ✅ Working — All four tabs functional, v3 schema with 10 body parts, 43 exercise mappings**
>
> The app builds, passes `flutter analyze` (4 info lints only), and the Windows release build succeeds. Ships with a blank `gym_tracker.db` (v3 template) containing 10 body parts and 43 exercise mappings — no personal data. Users can start tracking immediately.

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
- **Workout** free-text field for workout description (e.g. "push day", "chest and bis")
- Body part multi-select via FilterChips (10 categories) — auto-loads relevant exercises
- Exercise cards with pre-filled weight/reps/sets from last session (style-filtered)
- Body weight field (auto-filled from last session)
- Cardio fields: run distance (km), run time (min), sauna duration (min)
- Free-text notes field
- Save session (creates SESSIONS row with `Workout` + `BodyParts` JSON + WEIGHT_TRAINING rows)
- Reset form button

### Tab 2 — Exercises (Browse & Manage) ✅
- Exercises grouped by body part in ExpansionTiles (10 categories)
- Latest weight/reps/sets displayed per exercise (style-filtered)
- Modify weight via dialog (creates new WEIGHT_TRAINING row — preserves history)
- Weight history dialog (all past entries, newest first)
- Add new exercise via dialog (name, training style, multi-body-part selection, optional initial weight/reps/sets)
- Pull-to-refresh

### Tab 3 — History (Review Sessions) ✅
- All sessions listed in reverse chronological order (Date DESC)
- Each card shows: session ID, date, workout description, parsed body parts, training style, run distance/time, sauna, body weight, notes
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
- **BODY_PARTS:** 10 entries (Quads, Hamstrings, Calves, Glutes, Chest, Biceps, Triceps, Back, Shoulders, Abs)
- **EXERCISE_BODY_PARTS:** 43 exercise→body-part mappings (33 unique exercises, many multi-body-part)
- **SESSIONS, BODY_STATS, WEIGHT_TRAINING:** Empty — no personal data

---

## 3. Database Structure

All date columns use `YYYY/MM/DD` text format. Dart models normalise slashes to dashes when parsing.

### 3.1 SESSIONS — Workout Session Records
| Column | Type | Constraints |
|--------|------|------------|
| ID | INTEGER | PRIMARY KEY AUTOINCREMENT |
| Date | TEXT | NOT NULL (`YYYY/MM/DD`) |
| Workout | TEXT | Free-text workout description |
| BodyParts | TEXT | JSON array of canonical body part names (e.g. `["Chest","Biceps"]`) |
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

Pre-populated: Quads, Hamstrings, Calves, Glutes, Chest, Biceps, Triceps, Back, Shoulders, Abs

### 3.4 EXERCISE_BODY_PARTS — Exercise-to-BodyPart Mapping (pre-populated)
| Column | Type | Constraints |
|--------|------|------------|
| Exercise | TEXT | Composite PK |
| BodyPart | TEXT | Composite PK, `CHECK (BodyPart IN ('Quads','Hamstrings','Calves','Glutes','Chest','Biceps','Triceps','Back','Shoulders','Abs'))` |

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

SESSIONS.Workout    → free-text description
SESSIONS.BodyParts  → JSON array referencing BODY_PARTS.Name
```

---

## 4. Data Layer

### DatabaseHelper ✅
- Singleton pattern
- Copies bundled `gym_tracker.db` from assets on first launch
- FFI initialization for desktop (Windows/macOS/Linux)
- `_databaseVersion = 3`
- `onOpen`: `PRAGMA foreign_keys = ON` only (legacy v1→v2 RunTime migration removed in v0.1.0)
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
- `Session` — fields: `workout` (free-text), `bodyParts` (JSON array string), plus run/cardio/weight/training fields
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

## 6. Known Issues

### ⚠️ Windows Build: `cpp_client_wrapper` `.cc` Files Not Regenerated by `flutter pub get`

**Symptoms:**
```
error C1083: Cannot open source file: '...\cpp_client_wrapper\core_implementations.cc': No such file or directory
```
All C++ compilation fails — the Windows build cannot proceed.

**Root cause:**
The `windows/flutter/ephemeral/cpp_client_wrapper/*.cc` source files are generated artifacts (gitignored) that should be copied from the Flutter SDK engine cache by `flutter pub get`. On this project's setup, `flutter pub get` regenerates the `include/` subdirectory but **not** the `.cc` files. The build only succeeds when pre-compiled object files are cached in `build/` (hiding the problem). A `flutter clean` exposes it.

**Current workaround (applied successfully in v0.1.0 session):**
Manually copy the `.cc` files from the Flutter SDK cache after `flutter pub get`:
```bash
flutter clean
flutter pub get
# pub get doesn't regenerate the .cc files — copy them manually
SDK_CACHE="/c/Users/krisr/AppData/Roaming/flutter/bin/cache/artifacts/engine/windows-x64/cpp_client_wrapper"
cp "$SDK_CACHE"/*.cc windows/flutter/ephemeral/cpp_client_wrapper/
cp -r "$SDK_CACHE/include" windows/flutter/ephemeral/cpp_client_wrapper/
flutter build windows --release
```
The build then succeeds normally.

**Proper fix — investigation plan for next session:**

| # | Investigation step | Details |
|---|---|---|
| 1 | **Check `generated_config.cmake`** | Read `windows/flutter/ephemeral/generated_config.cmake` — it's regenerated by `pub get` and should reference the engine artifact paths. If the `cpp_client_wrapper` source path is wrong or missing, this is the root cause. |
| 2 | **Check Flutter SDK engine cache integrity** | `flutter doctor -v` reports the engine artifact hash. Compare with what's in `bin/cache/artifacts/engine/windows-x64/cpp_client_wrapper/`. If the SDK cache is corrupt, `flutter doctor` or `flutter precache --windows` may fix it. |
| 3 | **Run `flutter precache --windows`** | Forces re-download of Windows engine artifacts. This should repopulate the SDK cache and may cause `pub get` to correctly copy the `.cc` files on next run. **Try this first** — it's the least invasive fix. |
| 4 | **Compare with a fresh Flutter project** | `flutter create test_app && cd test_app && flutter pub get` — check if `windows/flutter/ephemeral/cpp_client_wrapper/*.cc` are generated correctly. If they are, the issue is project-specific (likely a stale `ephemeral/` or CMake state). If not, it's an environment/SDK issue. |
| 5 | **Check `windows/flutter/CMakeLists.txt`** | The CMake build file references `ephemeral/cpp_client_wrapper/` sources. If the glob or include path is wrong, the files won't be found even if physically present. Compare with the fresh project's CMakeLists.txt. |
| 6 | **Check `windows/CMakeLists.txt` for stale `build/` references** | `flutter clean` wipes `build/` but if `CMakeLists.txt` or a generated `.cmake` caches a path from a previous build, it may point to deleted files. A full `build/` delete + rebuild tests this. |
| 7 | **Flutter version bump** | Current SDK is 3.41.4 (4 months old). If steps 1–6 don't resolve it, `flutter upgrade` to latest stable may fix a known regression in the ephemeral file generation. |

**Expected outcome:** After the proper fix, the standard build sequence (`flutter clean && flutter pub get && flutter build windows --release`) should work without manual file copying. The workaround above can be removed once confirmed.

---

## 7. Roadmap

### v0 ✅ DONE — Initial Public Release
- Start Workout flow (session setup, exercises, cardio, notes, save)
- Exercises tab (browse, modify weight, add exercise, weight history)
- History tab (reverse chronological, delete)
- Profile tab (body stats add/edit/delete, database export)
- Training style filtering (Hypertrophy/Strength independent)
- RunTime column in schema
- Blank database with pre-populated exercise catalogue (no personal data)
- Windows release build verified

### v0.1 ✅ DONE — Expanded Body Part Taxonomy & Schema v3
- Expanded body part taxonomy from 5 → 10 categories (Legs→Quads/Hamstrings/Calves/Glutes, Arms→Biceps/Triceps, +Abs)
- SESSIONS: renamed `BodyPart` → `Workout` (free-text), added `BodyParts` (JSON array)
- EXERCISE_BODY_PARTS: CHECK constraint on BodyPart enforcing canonical names
- Re-mapped 33 exercises across 43 mappings
- `_databaseVersion` bumped 2 → 3, removed legacy v1→v2 `onOpen` migration
- Workout tab: new Workout text field, reordered layout (Date → Workout → Body Parts → Body Weight)
- History tab: displays Workout + parsed Body Parts (JSON decode with null/empty-array handling)
- Regenerated `assets/databases/gym_tracker.db` via updated `create_db.py`
- Archived v0 source to `archive/v0.0.0/`
- Removed stale extension-less tracked files from `lib/`
- Added `archive/**` exclusion to `analysis_options.yaml`

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

## 8. File Inventory

```
lib/
├── main.dart                          # ✅ Entry point (Provider for GymRepository + TrainingState)
├── database/
│   └── database_helper.dart           # ✅ SQLite helper (singleton + FFI + asset copy, schema v3)
├── models/
│   ├── body_part.dart                 # ✅
│   ├── body_stat.dart                 # ✅ (YYYY/MM/DD dates)
│   ├── exercise_body_part.dart        # ✅
│   ├── session.dart                   # ✅ (workout + bodyParts JSON, YYYY/MM/DD)
│   └── weight_training.dart           # ✅ (YYYY/MM/DD dates)
├── repositories/
│   └── gym_repository.dart            # ✅ Full CRUD + style-filtered queries
├── screens/
│   ├── active_workout_screen.dart     # ✅ Workout form (Workout field + 10 body part chips)
│   ├── exercises_screen.dart          # ✅ Browse/modify/add with style filtering
│   ├── history_screen.dart            # ✅ Reverse chronological, workout + parsed body parts
│   ├── main_screen.dart               # ✅ 4-tab shell
│   └── profile_screen.dart            # ✅ Body stats add/edit/delete + export
└── state/
    └── training_state.dart            # ✅ Hypertrophy/strength toggle

assets/
└── databases/
    └── gym_tracker.db                 # ✅ Bundled SQLite database (v3 template)

archive/
└── v2/                                # ✅ Pre-v0.1.0 source snapshot (DB + lib/ + pubspec.yaml)

edge_archive/                           # Archived web/Edge files (deprecated)
└── web/

create_db.py                            # ✅ Regenerates assets/databases/gym_tracker.db (v3 schema + seed)
analyze_db.py                           # ✅ Inspects bundled database (schema + row counts)
analysis_options.yaml                   # ✅ Flutter analyzer config (excludes archive/**)
```

---

## 9. Build & Verification

### Windows Release Build
```bash
flutter clean
flutter pub get
# NOTE: See Known Issues (Section 6) if cpp_client_wrapper .cc files are missing after pub get
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
- `python analyze_db.py` — Confirms v3 schema: 10 body parts, 43 exercise mappings, Workout + BodyParts columns

> **Important:** If the Windows build fails with `C1083: Cannot open source file` errors for `cpp_client_wrapper/*.cc`, see [Section 6 — Known Issues](#6-known-issues) for the workaround and fix plan.
