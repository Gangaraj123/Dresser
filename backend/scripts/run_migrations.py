#!/usr/bin/env python3
"""Run init_db.sql against the Supabase PostgreSQL database."""
import os
import sys
from pathlib import Path

import psycopg2
from dotenv import load_dotenv

load_dotenv(Path(__file__).parent.parent / ".env")


def main():
    db_url = os.getenv("DATABASE_URL")
    if not db_url:
        print("ERROR: DATABASE_URL not set in .env")
        sys.exit(1)

    sql_file = Path(__file__).parent / "init_db.sql"
    sql = sql_file.read_text()

    print("Connecting to database...")
    conn = psycopg2.connect(db_url)
    conn.autocommit = True
    cur = conn.cursor()

    print("Running init_db.sql...")
    cur.execute(sql)
    print("Database initialized successfully.")

    cur.close()
    conn.close()


if __name__ == "__main__":
    main()
