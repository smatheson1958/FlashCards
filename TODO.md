# Project TODO

Backlog for FlashCards. Add new sections or bullets as work items appear.

---

## Segmentation: expand `segmentation.json` for all journey words

**Goal:** Every word in `FlashCards/Resources/Seed/phonics_structure.json` has explicit rows in `FlashCards/Resources/Seed/segmentation.json` (`segmentation` + `construction`) so bundled graphemes are used and fallbacks are unnecessary for those words.

**References:** `phonics_structure.json` (word list / pairs), `segmentation.json` (target), `FlashCards/Core/Data/PhonicsModulePOCDTO.swift` (`PhonicsModulePOCLoader`). Ship only app-owned JSON seeds in the bundle—no third-party lesson XML in the target (copyright / App Store).

**Tasks**

- [ ] **Inventory words** — Collect every distinct `word` from all `visitPairs` → `items` in `phonics_structure.json` (case-normalised, trimmed).
- [ ] **Curriculum crosscheck** — Flag words that exist only in your authored data vs words that also appear in any private reference materials you keep outside the repo; document UK vs US spelling choices for the variant you ship.
- [ ] **Diff against current seed** — List words missing from `segmentation` and `construction` in `segmentation.json`.
- [ ] **Define segments** — For each word, define `segments` in `segmentation.json` (and `construction` where needed) to match your pedagogy; hand-edit where automated extraction is wrong (document why).
- [ ] **Stable IDs** — Unique `id` and sensible `orderIndex` (or document a convention).
- [ ] **Validate JSON** — Parses; `schemaVersion` consistent; no unintended duplicate words if tooling requires uniqueness.
- [ ] **Optional automation** — Script that fails if any journey word is missing from `segmentation.json`.
- [ ] **App check** — Segmentation/construction flows; confirm no G1/fallback for those words.
- [ ] **Audio / assets** — Regenerate or extend WAVs if needed (`Scripts/generate_segmentation_sounds.sh`, related scripts).

**Notes:** Journey scheduling stays in `phonics_structure.json`; keep it in sync when visit words change.

---

## Optional: external lesson XML (development only, never ship)

**Policy:** Third-party phonics / lesson XML may be useful **locally** for cross-checking or tooling. It must **not** be copied into `FlashCards/Resources/` or otherwise included in the app bundle—copyright and naming constraints. Production data lives in **`phonics_structure.json`**, **`segmentation.json`**, and other **app-authored** seeds only.

**Pattern semantics (if you parse external XML privately):** Example *skid* — `<text>skid</text>` + `<pattern>[sk]id</pattern>`: bracketed spans mark the **target grapheme**; characters outside the brackets complete the spelling around it. Parse `<pattern>` into ordered **`segments`** aligned with `<text>` (multi-letter brackets such as `[sk]`, `[ai]` are single graphemes). Longer words may include extra syllable markup—decide rules for `segments` vs audio-only syllables.

**Tasks**

- [ ] **Keep reference XML out of the target** — Confirm the Xcode synchronized `FlashCards` tree has no redistributable third-party XML; use private copies outside the repo if needed.
- [ ] **Enumerate teaching blocks (private)** — If you maintain a private corpus, list distinct sound keys per your parser’s rules and compare to `phonics_structure.json` for coverage and order drift.
- [ ] **Build word → pattern index (private)** — Optional tooling: parse word + pattern pairs; handle duplicates across lessons (canonical row or fail on conflict).
- [ ] **Pattern → `segments`** — Optional: bracket-based conversion to the app’s `segments` array; validate join matches `<text>` (modulo normalisation).
- [ ] **Crosscheck app vocabulary** — Diff app word union (seeds, `cards.json`, indices) against your private index; report only-in-app, only-in-corpus, and pattern / text mismatch.
- [ ] **Wire into seed workflow** — Merge results into `segmentation.json` (and related JSON); ship only merged, rights-cleared data.

**Notes:** Treat any external schema as unstable input; the shipped product should depend only on checked-in JSON you own.

---

## Phonics spelling: every word via Amazon’s phonics tool

**Goal:** Establish an authoritative phonics spelling (grapheme–phoneme style breakdown) for every word the application uses. Prefer **`segmentation.json`** and your own seeds; use **Amazon’s phonics tool** (or equivalent) for gaps, second opinions, or export formats the tool provides, then merge into seeds (`segmentation.json`, `phonics_structure.json`, or a single source of truth).

**Tasks**

- [ ] **Define scope** — Fix the master word list (e.g. union of `phonics_structure.json`, `segmentation.json`, cards/curriculum) so “every word” is unambiguous.
- [ ] **Prefer bundled JSON first** — For each word, use `segmentation.json` / `construction` when present before invoking external tools.
- [ ] **Export from the app / repo** — Script or doc step to emit a clean, deduplicated list (one word per line or CSV) suitable for the tool (typically **gaps** only).
- [ ] **Run through Amazon’s phonics tool** — Batch or workflow per Amazon’s docs; capture outputs (graphemes, positions, or whatever the tool returns) in a stable format.
- [ ] **Reconcile** — Map tool output to app `segments` arrays; resolve mismatches with your pedagogy rules where the tool and curriculum differ; if **JSON seeds** and Amazon disagree, decide precedence and document.
- [ ] **Apply to data** — Update `segmentation.json` (and `construction` where needed) and any other consumers; version or date the tool run in notes if outputs may change later.
- [ ] **Optional guard** — Script or checklist to ensure no in-scope word ships without a phonics spelling from this pipeline.

**Notes:** Link or name the exact Amazon product (console, API, or partner tool) in this file once you lock it, so the runbook stays reproducible.

---

## More actions

_Add bullets or new `##` sections below._
