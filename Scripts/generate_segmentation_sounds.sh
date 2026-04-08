#!/bin/bash
# Generates <grapheme>.wav (e.g. c.wav, sh.wav) under FlashCards/Resources/Sounds/Segmentation.
# Uses macOS `say` + `afconvert` — same format as Scripts/generate_word_wavs.py (LEI16@22050).
# Default voice: Kate (en_GB female). Override: VOICE=Samantha ./generate_segmentation_sounds.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/FlashCards/Resources/Sounds/Segmentation"
VOICE="${VOICE:-Kate}"
TMP="$(mktemp /tmp/segXXXX.aiff)"

mkdir -p "$OUT"

# Remove legacy seg_*.wav if present
rm -f "$OUT"/seg_*.wav 2>/dev/null || true

phrase_for() {
  case "$1" in
    c) echo "kuh" ;;
    a) echo "ah" ;;
    t) echo "tuh" ;;
    d) echo "duh" ;;
    o) echo "oh" ;;
    g) echo "guh" ;;
    s) echo "sss" ;;
    u) echo "uh" ;;
    n) echo "nn" ;;
    h) echo "huh" ;;
    p) echo "puh" ;;
    e) echo "eh" ;;
    *) echo "$1" ;;
  esac
}

# Unique graphemes from phonics_modules_poc.json segmentation (CVC POC).
for g in c a t d o g s u n h p e; do
  phrase="$(phrase_for "$g")"
  say -v "$VOICE" -o "$TMP" "$phrase"
  afconvert -f WAVE -d LEI16@22050 "$TMP" "$OUT/${g}.wav" 1>/dev/null
  echo "Wrote ${g}.wav ($phrase) voice=$VOICE"
done

rm -f "$TMP"
echo "Done: $OUT"
