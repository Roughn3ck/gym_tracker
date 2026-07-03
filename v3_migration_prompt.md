# Gym Tracker v3 Migration — Schema & UI Update

## Overview

Upgrade the gym_tracker Flutter app to v3. The core change is expanding the body part taxonomy from 5 categories (Legs, Chest, Arms, Back, Shoulders) to 10 (Quads, Hamstrings, Calves, Glutes, Chest, Biceps, Triceps, Back, Shoulders, Abs). Additionally, the SESSIONS table gets a new JSON `BodyParts` column and the old `BodyPart` column is renamed to `Workout`.

## Part 0 — Archive v2 Build

Before making any changes, archive the current v2 state:

1. Copy the current `assets/databases/gym_tracker.db` into `archive/v2/` (this preserves the v2 schema in a known location)
2. Copy all `.dart` source files from `lib/` into `archive/v2/lib/` (recursively, preserving directory structure)
3. Copy `pubspec.yaml` into `archive/v2/`

The `archive/v2/` directory already exists at `B:\Github\gym_tracker\archive\v2\`.

## Part 1 — Database Schema

Replace the blank `assets/databases/gym_tracker.db` with the v3 schema. The new schema is:

### BODY_PARTS table
10 rows: Quads, Hamstrings, Calves, Glutes, Chest, Biceps, Triceps, Back, Shoulders, Abs
(These replace the old 5: Legs, Chest, Arms, Back, Shoulders)

### SESSIONS table — TWO column changes
- **Rename** `BodyPart` → `Workout` (TEXT, stores the original free-text workout description, e.g. "chest and bis")
- **Add** `BodyParts` column (TEXT, stores a JSON array of canonical body part names taken from BODY_PARTS, e.g. `["Chest","Biceps","Triceps"]`)

### EXERCISE_BODY_PARTS table — updated CHECK constraint and data
- The CHECK constraint on `BodyPart` must accept the new 10 body part names
- Populate with these exercise mappings:

| Exercise | BodyPart |
|---|---|
| Squat | Quads, Hamstrings, Glutes |
| Leg press | Quads, Hamstrings, Glutes |
| Deadlift machine | Quads, Hamstrings, Glutes |
| Leg extension | Quads |
| Hamstring curl | Hamstrings |
| Seated calf raise | Calves |
| Leg press Calf raise | Calves |
| Chest press | Chest |
| Dumbbell chest press | Chest |
| Chest fly machine | Chest |
| Cable flys (decline) | Chest |
| Inclined Chest flys | Chest |
| Tricep dips | Chest, Triceps |
| Lat pull down | Back |
| Dual pulley pull-down | Back |
| Dual pulley row | Back |
| Close grip pulley row | Back |
| Bent over dumbbell row | Back, Biceps, Triceps |
| Back raise | Back |
| Rear delt | Back, Shoulders |
| Cable bicep curl | Biceps |
| Preacher curls | Biceps |
| Incline dumbbell curls | Biceps |
| Kettle bell fist pump | Biceps |
| Face away basion cable curl | Biceps |
| Cable tricep extension | Triceps |
| Assisted dips | Triceps |
| Arnold shoulder press | Shoulders |
| Dumbbell Shoulder press | Shoulders |
| Dumbbell shoulder press | Shoulders |
| Front shoulder raise | Shoulders |
| Side shoulder raise | Shoulders |
| Lateral shoulder raise | Shoulders |
| Cable delt pulls | Shoulders |

Note: Each exercise can map to multiple body parts — these are separate rows in EXERCISE_BODY_PARTS (it's a many-to-many junction table).

### Other tables
BODY_STATS and WEIGHT_TRAINING remain unchanged.

Create this as a fresh .db file. Do NOT use any ON CONFLICT or migration scripts — this is a clean v3 template database. The app copies it from assets on first launch.

## Part 2 — Dart Model Changes

### `lib/models/session.dart`
- Rename the `bodyPart` field to `workout` (String?)
- Add a new `bodyParts` field (String?) — this stores the JSON array as a raw string
- Update `toMap()`:
  - `'BodyPart'` becomes `'Workout'` — maps from `workout`
  - Add `'BodyParts': bodyParts`
- Update `fromMap()`:
  - `'BodyPart'` becomes `'Workout'` — maps to `workout`
  - Add `bodyParts: map['BodyParts'] as String?`
- Update `copyWith()`, `toString()`, `==`, and `hashCode` accordingly

### `lib/models/body_part.dart`
No changes needed — the model is just `id` and `name` which still works.

### `lib/models/exercise_body_part.dart`
No changes needed — the model is just `exercise` and `bodyPart` strings.

## Part 3 — Database Helper

In `lib/database_helper.dart`:
- Bump `_databaseVersion` from 2 to 3
- Remove the `onOpen` migration that conditionally adds `RunTime` (that was a v1→v2 migration; v3 starts fresh)
- Keep the copy-from-assets logic — it should now copy the v3 schema database

## Part 4 — UI Changes

### ActiveWorkoutScreen (`lib/screens/active_workout_screen.dart`)

This screen has a "Body Parts:" section that currently shows FilterChips for all body parts, and a "Session Setup" section with a date picker. The layout needs reordering:

**New layout order under "Session Setup":**
1. **Workout** — A `TextFormField` labeled "Workout" for free-text workout description. This replaces the old `bodyPart` free-text. This field sits right below the date picker.
2. **Body Parts:** — The FilterChips, now populated from the expanded 10 body parts (from BODY_PARTS table). Selected body parts get serialized to a JSON array string when saving.
3. Body Weight — unchanged
4. (Then Exercises, Cardio, Notes, Save — unchanged)

**Key changes in save logic (`_saveSession`):**
- The `workout` field on the Session model comes from the new Workout TextFormField
- The `bodyParts` field is the JSON-serialized array of selected filter chips: `jsonEncode(_selectedBodyParts.toList())` — import `dart:convert` for `jsonEncode`
- Remove the old logic that joined `_selectedBodyParts` into a comma-separated string for `bodyPart`

### ExercisesScreen (`lib/screens/exercises_screen.dart`)

The "Body Parts" filter chips in the Add Exercise dialog now show the expanded 10-category list. No code changes needed since it reads body parts dynamically from the database — it will automatically show whatever is in BODY_PARTS.

### HistoryScreen (`lib/screens/history_screen.dart`)

Update the session display:
- Instead of showing `session.bodyPart` (now `session.workout`), show:
  - `Workout: ${session.workout}` if not null
  - `Body Parts:` — parse the JSON `bodyParts` string and display as comma-separated names, e.g. `Chest, Biceps, Triceps`

### ProfileScreen
No changes needed — it shows BODY_STATS which are unchanged.

### Repository (`lib/repositories/gym_repository.dart`)
- The `getExerciseNamesByBodyParts` method already works with the new body part names since it queries EXERCISE_BODY_PARTS dynamically
- No changes needed, but verify the `insertSession` call passes the updated Session model correctly

## Part 5 — Verification Checklist

After all changes, verify:
1. The asset database at `assets/databases/gym_tracker.db` has the correct v3 schema (10 body parts, Workout + BodyParts columns in SESSIONS)
2. `flutter analyze` passes with no errors
3. The Workout tab shows: Date → Workout text field → Body Parts chips → Body Weight → Exercises → Cardio → Notes → Save
4. Selecting body part chips filters exercises correctly from the new EXERCISE_BODY_PARTS mappings
5. Saving a session stores `Workout` and `BodyParts` (JSON) correctly
6. History screen displays Workout and parsed Body Parts
7. Exercises screen shows all 10 body part categories with correct exercises under each

## What NOT to change
- BODY_STATS table and Profile screen (unchanged)
- WEIGHT_TRAINING table and its model (unchanged)
- Training mode toggle (unchanged)
- Cardio & Recovery section (unchanged)
- The `TrainingState` class (unchanged)
- Pubspec dependencies (unchanged, though you'll use `dart:convert` which is built-in)
