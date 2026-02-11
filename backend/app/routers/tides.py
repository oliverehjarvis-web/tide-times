from datetime import date, datetime, timedelta
from fastapi import APIRouter, Query
from zoneinfo import ZoneInfo

from ..database import get_db
from ..config import TIMEZONE

router = APIRouter(prefix="/api/tides", tags=["tides"])

tz = ZoneInfo(TIMEZONE)


def _utc_to_local(utc_str: str) -> str:
    """Convert a UTC datetime string to Europe/London local time."""
    dt = datetime.fromisoformat(utc_str).replace(tzinfo=ZoneInfo("UTC"))
    local_dt = dt.astimezone(tz)
    return local_dt.strftime("%Y-%m-%dT%H:%M:%S")


@router.get("/{location}")
def get_tides(location: str, date: date = Query(default=None)):
    """Get high/low tide predictions for a specific day."""
    if date is None:
        from datetime import date as d
        date = d.today()

    date_str = date.isoformat()
    next_day = (date + timedelta(days=1)).isoformat()

    with get_db() as db:
        rows = db.execute(
            "SELECT datetime_utc, type, height_metres FROM predictions "
            "WHERE location = ? AND datetime_utc >= ? AND datetime_utc < ? "
            "ORDER BY datetime_utc",
            (location, date_str, next_day),
        ).fetchall()

    return {
        "location": location,
        "date": date_str,
        "tides": [
            {
                "datetime_utc": row["datetime_utc"],
                "datetime_local": _utc_to_local(row["datetime_utc"]),
                "type": row["type"],
                "height_metres": row["height_metres"],
            }
            for row in rows
        ],
    }


@router.get("/{location}/range")
def get_tides_range(
    location: str,
    start: date = Query(...),
    end: date = Query(...),
):
    """Get tide predictions for a date range."""
    start_str = start.isoformat()
    end_str = (end + timedelta(days=1)).isoformat()

    with get_db() as db:
        rows = db.execute(
            "SELECT datetime_utc, type, height_metres FROM predictions "
            "WHERE location = ? AND datetime_utc >= ? AND datetime_utc < ? "
            "ORDER BY datetime_utc",
            (location, start_str, end_str),
        ).fetchall()

    # Group by local date
    days = {}
    for row in rows:
        local_dt = _utc_to_local(row["datetime_utc"])
        d = local_dt[:10]
        if d not in days:
            days[d] = []
        days[d].append({
            "datetime_utc": row["datetime_utc"],
            "datetime_local": local_dt,
            "type": row["type"],
            "height_metres": row["height_metres"],
        })

    return {
        "location": location,
        "start": start_str,
        "end": end.isoformat(),
        "days": days,
    }


@router.get("/{location}/hourly")
def get_hourly(location: str, date: date = Query(default=None)):
    """Get hourly water levels for chart rendering."""
    if date is None:
        from datetime import date as d
        date = d.today()

    date_str = date.isoformat()
    next_day = (date + timedelta(days=1)).isoformat()

    with get_db() as db:
        rows = db.execute(
            "SELECT datetime_utc, height_metres FROM hourly_levels "
            "WHERE location = ? AND datetime_utc >= ? AND datetime_utc < ? "
            "ORDER BY datetime_utc",
            (location, date_str, next_day),
        ).fetchall()

    return {
        "location": location,
        "date": date_str,
        "levels": [
            {
                "datetime_utc": row["datetime_utc"],
                "datetime_local": _utc_to_local(row["datetime_utc"]),
                "height_metres": row["height_metres"],
            }
            for row in rows
        ],
    }
