#!/usr/bin/env python3
"""Original, quiet regional soundscapes for Project Seven Seas.

All sounds are synthesised here from fixed-seed shaped noise and short
resonant events, with no recordings or third-party samples. Released under
CC0 1.0. The regional layers sit under the licensed sea/port/cave beds.
These are environmental textures, not replacement music tracks.

Periodic filtering, whole-cycle swells and wrapped one-shots make the WAV
files loop continuously. Use: python tools/audiogen/gen_regional.py
"""
from __future__ import annotations

import json
import math
from pathlib import Path
import wave

import numpy as np

SR = 22050
DURATION = 24.0
OUT = Path(__file__).resolve().parents[2] / "game/assets/audio/ambience/regional"
PROFILES = {
    "dawnwater": ("Sheltered fishing harbour: gentle surf, rope and wooden dock", 180, 1800, "wood", 8),
    "emberreach": ("Distant forge draft, cooling metal and low thermal air", 75, 850, "metal", 7),
    "verdant_maw": ("Leaf canopy, soft water drops and far insect calls", 480, 3600, "leaf", 16),
    "glass_current": ("Gentle air around suspended glass and crystal", 420, 2100, "glass", 6),
    "crown_shoals": ("Canvas awnings, distant workshop and harbour bell", 170, 1450, "cloth", 10),
    "stormbelt": ("Wind over stone shelter, loose rigging and distant spray", 95, 1500, "rigging", 10),
    "moonwake": ("Quiet night air, moth-wing rustle and distant observatory chimes", 260, 1400, "moon", 6),
    "ashen_trench": ("Low vent draft, settling stone and copper equipment", 45, 700, "stone", 9),
    "leviathan_ring": ("Warm lagoon wash, coral bubbles and shell resonance", 200, 1650, "bubble", 14),
    "grand_horizon": ("High harbour breeze, ceremonial brass and distant flags", 180, 1450, "brass", 6),
    "cabin": ("Sheltered timber creaks, cloth and restrained work taps", 80, 580, "cabin", 10),
}


def band(freq, low, high):
    f = np.maximum(freq, 1.0)
    return 1.0 / (1.0 + (low / f) ** 4) / (1.0 + (f / high) ** 4)


def noise(length, rng, low, high):
    spectrum = np.fft.rfft(rng.standard_normal(length))
    freq = np.fft.rfftfreq(length, 1.0 / SR)
    shaped = np.fft.irfft(spectrum * band(freq, low, high), length)
    return shaped / max(1e-9, np.max(np.abs(shaped)))


def wrap_into(track, signal, offset):
    indices = (np.arange(len(signal)) + int(offset)) % len(track)
    np.add.at(track, indices, signal)


def resonant_event(kind, rng):
    """Transient materials, deliberately inharmonic and softly attacked."""
    duration = {"wood": 0.38, "metal": 1.8, "leaf": 0.18, "glass": 2.6,
                "cloth": 0.55, "rigging": 0.8, "moon": 3.2, "stone": 0.7,
                "bubble": 0.2, "brass": 2.8, "cabin": 0.65}[kind]
    n = int(SR * duration)
    t = np.arange(n) / SR
    attack = np.minimum(1.0, t / 0.012)
    fade = np.minimum(1.0, (duration - t) / 0.08)
    signal = np.zeros(n)
    if kind in {"glass", "moon", "brass", "metal"}:
        base = {"glass": 1046.5, "moon": 523.25, "brass": 261.63, "metal": 367.0}[kind]
        base *= float(rng.choice([1.0, 1.5, 2.0]))
        for ratio, gain in [(1.0, 0.65), (2.71, 0.24), (4.13, 0.09)]:
            frequency = base * ratio
            if frequency < SR * 0.42:
                signal += gain * np.sin(math.tau * frequency * t) * np.exp(-t / (duration * 0.22 / math.sqrt(ratio)))
        signal *= 0.22 if kind in {"glass", "moon"} else 0.15
        signal += noise(n, rng, 900, 3500) * np.exp(-t / 0.018) * 0.08
    elif kind == "bubble":
        frequency = rng.uniform(440, 820) * (1.0 + t / duration * 1.4)
        signal = np.sin(math.tau * np.cumsum(frequency) / SR) * np.exp(-t / 0.045) * 0.2
    elif kind == "leaf":
        signal = noise(n, rng, 1800, 6500) * np.sin(np.pi * t / duration) ** 2 * 0.24
        # Insect-like distant paired clicks, not a continuous pitched drone.
        signal += noise(n, rng, 2200, 3300) * np.exp(-((t - 0.06) / 0.012) ** 2) * 0.08
    elif kind in {"wood", "cabin"}:
        signal = noise(n, rng, 90, 480) * np.exp(-t / 0.06) * 0.45
        if kind == "cabin":
            grain = noise(n, rng, 180, 380)
            signal += grain * np.sin(np.pi * t / duration) ** 2 * 0.13
        for freq in (170.0, 307.0):
            signal += np.sin(math.tau * freq * t) * np.exp(-t / 0.045) * 0.035
    elif kind == "cloth":
        signal = noise(n, rng, 900, 5000) * np.sin(np.pi * t / duration) ** 2 * 0.18
    elif kind == "rigging":
        signal = noise(n, rng, 280, 1700) * np.sin(np.pi * t / duration) ** 2 * 0.22
        signal += noise(n, rng, 80, 260) * np.exp(-t / 0.1) * 0.1
    else:
        signal = noise(n, rng, 45, 580) * np.exp(-t / 0.14) * 0.38
        signal += noise(n, rng, 1000, 3200) * np.exp(-t / 0.035) * 0.05
    return signal * attack * fade


