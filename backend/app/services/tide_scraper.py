"""
Scrape exact ADMIRALTY tide predictions from tidetimes.co.uk and overlay
them onto the predictions table, replacing harmonic approximations for
the next ~7 days.
"""
import json
import logging
import re
import time
from datetime import datetime
from urllib.request import urlopen, Request
from zoneinfo import ZoneInfo

from ..database import get_db

logger = logging.getLogger(__name__)

UK_TZ = ZoneInfo("Europe/London")
UTC_TZ = ZoneInfo("UTC")

# Map our location IDs to tidetimes.co.uk URL slugs
SCRAPE_SLUGS = {
    "newquay": "newquay",
    "holywell": "newquay",       # Same coast, ~5km, identical tides
    "polzeath": "padstow",       # Nearest available (~4km, same estuary)
    "port_isaac": "port-isaac",
}


def _fetch_page(slug: str, date_str: str) -> str | None:
    """Fetch HTML from tidetimes.co.uk for a given slug and YYYYMMDD date."""
    url = f"https://www.tidetimes.co.uk/{slug}-tide-times-{date_str}"
    req = Request(url, headers={"User-Agent": "TideTimesApp/1.0"})
    try:
        with urlopen(req, timeout=15) as resp:
            return resp.read().decode("utf-8")
    except Exception as e:
        logger.warning("Failed to fetch %s: %s", url, e)
        return None


def _parse_forecasts(html: str) -> list[dict]:
    """Extract tide forecasts from tt.forecast JSON embedded in page JS."""
    match = re.search(r'tt\.forecast\s*=\s*(\{.*?\});', html, re.DOTALL)
    if not match:
        return []

    try:
        data = json.loads(match.group(1))
        forecasts = data.get("forecasts", [])
    except json.JSONDecodeError:
        return []

    results = []
    for f in forecasts:
        try:
            dt_str = f.get("forecast_at")
            height = f.get("tide_height")
            tide_type = f.get("tide_type")

            if dt_str and height is not None and tide_type:
                # Parse local UK time
                for fmt in ("%Y-%m-%dT%H:%M:%S", "%Y-%m-%dT%H:%M",
                            "%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M"):
                    try:
                        dt_local = datetime.strptime(dt_str[:19], fmt)
                        break
                    except ValueError:
                        continue
                else:
                    continue

                # Convert local UK time (GMT/BST) to UTC
                dt_local = dt_local.replace(tzinfo=UK_TZ)
                dt_utc = dt_local.astimezone(UTC_TZ).replace(tzinfo=None)

                results.append({
                    "datetime_utc": dt_utc.strftime("%Y-%m-%dT%H:%M:%S"),
                    "type": "high" if tide_type == "HW" else "low",
                    "height": float(height),
                })
        except (ValueError, TypeError):
            continue

    return results


def scrape_and_overlay(db=None):
    """Scrape the next ~7 days of ADMIRALTY predictions and overwrite
    the corresponding entries in the predictions table.

    If db is provided, uses that connection. Otherwise opens a new one.
    """
    logger.info("Scraping ADMIRALTY predictions from tidetimes.co.uk...")

    own_db = db is None
    if own_db:
        ctx = get_db()
        db = ctx.__enter__()

    try:
        today_str = datetime.utcnow().strftime("%Y%m%d")
        slug_cache: dict[str, list[dict]] = {}
        total_inserted = 0

        for location, slug in SCRAPE_SLUGS.items():
            try:
                # Only fetch each unique slug once
                if slug not in slug_cache:
                    if slug_cache:
                        time.sleep(0.5)  # Polite delay between requests

                    html = _fetch_page(slug, today_str)
                    if html is None:
                        logger.warning("Skipping %s — fetch failed", location)
                        continue

                    forecasts = _parse_forecasts(html)
                    if not forecasts:
                        logger.warning("No forecasts parsed for %s", slug)
                        continue

                    slug_cache[slug] = forecasts
                else:
                    forecasts = slug_cache[slug]

                # Determine date range covered by scraped data
                dates_covered = set()
                for f in forecasts:
                    dates_covered.add(f["datetime_utc"][:10])

                # Delete existing predictions for this location in scraped date range
                for d in dates_covered:
                    db.execute(
                        "DELETE FROM predictions WHERE location = ? AND datetime_utc LIKE ?",
                        (location, f"{d}%"),
                    )

                # Insert scraped predictions
                for f in forecasts:
                    db.execute(
                        "INSERT OR REPLACE INTO predictions "
                        "(location, datetime_utc, type, height_metres) "
                        "VALUES (?, ?, ?, ?)",
                        (location, f["datetime_utc"], f["type"], round(f["height"], 2)),
                    )
                    total_inserted += 1

                logger.info(
                    "  %s: %d predictions overlaid (%s to %s)",
                    location,
                    len(forecasts),
                    min(dates_covered),
                    max(dates_covered),
                )

            except Exception:
                logger.exception("Error scraping %s — harmonic fallback retained", location)

        if own_db:
            db.commit()

        logger.info("ADMIRALTY overlay complete: %d predictions inserted", total_inserted)

    except Exception:
        logger.exception("scrape_and_overlay failed — harmonic predictions unchanged")
    finally:
        if own_db:
            ctx.__exit__(None, None, None)
