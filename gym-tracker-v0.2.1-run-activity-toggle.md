# Forge Prompt — Gym Tracker v0.2.1: Run Activity Type Toggle (Walk / Walk-Run / Run)

## Project

`/mnt/b/Github/gym_tracker/` — Flutter 3.44 / Dart, SQLite, Provider state management.

Read `AGENTS.md` at the project root for full architecture, conventions, and constraints before starting.

## Objective

Add a three-way activity-type toggle to every run entry in the Cardio & Recovery section: **Run / Walk / Walk-Run**.

Use case: on injured days the user walks instead of runs; on interval days they alternate walking and running. In both cases the intention is logging the activity, not a performance time — so for Walk and Walk-Run entries the pace field must disappear entirely. No stopwatch, no M:SS. Just "I moved, here's roughly how far."

## Key design facts (read first)

1. **No database change.** `Runs` is a TEXT column holding a JSON array — adding a `type` key inside those JSON objects needs no migration. DB schema stays at **v4**. Do NOT bump `_databaseVersion`, do NOT touch `database_helper.dart`, do NOT regenerate the bundled DB (`create_db.py` / `analyze_db.py` untouched).
2. **Backward compatibility.** v0.2.0 run JSON is `{"distance": 2.6, "pace": "6:38"}` with no `type` key. When reading, a missing `type` **defaults to `run`**. Existing data displays exactly as before.
3. **Type values:** `"run"` | `"walk"` | `"walk_run"` (display label for `walk_run` is "Walk/Run").
4. The branch is **`master`**, not `main`.

## JSON format

```json
[
  {"type": "run", "distance": 2.6, "pace": "6:38"},
  {"type": "walk", "distance": 1.8, "pace": null},
  {"type": "walk_run", "distance": 3.0, "pace": null}
]
```

Rules:
- `type` is always written on new saves.
- `pace` is written **only** when `type == "run"` and the pace field is non-empty; otherwise `null`.
- Save condition is unchanged: an entry is saved only if `distance` parses to a double > 0. Do NOT add distance-less "activity marker" entries — an empty walk row is dropped, same as an empty run row today.

## Changes: `lib/screens/active_workout_screen.dart`

### 1. `_RunEntry` class (~line 811)

Add a mutable type field:

```dart
class _RunEntry {
  final TextEditingController distanceController;
  final TextEditingController paceController;
  String type = 'run'; // 'run' | 'walk' | 'walk_run'
  // existing constructor / dispose unchanged
}
```

### 2. `_buildRunEntry(int index)` (~line 540)

- Add a compact three-way `SegmentedButton<String>` (Material 3 is enabled in `main.dart`) as a full-width row at the top of each run entry:
  - Segments: **Run** / **Walk** / **Walk/Run** → values `'run'` / `'walk'` / `'walk_run'`
  - Single-select: `selected: {run.type}`; on change `setState(() => run.type = value)`
  - Keep it visually compact — it sits above the fields, don't inflate card padding
- **When `run.type != 'run'`: do not render the pace field at all.** The distance field takes the row (remove the pace slot from the Row rather than leaving a gap).
- Toggling back to Run re-shows the pace field with its controller text intact — **never clear the pace controller on toggle**.
- The entry label must reflect the current type instead of hardcoded `Run ${index + 1}`:
  - `'run'` → `Run 1` · `'walk'` → `Walk 1` · `'walk_run'` → `Walk/Run 1`
  - Numbering stays the entry index across mixed types (entry 2 toggled to walk shows `Walk 2`)

### 3. `_saveSession()` — pace validation loop (~line 264)

Only validate pace for run-type entries:

```dart
for (final run in _runEntries) {
  if (run.type != 'run') continue;
  final pace = run.paceController.text.trim();
  if (pace.isNotEmpty && !_paceRegex.hasMatch(pace)) {
    // existing SnackBar + return
  }
}
```

### 4. `_saveSession()` — runs JSON build loop (~line 287)

```dart
for (final run in _runEntries) {
  final dist = double.tryParse(run.distanceController.text.trim());
  final pace = run.paceController.text.trim();
  if (dist != null && dist > 0) {
    runsList.add({
      'type': run.type,
      'distance': dist,
      'pace': run.type == 'run' && pace.isNotEmpty ? pace : null,
    });
  }
}
```

### 5. `_resetForm()`

A fresh `_RunEntry()` already defaults to `run` — no stale type can survive reset. No change needed; verify it.

## Changes: `lib/screens/history_screen.dart`

### 1. Session card run display (~lines 88–112)

Read `type` with default `run`:

