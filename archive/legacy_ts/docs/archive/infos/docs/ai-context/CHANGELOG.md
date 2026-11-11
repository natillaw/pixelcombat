# Changelog

Only record work actually performed and verified. Newest first.

## 2026-10-28 — v1.7 Five heroes final, hero growth, reference systems
- D-017: five-hero squad confirmed final; removed all "first slice may use three" language; test roster is now at least six heroes; keys 1-5 required.
- D-018: added Synthesis, Sacrifice and Promotion (spec in SUMMONS section 14, roadmap Phase 3B, gaps 21-26). Memory unlock on promotion is MAYBE.
- Added `REFERENCE_SYSTEMS.md` (inspiration systems, status per mechanic, naming rules) and tasks T-014 to T-021.
- Recorded that a Godot project with working summons exists locally but is not in Git; owner-supplied pixel-art pack noted in the asset manifest.
- Removed leftover turn-based items (rank markers, stress panel, turn/initiative checklist lines).
- Documentation only; no Godot code was inspected, implemented or tested.

## 2026-10-28 — v1.6 Multi-agent sync
- Added `AGENTS.md` (+ `CLAUDE.md`, `.github/copilot-instructions.md`), `AGENT_SYNC.md`, `TASK_BOARD.md`, `HANDOFF_LOG.md` and `tools/sync/ts_sync.py` (start, claim, release, log, bundle, check, install-hooks).
- Fixed contradictions: personality dimensions (5 -> 8 in ROADMAP), camera wording in DECISIONS, superseded turn-based line in this file, checklist version.
- Documentation/tooling only; no Godot code implemented or tested.

## 2026-10-28 — Prototype direction updated
- Superseded the provisional 3D/low-poly art direction with 2D pixel art.
- [SUPERSEDED by v1.4] Selected turn-based, rank/formation-aware combat. Do not implement; see D-014.
- Confirmed permanent death for the first prototype, no resurrection, and a persistent memorial/chronicle.
- Prioritized procedural hero personality, backstory, skills and persistent identity.
- Deferred/left undecided procedural world generation; first mission uses fixed encounters.
- Added `COMBAT_AND_STATS.md` with initial five attributes, provisional formulas, targeting/turn flow, generation contract, tests and unresolved design decisions.
- Updated the Bible, roadmap, decisions, current state, art direction, master checklist and handoff prompt.
- Documentation only: no Godot scripts/scenes/assets were implemented or tested.

## 2026-10-27 — Script-first workflow
- Adopted a cross-account rule: prefer code and Godot editor/CLI scripts for scene creation, setup, repetitive work and tests; minimize manual clicking; inspect, preserve and verify project files.
- Initial Godot project and exact engine version are still unverified.

## 2026-10-27 — Initial continuity pack
- Created initial Bible, roadmap, current state, decisions, asset manifest, art direction and handoff prompt.
- The previous art direction was stylized 3D; it is superseded by the 2026-10-28 decision above.
- Researched candidate free asset sources.
- No game code was inspected or changed while creating this pack.
- No assets have been downloaded or tested in Godot.

## 2026-10-28 — v1.4 Hybrid RTS control decision
- Superseded the earlier turn-based/rank-based combat baseline with hybrid RTS.
- Confirmed autonomous heroes plus direct player orders and direct skill activation.
- Confirmed top-down group camera and continuous real time without pause.
- Added `CONTROL_AND_REALTIME_MISSIONS.md` covering input proposal, order states/priorities, autonomy, camera/UI, no-pause readability, mission integration, boss principles and acceptance criteria.
- Updated the Project Bible, combat specification, decisions, roadmap, current state, design gaps, README, checklist and handoff prompt.
- Long-term squad target is five; first vertical slice may use three to reduce scope.
- This is documentation only. No Godot code was implemented or tested by this update.

## 2026-10-28 — v1.5 Hero focus, contextual HUD and summon/social systems
- Added number keys 1–5 for hero selection and camera-follow focus; Tab returns to group view; G selects the squad.
- Specified the contextual hero interface: identity, vitals, active skills, cooldown/cost/range, command controls, current order and compact social-state indicators.
- Added `SUMMONS_AND_HERO_GENERATION.md` with deterministic summon flow, stable hero identity, traits, Trust, Obedience, Composure, bonds/rivalries, event memory and open summon-economy decisions.
- Updated combat, Project Bible, roadmap, decisions, current state, design gaps, art direction, checklist, README and handoff prompt to align.
- Trust and Obedience do not randomly cancel routine direct orders; MVP relationship effects are deterministic and conservative.
- Documentation only; no Godot implementation or playtest is claimed.

## v1.7 addendum — 2026-10-28 (low-usage mode)
- Added `ts_sync.py lite` (CONTEXT_LITE.md ~10 KB vs 100 KB bundle), `RULES_LITE.md`, lite prompt, LITE MODE in AGENTS.md. Verified: `ts_sync.py lite` and `check` run, 0 errors.
- Added D-019 (no-hands Godot: all by script/PowerShell incl. animations) and tools/audit/Audit-GodotProject.ps1 for T-001 (untested on Windows: pwsh not available in author sandbox).

## v1.7 addendum 2 — 2026-10-28 (Drop B implemented)
- Summons v2, Trust/Obedience/Composure + event ledger, save v2 with atomic write and migration, real-time sandbox (map, camera, selection, move orders, anti-clumping), walk/idle animation definitions, tools/Run-Tests.ps1.
- Verified: Godot 4.4.1 headless, suites test_core / test_summons / smoke_ui / smoke_sandbox all PASS; main scene boots with no script errors.
- Not verified: visuals/animation look, Windows PowerShell scripts, Godot 4.7.
