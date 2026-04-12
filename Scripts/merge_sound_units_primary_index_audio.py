#!/usr/bin/env python3
"""
Merge Polly-style audio metadata into `sound_units_primary_index_146.json`.

- Copies en-GB / en-US blocks from `FLshCards Source JSON/polly_sidecar_g1_foundation.json` for ids 1–30.
- Adds IPA + SSML + filenames for ids 31–146 (RP-style en-GB).
- Sets bundled `file` paths to offline test WAVs: `SoundUnitsTest/NNN_sound.wav` and `NNN_word.wav` (en-GB and en-US; generate via `Scripts/generate_sound_units_test_wavs.py`).
- Injects `supportsModes` from `sound_units_primary_index_146_v1.json` (required by app DTOs).

Run from repo root:
  python3 Scripts/merge_sound_units_primary_index_audio.py
"""

from __future__ import annotations

import json
from pathlib import Path
import xml.sax.saxutils as xml


ROOT = Path(__file__).resolve().parents[1]
SEED = ROOT / "FlashCards/Resources/Seed"
POLLY_G1 = ROOT / "FLshCards Source JSON/polly_sidecar_g1_foundation.json"
OUT = SEED / "sound_units_primary_index_146.json"
V1 = SEED / "sound_units_primary_index_146_v1.json"
# Offline test clips (mono WAV in app bundle); same logical id for en-GB / en-US.
BUNDLE_SOUND_DIR = "SoundUnitsTest"


def ssml_wrap(surface: str, ipa: str) -> str:
    surf = xml.escape(surface, entities={"'": "&apos;", '"': "&quot;"})
    ipa_esc = xml.escape(ipa, entities={"'": "&apos;", '"': "&quot;"})
    return f'<speak><phoneme alphabet="ipa" ph="{ipa_esc}">{surf}</phoneme></speak>'


def wav_paths(sid: int) -> tuple[str, str]:
    stem = f"{sid:03d}"
    return (
        f"{BUNDLE_SOUND_DIR}/{stem}_sound.wav",
        f"{BUNDLE_SOUND_DIR}/{stem}_word.wav",
    )


def apply_bundle_wav_files(audio: dict, sid: int) -> None:
    sound_f, word_f = wav_paths(sid)
    for locale_key in ("en-GB", "en-US"):
        loc = audio[locale_key]
        loc["soundUnit"]["file"] = sound_f
        loc["exampleWord"]["file"] = word_f


def audio_block(
    sound_text: str,
    sound_ipa: str,
    word_text: str,
    word_ipa: str,
    sid: int,
) -> dict:
    block = {
        "en-GB": {
            "soundUnit": {
                "text": sound_text,
                "phoneme": sound_ipa,
                "ssml": ssml_wrap(sound_text, sound_ipa),
                "file": "",
            },
            "exampleWord": {
                "text": word_text,
                "phoneme": word_ipa,
                "ssml": ssml_wrap(word_text, word_ipa),
                "file": "",
            },
        },
        "en-US": {
            "soundUnit": {
                "text": sound_text,
                "phoneme": "",
                "ssml": "",
                "file": "",
            },
            "exampleWord": {
                "text": word_text,
                "phoneme": "",
                "ssml": "",
                "file": "",
            },
        },
    }
    apply_bundle_wav_files(block, sid)
    return block


