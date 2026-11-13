# Guia de contenido de misiones

1. **Mision secundaria**: anadir a `data/quests/definitions.json` un objeto con `id`, `type:"side"`, `category`, `rarity`, `title`, `desc` (`{count}` se sustituye), `floor_min/max`, `objectives` (`id, kind, target, count` fijo o `[min,max]`, `optional`), `rewards` (id de tabla).
2. **Objetivos**: kinds `kill` (target admite `bandit_*`), `collect` (`gatherable`, item o tier), `interact`/`discover` (objeto del piso), `reach` (`floor`), `survive` (`beacon`, segundos), `condition` (`no_potions_floor`, `no_damage_floor`).
3. **Cadenas**: `requires_flags`, `set_flags`, `next: [ids]`; con decision, `branches:[{id,set_flags,next}]`.
4. **Secretas**: definicion `type:"secret"` + disparador en `secret_events.json` (`conditions.all|any|sequence`, `effect.start_quest|flag|message`).
5. **Recompensas**: `reward_tables.json` (`guaranteed`, `slots` ponderados, `rarity_mult`); items y consumibles deben existir.
6. Ejecutar `tests/test_quests.gd`: valida referencias rotas, objetivos imposibles y tablas.
