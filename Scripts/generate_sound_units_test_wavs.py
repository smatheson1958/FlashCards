#!/usr/bin/env python3
"""
Offline placeholder WAVs for all 146 curriculum sound rows (grapheme clip + example word).

- Reads `FlashCards/Resources/Seed/sound_units_primary_index_146.json`.
- Writes mono LEI16 @ 22050 Hz under `FlashCards/Resources/Sounds/SoundUnitsTest/`:
    NNN_sound.wav   — short phonics-style cue for the grapheme (Kate / `say`)
    NNN_word.wav    — speaks the example word
- Filenames match `audio.*.file` after `Scripts/merge_sound_units_primary_index_audio.py` (SoundUnitsTest/…).

macOS: `say` + `afconvert` (same stack as `generate_word_wavs.py`). Other platforms: sine tones.

Replace these with higher-quality phonics recordings later; keep the same names so JSON paths stay valid.

  VOICE=Kate SAY_RATE=220 python3 Scripts/generate_sound_units_test_wavs.py
  python3 Scripts/generate_sound_units_test_wavs.py --force
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SEED = ROOT / "FlashCards/Resources/Seed/sound_units_primary_index_146.json"
OUT_DIR = ROOT / "FlashCards/Resources/Sounds/SoundUnitsTest"

# Ids 1–55: foundation + digraphs through `si` (vision).
_PHRASES_1_55: tuple[str, ...] = (
    "ah",
    "eh",
    "ih",
    "oh",
    "uh",
    "buh",
    "kuh",
    "duh",
    "fuh",
    "guh",
    "huh",
    "juh",
    "kuh",
    "luh",
    "muh",
    "nuh",
    "puh",
    "ruh",
    "sss",
    "tuh",
    "vuh",
    "wuh",
    "yuh",
    "zuh",
    "ks",
    "f",
    "l",
    "sss",
    "zuh",
    "kuh",
    "shh",
    "ch",
    "thin",
    "this",
    "ung",
    "unk",
    "kw",
    "w",
    "f",
    "ch",
    "j",
    "j",
    "j",
    "j",
    "s",
    "s",
    "s",
    "r",
    "n",
    "n",
    "m",
    "s",
    "sh",
    "sh",
    "zh",
)

# Ids 56–146: vowel teams, r-controlled, schwa, alternates, -ed.
_PHRASES_56_146: tuple[str, ...] = (
    *("ay",) * 8,
    *("ee",) * 4,
    "ih",
    *("ee",) * 2,
    *("eye",) * 4,
    "uh",
    "eye",
    *("oh",) * 8,
    *("oo",) * 7,
    "uu",
    *("yoo",) * 6,
    *("ar",) * 3,
    *("or",) * 7,
    *("er",) * 6,
    *("air",) * 5,
    *("ear",) * 3,
    *("oy",) * 2,
    *("ow",) * 3,
    "or",
    "uff",
    "or",
    "uh",
    "o",
    *("uh",) * 3,
    *("uh",) * 5,
    "k",
    "sh",
    "zh",
    "gz",
    "t",
    "id",
)

SOUND_PHRASES: tuple[str, ...] = _PHRASES_1_55 + _PHRASES_56_146
assert len(_PHRASES_1_55) == 55
assert len(_PHRASES_56_146) == 91
assert len(SOUND_PHRASES) == 146


def repo_root() -> Path:
    return ROOT


def macos_say_wav(path: str, phrase: str, voice: str, rate: int) -> bool:
    tmp_aiff = path + ".tmp.aiff"
    try:
        subprocess.run(
            ["say", "-v", voice, "-r", str(rate), "-o", tmp_aiff, phrase],
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


def write_tone_wav(path: str, label: str) -> None:
    import math
    import struct
    import wave

    framerate = 22050
    h = sum(ord(c) for c in label) % 500
    freq = 200 + h
    duration = 0.35 + (len(label) % 5) * 0.05
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


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate SoundUnitsTest/*.wav for the 146-row index.")
    parser.add_argument("--force", action="store_true", help="Overwrite existing WAVs.")
    args = parser.parse_args()

    data = json.loads(SEED.read_text(encoding="utf-8"))
    sounds = sorted(data["sounds"], key=lambda s: s["id"])
    if len(sounds) != 146:
        print(f"error: expected 146 sounds, got {len(sounds)}", file=sys.stderr)
        return 1
    if len(SOUND_PHRASES) != 146:
        print(f"error: SOUND_PHRASES length {len(SOUND_PHRASES)} != 146", file=sys.stderr)
        return 1

    voice = os.environ.get("VOICE", "Kate")
    rate = int(os.environ.get("SAY_RATE", "220"))
    use_say = sys.platform == "darwin"

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    for s in sounds:
        sid = s["id"]
        word = s["exampleWord"].strip()
        phrase = SOUND_PHRASES[sid - 1]
        stem = f"{sid:03d}"
        sound_path = OUT_DIR / f"{stem}_sound.wav"
        word_path = OUT_DIR / f"{stem}_word.wav"

        for dest, text in ((sound_path, phrase), (word_path, word)):
            p = str(dest)
            if dest.exists() and not args.force:
                print(f"skip (exists): {dest.name}")
                continue
            if use_say and macos_say_wav(p, text, voice, rate):
                print(f"OK (say {voice}): {dest.relative_to(repo_root())}")
            else:
                write_tone_wav(p, text)
                print(f"OK (tone): {dest.relative_to(repo_root())}")

    print(f"Done: {OUT_DIR} (up to {146 * 2} WAVs)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