# Ids 31–146: (sound_unit_ipa, example_word_ipa) — RP-oriented en-GB; refine later in tooling.
EXTRA_IPA: dict[int, tuple[str, str]] = {
    31: ("ʃ", "ʃɪp"),
    32: ("tʃ", "tʃɪp"),
    33: ("θ", "θɪn"),
    34: ("ð", "ðɪs"),
    35: ("ŋ", "rɪŋ"),
    36: ("ŋk", "bæŋk"),
    37: ("kw", "kwiːn"),
    38: ("w", "wiːl"),
    39: ("f", "fəʊn"),
    40: ("tʃ", "mætʃ"),
    41: ("dʒ", "brɪdʒ"),
    42: ("dʒ", "keɪdʒ"),
    43: ("dʒ", "dʒaɪənt"),
    44: ("dʒ", "dʒɪm"),
    45: ("s", "fɛns"),
    46: ("s", "sɪti"),
    47: ("s", "fænsi"),
    48: ("r", "raɪt"),
    49: ("n", "niː"),
    50: ("n", "nəʊm"),
    51: ("m", "læm"),
    52: ("s", "saɪəns"),
    53: ("ʃ", "steɪʃən"),
    54: ("ʃ", "speʃəl"),
    55: ("ʒ", "vɪʒən"),
    56: ("eɪ", "keɪk"),
    57: ("eɪ", "reɪn"),
    58: ("eɪ", "pleɪ"),
    59: ("eɪ", "eɪkɔːn"),
    60: ("eɪ", "veɪn"),
    61: ("eɪ", "eɪt"),
    62: ("eɪ", "ðeɪ"),
    63: ("eɪ", "steɪk"),
    64: ("iː", "ðiːz"),
    65: ("iː", "triː"),
    66: ("iː", "biːtʃ"),
    67: ("iː", "hiː"),
    68: ("i", "hæpi"),
    69: ("iː", "tʃiːf"),
    70: ("iː", "rɪsiːv"),
    71: ("aɪ", "baɪk"),
    72: ("aɪ", "laɪt"),
    73: ("aɪ", "maɪ"),
    74: ("aɪ", "paɪ"),
    75: ("ə", "taɪɡə"),
    76: ("aɪ", "baɪ"),
    77: ("əʊ", "həʊm"),
    78: ("əʊ", "bəʊt"),
    79: ("əʊ", "snəʊ"),
    80: ("əʊ", "təʊ"),
    81: ("əʊ", "ɡəʊ"),
    82: ("əʊ", "səʊl"),
    83: ("əʊ", "plætəʊ"),
    84: ("əʊ", "ðəʊ"),
    85: ("uː", "muːn"),
    86: ("uː", "fluːt"),
    87: ("uː", "bluː"),
    88: ("uː", "tʃuː"),
    89: ("uː", "fruːt"),
    90: ("uː", "suːp"),
    91: ("uː", "duː"),
    92: ("ʊ", "bʊk"),
    93: ("juː", "kjuːb"),
    94: ("juː", "pjuːpəl"),
    95: ("juː", "reskjuː"),
    96: ("juː", "fjuː"),
    97: ("juː", "jʊərəp"),
    98: ("juː", "bjuːti"),
    99: ("ɑː", "kɑː"),
    100: ("ɑː", "fɑːðə"),
    101: ("ɑː", "hɑːt"),
    102: ("ɔː", "fɔːk"),
    103: ("ɔː", "klɔː"),
    104: ("ɔː", "ɔːθə"),
    105: ("ɔː", "tɔːk"),
    106: ("ɔː", "ʃɔː"),
    107: ("ɔː", "dɔː"),
    108: ("ɔː", "fɔː"),
    109: ("ɜː", "hɜː"),
    110: ("ɜː", "bɜːd"),
    111: ("ɜː", "tɜːn"),
    112: ("ɜː", "lɜːn"),
    113: ("ɜː", "wɜːd"),
    114: ("ɜː", "wɜːm"),
    115: ("ɛə", "tʃɛə"),
    116: ("ɛə", "kɛə"),
    117: ("ɛə", "pɛə"),
    118: ("ɛə", "ðɛə"),
    119: ("ɛə", "ðɛə"),
    120: ("ɪə", "dɪə"),
    121: ("ɪə", "tʃɪə"),
    122: ("ɪə", "hɪə"),
    123: ("ɔɪ", "kɔɪn"),
    124: ("ɔɪ", "bɔɪ"),
    125: ("aʊ", "kaʊ"),
    126: ("aʊ", "klaʊd"),
    127: ("aʊ", "baʊ"),
    128: ("ɔː", "θɔːt"),
    129: ("ʌf", "rʌf"),
    130: ("ɔː", "dɔːtə"),
    131: ("ə", "wɔːtə"),
    132: ("ɒ", "wɒz"),
    133: ("ʌ", "sʌn"),
    134: ("ʌ", "jʌŋ"),
    135: ("ʌ", "blʌd"),
    136: ("ə", "əbaʊt"),
    137: ("ə", "prɒbləm"),
    138: ("ə", "pensəl"),
    139: ("ə", "lemən"),
    140: ("ə", "səplaɪ"),
    141: ("k", "skuːl"),
    142: ("ʃ", "ʃef"),
    143: ("ʒ", "meʒə"),
    144: ("ɡz", "ɪɡzæm"),
    145: ("t", "dʒʌmpt"),
    146: ("ɪd", "wɒntɪd"),
}


def main() -> None:
    base = json.loads(OUT.read_text(encoding="utf-8"))
    v1 = json.loads(V1.read_text(encoding="utf-8"))
    polly = json.loads(POLLY_G1.read_text(encoding="utf-8"))

    sm_by_id = {s["id"]: s["supportsModes"] for s in v1["sounds"]}

    g1_by_id: dict[int, dict] = {}
    for item in polly["items"]:
        g1_by_id[item["id"]] = item["audio"]

    sounds_out = []
    for s in base["sounds"]:
        sid = s["id"]
        su = s["soundUnit"]
        word = s["exampleWord"]
        merged = {**s, "supportsModes": sm_by_id[sid]}

        if sid in g1_by_id:
            merged["audio"] = json.loads(json.dumps(g1_by_id[sid]))  # deep copy
            apply_bundle_wav_files(merged["audio"], sid)
        else:
            su_ipa, w_ipa = EXTRA_IPA[sid]
            merged["audio"] = audio_block(su, su_ipa, word, w_ipa, sid)

        sounds_out.append(merged)

    base["sounds"] = sounds_out
    base["polly"] = {
        "schemaNote": "Bundled offline test WAVs: run `python3 Scripts/generate_sound_units_test_wavs.py` (Kate, 22050 Hz). Replace with higher-quality phonics or Polly exports later; keep paths under SoundUnitsTest/ if filenames stay the same.",
        "voices": polly["voices"],
    }

    OUT.write_text(json.dumps(base, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUT} ({len(sounds_out)} sounds + polly voice preset)")


if __name__ == "__main__":
    main()
