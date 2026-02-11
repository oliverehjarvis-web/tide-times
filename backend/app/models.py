from pydantic import BaseModel


class TideEvent(BaseModel):
    datetime_utc: str
    datetime_local: str
    type: str  # "high" or "low"
    height_metres: float


class HourlyLevel(BaseModel):
    datetime_utc: str
    height_metres: float


class SunTimes(BaseModel):
    date: str
    sunrise: str
    sunset: str
    day_length_hours: float


class LocationInfo(BaseModel):
    id: str
    name: str
    latitude: float
    longitude: float
    datum: str


class DayOverview(BaseModel):
    date: str
    location: str
    tides: list[TideEvent]
    sun: SunTimes
    hourly_levels: list[HourlyLevel]
