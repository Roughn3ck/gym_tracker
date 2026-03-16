#!/usr/bin/env python3
"""
Database analysis script to examine the SQLite database structure.
"""
import sqlite3
import os
from pathlib import Path

def analyze_database(db_path: str):
    """Analyze the SQLite database structure and tables."""
    try:
        # Check if database file exists
        if not os.path.exists(db_path):
            print(f"Database file not found: {db_path}")
            return
        
        # Connect to database
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Get list of tables
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
        tables = cursor.fetchall()
        
        print("Database Tables:")
        print("-" * 50)
        
        for table in tables:
            table_name = table[0]
            print(f"\nTable: {table_name}")
            print("-" * 30)
            
            # Get table schema
            cursor.execute(f"PRAGMA table_info({table_name});")
            columns = cursor.fetchall()
            
            print("Columns:")
            for col in columns:
                col_id, col_name, col_type, not_null, default_val, pk = col
                print(f"  {col_name}: {col_type} {'NOT NULL' if not_null else ''} {'PRIMARY KEY' if pk else ''}")
            
            # Get sample data (first 3 rows)
            try:
                cursor.execute(f"SELECT * FROM {table_name} LIMIT 3;")
                sample_data = cursor.fetchall()
                
                if sample_data:
                    print("\nSample Data (first 3 rows):")
                    for i, row in enumerate(sample_data, 1):
                        print(f"  Row {i}: {row}")
                else:
                    print("\nNo data in table")
                    
            except sqlite3.Error as e:
                print(f"  Error reading sample data: {e}")
                
        conn.close()
        
    except sqlite3.Error as e:
        print(f"Database error: {e}")
    except Exception as e:
        print(f"Unexpected error: {e}")

if __name__ == "__main__":
    db_path = Path("assets/databases/kris_gym.db")
    print(f"Analyzing database: {db_path}")
    print("=" * 60)
    analyze_database(str(db_path))