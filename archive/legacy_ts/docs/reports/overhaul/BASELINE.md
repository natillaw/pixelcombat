# Línea base de tests antes del overhaul (2026-10-31)

Commit `06cdb80` (rama `feat/master-prompt-bandits`), Godot 4.7.2, headless, logs en `tests/out/`.

- 25 suites en verde: smoke_ingame, smoke_wilds, smoke_tower, smoke_slice, smoke_mission, smoke_combat,
  smoke_tactics, smoke_bandits, smoke_ui, smoke_boot, smoke_sandbox, smoke_skills, smoke_orders, smoke_vfx,
  smoke_combat_core, test_core, test_hq, test_town, test_procedural, test_items, test_economy, test_summons,
  test_simulation, test_deep_systems, test_memorial. Resultado: `RESULT failing:[ ]`.
- Ninguna fallaba de antes.
- Fixture de 200 semillas: `tests/fixtures/hero_seeds_v3.json` (`tests/test_hero_fixture.gd`, ALL PASSED).
