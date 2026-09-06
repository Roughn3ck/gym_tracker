#!/usr/bin/env python3
"""Create a fresh gym_tracker.db with the v4 schema and seed data (no personal data).

v4 changes vs v3:
- SESSIONS: added `Runs` (TEXT) — JSON array of run entries with distance (km)
  and pace (M:SS /km). Legacy `RunDistance` and `RunTime` columns are kept for
  backward compatibility.
- Existing v3 databases are upgraded in-place via `onUpgrade` in
  `database_helper.dart` (ALTER TABLE SESSIONS ADD COLUMN Runs TEXT).
- BODY_PARTS and EXERCISE_BODY_PARTS seed data are unchanged.
"""
import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'assets', 'databases', 'gym_tracker.db')

# The 10 canonical v4 body part names. Keep in sync with the CHECK constraint
# on EXERCISE_BODY_PARTS.BodyPart and the BODY_PARTS seed below.
CANONICAL_BODY_PARTS = [
    'Quads', 'Hamstrings', 'Calves', 'Glutes', 'Chest',
    'Biceps', 'Triceps', 'Back', 'Shoulders', 'Abs',
]

# Comma-joined list for embedding in the SQL CHECK constraint.
_BODY_PART_LIST = ", ".join(f"'{bp}'" for bp in CANONICAL_BODY_PARTS)


def main():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)

    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()

    # SESSIONS — v4: keep RunDistance/RunTime, add Runs JSON column.
    c.execute(f'''CREATE TABLE SESSIONS (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        Date TEXT NOT NULL,
        Workout TEXT,
        BodyParts TEXT,
        RunDistance REAL,
        RunTime INTEGER,
        SaunaDuration INTEGER,
        BodyWeight REAL,
        TrainingStyle TEXT,
        Other TEXT,
        Runs TEXT
    )''')

    c.execute('''CREATE TABLE BODY_STATS (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        Date TEXT NOT NULL,
        Weight_kg REAL,
        Waist_inches REAL,
        Neck_inches REAL,
        Notes TEXT
    )''')

    c.execute('''CREATE TABLE WEIGHT_TRAINING (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        Date TEXT,
        TrainingStyle TEXT,
        Exercises TEXT,
        Weight TEXT,
        Reps INTEGER,
        Sets INTEGER
    )''')

    c.execute('''CREATE TABLE BODY_PARTS (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        Name TEXT NOT NULL
    )''')

    # EXERCISE_BODY_PARTS — v4: same CHECK constraint on BodyPart.
    # Many-to-many junction: each (Exercise, BodyPart) pair is its own row.
    c.execute(f'''CREATE TABLE EXERCISE_BODY_PARTS (
        Exercise TEXT NOT NULL,
        BodyPart TEXT NOT NULL CHECK (BodyPart IN ({_BODY_PART_LIST})),
        PRIMARY KEY (Exercise, BodyPart)
    )''')

    # Seed BODY_PARTS (10 canonical categories)
    for bp in CANONICAL_BODY_PARTS:
        c.execute('INSERT INTO BODY_PARTS (Name) VALUES (?)', (bp,))

    # Seed EXERCISE_BODY_PARTS (v4 mappings). Use INSERT OR IGNORE so the
    # composite PRIMARY KEY (Exercise, BodyPart) tolerates any duplicate
    # (Exercise, BodyPart) pairs in the source list.
    exercise_body_parts = [
        # Legs
        ('Squat', 'Quads'),
        ('Squat', 'Hamstrings'),
        ('Squat', 'Glutes'),
        ('Leg press', 'Quads'),
        ('Leg press', 'Hamstrings'),
        ('Leg press', 'Glutes'),
        ('Deadlift machine', 'Quads'),
        ('Deadlift machine', 'Hamstrings'),
        ('Deadlift machine', 'Glutes'),
        ('Leg extension', 'Quads'),
        ('Hamstring curl', 'Hamstrings'),
        ('Seated calf raise', 'Calves'),
        ('Leg press Calf raise', 'Calves'),
        # Chest
        ('Chest press', 'Chest'),
        ('Dumbbell chest press', 'Chest'),
        ('Chest fly machine', 'Chest'),
        ("Cable flys (decline)", 'Chest'),
        ('Inclined Chest flys', 'Chest'),
        ('Tricep dips', 'Chest'),
        ('Tricep dips', 'Triceps'),
        # Back
        ('Lat pull down', 'Back'),
        ('Dual pulley pull-down', 'Back'),
        ('Dual pulley row', 'Back'),
        ('Close grip pulley row', 'Back'),
        ('Bent over dumbbell row', 'Back'),
        ('Bent over dumbbell row', 'Biceps'),
        ('Bent over dumbbell row', 'Triceps'),
        ('Back raise', 'Back'),
        ('Rear delt', 'Back'),
        ('Rear delt', 'Shoulders'),
        # Biceps
        ('Cable bicep curl', 'Biceps'),
        ('Preacher curls', 'Biceps'),
        ('Incline dumbbell curls', 'Biceps'),
        ('Kettle bell fist pump', 'Biceps'),
        ('Face away basion cable curl', 'Biceps'),
        # Triceps
        ('Cable tricep extension', 'Triceps'),
        ('Assisted dips', 'Triceps'),
        # Shoulders
        ('Arnold shoulder press', 'Shoulders'),
        ('Dumbbell Shoulder press', 'Shoulders'),
        ('Front shoulder raise', 'Shoulders'),
        ('Side shoulder raise', 'Shoulders'),
        ('Lateral shoulder raise', 'Shoulders'),
        ('Cable delt pulls', 'Shoulders'),
    ]
    for exercise, bp in exercise_body_parts:
        c.execute('INSERT OR IGNORE INTO EXERCISE_BODY_PARTS (Exercise, BodyPart) VALUES (?, ?)',
                  (exercise, bp))

    # Set schema version to 4.
    c.execute('PRAGMA user_version = 4')

    conn.commit()
    conn.close()

    print(f'Created gym_tracker.db at: {DB_PATH}')
    print(f'File exists: {os.path.exists(DB_PATH)}')
    print(f'File size: {os.path.getsize(DB_PATH)} bytes')


if __name__ == '__main__':
    main()
