"""
Scrape tide data from tidetimes.co.uk and fit harmonic constituents.
Fetches ~6 months of historical high/low data for Newquay to get
enough data points for accurate harmonic separation.
"""
import json
import re
import time
import numpy as np
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo
from urllib.request import urlopen, Request
from uptide import Tides
from uptide.analysis import harmonic_analysis

UK_TZ = ZoneInfo("Europe/London")
UTC_TZ = ZoneInfo("UTC")

LOCATIONS = {
    "newquay": {
        "slug": "newquay",
        "station": "Newquay",
        "port_id": "0546",
        "latitude": 50.4167,
        "longitude": -5.0833,
    },
}

# Subordinate stations - use Newquay harmonics with offsets
SUBORDINATE_STATIONS = {
    "holywell": {
        "station": "Holywell Bay",
        "latitude": 50.3930,
        "longitude": -5.1480,
        "offsets": {
            "time_hw_min": 0, "time_lw_min": 0,
            "height_hw_m": 0.0, "height_lw_m": 0.0,
        },
    },
    "polzeath": {
        "station": "Polzeath",
        "latitude": 50.5720,
        "longitude": -4.9190,
        "offsets": {
            "time_hw_min": 5, "time_lw_min": 5,
            "height_hw_m": 0.0, "height_lw_m": 0.0,
        },
    },
    "port_isaac": {
        "station": "Port Isaac",
        "latitude": 50.5930,
        "longitude": -4.8290,
        "offsets": {
            "time_hw_min": 6, "time_lw_min": 0,
            "height_hw_m": 0.5, "height_lw_m": 0.1,
        },
    },
}

CONSTITUENTS = [
    # Principal semidiurnal
    'M2', 'S2', 'N2', 'K2',
    # Additional semidiurnal
    '2N2', 'L2', 'MU2', 'NU2', 'T2',
    # Diurnal
    'K1', 'O1', 'P1', 'Q1',
    # Shallow water (quarter-diurnal)
    'M4', 'MS4', 'MN4',
]
EPOCH = datetime(2025, 1, 1)  # Use 2025 epoch since data spans 2025-2026


def fetch_page(slug, date_str):
    """Fetch a tide times page and return the HTML."""
    url = f"https://www.tidetimes.co.uk/{slug}-tide-times-{date_str}"
    req = Request(url, headers={"User-Agent": "TideTimesApp/1.0"})
    try:
        with urlopen(req, timeout=15) as resp:
            return resp.read().decode("utf-8")
    except Exception as e:
        print(f"  Error fetching {url}: {e}")
        return None


def parse_forecasts(html):
    """Extract tide forecasts from tt.forecast JSON in page JavaScript."""
    # Find the tt.forecast = {...}; block
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
                results.append({
                    "datetime": dt_str,
                    "height": float(height),
                    "is_high": tide_type == "HW",
                })
        except (ValueError, TypeError):
            continue

    return results


def scrape_location(slug, start_date, end_date):
    """Scrape tide data for a location over a date range."""
    all_data = []
    seen_datetimes = set()

    current = start_date
    while current <= end_date:
        date_str = current.strftime("%Y%m%d")
        print(f"  Fetching {slug} {date_str}...")
        html = fetch_page(slug, date_str)
        if html:
            forecasts = parse_forecasts(html)

            for f in forecasts:
                dt_key = f["datetime"][:16]
                if dt_key not in seen_datetimes:
                    seen_datetimes.add(dt_key)
                    all_data.append(f)

        # Each page shows 7 days, so jump ahead 7 days
        current += timedelta(days=7)
        time.sleep(0.5)  # Be polite

    all_data.sort(key=lambda x: x["datetime"])
    return all_data


