# SoloUse (TrafficMaster)

Single-user iOS/iPad app for drilling Belarus GAI theory questions with a local FSRS scheduler.

## What is implemented

- Local-only study flow (no backend, no auth, no profiles).
- SQLite source of truth with schema:
  - `questions`
  - `answer_options`
  - `review_logs`
  - `fsrs_state`
  - `settings`
  - `rules_chunks` (FTS5 local retrieval)
  - `ai_explanations_cache`
- FSRS-style ratings:
  - Wrong -> `Again`
  - Correct -> `Good`
  - Guessed -> `Hard`
  - Optional `Easy` button in settings.
- Hybrid RAG for mistakes:
  - local retrieval from `rules_chunks`
  - optional cloud generation via OpenRouter API.

## Run

1. Open `TrafficMaster.xcodeproj`.
2. Build and run on iPhone/iPad simulator or device.
3. App imports questions from source in this priority:
   - external `export_all_questions` path from Settings;
   - macOS fallback: `/Users/vlad/PizdPDD/ADrive/export_all_questions` (if exists);
   - bundled `adrive_questions` asset fallback.
4. On source change app resets schema and reimports data into local SQLite.

## Settings

Inside **Settings** tab:
- `new/day`
- `max reviews/day`
- `show Easy`
- `AI explanations`
- `OpenRouter model`
- `OpenRouter API key` (stored in Keychain)

## Optional local rules corpus

If you want better local retrieval quality, add `pdd_rules.txt` to app bundle and split it by blank lines.
The app also auto-seeds `rules_chunks` from question explanations.

## ADrive export integration

- Supported source format: folder with `questions/*.json`, `chapters/**.json`, `media/**`, `state.json`.
- Media in `media_files` is resolved by absolute path from selected export folder.
- Set export path in **Settings -> База Вопросов** and run reimport.

## Notes

- v1 target: iOS/iPad only.
- Works fully offline except optional cloud explanation generation.
