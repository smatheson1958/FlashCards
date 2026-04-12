#!/usr/bin/env python3
"""
Generate WordsAudio/<word>.wav for whole-word playback in Construction / Segmentation / Sound Cards.

Curriculum reality (why this is not “146 sounds × 5–10 words” yet):
  - `construction_index_g1_foundation.json` only defines multi-word construction sets for the
    foundation slice (sound ids 1…30 in that file). That is the source of the ~238 distinct stems
    used when `ConstructionIndexG1Loader` has a row.
  - For sounds without that row, the app uses a single `exampleWord` from
    `sound_units_primary_index_146.json` (see `LearningProgressionEngine.wordsForMode`).
  - A full 146×(5–10) word list would require a **full** construction index (or equivalent) in Seed;
    that bundle does not exist in the repo today. This script still generates audio for every
    **exampleWord** on the 146 list so those fallback words are covered.

Sources merged here:
  - construction_index_g1_foundation.json → constructionSets[].word
  - segmentation.json → segmentation[].word + construction[].word
  - sound_units_primary_index_146.json → each sounds[].exampleWord

Do not add nested WordsAudio/sound_<n>/ copies: Xcode’s synchronized resource bundle flattens
duplicate basenames and breaks the build (“Multiple commands produce …/cat.wav”).

Options:
  --skip-existing   Do not regenerate if <word>.wav already exists (fast when adding new stems).

Voice and format match Scripts/generate_word_wavs.py (Kate, LEI16@22050). Override: VOICE=Samantha python3 ...
"""
from __future__ import annotations

import json
import os
import subprocess
import sys

from generate_word_wavs import out_dir, repo_root, write_tone_wav


def load_construction_index() -> dict:
    root = repo_root()
    index_path = os.path.join(
        root,
        "FlashCards",
        "Resources",
        "Seed",
        "construction_index_g1_foundation.json",
    )
    with open(index_path, encoding="utf-8") as f:
        return json.load(f)


def load_sound_units_primary_index() -> dict:
    root = repo_root()
    path = os.path.join(
        root,
        "FlashCards",
        "Resources",
        "Seed",
        "sound_units_primary_index_146.json",
    )
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def collect_words(idx: dict | None = None) -> list[str]:
    words: set[str] = set()
    root = repo_root()

    if idx is None:
        idx = load_construction_index()
    for item in idx.get("items", []):
        for cs in item.get("constructionSets", []):
            w = cs.get("word")
            if isinstance(w, str):
                k = w.strip().lower()
                if k:
                    words.add(k)

    poc_path = os.path.join(
        root,
        "FlashCards",
        "Resources",
        "Seed",
        "segmentation.json",
    )
    with open(poc_path, encoding="utf-8") as f:
        poc = json.load(f)
    for key in ("segmentation", "construction"):
        for ex in poc.get(key, []):
            w = ex.get("word")
            if isinstance(w, str):
                k = w.strip().lower()
                if k:
                    words.add(k)

    primary = load_sound_units_primary_index()
    for s in primary.get("sounds", []):
        w = s.get("exampleWord")
        if isinstance(w, str):
            k = w.strip().lower()
            if k:
                words.add(k)

    return sorted(words)


def macos_say_wav(path: str, word: str, voice: str) -> bool:
    tmp_aiff = path + ".tmp.aiff"
    try:
        subprocess.run(
            ["say", "-v", voice, "-o", tmp_aiff, word],
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
    voice = os.environ.get("VOICE", "Kate")
    skip_existing = "--skip-existing" in sys.argv
    od = out_dir()
    os.makedirs(od, exist_ok=True)
    use_say = sys.platform == "darwin"
    idx = load_construction_index()
    words = collect_words(idx)

    for w in words:
        dest = os.path.join(od, f"{w}.wav")
        if skip_existing and os.path.isfile(dest) and os.path.getsize(dest) > 0:
            print(f"SKIP: {dest}")
            continue
        if use_say and macos_say_wav(dest, w, voice):
            print(f"OK (say {voice}): {dest}")
        else:
            write_tone_wav(dest, w)
            print(f"OK (tone): {dest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
