# Forge Prompt — Gym Tracker v0.2.0: Multiple Runs, Pace, Body Weight Fix

## Project
`/mnt/b/Github/gym_tracker/` — Flutter 3.44 / Dart, SQLite, Provider state management.

Read `AGENTS.md` at the project root for full architecture, conventions, and constraints before starting.

## Objective
Three changes for v0.2.0:

1. **Body Weight starts blank** — don't pre-populate the Body Weight field with the last recorded value. Show the last value as helper text instead.
2. **Run Time → Pace (min:sec/km)** — replace the "Run Time" integer-minutes field with a "Pace" field that accepts `M:SS` format (e.g. `6:38` meaning 6 min 38 sec per km).
3. **Multiple runs** — add an "Add Run" button so the user can log multiple separate runs in one session (e.g. run to the gym, train, run home). Each run has its own distance (km) and pace (M:SS/km).

## Schema Change: v3 → v4

### New column: `Runs` (TEXT, nullable, JSON)

Add a `Runs` TEXT column to the `SESSIONS` table. This stores a JSON array of run entries:

```json
[
  {"distance": 2.6, "pace": "6:38"},
  {"distance": 2.6, "pace": "6:35"}
]
```

- `distance` is a double (km)
- `pace` is a string in `M:SS` format (minutes:seconds per km)

### Backward compatibility

