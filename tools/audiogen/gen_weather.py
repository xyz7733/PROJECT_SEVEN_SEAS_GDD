#!/usr/bin/env python3
"""Original weather sounds and the boss horn for Project Seven Seas.

Everything is synthesised from shaped noise and sine partials with fixed
random seeds, so the files carry no third-party rights. They are released
with the project under CC0 1.0.

- ambience/rain_loop.wav, ambience/storm_loop.wav: seamless loops. The noise
  is shaped in the frequency domain (so it is periodic over the file), the
  droplets wrap around the end and every slow swell completes a whole
  number of cycles, so the loop point is inaudible.
- sfx/thunder_near.wav, sfx/thunder_far.wav: a crack and a rolling rumble,
  and a distant roll without the crack.
- sfx/boss_horn.wav: a low war horn on an open fifth over two drum hits,
  played when a boss steps forward.

Usage: tools/artgen/.venv/bin/python tools/audiogen/gen_weather.py
"""
from __future__ import annotations

import wave
from pathlib import Path

import numpy as np

SR = 22050
ROOT = Path(__file__).resolve().parents[2] / "game" / "assets" / "audio"


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def shaped_noise(n, rng, gain_fn):
    """Periodic noise of n samples whose spectrum follows gain_fn(freq)."""
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    spec *= gain_fn(f)
    x = np.fft.irfft(spec, n)
    return x / max(1e-9, np.max(np.abs(x)))


def band(f, lo, hi, slope=2.0):
    """Smooth band-pass gain: flat between lo and hi, rolling off outside."""
    g = np.ones_like(f)
    with np.errstate(divide="ignore", invalid="ignore"):
        g *= 1.0 / (1.0 + (lo / np.maximum(f, 1.0)) ** (2 * slope))
        g *= 1.0 / (1.0 + (f / hi) ** (2 * slope))
    return g


def peak(f, centre, width):
    return np.exp(-0.5 * ((f - centre) / width) ** 2)


def lfo(n, cycles, phase=0.0):
    """A slow swell that completes a whole number of cycles over n samples."""
    t = np.arange(n) / n
    return 0.5 + 0.5 * np.sin(2 * np.pi * (cycles * t + phase))


def droplet(rng, f0, dur):
    """A raindrop: a tiny bubble whose pitch rises as it rings down."""
    m = int(SR * dur)
    t = np.arange(m) / SR
    f = f0 * (1.0 + 2.5 * t / dur)
    ph = 2 * np.pi * np.cumsum(f) / SR
    env = np.exp(-t / (dur * 0.28)) * np.minimum(1.0, t / 0.0006)
    click = np.zeros(m)
    k = min(m, 12)
    click[:k] = rng.uniform(-1, 1, k) * np.linspace(1, 0, k)
    return np.sin(ph) * env * 0.8 + click * 0.5


def place_wrapped(track, sig, at):
    n = len(track)
    idx = (np.arange(len(sig)) + at) % n
    np.add.at(track, idx, sig)


def place(track, sig, at):
    i = int(at * SR)
    end = min(len(track), i + len(sig))
    if end > i:
        track[i:end] += sig[: end - i]


def drops(n, rng, count, loud=1.0):
    tr = np.zeros(n)
    for _ in range(count):
        f0 = rng.uniform(900, 3600)
        d = droplet(rng, f0, rng.uniform(0.006, 0.02))
        place_wrapped(tr, d * loud * rng.uniform(0.15, 1.0) ** 2, int(rng.integers(0, n)))
    return tr


