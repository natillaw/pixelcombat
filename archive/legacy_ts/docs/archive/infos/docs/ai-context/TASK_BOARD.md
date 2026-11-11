# Task Board

Status: `open` | `claimed` | `blocked` | `done`. Edit via `ts_sync.py claim/release` when possible.
Verified tasks only become `done` with a log entry containing a command and result.

<!-- TASKS:BEGIN -->
| ID | Task | Phase | Status | Owner | Files | Updated |
|----|------|-------|--------|-------|-------|---------|
| T-001 | Put the existing local Godot project (summons working) under Git, confirm Godot version, audit | 0 | open | - | tools/audit/Audit-GodotProject.ps1 | 2026-10-28 19:26 |
| T-002 | Persistent hero schema (HeroData), IDs, seed, generator version (exists locally: audit, do not rewrite) | 1 | done | - | - | 2026-10-28 19:26 |
| T-003 | Generate at least 6 test heroes; save/load without regenerating | 1 | done | - | - | 2026-10-28 19:26 |
| T-004 | Fixed test map + top-down group camera | 1 | done | - | - | 2026-10-28 19:26 |
| T-005 | Selection: click, drag, keys 1-5, Tab, G | 1 | done | - | - | 2026-10-28 19:27 |
| T-006 | Navigation + move orders + anti-clumping | 1 | done | - | - | 2026-10-28 19:27 |
| T-022 | VISUAL FIRST. Asset inbox: assets/_inbox/ + Import-Asset.ps1 that registers each file (source URL, author, license, frame size) in ASSET_MANIFEST | 1V | open | - | - | - |
| T-023 | VISUAL FIRST. Hero animations in code per D-020 (hit, death, cast, bow, up/down attack) + attack anim wired to combat; no assets needed | 1V | done | Gemini | - | 2026-10-28 22:15 |
| T-025 | VISUAL FIRST. Tileset + sandbox map drawn with tiles instead of colored squares (needs owner-supplied tileset; placeholder loader first) | 1V | done | Gemini | - | 2026-10-28 22:34 |
| T-024 | VISUAL FIRST. Enemy sprites + enemy type table replacing red circles (needs owner-supplied enemy pack) | 1V | open | - | - | - |
| T-026 | VISUAL FIRST. UI art: frames, skill/command icons, health bars, portraits | 1V | open | - | - | - |
| T-027 | VISUAL FIRST. Effects: hit sparks, telegraph circle art, skill effects, projectiles | 1V | open | - | - | - |
| T-028 | VISUAL FIRST. Audio: hit/summon/death/UI sounds + 1-2 music tracks | 1V | open | - | - | - |
| T-029 | VISUAL FIRST. Pixel font set in the UI theme | 1V | open | - | - | - |
| T-007 | Autonomous basic attacks | 1 | claimed | Claude (awaiting owner test run) | tactical_summoners dropC | 2026-10-28 20:00 |
| T-008 | Contextual hero panel (vitals, skills, orders) | 1 | claimed | Claude (awaiting owner test run) | tactical_summoners dropC | 2026-10-28 20:00 |
| T-009 | One active skill per hero | 1 | claimed | Claude (awaiting owner test run) | tactical_summoners dropC | 2026-10-28 20:00 |
| T-010 | Enemies, perception, telegraphed attacks | 1 | claimed | Claude (awaiting owner test run) | tactical_summoners dropC | 2026-10-28 20:00 |
| T-011 | Non-combat objective + extraction + mission result | 1 | claimed | Claude (awaiting owner test run) | tactical_summoners dropC | 2026-10-28 20:00 |
| T-012 | Trust/Obedience/Composure fields + persistent event log | 2 | done | - | - | 2026-10-28 19:27 |
| T-013 | Permanent death + memorial + save integrity tests | 2 | claimed | Claude (awaiting owner test run) | tactical_summoners dropC | 2026-10-28 20:00 |
| T-014 | Hero schema v+1: tier, histories, retired fields, save migration | 3B | open | - | - | - |
| T-015 | Config tables: synthesis, sacrifice yields, promotion costs and unlocks | 3B | open | - | - | - |
| T-016 | SynthesisService + SacrificeService (pure, transactional, headless tests) | 3B | open | - | - | - |
| T-017 | PromotionService + unlock table + tests | 3B | open | - | - | - |
| T-018 | Memorial entries for sacrificed heroes + ledger events | 3B | open | - | - | - |
| T-019 | Confirmation UI showing exact loss and gain | 3B | open | - | - | - |
| T-020 | Placeholder promotion material reward from mission result | 3B | open | - | - | - |
| T-021 | Import owner pixel-art hero pack: record license, sprite size, map designs to generator part IDs | 5 | open | - | - | - |
| T-030 | Equipment layers per D-021: item data table, slots, multi-pack loader with per-pack frame map, equipped item hides the base layer, stats only from items | 4 | open | - | - | - |
| T-031 | Skill engine: implement the effect kinds in SKILL_LIBRARY (statuses, dashes, channels, zones, summons, ultimates), loadout of 4 actives + 1 ultimate, skill picking UI; start with 8 per class | 3 | open | - | - | - |
| T-032 | Skill VFX + icons: map each skill to an effect/icon from the researched packs (see ASSET_MANIFEST) | 1V | open | - | - | - |
<!-- TASKS:END -->