- **Keep** the existing `RunDistance` (REAL) and `RunTime` (INTEGER) columns. Do NOT remove or migrate existing data.
- **Old sessions** (pre-v0.2.0): if `Runs` is null/empty, display using the old `RunDistance`/`RunTime` fields as before.
- **New sessions**: save runs to the `Runs` JSON column. Leave `RunDistance` and `RunTime` as null for new sessions (don't write to them).
- The `Runs` column takes priority for display when it's non-null and non-empty.

### Migration

- Bump `_databaseVersion` from 3 to 4 in `database_helper.dart`
- Add an `onUpgrade` callback in `_initDatabase()` that runs `ALTER TABLE SESSIONS ADD COLUMN Runs TEXT` when upgrading from v3 to v4
- Update `_fixSessionsUniqueConstraintIfPresent()` to include `Runs TEXT` in the `SESSIONS_new` table definition (for legacy external DBs that need the UNIQUE constraint fix)
- Update the bundled `assets/databases/gym_tracker.db` to include the `Runs` column. To do this, create a new `create_db.py` at the project root that generates a fresh v4 schema database with the same seed data (10 body parts, 43 exercise mappings). Model it on the archived `archive/v0.1.0/create_db.py` but:
  - Use `RunDistance` (not `RunDuration` — the archived script had a bug)
  - Add `Runs TEXT` column to the SESSIONS table
  - Set the DB version pragma to 4: `PRAGMA user_version = 4`
  - Run `python3 create_db.py` to regenerate the bundled DB
  - Verify with `python3 analyze_db.py` that the schema is correct

## Model Changes: `lib/models/session.dart`

### Add `runs` field

- Type: `String?` (JSON array string, same pattern as `bodyParts`)
- In `toMap()`: include `'Runs': runs`
- In `fromMap()`: read `map['Runs'] as String?`
- In `copyWith()`: add `String? runs` parameter
- In `==` and `hashCode`: include `runs`
- In `toString()`: include `runs`
- Update constructor to accept `this.runs`

### No changes to RunDistance/RunTime fields

Keep `runDistance` and `runTime` as-is for backward compatibility. They'll be null for new sessions but still used to read old data.

## UI Changes: `lib/screens/active_workout_screen.dart`

### Issue 1: Body Weight starts blank

**Current behaviour:** `_loadInitialData()` calls `repository.getLatestBodyWeight()` and sets `_bodyWeightController.text = lastWeight.toString()`. `_resetForm()` also re-fills it.

**New behaviour:**
- Keep loading `_lastBodyWeight` in `_loadInitialData()` (we'll use it for helper text)
- Do NOT set `_bodyWeightController.text` in `_loadInitialData()` — leave it blank
- Do NOT set `_bodyWeightController.text` in `_resetForm()` — leave it blank
- Change the Body Weight `TextFormField` decoration to show the last weight as `helperText`:
  - If `_lastBodyWeight != null`: `helperText: 'Last: ${_lastBodyWeight} kg'`
  - If `_lastBodyWeight == null`: `helperText: null` (or omit)
- This way the user sees their last weight as a hint but the field starts empty, preventing accidental re-entry

### Issue 2 & 3: Multiple runs with Pace field

**Replace** the current single Run Dist + Run Time row with a runs section.

**New data structure for the form:**
Add a `List<_RunEntry>` to the screen state. Each `_RunEntry` has:
```dart
class _RunEntry {
  final TextEditingController distanceController; // km, decimal
  final TextEditingController paceController;     // M:SS format
  // constructor, dispose()
}
```

**UI layout for the runs section** (replaces the current Row with Run Dist + Run Time):

```
Cardio & Recovery
─────────────────────
Run 1
  [Run Dist (km)] [Pace (min/km)]
  [Remove] (if more than 1 run)
  
[+ Add Run] button
─────────────────────
Sauna Duration (min)
```

- Start with exactly 1 run entry (distance + pace)
- "Add Run" button creates a new `_RunEntry` and adds it to the list
- Each run entry after the first has a "Remove" button (or icon)
- The first run can also be removed if there's more than 1 entry (keep at least 1 empty entry at all times — if the user removes the last one, add a fresh empty one)
- Pace field: `TextInputType.text` (not number, because of the colon), with an `inputFormatters` or validation for `M:SS` format
- Pace field suffix: `min/km`
- Distance field: same as before — `TextInputType.numberWithOptions(decimal: true)`, suffix `km`

**Pace validation:**
- Accept format `M:SS` or `MM:SS` (single or double-digit minutes, double-digit seconds)
- Regex: `^\d{1,2}:[0-5]\d$`
- On save: if pace field is non-empty but doesn't match the format, show a validation error in a SnackBar and abort save
- Empty pace is OK (user might only want to log distance)

### Save logic changes in `_saveSession()`:

1. Build the runs JSON from the `_RunEntry` list:
   ```dart
   final runsList = <Map<String, dynamic>>[];
   for (final run in _runEntries) {
     final dist = double.tryParse(run.distanceController.text.trim());
     final pace = run.paceController.text.trim();
     if (dist != null && dist > 0) {
       runsList.add({'distance': dist, 'pace': pace.isNotEmpty ? pace : null});
     }
   }
   final runsJson = runsList.isNotEmpty ? jsonEncode(runsList) : null;
   ```

2. Create the Session with `runs: runsJson` and `runDistance: null`, `runTime: null` (don't populate old columns for new sessions)

3. Keep the existing exercise saving logic unchanged

### Reset logic in `_resetForm()`:
- Clear all run entries
- Add a single fresh empty `_RunEntry`
- Clear body weight (leave blank — don't pre-fill)

## UI Changes: `lib/screens/history_screen.dart`

### Display runs

In the session card `subtitle`, update the run display:

```dart
// Priority: Runs JSON > old RunDistance/RunTime
if (session.runs != null && session.runs!.isNotEmpty) {
  // Parse JSON and display each run
  try {
    final runs = jsonDecode(session.runs!);
    if (runs is List && runs.isNotEmpty) {
      for (int i = 0; i < runs.length; i++) {
        final r = runs[i];
        final dist = r['distance'];
        final pace = r['pace'];
        if (pace != null) {
          Text('Run ${i+1}: $dist km @ $pace/km');
        } else {
          Text('Run ${i+1}: $dist km');
        }
      }
    }
  } catch (_) {
    // Fall through to old display
  }
} else if (session.runDistance != null) {
  Text('Run: ${session.runDistance} km');
  if (session.runTime != null) {
    Text('Run Time: ${session.runTime} min');
  }
}
```

### Edit session dialog (`_EditSessionDialog`)

Update the dialog to support multiple runs with pace fields, mirroring the active workout screen:
- Replace the single Run Dist + Run Time row with the same multi-run UI (list of distance + pace entries, "Add Run" button, "Remove" buttons)
- Load existing runs from the session's `Runs` JSON (if present), otherwise from old `RunDistance`/`RunTime` (convert old RunTime in minutes to a pace string if RunDistance is also present — calculate pace as total seconds / distance, then format as M:SS. If that's not possible, just show the old fields as-is)
- On save: serialize runs to JSON and set `runs` on the Session, leave `runDistance`/`runTime` as the original values (don't modify old columns during edit either — OR if runs are entered, set runDistance/runTime to null. Actually, safest: if the user edits runs in the dialog, set `runs` to the JSON and leave `runDistance`/`runTime` as they were from the original session)

Actually, for the edit dialog:
- Load from `Runs` JSON if present
- If no `Runs` JSON but `RunDistance` and/or `RunTime` exist, create one run entry with the old values. For pace: if both RunDistance and RunTime exist, calculate pace = (RunTime * 60) / RunDistance seconds, then format as M:SS. If only RunDistance exists, show just distance with empty pace. If only RunTime exists, skip it (can't convert to pace without distance).
- On save: set `runs` to the JSON. For `runDistance` and `runTime`, keep the original values from the existing session (don't null them out — just pass them through unchanged). This preserves backward compat without overwriting old data.

## Version & Documentation Updates

### `pubspec.yaml`
- Bump version from `0.1.1+1` to `0.2.0+1`

### `README.md`
- Update the version reference from `v0.1.1` to `v0.2.0`
- Add a "What's New in v0.2.0" section:
  - **Multiple Runs**: Log multiple separate runs per session with individual distance and pace
  - **Pace Field**: Run time changed to pace (min:sec per km) — enter as M:SS (e.g. 6:38)
  - **Body Weight Blank Start**: Body weight field no longer auto-fills — shows last weight as helper text instead
  - **Schema v4**: Added `Runs` JSON column for multiple run entries (backward compatible with v3)

### `STATUS.md`
- Update app version to `0.2.0` and DB schema version to `4`
- Update the SESSIONS table schema in section 3.1 to include the `Runs` column
- Add `v0.2.0` to the roadmap/changelog section
- Update the "Current Capabilities" for Tab 1 (Workout) and Tab 3 (History) to reflect multiple runs and pace
- Update "What's Not Yet Implemented" if needed

### `AGENTS.md`
- Update "Current version" from `0.1.1+1` to `0.2.0+1` and DB schema from `v3` to `v4`
- Add `Runs` column to the SESSIONS table description in "Database Schema (v3)" section — rename to "Database Schema (v4)"
- Update the SESSIONS table row to include: `Runs` (TEXT, JSON array of `{distance, pace}`)
- Note the backward compatibility: old sessions use `RunDistance`/`RunTime`, new sessions use `Runs`
- Add `create_db.py` to the File Inventory if it's created at the project root

## Build & Verify

After all code changes are complete:

1. Run `flutter analyze` — must pass with 0 errors/warnings (info lints acceptable)
2. Run `python3 create_db.py` — regenerate the bundled DB with v4 schema
3. Run `python3 analyze_db.py` — verify the v4 schema is correct (Runs column present, 10 body parts, 43 mappings)
4. Run `flutter clean && flutter pub get && flutter build windows --release` — verify the Windows build succeeds
5. Check the output EXE exists at `build/windows/x64/runner/Release/gym_tracker.exe`

## Git & Release

After the build succeeds:

1. `git add -A`
2. `git commit -m "v0.2.0: Multiple runs with pace, body weight blank start, schema v4"`
3. `git push origin main`
4. Create a GitHub release:
   - Tag: `v0.2.0`
   - Title: `Gym Tracker v0.2.0 — Multiple Runs & Pace`
   - Body:
     ```
     ## What's New
     
     ### Multiple Runs
     Log multiple separate runs per session. Perfect for run-to-gym, train, run-home days. Each run has its own distance and pace.
     
     ### Pace Field (replaces Run Time)
     Run time is now entered as pace in `M:SS` format (e.g. `6:38` = 6 min 38 sec per km). This is more useful for tracking running performance than total minutes.
     
     ### Body Weight Starts Blank
     The body weight field no longer auto-fills with your last recorded weight. It shows your last weight as helper text below the field, so you don't accidentally re-enter an old weight on a day you didn't weigh in.
     
     ### Schema v4
     Added `Runs` JSON column for multiple run entries. Fully backward compatible — existing sessions with `RunDistance`/`RunTime` display correctly.
     ```
   - Attach the Windows release EXE (`build/windows/x64/runner/Release/gym_tracker.exe`) as a release asset
   - Review the existing release formatting at https://github.com/Roughn3ck/gym_tracker/releases before creating the release

## Constraints

- Do NOT add web/Edge support
- Do NOT re-add geolocator or health packages
- Do NOT use ISO 8601 dates — the DB uses `YYYY/MM/DD` text format
- Do NOT delete platform scaffolding directories
- Follow the existing code patterns: Provider for data access, DataRefreshNotifier for cross-screen updates, JSON encoding for complex column data (same pattern as BodyParts)
- Keep the existing `RunDistance` and `RunTime` columns in the schema — do NOT remove them
- `flutter analyze` must pass with 0 errors/warnings