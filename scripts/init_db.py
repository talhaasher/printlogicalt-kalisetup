#!/usr/bin/env python3
"""
Database initialization script for the Process API.
Creates the SQLite database schema with proper indexes.
"""

import os
import sys
import sqlite3


def init_database(db_path: str = "logs/logs.db"):
    """Initialize SQLite database with requests table and indexes"""

    # Ensure logs directory exists
    os.makedirs(os.path.dirname(db_path), exist_ok=True)

    print(f"Initializing database at: {db_path}")

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Create requests table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS requests (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            request_id TEXT UNIQUE NOT NULL,
            dataset_id TEXT NOT NULL,
            action TEXT NOT NULL,
            status TEXT NOT NULL,
            duration_ms INTEGER NOT NULL,
            output TEXT NOT NULL,
            http_status INTEGER NOT NULL,
            client TEXT
        )
    """)

    # Create indexes for faster lookups
    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_request_id ON requests(request_id)
    """)

    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_timestamp ON requests(timestamp)
    """)

    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_dataset_id ON requests(dataset_id)
    """)

    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_status ON requests(status)
    """)

    conn.commit()
    conn.close()

    print("✓ Database initialized successfully")
    print("✓ Table 'requests' created")
    print("✓ Indexes created: request_id, timestamp, dataset_id, status")


def query_logs(db_path: str = "logs/logs.db", limit: int = 10):
    """Query and display recent log entries"""

    if not os.path.exists(db_path):
        print(f"Database not found at {db_path}")
        return

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    cursor.execute(f"""
        SELECT timestamp, request_id, dataset_id, action, status, duration_ms, http_status
        FROM requests
        ORDER BY timestamp DESC
        LIMIT {limit}
    """)

    rows = cursor.fetchall()
    conn.close()

    if not rows:
        print("No log entries found")
        return

    print(f"\nMost recent {limit} log entries:")
    print("-" * 120)
    print(f"{'Timestamp':<27} {'Request ID':<36} {'Dataset':<20} {'Action':<12} {'Status':<10} {'Duration':<10} {'HTTP':<5}")
    print("-" * 120)

    for row in rows:
        print(f"{row[0]:<27} {row[1]:<36} {row[2]:<20} {row[3]:<12} {row[4]:<10} {row[5]:<10} {row[6]:<5}")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "query":
        query_logs()
    else:
        init_database()
