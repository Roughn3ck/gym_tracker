# Gym Tracker

A Flutter-based fitness tracking app for logging strength and hypertrophy workouts, monitoring body stats, and reviewing session history. Ships with a pre-populated exercise catalogue — no personal data, works out of the box.

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
   - **Body Parts** — Tap one or more filter chips (Legs, Chest, Arms, Back, Shoulders) to select which muscle groups you're training. Selecting body parts automatically loads the relevant exercises below.
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

1. **Browse** — Exercises are grouped by body part in expandable sections (Legs, Chest, Arms, Back, Shoulders). Tap a section to expand it.
2. **View Latest Weight** — Each exercise shows its latest recorded weight, training style, reps, and sets (e.g., "40 kg | Hypertrophy | 12x4"). Exercises with no recorded weight show "No weight recorded yet".
3. **Modify Weight** — Tap the **⋮ (three-dot menu)** next to an exercise and select **Modify Weight**. Enter the new weight and save. This creates a new weight record (preserving history) with today's date and your current training style.
4. **Weight History** — Tap the **⋮ menu** and select **Weight History** to see all past weight entries for that exercise, sorted by date (newest first).
5. **Add Exercise** — Tap the **＋ (floating action button)** in the bottom-right corner. Fill in:
   - **Exercise Name** — The name of the exercise.
   - **Training Style** — Hypertrophy or Strength (dropdown).
   - **Body Parts** — Select one or more body parts (an exercise can target multiple, e.g., "Tricep dips" targets both Chest and Arms).
   - **Initial Weight (optional)** — Starting weight in kg.
   - **Reps / Sets** — Optional initial values.
   - Tap **Save** to add the exercise to the catalogue.

### Tab 3 — History (Review Sessions)

View all past workout sessions in reverse chronological order (newest first).

- Each session card shows: Session ID, date, body parts trained, training style, run distance/time, sauna duration, body weight, and any notes.
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

The app ships with 5 body parts and 31 exercise mappings:

| Body Part | Exercises |
|-----------|-----------|
| **Legs** | Deadlift machine, Hamstring curl, Leg extension, Leg press, Leg press Calf raise, Seated calf raise, Squat |
| **Chest** | Cable flys (decline), Chest fly machine, Chest press, Inclined Chest flys, Tricep dips |
| **Arms** | Bent over dumbbell row, Cable bicep curl, Cable tricep extension, Incline dumbbell curls, Kettle bell fist pump, Preacher curls, Tricep dips |
| **Back** | Back raise, Bent over dumbbell row, Close grip pulley row, Dual pulley pull-down, Dual pulley row, Lat pull down, Rear delt |
| **Shoulders** | Arnold shoulder press, Dumbbell Shoulder press, Front shoulder raise, Rear delt, Side shoulder raise |

> **Note:** Some exercises target multiple body parts (e.g., "Tricep dips" → Chest + Arms, "Rear delt" → Back + Shoulders). Adding your own exercises with multiple body parts creates one row per body part.

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
| BodyPart | TEXT | Comma-separated body parts trained |
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
| Name | TEXT | NOT NULL — e.g., "Legs", "Chest" |

#### EXERCISE_BODY_PARTS — Exercise-to-BodyPart Mapping (pre-populated)
| Column | Type | Description |
|--------|------|-------------|
| Exercise | TEXT | Exercise name (composite PK with BodyPart) |
| BodyPart | TEXT | Body part name (composite PK with Exercise) |

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
│   ├── session.dart               # Session model
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
    └── gym_tracker.db             # Bundled SQLite database (blank + seed data)
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