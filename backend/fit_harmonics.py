"""
Bootstrap script: Fit harmonic constituents from known tide predictions.
Uses real Newquay tide data to derive harmonic constants for offline prediction.
"""
import json
import numpy as np
from datetime import datetime
from uptide import Tides
from uptide.analysis import harmonic_analysis

# Real tide data for Newquay from ADMIRALTY predictions (Feb 2026, UTC)
# Source: tidetimes.co.uk (ADMIRALTY port 0546)
NEWQUAY_DATA = [
    ("2026-02-11 05:37", 3.06),
    ("2026-02-11 11:43", 4.68),
    ("2026-02-11 18:29", 3.18),
    ("2026-02-12 00:43", 4.68),
    ("2026-02-12 07:23", 3.13),
    ("2026-02-12 13:29", 4.66),
    ("2026-02-12 20:09", 3.02),
    ("2026-02-13 02:14", 4.95),
    ("2026-02-13 08:45", 2.76),
    ("2026-02-13 14:48", 5.01),
    ("2026-02-13 21:13", 2.56),
    ("2026-02-14 03:13", 5.43),
    ("2026-02-14 09:39", 2.24),
    ("2026-02-14 15:38", 5.47),
    ("2026-02-14 21:58", 2.04),
    ("2026-02-15 03:56", 5.92),
    ("2026-02-15 10:20", 1.71),
    ("2026-02-15 16:17", 5.91),
    ("2026-02-15 22:35", 1.55),
    ("2026-02-16 04:32", 6.35),
    ("2026-02-16 10:57", 1.24),
    ("2026-02-16 16:52", 6.29),
    ("2026-02-16 23:09", 1.12),
    ("2026-02-17 05:07", 6.70),
    ("2026-02-17 11:30", 0.84),
    ("2026-02-17 17:26", 6.61),
    ("2026-02-17 23:43", 0.78),
]

CONSTITUENTS = ['M2', 'S2', 'N2', 'K2', 'K1', 'O1', 'P1', 'Q1']
INITIAL_TIME = datetime(2026, 1, 1)


def fit_constituents():
    """Fit tidal harmonic constituents from known predictions."""
    times_dt = []
    heights = []
    for dt_str, h in NEWQUAY_DATA:
        times_dt.append(datetime.strptime(dt_str, "%Y-%m-%d %H:%M"))
        heights.append(h)

    heights = np.array(heights)
    mean_level = np.mean(heights)

    # Subtract mean level for harmonic analysis
    heights_centered = heights - mean_level

    # Convert times to seconds from initial time
    times_sec = np.array([
        (dt - INITIAL_TIME).total_seconds() for dt in times_dt
    ])

    # Create tides object
    tide = Tides(CONSTITUENTS)
    tide.set_initial_time(INITIAL_TIME)

    # Perform harmonic analysis
    amplitudes, phases = harmonic_analysis(tide, heights_centered, times_sec)

    return mean_level, amplitudes, phases, tide


def verify_predictions(mean_level, amplitudes, phases, tide):
    """Verify fitted model against known data."""
    print("\nVerification against known data:")
    print(f"{'DateTime':>20} {'Known':>8} {'Predicted':>10} {'Error':>8}")
    print("-" * 50)

    errors = []
    for dt_str, known_h in NEWQUAY_DATA:
        dt = datetime.strptime(dt_str, "%Y-%m-%d %H:%M")
        t_sec = (dt - INITIAL_TIME).total_seconds()
        predicted = mean_level + tide.from_amplitude_phase(amplitudes, phases, t_sec)
        error = predicted - known_h
        errors.append(abs(error))
        print(f"{dt_str:>20} {known_h:>8.2f} {predicted:>10.2f} {error:>8.2f}")

    print(f"\nMean absolute error: {np.mean(errors):.3f}m")
    print(f"Max absolute error:  {np.max(errors):.3f}m")
    return np.mean(errors)


def save_harmonics(mean_level, amplitudes, phases, location_name, port_id, lat, lon, offsets=None):
    """Save harmonic data to JSON."""
    constituents = []
    for i, name in enumerate(CONSTITUENTS):
        constituents.append({
            "name": name,
            "amplitude": float(amplitudes[i]),
            "phase": float(phases[i]),
        })

    data = {
        "station": location_name,
        "port_id": port_id,
        "latitude": lat,
        "longitude": lon,
        "datum": "Chart Datum (LAT)",
        "mean_level": float(mean_level),
        "fitted_from": "ADMIRALTY predictions Feb 2026",
        "constituents": constituents,
    }
    if offsets:
        data["offsets_from_newquay"] = offsets

    return data


def main():
    print("Fitting harmonic constituents for Newquay...")
    mean_level, amplitudes, phases, tide = fit_constituents()

    print(f"\nMean sea level: {mean_level:.3f}m above CD")
    print(f"\nFitted {len(CONSTITUENTS)} constituents:")
    print(f"{'Name':>6} {'Amplitude':>12} {'Phase (rad)':>12}")
    print("-" * 34)
    for i, name in enumerate(CONSTITUENTS):
        print(f"{name:>6} {amplitudes[i]:>12.4f} {phases[i]:>12.4f}")

    mae = verify_predictions(mean_level, amplitudes, phases, tide)

    # Build harmonics for all 4 locations
    locations = {
        "newquay": save_harmonics(
            mean_level, amplitudes, phases,
            "Newquay", "0546", 50.4167, -5.0833
        ),
        "holywell": save_harmonics(
            mean_level, amplitudes, phases,
            "Holywell Bay", "N/A", 50.3930, -5.1480,
            offsets={"time_hw_min": 0, "time_lw_min": 0,
                     "height_hw_m": 0.0, "height_lw_m": 0.0}
        ),
        "polzeath": save_harmonics(
            mean_level, amplitudes, phases,
            "Polzeath", "N/A", 50.5720, -4.9190,
            offsets={"time_hw_min": 5, "time_lw_min": 5,
                     "height_hw_m": 0.0, "height_lw_m": 0.0}
        ),
        "port_isaac": save_harmonics(
            mean_level, amplitudes, phases,
            "Port Isaac", "N/A", 50.5930, -4.8290,
            offsets={"time_hw_min": 6, "time_lw_min": 0,
                     "height_hw_m": 0.5, "height_lw_m": 0.1}
        ),
    }

    output_path = "backend/app/data/harmonics.json"
    with open(output_path, "w") as f:
        json.dump(locations, f, indent=2)
    print(f"\nSaved all locations to {output_path}")
    print(f"Mean absolute error: {mae:.3f}m")


if __name__ == "__main__":
    main()