```dart
final type = (r['type'] ?? 'run').toString();
final label = type == 'walk' ? 'Walk' : (type == 'walk_run' ? 'Walk/Run' : 'Run');
final pace = r['pace'];
if (type == 'run' && pace != null && pace.toString().isNotEmpty) {
  widgets.add(Text('$label ${i + 1}: $dist km @ $pace/km'));
} else {
  widgets.add(Text('$label ${i + 1}: $dist km'));
}
```

Pace shows only for `run` entries — Walk/Walk-Run never display a pace, even if one somehow exists in old JSON.

### 2. `_EditSessionDialog` `_RunEntry` class (~line 330)

- Constructor gains a `type` param: `_RunEntry({String distance = '', String pace = '', this.type = 'run'})` with a mutable `type` field, same as the main screen
- Loading runs JSON (~line 393): pass `type: (r['type'] ?? 'run').toString()`
- Legacy fallback (~line 408, old `RunDistance`/`RunTime`): defaults to `'run'` — no change needed
- Dialog UI: mirror the main screen — `SegmentedButton` per entry, pace field hidden for non-run types, entry label reflects type, "Add Run" button unchanged
- Dialog save: same rules — validate pace only for `run` entries (`_paceRegex`), serialize with `type`, and write `pace` only for `run` entries with non-empty pace

## Version & Documentation Updates

### `pubspec.yaml`
- Bump version `0.2.0+1` → `0.2.1+1`

### `README.md`
- Update version reference to `v0.2.1`
- Add a "What's New in v0.2.1" section:
  - **Activity Type Toggle** — every run entry can be marked Run, Walk, or Walk/Run. Injured days and interval days get logged as activity, not performance
  - **Pace hidden for Walk / Walk-Run** — no M:SS entry needed when the point is just moving
  - **Backward compatible** — existing v0.2.0 entries display unchanged; no DB migration

### `STATUS.md`
- App version → `0.2.1`; DB schema stays `4`
- Tab 1 capabilities: mention the activity-type toggle (Run / Walk / Walk-Run) and that the pace field is hidden for non-run entries
- Tab 3 capabilities: mention type-aware run labels (`Walk 2: 1.8 km`)
- Roadmap/changelog: add v0.2.1

### `AGENTS.md` (project root)
- Current version → `0.2.1+1`; DB schema `v4` (unchanged)
- SESSIONS `Runs` column description → "JSON array of `{type, distance, pace}`" and note: missing `type` defaults to `run` (v0.2.0 compatibility)

## Build & Verify

1. `flutter analyze` — 0 errors/warnings (info lints acceptable, match current baseline)
2. **Do NOT regenerate the bundled DB** — schema is unchanged
3. `flutter clean && flutter pub get && flutter build windows --release`
4. Verify the EXE exists at `build/windows/x64/runner/Release/gym_tracker.exe`
5. Smoke test the Windows build:
   - Toggle each type on an entry; confirm the pace field hides for Walk / Walk-Run and returns intact when toggled back to Run
   - Add a second entry with a different type; save; confirm History shows lines like `Walk 2: 1.8 km` and `Run 1: 2.6 km @ 6:38/km`
   - Edit that session; confirm the toggles load back with the right types selected
   - Open a pre-v0.2.1 session; confirm its runs still display as `Run N: ...` (missing `type` → run)

## Backup

After verification, create `backups/v0.2.1/` at the project root containing the post-change `lib/` directory plus `pubspec.yaml`, `create_db.py`, `analyze_db.py`, `README.md`, `STATUS.md`, and `AGENTS.md`. Include it in the commit below.

## Git & Release

1. `git add -A`
2. `git commit -m "v0.2.1: Run activity type toggle (Run/Walk/Walk-Run), pace hidden for non-run entries"`
3. `git push origin master`
4. Create a GitHub release:
   - First review the existing release formatting at https://github.com/Roughn3ck/gym_tracker/releases and match it
   - Tag: `v0.2.1`
   - Title: `Gym Tracker v0.2.1 — Run Activity Type Toggle`
   - Body (What's New): activity-type toggle per run entry (Run / Walk / Walk-Run); pace field hidden for Walk and Walk-Run — log the activity, not the time; fully backward compatible, no DB migration
   - Attach the Windows release EXE as a release asset

## Constraints

- No DB schema/version changes — this change is JSON-only inside the existing `Runs` column
- Don't touch `database_helper.dart`, the `session.dart` model (`runs` stays a raw JSON string), repositories, or any screen other than the two named
- Don't change the save condition (`dist > 0`), the "Add Run" button, sauna / body-weight / notes logic, or exercise handling
- Don't clear user input on toggle — pace text survives a walk → run round trip
- Follow existing code style: same naming, spacing, and widget patterns the files already use