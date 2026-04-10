#!/usr/bin/env python3
"""
Write a short, clean unvoiced /s/-like fricative (band-shaped noise — no TTS vowels).
Mono 16-bit LE PCM @ 22050 Hz, matching other segmentation / word WAVs.

`say` cannot produce a true voiceless fricative; this is a common stand-in. For a
recorded human /s/, drop a hand-made s.wav in Sounds/Segmentation/ instead.
"""

from __future__ import annotations

import argparse
import math
import random
import struct
import wave


def main() -> None:
    p = argparse.ArgumentParser(description="Generate s.wav-style fricative clip.")
    p.add_argument("-o", "--output", required=True, help="Output .wav path")
    p.add_argument("--sr", type=int, default=22050, help="Sample rate (Hz)")
    p.add_argument("--duration", type=float, default=0.26, help="Seconds")
    p.add_argument("--seed", type=int, default=42, help="RNG seed (reproducible)")
    args = p.parse_args()

    rng = random.Random(args.seed)
    n = max(1, int(args.sr * args.duration))
    # Gaussian noise = smoother spectrum than uniform (less “hashy” static).
    x = [rng.gauss(0.0, 1.0) for _ in range(n)]

    # Pre-emphasis (speech-style): boosts highs, closer to unvoiced fricative energy.
    coef = 0.94
    for _ in range(2):
        prev = 0.0
        y: list[float] = []
        for v in x:
            y.append(v - coef * prev)
            prev = v
        peak = max(abs(v) for v in y) or 1.0
        x = [v / peak for v in y]

    rms = math.sqrt(sum(v * v for v in x) / len(x))
    if rms > 1e-12:
        x = [v * (0.24 / rms) for v in x]

    out: list[float] = []
    for i, v in enumerate(x):
        w = 0.5 - 0.5 * math.cos(2.0 * math.pi * (i + 0.5) / n)
        out.append(v * w)

    with wave.open(args.output, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(args.sr)
        for v in out:
            s = max(-1.0, min(1.0, v))
            wf.writeframes(struct.pack("<h", int(s * 32767.0 * 0.88)))


if __name__ == "__main__":
    main()
