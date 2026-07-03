# Gym Tracker

A Flutter-based fitness tracking app for logging strength and hypertrophy workouts, monitoring body stats, and reviewing session history. Ships with a pre-populated exercise catalogue — no personal data, works out of the box.

**Current release: `v0.1.0`** (DB schema `v3`) — see [What's New](#whats-new) below.

---

## What's New

### v0.1.0 — Expanded Body Part Taxonomy & Schema v3

This release overhauls the muscle-group model from a coarse 5-category list to a precise 10-category one, and introduces a clean separation between a free-text workout description and the canonical body parts trained.

**Body part taxonomy: 5 → 10**

| v0.0.0 (old) | v0.1.0 (new) |
|---|---|
| Legs | **Quads, Hamstrings, Calves, Glutes** |
| Arms | **Biceps, Triceps** |
| Chest | Chest (unchanged) |
| Back | Back (unchanged) |
| Shoulders | Shoulders (unchanged) |
| — | **Abs** (new) |

**SESSIONS table — two column changes:**
- **Renamed** `BodyPart` → `Workout` (TEXT) — now stores the original free-text workout description (e.g. `"chest and bis"`), decoupled from the canonical taxonomy.
- **Added** `BodyParts` (TEXT) — stores a JSON array of canonical body part names taken from `BODY_PARTS` (e.g. `["Chest","Biceps","Triceps"]`).

**EXERCISE_BODY_PARTS table:**
- Added a `CHECK (BodyPart IN (...))` constraint enforcing the 10 canonical names, preventing typos and stale taxonomy entries.
- Re-mapped all 33 exercises across the new taxonomy (43 mappings total — several exercises target multiple refined groups, e.g. *Squat* → Quads + Hamstrings + Glutes; *Bent over dumbbell row* → Back + Biceps + Triceps).

**Schema versioning:**
- `_databaseVersion` bumped `2` → `3` in `database_helper.dart`.
- Removed the legacy v1→v2 `onOpen` migration (`ALTER TABLE SESSIONS ADD COLUMN RunTime`) — v3 ships a clean template DB; no in-place migrations.
- The asset DB is regenerated from `create_db.py`, so the bundled `.db` is always the v3 template.

**UI:**
- **Workout tab** gains a dedicated **Workout** free-text field (below Date, above Body Parts chips), and the chip grid now reflects all 10 categories. Body part selection is serialised to the `BodyParts` JSON column on save.
- **History tab** renders `Workout: <text>` and a parsed, comma-joined `Body Parts:` line. Empty/null body parts render nothing (no orphaned "Body Parts:" header).
- **Exercises tab** automatically reflects the 10 categories (it reads `BODY_PARTS` dynamically — no code change needed).

**Cleanup:**
- Removed four stale, extension-less tracked files under `lib/` (legacy copies from a prior tooling iteration).
- `archive/v0.0.0/` holds the pre-migration source (DB + `lib/` tree + `pubspec.yaml`) for reference.
- `analysis_options.yaml` excludes `archive/**` from analysis so frozen archived code doesn't fail `flutter analyze`.

> **Not a breaking change for the build:** no dependency or pubspec changes. Existing v0.0.0 databases on a user's device are *not* auto-migrated — the app copies the bundled v3 template on first launch into a fresh location. See [Database Structure](#database-structure).

---

## Releases & Installation

### Android

1. **Download the APK** from the [GitHub Releases page](https://github.com/Roughn3ck/gym_tracker/releases).
2. On your phone, open **Settings → Security** and enable **"Install unknown apps"** for your browser or file manager.
3. Open the downloaded `.apk` file and tap **Install**.
4. Launch **Gym Tracker** from your app drawer.

> **Requirements:** Android 5.0 (API 21) or higher.

### Windows

1. **Download the ZIP** from the [GitHub Releases page](https://github.com/Roughn3ck/gym_tracker/releases).
2. Extract the ZIP to a folder of your choice (e.g., `C:\GymTracker`).
3. Run `gym_tracker.exe` from the extracted folder.

> **Requirements:** Windows 10 x64 or higher. No installation required — it's a portable app.

### Build from Source (Developers)

```bash
flutter clean
flutter pub get
flutter build windows --release       # Windows
flutter build apk --release           # Android
flutter build ios --release           # iOS (requires macOS + Xcode)
```

> **Important:** Always run `flutter clean` before `flutter run` if you get CMake cache errors.

---

## Using the App

The app has four tabs at the bottom: **Workout**, **Exercises**, **History**, and **Profile**.

### Tab 1 — Workout (Log a Session)

This is the main screen for recording a workout session.

1. **Training Mode Toggle** — At the top, a card shows your current training mode. Tap **"Switch to Strength/Hyper"** to toggle between:
   - **Hypertrophy** — ~12 reps / 3 sets, focus on muscle growth (purple)
   - **Strength** — ~6 reps / 5 sets, focus on maximal strength (blue)

2. **Session Setup** — Set the details for this session:
   - **Date** — Tap the date field to open a date picker. Defaults to today.
   - **Workout** — Free-text description of the workout (e.g. `"chest and bis"`, `"push day"`). Optional.
   - **Body Parts** — Tap one or more filter chips (Quads, Hamstrings, Calves, Glutes, Chest, Biceps, Triceps, Back, Shoulders, Abs) to select which muscle groups you're training. Selecting body parts automatically loads the relevant exercises below.
   - **Body Weight (kg)** — Enter your current body weight. Auto-filled from your last session if available.

3. **Exercises** — Once you select body parts, exercise cards appear with fields for:
   - **Weight (kg)** — Pre-filled with your last recorded weight for the current training style (if any). Shows "Last: X kg" hint.
   - **Reps** — Pre-filled from your last session.
   - **Sets** — Pre-filled from your last session.
   - Leave the weight blank to skip saving that exercise.

4. **Cardio & Recovery** — Optional fields:
   - **Run Dist (km)** — Distance run.
   - **Run Time (min)** — Time taken.
   - **Sauna Duration (min)** — Time in the sauna.

5. **Notes** — Free-text field for anything else (e.g., "Run 2: 3km, 15min").

6. **Save Session** — Tap the blue **Save Session** button. You'll see a "Session saved!" confirmation. Tap **Reset Form** to clear everything and start fresh.

### Tab 2 — Exercises (Browse & Manage)

Browse the exercise catalogue, view and update weights, and add new exercises.

1. **Browse** — Exercises are grouped by body part in expandable sections (Quads, Hamstrings, Calves, Glutes, Chest, Biceps, Triceps, Back, Shoulders, Abs). Tap a section to expand it.
2. **View Latest Weight** — Each exercise shows its latest recorded weight, training style, reps, and sets (e.g., "40 kg | Hypertrophy | 12x4"). Exercises with no recorded weight show "No weight recorded yet".
3. **Modify Weight** — Tap the **⋮ (three-dot menu)** next to an exercise and select **Modify Weight**. Enter the new weight and save. This creates a new weight record (preserving history) with today's date and your current training style.
4. **Weight History** — Tap the **⋮ menu** and select **Weight History** to see all past weight entries for that exercise, sorted by date (newest first).
5. **Add Exercise** — Tap the **＋ (floating action button)** in the bottom-right corner. Fill in:
   - **Exercise Name** — The name of the exercise.
   - **Training Style** — Hypertrophy or Strength (dropdown).
   - **Body Parts** — Select one or more body parts (an exercise can target multiple, e.g., "Tricep dips" targets both Chest and Triceps).
   - **Initial Weight (optional)** — Starting weight in kg.
   - **Reps / Sets** — Optional initial values.
   - Tap **Save** to add the exercise to the catalogue.

### Tab 3 — History (Review Sessions)

View all past workout sessions in reverse chronological order (newest first).

- Each session card shows: Session ID, date, workout description, body parts trained, training style, run distance/time, sauna duration, body weight, and any notes.
- Tap the **refresh button** (floating action button) to reload history.
- If no sessions exist yet, you'll see "No workout history yet".
- Session detail view (drill-down into individual exercises within a session) is planned for a future release.

### Tab 4 — Profile (Body Stats & Settings)

Track body measurements and manage app settings.

1. **Body Statistics** — Record and review body measurements over time:
   - **Add** — Tap **"Add"** or the **＋ (floating action button)**. Enter date, weight (kg), waist (inches), neck (inches), and optional notes. Tap **Save**.
   - **Edit** — Tap the **⋮ menu** next to an entry and select **Modify**.
   - **Delete** — Tap the **⋮ menu** and select **Delete** (with confirmation).
   - Each entry shows date, weight, waist, neck, and notes.

2. **Settings** — Toggles for Notifications, GPS Tracking, Health Connect, and Auto Backup. These are UI placeholders for now (not yet functional).

3. **Export Database** — Tap **Export Database** to share a copy of your `gym_tracker.db` file via the system share sheet (e.g., email, cloud drive, messaging). Useful for backups.

4. **Refresh Data** — Tap **Refresh Data** to reload body stats from the database.

---

## Pre-Populated Exercise Catalogue

The app ships with 10 body parts and 43 exercise mappings (33 unique exercises):

| Body Part | Exercises |
|-----------|-----------|
| **Quads** | Squat, Leg press, Deadlift machine, Leg extension |
| **Hamstrings** | Squat, Leg press, Deadlift machine, Hamstring curl |
| **Calves** | Seated calf raise, Leg press Calf raise |
| **Glutes** | Squat, Leg press, Deadlift machine |
| **Chest** | Chest press, Dumbbell chest press, Chest fly machine, Cable flys (decline), Inclined Chest flys, Tricep dips |
| **Biceps** | Bent over dumbbell row, Cable bicep curl, Preacher curls, Incline dumbbell curls, Kettle bell fist pump, Face away basion cable curl |
| **Triceps** | Tricep dips, Bent over dumbbell row, Cable tricep extension, Assisted dips |
| **Back** | Lat pull down, Dual pulley pull-down, Dual pulley row, Close grip pulley row, Bent over dumbbell row, Back raise, Rear delt |
| **Shoulders** | Arnold shoulder press, Dumbbell Shoulder press, Front shoulder raise, Side shoulder raise, Lateral shoulder raise, Cable delt pulls, Rear delt |
| **Abs** | *(no pre-populated exercises — add your own)* |

> **Note:** Many exercises target multiple body parts (e.g., "Squat" → Quads + Hamstrings + Glutes, "Rear delt" → Back + Shoulders, "Bent over dumbbell row" → Back + Biceps + Triceps). Each mapping is a separate row in the `EXERCISE_BODY_PARTS` junction table.

---

## Tech Stack

- **Framework:** Flutter / Dart (SDK ^3.11.1)
- **Database:** SQLite via `sqflite` (+ `sqflite_common_ffi` for desktop)
- **State Management:** Provider
- **Architecture:** Clean Architecture with Repository Pattern
- **Platforms:** Windows, macOS, Linux, Android, iOS

> **Web/Edge deprecated:** Web support was removed due to database loading issues with `sqflite_common_ffi_web`. Archived files are in `/edge_archive`.

---

## Database Structure

The app uses a SQLite database (`gym_tracker.db`) bundled as an asset. On first launch, the database is copied to the system's app data directory. It ships with pre-populated body parts and exercise mappings — **no personal data included**.

### Tables

#### SESSIONS — Workout Session Records
| Column | Type | Description |
|--------|------|-------------|
| ID | INTEGER | Primary key, auto-increment |
| Date | TEXT | `YYYY/MM/DD` format |
| Workout | TEXT | Free-text workout description (e.g. "chest and bis") |
| BodyParts | TEXT | JSON array of canonical body part names (e.g. `["Chest","Biceps"]`) |
| RunDuration | REAL | Run distance in km |
| RunTime | INTEGER | Run time in minutes |
| SaunaDuration | INTEGER | Sauna time in minutes |
| BodyWeight | REAL | Body weight in kg |
| TrainingStyle | TEXT | 'Hypertrophy' or 'Strength' |
| Other | TEXT | Free-text notes |

#### BODY_STATS — Body Measurements
| Column | Type | Description |
|--------|------|-------------|
| ID | INTEGER | Primary key, auto-increment |
| Date | TEXT | `YYYY/MM/DD` format |
| Weight_kg | REAL | Body weight in kg |
| Waist_inches | REAL | Waist circumference in inches |
| Neck_inches | REAL | Neck circumference in inches |
| Notes | TEXT | Free-text notes |

#### BODY_PARTS — Muscle Group Catalog (pre-populated)
| Column | Type | Description |
|--------|------|-------------|
| ID | INTEGER | Primary key, auto-increment |
| Name | TEXT | NOT NULL — Quads, Hamstrings, Calves, Glutes, Chest, Biceps, Triceps, Back, Shoulders, Abs |

#### EXERCISE_BODY_PARTS — Exercise-to-BodyPart Mapping (pre-populated)
| Column | Type | Description |
|--------|------|-------------|
| Exercise | TEXT | Exercise name (composite PK with BodyPart) |
| BodyPart | TEXT | Body part name (composite PK with Exercise), `CHECK` constraint enforces the 10 canonical names |

Many-to-many: one exercise can target multiple body parts. Each mapping is a separate row.

#### WEIGHT_TRAINING — Weight Training Records
| Column | Type | Description |
|--------|------|-------------|
| ID | INTEGER | Primary key, auto-increment |
| Date | TEXT | `YYYY/MM/DD` format |
| TrainingStyle | TEXT | 'Hypertrophy' or 'Strength' |
| Exercises | TEXT | Exercise name |
| Weight | TEXT | Weight value (supports ranges like "20-30") |
| Reps | INTEGER | Repetitions per set |
| Sets | INTEGER | Number of sets |

> **Training Style Independence:** Hypertrophy and Strength entries for the same exercise coexist as separate rows. `getLatestWeightForExercise(exercise, trainingStyle)` filters by style. Adding a weight with a different style creates a **new** row (INSERT, never UPDATE).

### Date Format
All dates stored as `YYYY/MM/DD` text format. Dart models normalise slashes to dashes when parsing.

---

## Project Structure

```
lib/
├── main.dart                      # Entry point (Provider setup)
├── database/
│   └── database_helper.dart       # SQLite helper (singleton + FFI + asset copy)
├── models/
│   ├── session.dart               # Session model (Workout + BodyParts JSON)
│   ├── body_stat.dart             # Body stats model
│   ├── body_part.dart             # Body part model
│   ├── exercise_body_part.dart    # Exercise→BodyPart mapping model
│   └── weight_training.dart       # Weight training record model
├── repositories/
│   └── gym_repository.dart        # Data access layer (CRUD + filtered queries)
├── screens/
│   ├── main_screen.dart           # 4-tab bottom navigation shell
│   ├── active_workout_screen.dart # Workout logging form
│   ├── exercises_screen.dart      # Exercise browser & management
│   ├── history_screen.dart        # Session history (reverse chronological)
│   └── profile_screen.dart        # Body stats + settings + export
└── state/
    └── training_state.dart        # Hypertrophy/Strength toggle (ChangeNotifier)

assets/
└── databases/
    └── gym_tracker.db             # Bundled SQLite database (v3 template)

archive/
└── v2/                            # Pre-v0.1.0 source snapshot (DB + lib/ + pubspec.yaml)

create_db.py                       # Regenerates assets/databases/gym_tracker.db from schema
analyze_db.py                      # Inspects the bundled database (schema + row counts)
```

---

## Dependencies

| Package | Purpose |
|---------|---------|
| `sqflite` | SQLite database operations |
| `sqflite_common_ffi` | SQLite FFI for desktop (Windows/macOS/Linux) |
| `path` | File path utilities |
| `intl` | Date/time formatting |
| `provider` | State management |
| `share_plus` | Database export via system share sheet |
| `path_provider` | File system directory access |

---

## Future Enhancements

- **Session detail view** — Drill into individual exercises within a past session
- **Edit/delete individual sets** from a session
- **Date-range filter and search** in History
- **BMI display** in Profile
- **Settings persistence** (SharedPreferences)
- **GPS running tracking** — Live run screen with distance, duration, and pace (geolocator to be re-added)
- **Health Connect sync** — Import body weight/metrics from Android Health Connect
- **Personal Best tracking** per exercise per training style
- **Analytics dashboard** with charts
- **Data export/import** (JSON / CSV)
- **iOS deployment** — Build and publish to the App Store (requires macOS + Xcode + Apple Developer account)
- **Cloud synchronization**

---

## License

This project is open source. See the [GitHub repository](https://github.com/Roughn3ck/gym_tracker) for details.