def fit_harmonics(tide_data):
    """Fit harmonic constituents from scraped tide data."""
    times_dt = []
    heights = []

    for entry in tide_data:
        dt_str = entry["datetime"]
        # Handle various datetime formats
        for fmt in ["%Y-%m-%dT%H:%M:%S", "%Y-%m-%dT%H:%M", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M"]:
            try:
                dt = datetime.strptime(dt_str[:19], fmt)
                break
            except ValueError:
                continue
        else:
            print(f"  Skipping unparseable datetime: {dt_str}")
            continue

        # tidetimes.co.uk returns local UK time (GMT/BST)
        # Convert to UTC for harmonic analysis
        dt_local = dt.replace(tzinfo=UK_TZ)
        dt_utc = dt_local.astimezone(UTC_TZ).replace(tzinfo=None)

        times_dt.append(dt_utc)
        heights.append(entry["height"])

    heights = np.array(heights)
    mean_level = np.mean(heights)
    heights_centered = heights - mean_level

    times_sec = np.array([
        (dt - EPOCH).total_seconds() for dt in times_dt
    ])

    tide = Tides(CONSTITUENTS)
    tide.set_initial_time(EPOCH)

    amplitudes, phases = harmonic_analysis(tide, heights_centered, times_sec)

    return mean_level, amplitudes, phases, tide, times_dt, heights


def verify_predictions(mean_level, amplitudes, phases, tide, times_dt, known_heights):
    """Verify fitted model against all known data."""
    errors = []
    for dt, known_h in zip(times_dt, known_heights):
        t_sec = (dt - EPOCH).total_seconds()
        predicted = mean_level + tide.from_amplitude_phase(amplitudes, phases, t_sec)
        errors.append(abs(predicted - known_h))

    mae = np.mean(errors)
    max_err = np.max(errors)
    print(f"\n  Verification ({len(errors)} data points):")
    print(f"  Mean absolute error: {mae:.3f}m")
    print(f"  Max absolute error:  {max_err:.3f}m")

    # Show worst predictions
    sorted_idx = np.argsort(errors)[-5:]
    print(f"\n  Worst predictions:")
    for idx in reversed(sorted_idx):
        dt = times_dt[idx]
        t_sec = (dt - EPOCH).total_seconds()
        predicted = mean_level + tide.from_amplitude_phase(amplitudes, phases, t_sec)
        print(f"    {dt.strftime('%Y-%m-%d %H:%M')}: known={known_heights[idx]:.2f}, predicted={predicted:.2f}, error={errors[idx]:.2f}")

    return mae


def verify_against_known():
    """Verify against the specific data point the user mentioned."""
    print("\n  Checking Feb 17 05:07 (expected: 6.70m high tide)...")


def main():
    # Scrape ~6.5 months of data: Aug 2025 to Feb 2026
    start = datetime(2025, 8, 1)
    end = datetime(2026, 2, 17)

    print("=" * 60)
    print("Scraping tide data from tidetimes.co.uk")
    print("=" * 60)

    for loc_id, loc_info in LOCATIONS.items():
        print(f"\nScraping {loc_info['station']}...")
        data = scrape_location(loc_info["slug"], start, end)
        print(f"  Collected {len(data)} tide events")

        if len(data) < 50:
            print("  ERROR: Not enough data points. Aborting.")
            return

        print(f"\n  Date range: {data[0]['datetime'][:10]} to {data[-1]['datetime'][:10]}")
        print(f"  Fitting {len(CONSTITUENTS)} harmonic constituents...")

        mean_level, amplitudes, phases, tide, times_dt, heights = fit_harmonics(data)

        print(f"\n  Mean sea level: {mean_level:.3f}m above CD")
        print(f"\n  Fitted constituents:")
        print(f"  {'Name':>6} {'Amplitude':>12} {'Phase (rad)':>12}")
        print("  " + "-" * 34)
        for i, name in enumerate(CONSTITUENTS):
            print(f"  {name:>6} {amplitudes[i]:>12.4f} {phases[i]:>12.4f}")

        mae = verify_predictions(mean_level, amplitudes, phases, tide, times_dt, heights)

        # Verify the specific Feb 17 prediction (05:07 local = 05:07 UTC in Feb)
        dt_check = datetime(2026, 2, 17, 5, 7)  # Feb is GMT, so local == UTC
        t_sec = (dt_check - EPOCH).total_seconds()
        predicted = mean_level + tide.from_amplitude_phase(amplitudes, phases, t_sec)
        print(f"\n  Feb 17 05:07 UTC prediction: {predicted:.2f}m (expected: 6.70m)")

        # Also find actual predicted high tide time near Feb 17 morning
        print("\n  Scanning Feb 17 for high/low tides...")
        scan_start = datetime(2026, 2, 17, 0, 0)
        prev_h = None
        prev_t = None
        for minute in range(0, 24*60, 3):
            dt = scan_start + timedelta(minutes=minute)
            t_sec = (dt - EPOCH).total_seconds()
            h = mean_level + tide.from_amplitude_phase(amplitudes, phases, t_sec)
            if prev_h is not None and prev_t is not None:
                if minute >= 6:
                    dt_prev2 = scan_start + timedelta(minutes=minute-6)
                    t_prev2 = (dt_prev2 - EPOCH).total_seconds()
                    h_prev2 = mean_level + tide.from_amplitude_phase(amplitudes, phases, t_prev2)
                    if prev_h > h and prev_h > h_prev2:
                        print(f"    HIGH: {prev_t.strftime('%H:%M')} UTC = {prev_h:.2f}m")
                    elif prev_h < h and prev_h < h_prev2:
                        print(f"    LOW:  {prev_t.strftime('%H:%M')} UTC = {prev_h:.2f}m")
            prev_h = h
            prev_t = dt

        # Build output
        locations = {}

        # Newquay
        constituents_list = []
        for i, name in enumerate(CONSTITUENTS):
            constituents_list.append({
                "name": name,
                "amplitude": float(amplitudes[i]),
                "phase": float(phases[i]),
            })

        locations["newquay"] = {
            "station": "Newquay",
            "port_id": "0546",
            "latitude": 50.4167,
            "longitude": -5.0833,
            "datum": "Chart Datum (LAT)",
            "mean_level": float(mean_level),
            "epoch": EPOCH.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "constituents": constituents_list,
        }

        # Subordinate stations
        for sub_id, sub_info in SUBORDINATE_STATIONS.items():
            locations[sub_id] = {
                "station": sub_info["station"],
                "port_id": "N/A",
                "latitude": sub_info["latitude"],
                "longitude": sub_info["longitude"],
                "datum": "Chart Datum (LAT)",
                "mean_level": float(mean_level),
                "epoch": EPOCH.strftime("%Y-%m-%dT%H:%M:%SZ"),
                "constituents": constituents_list,
                "offsets_from_newquay": sub_info["offsets"],
            }

        output_path = "app/data/harmonics.json"
        with open(output_path, "w") as f:
            json.dump(locations, f, indent=2)
        print(f"\n  Saved to {output_path}")

    print("\n" + "=" * 60)
    print("Done!")


if __name__ == "__main__":
    main()
