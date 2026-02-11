from datetime import date
from fastapi import APIRouter, Query

from ..database import get_db
from ..services.sun_calculator import SunCalculator

router = APIRouter(prefix="/api", tags=["locations"])

sun_calc = SunCalculator()


@router.get("/locations")
def get_locations():
    """List all available tide locations."""
    return {
        "locations": [
            {"id": "newquay", "name": "Newquay", "latitude": 50.4167, "longitude": -5.0833},
            {"id": "holywell", "name": "Holywell Bay", "latitude": 50.3930, "longitude": -5.1480},
            {"id": "polzeath", "name": "Polzeath", "latitude": 50.5720, "longitude": -4.9190},
            {"id": "port_isaac", "name": "Port Isaac", "latitude": 50.5930, "longitude": -4.8290},
        ]
    }


@router.get("/sun/{location}")
def get_sun_times(location: str, date: date = Query(default=None)):
    """Get sunrise and sunset times."""
    if date is None:
        from datetime import date as d
        date = d.today()

    # Try cache first
    with get_db() as db:
        row = db.execute(
            "SELECT sunrise, sunset FROM sun_times WHERE location = ? AND date = ?",
            (location, date.isoformat()),
        ).fetchone()

    if row:
        sunrise = row["sunrise"]
        sunset = row["sunset"]
        # Calculate day length from cached data
        sr_parts = sunrise.split(":")
        ss_parts = sunset.split(":")
        sr_mins = int(sr_parts[0]) * 60 + int(sr_parts[1])
        ss_mins = int(ss_parts[0]) * 60 + int(ss_parts[1])
        day_length = round((ss_mins - sr_mins) / 60, 2)
        return {
            "date": date.isoformat(),
            "sunrise": sunrise,
            "sunset": sunset,
            "day_length_hours": day_length,
        }

    # Calculate on-demand if not cached
    return sun_calc.get_sun_times(location, date)


@router.get("/health")
def health_check():
    """Health check endpoint for Docker."""
    with get_db() as db:
        count = db.execute("SELECT COUNT(*) as c FROM predictions").fetchone()["c"]
    return {"status": "healthy", "predictions_cached": count}
