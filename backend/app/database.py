import sqlite3
from contextlib import contextmanager
from .config import DB_PATH


def init_db():
    with get_db() as db:
        db.executescript("""
            CREATE TABLE IF NOT EXISTS predictions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                location TEXT NOT NULL,
                datetime_utc TEXT NOT NULL,
                type TEXT NOT NULL,
                height_metres REAL NOT NULL,
                UNIQUE(location, datetime_utc, type)
            );

            CREATE TABLE IF NOT EXISTS hourly_levels (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                location TEXT NOT NULL,
                datetime_utc TEXT NOT NULL,
                height_metres REAL NOT NULL,
                UNIQUE(location, datetime_utc)
            );

            CREATE TABLE IF NOT EXISTS sun_times (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                location TEXT NOT NULL,
                date TEXT NOT NULL,
                sunrise TEXT NOT NULL,
                sunset TEXT NOT NULL,
                UNIQUE(location, date)
            );

            CREATE INDEX IF NOT EXISTS idx_pred_loc_date
                ON predictions(location, datetime_utc);
            CREATE INDEX IF NOT EXISTS idx_hourly_loc_date
                ON hourly_levels(location, datetime_utc);
            CREATE INDEX IF NOT EXISTS idx_sun_loc_date
                ON sun_times(location, date);
        """)


@contextmanager
def get_db():
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()
