# Project TODO

Backlog for FlashCards. Add new sections or bullets as work items appear.

---

## Segmentation: expand `segmentation.json` for all journey words

**Goal:** Every word in `FlashCards/Resources/Seed/segmentation_seed_146.json` has explicit rows in `FlashCards/Resources/Seed/segmentation.json` (`segmentation` + `construction`) so bundled graphemes are used and fallbacks are unnecessary for those words.

**References:** `segmentation_seed_146.json` (word list / pairs), `segmentation.json` (target), `FlashCards/Core/Data/PhonicsModulePOCDTO.swift` (`PhonicsModulePOCLoader`). For graphemes, prefer **`FlashCards/Resources/UofSXML/`** (`UK/reading.xml` / `US/reading.xml`) — see section below.

**Tasks**

- [ ] **Inventory words** — Collect every distinct `word` from all `visitPairs` → `items` in `segmentation_seed_146.json` (case-normalised, trimmed).
- [ ] **Crosscheck against sound XML** — For each app word, confirm it appears in **`UofSXML`** reading (or flag curriculum-only additions). Crosscheck each **`block/@uofs`** sound from `reading.xml` against the journey seed and note degree of match (coverage, order, naming). Resolve US vs UK trees per what the app ships.
- [ ] **Diff against current seed** — List words missing from `segmentation` and `construction` in `segmentation.json`.
- [ ] **Define segments** — Derive `segments` from `<pattern>`: each `[…]` group is a grapheme (e.g. `[sk]` + `id` → `sk`, `id` for *skid*); runs outside brackets are prefix/suffix spellings that complete `<text>`. Mirror into `construction` where both modes apply. Hand-edit only when XML and app behaviour must diverge (document why).
- [ ] **Stable IDs** — Unique `id` and sensible `orderIndex` (or document a convention).
- [ ] **Validate JSON** — Parses; `schemaVersion` consistent; no unintended duplicate words if tooling requires uniqueness.
- [ ] **Optional automation** — Script that fails if any journey word is missing from `segmentation.json`.
- [ ] **App check** — Segmentation/construction flows; confirm no G1/fallback for those words.
- [ ] **Audio / assets** — Regenerate or extend WAVs if needed (`Scripts/generate_segmentation_sounds.sh`, related scripts).

**Notes:** Journey scheduling stays in `segmentation_seed_146.json`; keep it in sync when visit words change.

---

## Sound XML (`UofSXML`): vocabulary crosscheck and segmentation

**Goal:** Use bundled **`FlashCards/Resources/UofSXML/`** (full **UK** and **US** trees) as the canonical reading/spelling corpus for Flash Cards. **`UK/reading.xml`** is the key file for flash cards (use **`US/reading.xml`** when the US variant matters). Inside **`<ReadingBlock>`** or **`<APageReadingBlock>`**, each **`<block uofs="…">`** is one teaching sound — crosscheck those sounds against **`segmentation_seed_146.json`** and quantify how well they match (order, labels, coverage; analyse in detail separately).

**Pattern semantics (segmentation):** Example *skid* — `<text>skid</text>` + `<pattern>[sk]id</pattern>`: **`[sk]`** marks where the **unit of sound** for that block sits in the word; characters outside the brackets (**`id`**) spell the rest of the word (prefix/suffix around the target grapheme(s)). Parse `<pattern>` into ordered **`segments`** aligned with `<text>` (multi-letter brackets such as `[sk]`, `[ai]` are single graphemes). Longer words may include **`<sylabul>`** with extra patterns — decide rules vs top-level `<pattern>` for `segments` vs audio-only syllables.

**Tasks**

- [ ] **Treat `UofSXML` as primary** — Prefer `FlashCards/Resources/UofSXML/UK/reading.xml` (and `…/US/reading.xml` as needed). Keep `specifiction /xml-models-v6/` only for diff, legacy, or tooling if still useful.
- [ ] **Enumerate sounds from reading XML** — All distinct **`block/@uofs`** (and `regex` if useful) inside **`<ReadingBlock>`** and **`<APageReadingBlock>`** in `reading.xml`; normalise keys for comparison to `segmentation_seed_146.json`.
- [ ] **Sound-level crosscheck** — For each XML sound, check presence and alignment with the 146 journey seed; document gaps, renames, and order drift.
- [ ] **Build word → pattern index** — Parse `<word>` → `<text>` + `<pattern>` (and optional `<sylabul>`); handle duplicate words across lessons (canonical row or fail on conflict).
- [ ] **Pattern → `segments`** — Implement bracket-based conversion to the app’s `segments` array; validate join matches `<text>` (modulo normalisation).
- [ ] **Crosscheck app vocabulary** — Diff app word union (seeds, `cards.json`, indices) against the XML index; report **only in app**, **only in XML**, and **pattern / text mismatch**.
- [ ] **Wire into seed workflow** — Populate or verify `segmentation.json`; Amazon / manual only for **gaps** outside the bundled XML.

**Notes:** Some files use **`<APageReadingBlock>`** vs **`<ReadingBlock>`** — include both in parsers if you scan beyond `reading.xml`. QA typos, placeholder clips, and non-flashcard `<text>` (e.g. full sentences) vs single-word entries.

---

## Phonics spelling: every word via Amazon’s phonics tool

**Goal:** Establish an authoritative phonics spelling (grapheme–phoneme style breakdown) for every word the application uses. **Prefer `UofSXML`** (`UK/reading.xml` / `US/reading.xml` and related bundled files) where the word is defined there; use **Amazon’s phonics tool** for words outside the XML, second opinions, or export formats the tool provides, then merge into seeds (`segmentation.json`, journey JSON, or a single source of truth).

**Tasks**

- [ ] **Define scope** — Fix the master word list (e.g. union of `segmentation_seed_146`, `segmentation.json`, cards/curriculum) so “every word” is unambiguous.
- [ ] **Prefer XML first** — For each word, if present in **`FlashCards/Resources/UofSXML/`** reading (or other in-scope XML), derive segments from `<pattern>` before invoking external tools.
- [ ] **Export from the app / repo** — Script or doc step to emit a clean, deduplicated list (one word per line or CSV) suitable for the tool (typically **XML gaps** only).
- [ ] **Run through Amazon’s phonics tool** — Batch or workflow per Amazon’s docs; capture outputs (graphemes, positions, or whatever the tool returns) in a stable format.
- [ ] **Reconcile** — Map tool output to app `segments` arrays; resolve mismatches with your pedagogy rules where the tool and curriculum differ; if **`UofSXML`** and Amazon disagree, decide precedence and document.
- [ ] **Apply to data** — Update `segmentation.json` (and `construction` where needed) and any other consumers; version or date the tool run in notes if outputs may change later.
- [ ] **Optional guard** — Script or checklist to ensure no in-scope word ships without a phonics spelling from this pipeline.

**Notes:** Link or name the exact Amazon product (console, API, or partner tool) in this file once you lock it, so the runbook stays reproducible.

---

## More actions

_Add bullets or new `##` sections below._