def onepole_lp(x, k):
    """First-order low-pass via the FFT (periodic; fine for loops)."""
    n = len(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    fc = k * SR / (2 * np.pi)
    return np.fft.irfft(np.fft.rfft(x) / (1 + 1j * f / fc), n)


def lowpass(x, k):
    """The same filter for one-shots: zero-padded, so nothing wraps round."""
    n = len(x)
    return onepole_lp(np.concatenate([x, np.zeros(n)]), k)[:n]


def rain(secs=8.0, seed=11):
    rng = np.random.default_rng(seed)
    n = int(SR * secs)
    hiss = shaped_noise(n, rng, lambda f: band(f, 900, 7000, 1.5) * (1000.0 / np.maximum(f, 300.0)) ** 0.35)
    body = shaped_noise(n, rng, lambda f: band(f, 120, 900, 1.5))
    swell = 0.8 + 0.2 * lfo(n, 2, 0.1) * lfo(n, 3, 0.6)
    x = (0.42 * hiss + 0.22 * body) * swell
    x += 0.55 * drops(n, rng, int(secs * 260))
    # a few nearer, heavier drops on a roof or a deck
    x += 0.9 * onepole_lp(drops(n, rng, int(secs * 14), 1.0), 0.35)
    return x


def storm(secs=10.0, seed=23):
    rng = np.random.default_rng(seed)
    n = int(SR * secs)
    hiss = shaped_noise(n, rng, lambda f: band(f, 700, 8000, 1.3) * (1000.0 / np.maximum(f, 250.0)) ** 0.25)
    body = shaped_noise(n, rng, lambda f: band(f, 90, 1200, 1.4))
    gust = 0.62 + 0.38 * lfo(n, 2, 0.2) ** 1.6
    x = (0.5 * hiss + 0.34 * body) * gust
    x += 0.6 * drops(n, rng, int(secs * 420))
    # wind moaning through rigging: two narrow resonances that swell apart
    for centre, width, cyc, ph, amp in [(310, 18, 1, 0.0, 0.32), (470, 26, 3, 0.4, 0.2), (690, 40, 2, 0.75, 0.12)]:
        moan = shaped_noise(n, rng, lambda f, c=centre, w=width: peak(f, c, w))
        x += amp * moan * lfo(n, cyc, ph) ** 2
    rumble = shaped_noise(n, rng, lambda f: band(f, 25, 140, 2.0))
    x += 0.3 * rumble * (0.6 + 0.4 * lfo(n, 1, 0.3))
    return x


def thunder(seed, crack=True, secs=4.6):
    rng = np.random.default_rng(seed)
    n = int(SR * secs)
    t = np.arange(n) / SR
    tr = np.zeros(n)
    start = 0.0 if crack else 0.15
    if crack:
        # the crack: a dense burst of broadband noise and a few sharp snaps
        m = int(SR * 1.0)
        tc = np.arange(m) / SR
        burst = rng.standard_normal(m) * np.exp(-tc / 0.07)
        burst = lowpass(burst, 1.6)
        place(tr, 0.9 * burst, 0.0)
        for k in range(5):
            at = rng.uniform(0.0, 0.18)
            ln = int(SR * 0.01)
            snap = rng.uniform(-1, 1, ln) * np.linspace(1, 0, ln)
            place(tr, snap * rng.uniform(0.4, 0.9), at)
    # the roll: brown-ish low noise under a chain of overlapping swells
    roll = shaped_noise(n, rng, lambda f: band(f, 22, 180 if crack else 120, 1.6) * (60.0 / np.maximum(f, 30.0)) ** 0.6)
    env = np.zeros(n)
    at = start
    while at < secs - 0.8:
        width = rng.uniform(0.25, 0.7)
        height = rng.uniform(0.5, 1.0) * np.exp(-(at - start) / (1.6 if crack else 2.2))
        env += height * np.exp(-0.5 * ((t - at - width) / (width * 0.6)) ** 2)
        at += rng.uniform(0.18, 0.55)
    env *= np.minimum(1.0, t / 0.03)
    tr += (1.1 if crack else 0.9) * roll * env
    tail = np.minimum(1.0, (secs - t) / 0.9)
    tr *= tail
    # soft saturation keeps the crack from dwarfing the roll after normalising
    tr /= max(1e-9, np.max(np.abs(tr)))
    return np.tanh(2.2 * tr)


def boss_horn(seed=5, secs=2.6):
    rng = np.random.default_rng(seed)
    n = int(SR * secs)
    t = np.arange(n) / SR
    tr = np.zeros(n)
    # two drum hits: a pitched-down sine thump with a skin slap
    for at, amp in [(0.0, 1.0), (0.42, 0.75)]:
        m = int(SR * 1.8)
        td = np.arange(m) / SR
        f = 52.0 + 60.0 * np.exp(-td / 0.04)
        thump = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-td / 0.22)
        slap = rng.standard_normal(m) * np.exp(-td / 0.012)
        place(tr, amp * (0.9 * thump + 0.25 * lowpass(slap, 0.6)), at)
    # the horn: D2 and A2 with a brassy stack of harmonics, scooping up into
    # pitch, a slow vibrato and a swell
    h_start = 0.5
    th = np.clip(t - h_start, 0.0, None)
    env = np.minimum(1.0, th / 0.28) * np.exp(-np.clip(th - 1.3, 0.0, None) / 0.45) * (t >= h_start)
    for note, amp in [(38, 1.0), (45, 0.6), (50, 0.25)]:
        f0 = midi(note)
        scoop = 2 ** ((-1.2 * np.exp(-th / 0.12)) / 12)
        vib = 1.0 + 0.004 * np.sin(2 * np.pi * 5.2 * th) * np.minimum(1.0, th / 0.6)
        ph = 2 * np.pi * np.cumsum(f0 * scoop * vib) / SR
        voice = np.zeros(n)
        for h in range(1, 14):
            # brass formant: the harmonics around 400-700 Hz ring loudest
            fh = f0 * h
            g = (1.0 / h ** 0.7) * (0.35 + np.exp(-0.5 * ((fh - 560.0) / 260.0) ** 2))
            if fh > 4000:
                break
            voice += g * np.sin(h * ph + rng.uniform(0, 2 * np.pi))
        tr += amp * 0.22 * voice * env
    # a low rumble under it all
    rum = shaped_noise(n, rng, lambda f: band(f, 25, 110, 2.0))
    tr += 0.25 * rum * np.minimum(1.0, t / 0.4) * np.exp(-t / 1.4)
    tail = np.minimum(1.0, (secs - t) / 0.4)
    return lowpass(tr, 0.9) * tail


def write(rel, x, peak_level=0.82, loop=False):
    x = x / max(1e-6, np.max(np.abs(x))) * peak_level
    if not loop:
        fade = int(0.05 * SR)
        x[-fade:] *= np.linspace(1, 0, fade)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print("wrote", path, "%.2fs" % (len(x) / SR))


if __name__ == "__main__":
    write("ambience/rain_loop.wav", rain(), 0.7, loop=True)
    write("ambience/storm_loop.wav", storm(), 0.78, loop=True)
    write("sfx/thunder_near.wav", thunder(31, True), 0.9)
    write("sfx/thunder_far.wav", thunder(47, False), 0.75)
    write("sfx/boss_horn.wav", boss_horn(), 0.88)
