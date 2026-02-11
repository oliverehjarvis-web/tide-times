"""
Offline tide prediction using harmonic analysis via uptide.
Calculates tide heights at arbitrary times and finds high/low extremes.
"""
import json
import numpy as np
from datetime import datetime, timedelta
from uptide import Tides
from ..config import HARMONICS_PATH


class TideCalculator:
    def __init__(self):
        with open(HARMONICS_PATH) as f:
            self._data = json.load(f)

        self._tides = {}
        self._amplitudes = {}
        self._phases = {}
        self._mean_levels = {}
        self._offsets = {}
        self._epoch = datetime(2026, 1, 1)

        for loc_id, loc_data in self._data.items():
            names = [c["name"] for c in loc_data["constituents"]]
            tide = Tides(names)
            tide.set_initial_time(self._epoch)

            self._tides[loc_id] = tide
            self._amplitudes[loc_id] = np.array([c["amplitude"] for c in loc_data["constituents"]])
            self._phases[loc_id] = np.array([c["phase"] for c in loc_data["constituents"]])
            self._mean_levels[loc_id] = loc_data["mean_level"]
            self._offsets[loc_id] = loc_data.get("offsets_from_newquay")

    def height_at(self, location: str, dt: datetime) -> float:
        """Calculate tide height at a specific time for a location."""
        # Use newquay constituents for subordinate stations
        base_loc = "newquay" if self._offsets.get(location) else location
        t_sec = (dt - self._epoch).total_seconds()

        tide = self._tides[base_loc]
        height = self._mean_levels[base_loc] + tide.from_amplitude_phase(
            self._amplitudes[base_loc], self._phases[base_loc], t_sec
        )

        # Apply subordinate station offsets
        offsets = self._offsets.get(location)
        if offsets:
            height += offsets.get("height_hw_m", 0) / 2 + offsets.get("height_lw_m", 0) / 2

        return float(height)

    def hourly_heights(self, location: str, date: datetime) -> list[tuple[datetime, float]]:
        """Calculate hourly tide heights for a full day."""
        results = []
        start = datetime(date.year, date.month, date.day)
        for hour in range(25):  # 0-24 inclusive for smooth charts
            dt = start + timedelta(hours=hour)
            h = self.height_at(location, dt)
            results.append((dt, h))
        return results

    def find_extremes(self, location: str, date: datetime) -> list[dict]:
        """Find high and low tide times and heights for a day.

        Uses 6-minute resolution scanning with parabolic refinement.
        """
        offsets = self._offsets.get(location)
        time_offset_hw = timedelta(minutes=offsets["time_hw_min"]) if offsets else timedelta()
        time_offset_lw = timedelta(minutes=offsets["time_lw_min"]) if offsets else timedelta()
        height_offset_hw = offsets["height_hw_m"] if offsets else 0
        height_offset_lw = offsets["height_lw_m"] if offsets else 0

        base_loc = "newquay" if offsets else location

        # Scan at 6-minute intervals over the day (with buffer)
        start = datetime(date.year, date.month, date.day) - timedelta(hours=1)
        end = start + timedelta(hours=26)
        step = timedelta(minutes=6)

        times = []
        heights = []
        t = start
        while t <= end:
            t_sec = (t - self._epoch).total_seconds()
            h = self._mean_levels[base_loc] + self._tides[base_loc].from_amplitude_phase(
                self._amplitudes[base_loc], self._phases[base_loc], t_sec
            )
            times.append(t)
            heights.append(h)
            t += step

        # Find local extremes
        extremes = []
        for i in range(1, len(heights) - 1):
            if heights[i] > heights[i-1] and heights[i] > heights[i+1]:
                # High tide - refine with parabolic interpolation
                refined_t, refined_h = self._refine_extreme(times, heights, i)
                if datetime(date.year, date.month, date.day) <= refined_t < datetime(date.year, date.month, date.day) + timedelta(days=1):
                    extremes.append({
                        "datetime": refined_t + time_offset_hw,
                        "height": refined_h + height_offset_hw,
                        "type": "high",
                    })
            elif heights[i] < heights[i-1] and heights[i] < heights[i+1]:
                # Low tide
                refined_t, refined_h = self._refine_extreme(times, heights, i)
                if datetime(date.year, date.month, date.day) <= refined_t < datetime(date.year, date.month, date.day) + timedelta(days=1):
                    extremes.append({
                        "datetime": refined_t + time_offset_lw,
                        "height": refined_h + height_offset_lw,
                        "type": "low",
                    })

        extremes.sort(key=lambda e: e["datetime"])
        return extremes

    def _refine_extreme(self, times, heights, idx):
        """Parabolic interpolation to refine extreme time and height."""
        t0 = (times[idx-1] - self._epoch).total_seconds()
        t1 = (times[idx] - self._epoch).total_seconds()
        t2 = (times[idx+1] - self._epoch).total_seconds()
        h0, h1, h2 = heights[idx-1], heights[idx], heights[idx+1]

        # Parabolic interpolation
        denom = (t0 - t1) * (t0 - t2) * (t1 - t2)
        if abs(denom) < 1e-10:
            return times[idx], h1

        a = (t2 * (h1 - h0) + t1 * (h0 - h2) + t0 * (h2 - h1)) / denom
        b = (t2*t2 * (h0 - h1) + t1*t1 * (h2 - h0) + t0*t0 * (h1 - h2)) / denom

        if abs(a) < 1e-10:
            return times[idx], h1

        t_peak = -b / (2 * a)
        h_peak = h1 + a * (t_peak - t1) ** 2 + b * (t_peak - t1)

        # Use the actual height calculation at the refined time for accuracy
        refined_dt = self._epoch + timedelta(seconds=t_peak)
        refined_h = self.height_at("newquay" if self._offsets.get(times[idx]) else "newquay", refined_dt)

        return refined_dt, heights[idx]  # Use scanned height for stability

    def get_location_info(self, location: str) -> dict:
        return self._data.get(location, {})

    @property
    def locations(self) -> dict:
        return self._data
