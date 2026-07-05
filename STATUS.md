# Gym Tracker — Project Status

> **App version: 0.1.1** — DB schema version: **3**
>
> **Status: ✅ Working — All four tabs functional, v3 schema with 10 body parts, 43 exercise mappings, external database support, real-time cross-screen updates**
>
> The app builds, passes `flutter analyze` (7 info lints only), and the Windows release build succeeds. Ships with a blank `gym_tracker.db` (v3 template) containing 10 body parts and 43 exercise mappings — no personal data. Users can start tracking immediately.

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
| Key-value storage | `shared_preferences` (`^2.3.0`) — external DB path |
| Cross-screen refresh | `DataRefreshNotifier` (ChangeNotifier) — real-time updates |
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
- **"Train to Expand" exercise pattern** — exercises start collapsed with a "Train" button; tapping expands weight/reps/sets fields; "Complete" collapses to summary; only completed exercises are saved (v0.1.1)
- Body weight field (auto-filled from last session)
- Cardio fields: run distance (km), run time (min), sauna duration (min)
- Free-text notes field
- Save session (creates SESSIONS row with `Workout` + `BodyParts` JSON + only completed WEIGHT_TRAINING rows)
- Reset form button
- **Real-time updates** — saved sessions appear immediately in History and Exercises tabs (via `DataRefreshNotifier`)

### Tab 2 — Exercises (Browse & Manage) ✅
- Exercises grouped by body part in ExpansionTiles (10 categories)
- Latest weight/reps/sets displayed per exercise (style-filtered)
- **Modify weight updates the existing entry** (no longer creates a duplicate row)
- Weight history dialog (all past entries, newest first)
- Add new exercise via dialog (name, training style, multi-body-part selection, optional initial weight/reps/sets)
- Pull-to-refresh
- **Real-time updates** — modifications appear immediately across all tabs (via `DataRefreshNotifier`)

### Tab 3 — History (Review Sessions) ✅
- All sessions listed in reverse chronological order (Date DESC)
- Each card shows: session ID, date, workout description, parsed body parts, training style, run distance/time, sauna, body weight, notes
- Empty state: "No workout history yet"
- Refresh via floating action button
- **Modify session** — edit dialog with all session fields (date, workout, body parts, training style, run distance/time, sauna, body weight, notes)
- **Delete session** — with confirmation dialog
- **Real-time updates** — new sessions appear immediately after save (via `DataRefreshNotifier`)

### Tab 4 — Profile (Body Stats & Settings) ✅
- Body stats add/edit/delete via dialog (date, weight kg, waist in, neck in, notes)
- **Body stats show last 2 by default** with "Load More" / "Show Less" toggle
- Empty state: "No body statistics recorded yet"
- Settings toggles (Notifications, GPS, Health Connect, Auto Backup) — **UI only, not functional**
- **Database Source section** — shows Internal/External mode with Load/Change/Switch buttons
- **Export Database File** — save dialog to copy the internal `.db` to a chosen location
- **Share Database** — copies `gym_tracker.db` and shares via system share sheet
- **Import Database (Replace)** — replaces the internal DB from a `.db` file (with warning if in external mode)
- Refresh data button

### External Database Support ✅ (v0.1.1)
Three modes for database access:
1. **Internal DB (default)** — zero-config; copies bundled `gym_tracker.db` from assets on first launch. Unchanged from v0.1.0.
2. **External DB** — user picks a `.db` file via file picker; the app opens it directly at its filesystem path (no copying). The path is persisted in `SharedPreferences` so the choice survives app restarts. External tools (e.g. an AI coach) can read/write the same file simultaneously.
3. **Export internal DB** — users on the internal DB can save it as a `.db` file to a chosen location via a save dialog (in addition to the existing share flow).

Key design decisions:
- `getDatabasePath()` always returns the **internal** path — import and share/export always operate on the internal DB, never the external one.
- `setExternalDatabase()` validates the file is a v3 Gym Tracker DB (reuses `_validateV3Database`) before switching.
- `setExternalDatabase()` fixes legacy UNIQUE constraint on SESSIONS.Date (via `_fixSessionsUniqueConstraint`) when loading older external databases.
- `_loadDbSourceInfo()` calls `loadPersistedPath()` before reading `isExternal` — ensures correct display on app restart.
- If the external file is deleted while the app is closed, `_resolvePath()` falls back to internal mode.
- On Android, `file_picker` v8 returns a cached filesystem path — no `content://` URI workaround needed.

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
- External DB support: `setExternalDatabase()`, `useInternalDatabase()`, `loadPersistedPath()`, `_resolvePath()` (v0.1.1)
- `_fixSessionsUniqueConstraint()` — removes legacy UNIQUE constraint on SESSIONS.Date when loading external DBs
- `getDatabasePath()` always returns internal path (import/export never touch external DB)
- Reuses `_validateV3Database()` for external DB validation
- Generic CRUD helpers + table introspection methods

### GymRepository ✅
- Full CRUD for all 5 tables
- `getLatestWeightForExercise(exercise, [trainingStyle])` — style-filtered latest weight
- `getExerciseNamesByBodyParts(List<String>)` — exercises matching any of the given body parts
- `getLatestBodyWeight()` — most recent body weight from SESSIONS
- `addExercise(name, bodyParts)` — inserts one row per body part
- `deleteExercise(name)` — removes all body part mappings for an exercise
- `getDatabaseStats()` — row counts per table
- Exposed `isExternal`, `externalDbPath`, `setExternalDatabase`, `useInternalDatabase`

