"""
Pre-calculates tide predictions and sun times, storing them in SQLite.
Runs on container startup.
"""
import logging
from datetime import datetime, date, timedelta

from ..database import get_db
from .tide_calculator import TideCalculator
from .sun_calculator import SunCalculator
from .tide_scraper import scrape_and_overlay
from ..config import LOCATIONS, PRECALC_DAYS

logger = logging.getLogger(__name__)


def build_cache():
    """Pre-calculate all predictions and store in database."""
    tide_calc = TideCalculator()
    sun_calc = SunCalculator()

    today = date.today()
    end_date = today + timedelta(days=PRECALC_DAYS)

    logger.info(f"Pre-calculating {PRECALC_DAYS} days for {len(LOCATIONS)} locations...")

    with get_db() as db:
        # Clear existing data
        db.execute("DELETE FROM predictions")
        db.execute("DELETE FROM hourly_levels")
        db.execute("DELETE FROM sun_times")

        total_tides = 0
        total_hourly = 0
        total_sun = 0

        current = today
        while current <= end_date:
            dt = datetime(current.year, current.month, current.day)

            for loc in LOCATIONS:
                # High/low tide predictions
                extremes = tide_calc.find_extremes(loc, dt)
                for ext in extremes:
                    db.execute(
                        "INSERT OR REPLACE INTO predictions (location, datetime_utc, type, height_metres) VALUES (?, ?, ?, ?)",
                        (loc, ext["datetime"].strftime("%Y-%m-%dT%H:%M:%S"), ext["type"], round(ext["height"], 2)),
                    )
                    total_tides += 1

                # Hourly levels
                hourly = tide_calc.hourly_heights(loc, dt)
                for h_dt, h_val in hourly:
                    if h_dt.date() == current:
                        db.execute(
                            "INSERT OR REPLACE INTO hourly_levels (location, datetime_utc, height_metres) VALUES (?, ?, ?)",
                            (loc, h_dt.strftime("%Y-%m-%dT%H:%M:%S"), round(h_val, 2)),
                        )
                        total_hourly += 1

                # Sunrise/sunset
                sun_data = sun_calc.get_sun_times(loc, current)
                db.execute(
                    "INSERT OR REPLACE INTO sun_times (location, date, sunrise, sunset) VALUES (?, ?, ?, ?)",
                    (loc, current.isoformat(), sun_data["sunrise"], sun_data["sunset"]),
                )
                total_sun += 1

            current += timedelta(days=1)

            # Log progress every 30 days
            days_done = (current - today).days
            if days_done % 30 == 0:
                logger.info(f"  Progress: {days_done}/{PRECALC_DAYS} days calculated")

    logger.info(
        f"Cache built: {total_tides} tide events, {total_hourly} hourly levels, {total_sun} sun times"
    )

    # Overlay exact ADMIRALTY predictions for the next ~7 days
    scrape_and_overlay()
