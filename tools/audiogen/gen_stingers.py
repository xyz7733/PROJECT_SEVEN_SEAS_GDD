#!/usr/bin/env python3
"""Original victory and defeat stingers for Project Seven Seas.

Synthesised from scratch (Karplus-Strong plucked strings plus a soft bell
made of decaying sine partials), so they carry no third-party rights. They
are released with the project under CC0 1.0.

Usage: tools/artgen/.venv/bin/python tools/audiogen/gen_stingers.py
"""
from __future__ import annotations

import wave
from pathlib import Path

import numpy as np

SR = 22050
OUT = Path(__file__).resolve().parents[2] / "game" / "assets" / "audio" / "sfx"


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def pluck(freq, dur, rng, bright=0.5):
    n = int(SR * dur)
    period = max(2, int(SR / freq))
    buf = rng.uniform(-1, 1, period)
    # soften the excitation for a warmer, lute-like tone
    for _ in range(int(3 - 2 * bright)):
        buf = 0.5 * (buf + np.roll(buf, 1))
    out = np.zeros(n)
    decay = 0.996
    for i in range(n):
        out[i] = buf[i % period]
        j = i % period
        buf[j] = decay * 0.5 * (buf[j] + buf[(j + 1) % period])
    return out


def bell(freq, dur, amp=0.35):
    t = np.arange(int(SR * dur)) / SR
    s = np.zeros_like(t)
    for mult, a, d in [(1.0, 1.0, 1.6), (2.0, 0.5, 1.1), (2.76, 0.3, 0.8), (5.4, 0.12, 0.4)]:
        s += a * np.sin(2 * np.pi * freq * mult * t) * np.exp(-t / d)
    env = np.minimum(1.0, t / 0.004)
    return amp * s * env


def place(track, sig, at):
    i = int(at * SR)
    end = min(len(track), i + len(sig))
    track[i:end] += sig[: end - i]


def lowpass(x, k=0.25):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += k * (v - acc)
        y[i] = acc
    return y


def write(name, x):
    x = x / max(1e-6, np.max(np.abs(x))) * 0.82
    fade = int(0.08 * SR)
    x[-fade:] *= np.linspace(1, 0, fade)
    data = (x * 32767).astype("<i2").tobytes()
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print("wrote", OUT / name, "%.2fs" % (len(x) / SR))


def victory():
    rng = np.random.default_rng(7)
    tr = np.zeros(int(SR * 2.6))
    # rising D major arpeggio, then a held chord with a ship's-bell top
    notes = [(62, 0.00), (66, 0.13), (69, 0.26), (74, 0.42)]
    for n, at in notes:
        place(tr, 0.6 * pluck(midi(n), 1.6, rng, 0.8), at)
    for n in (62, 66, 69, 74, 78):
        place(tr, 0.35 * pluck(midi(n), 2.0, rng, 0.6), 0.62 + 0.012 * (n % 5))
    place(tr, bell(midi(86), 1.9, 0.25), 0.62)
    return tr


def defeat():
    rng = np.random.default_rng(3)
    tr = np.zeros(int(SR * 2.9))
    # slow falling D minor line ending on a low open fifth
    notes = [(69, 0.00), (65, 0.34), (62, 0.68), (57, 1.05)]
    for n, at in notes:
        place(tr, 0.6 * pluck(midi(n), 1.8, rng, 0.2), at)
    for n in (50, 57):
        place(tr, 0.45 * pluck(midi(n), 1.8, rng, 0.1), 1.05)
    place(tr, bell(midi(62), 1.8, 0.18), 1.05)
    return lowpass(tr, 0.35)


if __name__ == "__main__":
    write("stinger_victory.wav", victory())
    write("stinger_defeat.wav", defeat())
