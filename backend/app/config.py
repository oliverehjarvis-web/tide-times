from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
DB_PATH = BASE_DIR / "data" / "tides.db"
HARMONICS_PATH = DATA_DIR / "harmonics.json"
STATIC_DIR = BASE_DIR.parent.parent / "frontend" / "build" / "web"

LOCATIONS = ["newquay", "holywell", "polzeath", "port_isaac"]

# Pre-calculate this many days ahead on startup
PRECALC_DAYS = 365

# Timezone for display (UK)
TIMEZONE = "Europe/London"