### Models ✅
All 5 models with `YYYY/MM/DD` date format and null-safe `fromMap()`:
- `Session` — fields: `workout` (free-text), `bodyParts` (JSON array string), plus run/cardio/weight/training fields
- `BodyStat`
- `BodyPart`
- `ExerciseBodyPart`
- `WeightTraining`

### State Management ✅
- `TrainingState` — ChangeNotifier with Hypertrophy/Strength toggle, `currentModeName`, `currentModeColor`, `currentModeDescription`
- `DataRefreshNotifier` — ChangeNotifier with `refreshCount` counter for cross-screen real-time updates (v0.1.1)

---

## 5. What's Not Yet Implemented

| Feature | Status |
|---------|--------|
| **Date-range filter & search** | History has no filter |
| **BMI display** | Not in Profile |
| **Settings persistence** | Toggles don't persist (SharedPreferences used only for external DB path) |
| **GPS running tracking** | Not started; geolocator removed |
| **Health Connect sync** | Not started; health package removed |
| **Personal Best tracking** | Not implemented |
| **Analytics / charts** | Not implemented |
| **Data export/import (JSON/CSV)** | Database file export works (share + save); JSON/CSV not yet |
| **iOS build & deployment** | Not yet built or published |
| **Web/Edge** | Deprecated — files in `/edge_archive` |

---

## 6. Known Issues

None — the Windows build now succeeds cleanly with the standard sequence (`flutter clean && flutter pub get && flutter build windows --release`). The previous `cpp_client_wrapper` `.cc` file issue has been resolved.

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

### v0.1.1 ✅ DONE — External Database Support & Fine-tuning
- Added `shared_preferences` dependency for persisting the external DB path
- `DatabaseHelper`: external path support (`setExternalDatabase`, `useInternalDatabase`, `loadPersistedPath`, `_resolvePath`), reuses `_validateV3Database` for validation
- `DatabaseHelper`: `_fixSessionsUniqueConstraint()` — removes legacy UNIQUE constraint on SESSIONS.Date when loading external DBs
- `GymRepository`: exposed `isExternal`, `externalDbPath`, `setExternalDatabase`, `useInternalDatabase`
- Profile screen: new Database Source section (Internal/External mode display, Load/Change/Switch buttons)
- Profile screen: renamed buttons — "Share Database" (was Export), "Export Database File" (new save dialog), "Import Database (Replace)" (was Import)
- Profile screen: body stats "Load More" (show 2 by default, expand on tap)
- Profile screen: fixed external DB display on reopen (calls `loadPersistedPath` before reading `isExternal`)
- Import-while-external warning dialog
- Android: added `WRITE_EXTERNAL_STORAGE` + `READ_EXTERNAL_STORAGE` permissions, `requestLegacyExternalStorage`
- `getDatabasePath()` always returns internal path (import/export never touch the external DB)
- Archived v0.1.0 source to `archive/v0.1.0/`
- **"Train to Expand" exercise pattern** — exercises start collapsed; only completed exercises saved
- **Exercises: modify weight updates existing row** (no more duplicates)
- **History: modify/delete session** with full edit dialog
- **Real-time cross-screen updates** via `DataRefreshNotifier` (new ChangeNotifier)
- **Tab state persistence** — `IndexedStack` in `MainScreen` keeps all tabs alive
- **Null-safe model `fromMap()`** — handles nullable columns in imported databases

### v1 (Next) — Remaining Polish
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
├── main.dart                          # ✅ Entry point (Provider for GymRepository + TrainingState + DataRefreshNotifier)
├── database/
│   └── database_helper.dart           # ✅ SQLite helper (singleton + FFI + asset copy, schema v3, external DB, UNIQUE fix)
├── models/
│   ├── body_part.dart                 # ✅ (null-safe fromMap)
│   ├── body_stat.dart                 # ✅ (YYYY/MM/DD dates)
│   ├── exercise_body_part.dart        # ✅ (null-safe fromMap)
│   ├── session.dart                   # ✅ (workout + bodyParts JSON, YYYY/MM/DD)
│   └── weight_training.dart           # ✅ (YYYY/MM/DD dates, null-safe fromMap)
├── repositories/
│   └── gym_repository.dart            # ✅ Full CRUD + style-filtered queries + external DB API
├── screens/
│   ├── active_workout_screen.dart     # ✅ Workout form (Train-to-Expand pattern, 10 body part chips)
│   ├── exercises_screen.dart          # ✅ Browse/modify/add with style filtering, real-time refresh
│   ├── history_screen.dart            # ✅ Reverse chronological, modify/delete session, real-time refresh
│   ├── main_screen.dart               # ✅ 4-tab shell (IndexedStack — tabs persist)
│   └── profile_screen.dart            # ✅ Body stats (Load More), export, external DB UI, real-time refresh
└── state/
    ├── training_state.dart            # ✅ Hypertrophy/strength toggle
    └── data_refresh_notifier.dart     # ✅ Cross-screen real-time refresh (v0.1.1)

assets/
└── databases/
    └── gym_tracker.db                 # ✅ Bundled SQLite database (v3 template)

archive/
└── v0.0.0/                            # ✅ Pre-v0.1.0 source snapshot
└── v0.1.0/                            # ✅ Pre-v0.1.1 source snapshot (DB + lib/ + pubspec.yaml)

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
flutter build windows --release
```
Output: `build\windows\x64\runner\Release\gym_tracker.exe`

### Android Release Build
```bash
flutter build apk --release
```
Output: `build\app\outputs\flutter-apk\app-release.apk`

### Verification
- `flutter analyze` — 7 info lints only (no errors/warnings)
- `flutter test` — All tests pass
- `python analyze_db.py` — Confirms v3 schema: 10 body parts, 43 exercise mappings, Workout + BodyParts columns