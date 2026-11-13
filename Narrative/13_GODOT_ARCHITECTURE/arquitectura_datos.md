# Arquitectura de datos y validacion de la narrativa

- **Texto en datos**: `data/lore.json` (intro, clases, tiers, `floors`, `dialogue`, `tier_closing`, `npcs` por etapa,
  `rumors`, `rumors_after`). Nunca en el codigo de simulacion. Acceso: `game/lore.gd` (`Lore`).
- **Banderas y etapa**: `game/world/tower_state.gd` (`flags`, `set_flag`, `story_stage`), guardadas con la torre.
- **Uso en el juego**: `game/session.gd` (titulo de piso al entrar, dialogos de jefes por senal del enemigo, banderas
  al morir, cierre del tier al completar el piso 10, lineas de PNJ por etapa); `game/world/tower_generator.gd`
  (titulo del piso); `game/services.gd` (rumores segun banderas).
- **Validacion**: `Lore.errors()` y `Lore.narrative_errors()`, ejecutados por `tests/test_narrative.gd`
  (suite registrada en `tools/run_tests.sh` y `.ps1`): ficha completa de los pisos 1-10, enemigos existentes, sin
  promesas de geografia (rio, montana, pantano, mina...), dialogos de los 4 jefes/elite, 4 lineas por PNJ, cierre del
  tier y rumores.
- **Ids estables**: pisos por numero; jefes por `def_id` (`bandit_rask`, `bandit_veyra`, `bandit_garrick`,
  `bandit_deserter`); PNJ por estacion (`blacksmith`, `alchemist`, `carpenter`, `tailor`, `tavern`, `guild`, `merchant`, `bank`).
- **Pendiente (Fases 5 y 8 completas)**: plantillas de mision con contexto narrativo y el marco de misiones descrito en
  `docs/quests/QUEST_SYSTEM_AUDIT.md`.
