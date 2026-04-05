#!/usr/bin/env python3
"""
Placeholder word WAVs: macOS uses `say` + `afconvert` (robotic TTS).
Other platforms: short distinct tones (replace manually with real recordings later).
"""
from __future__ import annotations

import math
import os
import struct
import subprocess
import sys
import wave

# Unique stems from Resources/Seed/words.json (one file per stem).
WORDS = [
    "cat", "bat", "cup", "dog", "egg", "fish", "goat", "hat", "igloo", "jam",
    "kite", "leg", "man", "net", "pen", "queen", "rat", "sun", "top",
]


def repo_root() -> str:
    return os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


def out_dir() -> str:
    return os.path.join(
        repo_root(),
        "FlashCards",
        "Resources",
        "WordsAudio",
    )


def write_tone_wav(path: str, word: str, framerate: int = 22050) -> None:
    """Very low-quality distinct placeholder: short sine burst; not speech."""
    # Stable pseudo-frequency from letters so files differ.
    h = sum(ord(c) for c in word) % 500
    freq = 200 + h
    duration = 0.35 + (len(word) % 5) * 0.05
    nframes = int(duration * framerate)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(framerate)
        for i in range(nframes):
            t = i / framerate
            env = min(1.0, i / 800) * min(1.0, (nframes - i) / 800)
            sample = int(32767 * 0.25 * env * math.sin(2 * math.pi * freq * t))
            w.writeframes(struct.pack("<h", max(-32767, min(32767, sample))))


def macos_say_wav(path: str, word: str) -> bool:
    tmp_aiff = path + ".tmp.aiff"
    try:
        subprocess.run(
            ["say", "-o", tmp_aiff, word],
            check=True,
            capture_output=True,
        )
        subprocess.run(
            ["afconvert", "-f", "WAVE", "-d", "LEI16@22050", tmp_aiff, path],
            check=True,
            capture_output=True,
        )
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False
    finally:
        if os.path.isfile(tmp_aiff):
            os.remove(tmp_aiff)


def main() -> int:
    od = out_dir()
    os.makedirs(od, exist_ok=True)
    use_say = sys.platform == "darwin"
    for w in WORDS:
        dest = os.path.join(od, f"{w}.wav")
        if use_say and macos_say_wav(dest, w):
            print(f"OK (say): {dest}")
        else:
            write_tone_wav(dest, w)
            print(f"OK (tone): {dest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
