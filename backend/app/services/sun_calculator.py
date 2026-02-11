"""
Offline sunrise/sunset calculation using astral library.
"""
from datetime import date
from astral import LocationInfo
from astral.sun import sun


LOCATION_COORDS = {
    "newquay": ("Newquay", 50.4167, -5.0833),
    "holywell": ("Holywell Bay", 50.3930, -5.1480),
    "polzeath": ("Polzeath", 50.5720, -4.9190),
    "port_isaac": ("Port Isaac", 50.5930, -4.8290),
}


class SunCalculator:
    def __init__(self):
        self._locations = {}
        for loc_id, (name, lat, lon) in LOCATION_COORDS.items():
            self._locations[loc_id] = LocationInfo(
                name=name,
                region="Cornwall, UK",
                timezone="Europe/London",
                latitude=lat,
                longitude=lon,
            )

    def get_sun_times(self, location: str, target_date: date) -> dict:
        loc = self._locations[location]
        s = sun(loc.observer, date=target_date, tzinfo=loc.timezone)

        sunrise = s["sunrise"]
        sunset = s["sunset"]
        day_length = (sunset - sunrise).total_seconds() / 3600

        return {
            "date": target_date.isoformat(),
            "sunrise": sunrise.strftime("%H:%M"),
            "sunset": sunset.strftime("%H:%M"),
            "day_length_hours": round(day_length, 2),
        }
