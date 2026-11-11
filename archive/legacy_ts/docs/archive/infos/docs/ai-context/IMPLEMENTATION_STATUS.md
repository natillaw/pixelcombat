# Tactical Summoners - Implementation Status & Reference Context

**Date:** October 29, 2026  
**Engine:** Godot 4.4.x, GDScript, 2D Pixel Art  

---

## 1. What Has Been Implemented (Drop B & Drop C)

### Summons & Hero Generation (v2)
- Data-driven banners (`scripts/data/summon_config.gd`).
- Seeded summon log (capped at 200 entries, deterministic hero re-generation).
- Persistent hero schema (`HeroData`: trust, obedience, composure, callsigns for duplicate names, event ledgers).

### Save & Memorial System
- Atomic save/load with `.bak` fallback and v1/v2/v3 schema migration.
- Permanent death tracking (`Game.record_death`): removes fallen heroes from roster/party, logs them permanently in `MemorialScreen`, and applies `ally_fell` (-2 Trust) to surviving squad members.

### Real-Time Combat & Sandbox
- 40×24 map with A\* pathing.
- 5-hero squad control (LMB select / drag-box, RMB move with formation offsets).
- Camera controls: `1–5` to focus heroes, `Tab` for group view, `G` for squad selection, `Q` for active skill, `S` to stop.
- Autonomous hero movement & combat combined with instant direct player order overrides.
- Enemy AI with chase behavior and telegraphed circle strike attacks.

### Mission & Objectives
- "Recover the Relic" mission flow: secure relic from far room, extract at exit point, relic drops if carrier falls, post-mission reward screen.

### Automated Testing
- 7 automated test suites (`test_core`, `test_summons`, `test_memorial`, `smoke_ui`, `smoke_sandbox`, `smoke_combat`, `smoke_mission`) runnable headlessly via `tools\Run-Tests.ps1`.

---

## 2. What Is Missing (Next Roadmap Phases)

- **Visual Asset Integration & In-Engine Polish:** Connecting raw sprite sheets (Tiny Pixel Fantasy generator layers, enemy packs, tilesets) and visually verifying animations inside the Godot editor.
- **Equipment & Gear System:** Inventory, weapons, and armor slot management (T-030).
- **Advanced Progression:** Sacrifice/synthesis mechanics, promotion tier unlocks, and stat growths (VIT/AGI/INT/etc.).
- **Audio & Visual Effects:** Sound effects, ambient music, particle effects, and UI typography.
- **Campaign / Tower Expansion:** Multi-floor tower progression and diverse mission types.

---

## 3. Game Context & References

### Core Concept
*Tactical Summoners* is an original 2D pixel-art tactical RPG combining **gacha summons** with **hybrid real-time tactical control** (autonomous hero AI + direct player positioning, movement, and skill activation). Heroes have permanent identities, personalities, and backgrounds. Death is permanent, leaving behind a memorial record of fallen fighters.

### Reference Inspiration
- Broadly inspired by the high-stakes tactical tower-climbing and gacha-management themes of web novel / manhwa works like ***Pick Me Up, Infinite Gacha***.
- **Key System Adaptations:** Expendable/persistent low-tier heroes, lossy sacrifice/synthesis mechanics, trust/obedience dynamics, and high-tension command mechanics where player authority over direct orders is absolute while hero traits reflect their background.
- *Note:* Strictly an original work—no protected characters, names, dialogue, art, or storyline elements from reference works are copied.
