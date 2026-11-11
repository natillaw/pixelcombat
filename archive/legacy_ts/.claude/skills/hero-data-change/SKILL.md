---
name: hero-data-change
description: Checklist for changing HeroData, HeroGenerator, HeroTables, the save format or anything that is persisted. Use before editing scripts/core/hero_data.gd, hero_generator.gd, scripts/data/*.gd or Game save/load.
---
# Changing persisted hero or save data

Rules: heroes never re-roll on load (D-004); identity never changes (D-018); deterministic changes only (D-016).

1. Read the row in `docs/IMPLEMENTATION_STATUS.md` and the spec `docs/specs/HEROES_AND_SUMMONING.md`.
2. New or renamed saved field → bump `Game.SAVE_VERSION`, add a step in `Game._migrate`, default it in `HeroData.from_dict`.
3. Any change that alters what a seed produces (new RNG call, table order, weights) → bump `HeroGenerator.VERSION` and keep old saves loading from their snapshot. Never insert RNG calls before existing ones without bumping.
4. Add a test: old-version save JSON loads; new field survives `to_dict`/`from_dict`; same seed + version gives the same hero.
5. Balance numbers live in data files, never in UI.
6. Pending design items (P-xx in `docs/DECISIONS.md`) are not implemented without the owner's answer.