def make_layer(name, seed):
    description, low, high, material, count = PROFILES[name]
    rng = np.random.default_rng(seed)
    n = int(SR * DURATION)
    u = np.arange(n) / n
    slow = 0.62 + 0.22 * np.sin(math.tau * (2 * u + 0.13)) + 0.12 * np.sin(math.tau * (3 * u + 0.57))
    track = noise(n, rng, low, high) * slow * (0.16 if name == "stormbelt" else 0.1)
    if name in {"dawnwater", "leviathan_ring", "grand_horizon"}:
        wash = noise(n, rng, 350, 3700)
        surf = (0.5 + 0.5 * np.sin(math.tau * (5 * u + 0.2))) ** 3
        track += wash * surf * 0.12
    if name in {"emberreach", "ashen_trench"}:
        track += noise(n, rng, 36, 180) * (0.4 + 0.6 * np.sin(math.tau * u) ** 2) * 0.07
    for index in range(count):
        # Stratified spacing leaves quiet gaps and avoids obvious metronomes.
        at = (index + rng.uniform(0.15, 0.85)) / count * n
        event = resonant_event(material, rng) * rng.uniform(0.36, 0.85)
        wrap_into(track, event, at)
    track -= np.mean(track)
    # Keep peak and RMS conservative: these layers supplement existing beds.
    track *= min(1.0, 0.3 / max(1e-9, np.max(np.abs(track))))
    data = np.round(np.clip(track, -1, 1) * 32767).astype("<i2")
    path = OUT / (name + ".wav")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SR)
        output.writeframes(data.tobytes())
    diff = np.diff(track)
    return {
        "file": path.name, "description": description, "seed": seed,
        "sampleRate": SR, "duration": DURATION, "channels": 1,
        "peakDbFS": round(float(20 * np.log10(max(1e-9, np.max(np.abs(track))))), 2),
        "rmsDbFS": round(float(20 * np.log10(max(1e-9, np.sqrt(np.mean(track ** 2))))), 2),
        "joinStep": round(float(abs(track[0] - track[-1])), 7),
        "joinTo95PercentileStep": round(float(abs(track[0] - track[-1]) / max(1e-9, np.percentile(np.abs(diff), 95))), 3),
        "origin": "Original procedural synthesis; tools/audiogen/gen_regional.py",
        "license": "CC0-1.0", "humanListeningReviewed": False,
    }


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    records = [make_layer(name, 7301 + i * 137) for i, name in enumerate(PROFILES)]
    (OUT / "manifest.json").write_text(json.dumps({"files": records}, indent=2) + "\n", encoding="utf-8")
    print(f"[audiogen] {len(records)} original mono layers, {DURATION:g}s each, {SR} Hz, CC0-1.0")
    for record in records:
        print(f"  {record['file']}: peak {record['peakDbFS']} dBFS; RMS {record['rmsDbFS']} dBFS; loop join ratio {record['joinTo95PercentileStep']}")


if __name__ == "__main__":
    main()
