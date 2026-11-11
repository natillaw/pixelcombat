# AGENTS.md

Guía para agentes y personas que trabajen en **PixelCombat**. Léela antes de
tocar código o assets.

## Contexto

PixelCombat es un action RPG 2D de pixel art: combate de acción con el ratón
(referencia Drakantos + Battlerite), torre de 100 pisos procedurales, crafting,
items con rarezas y ciudad hub. Cuatro clases base (Warrior, Rogue, Mage,
Archer) con muchas subclases. Habrá PvP, así que el balance importa. El único
corte jugable hoy es el **Warrior** en un patio de entrenamiento. Godot 4.7.2,
renderer `gl_compatibility`. El plan está en `docs/ROADMAP.md` y las decisiones
en `docs/DECISIONES.md`.

## Reglas de arquitectura (no romper)

1. **La simulación solo cambia dentro de un tick fijo.** El único `Tickable`
   registrado en `TickManager` es `CombatWorld`. `PlayerSim` y `DummySim` solo
   mutan dentro de `step()`.
2. **Presentación ≠ simulación.** `Arena`, `PlayerActor`, `DummyActor`, VFX,
   cámara y `GameHud` leen estado o escuchan señales; nunca escriben posición,
   vida, Rage, cooldowns ni estado de ataque.
3. **Determinismo.** Nada de `randf()` global ni `Time` dentro de la simulación.
   Usa el RNG del `CombatWorld`/`PlayerSim`, sembrado y avanzado por tick.
4. **Input como comando.** El input del jugador se empaqueta en `InputMessage`
   (`move_dir`, `aim_dir`, `actions`) y se entrega una vez por tick. Esto es lo
   que permite que el netcode futuro reutilice la misma simulación.
5. **Números de balance en datos.** Las skills ejecutables viven en
   `data/skills/*.json` (cargadas por `SkillCatalog`); el resto de datos del
   Warrior, en `combat/warrior_kit.gd`. La simulación los lee, no los duplica.
   La UI no contiene números de combate.
6. **Contenido dirigido por datos.** Skills, items, recetas, enemigos, pisos y
   tiers nuevos se añaden como datos en `data/` o en los kits, no con código
   específico por contenido.
7. **Rareza no es poder.** Las clases, subclases y skills raras, únicas o
   legendarias cambian cómo se juega; no suben el techo de balance (PvP).
8. **Un `class_name` por archivo**, GDScript tipado. Evita `:=` cuando la
   expresión devuelve `Variant` (acceso a `Dictionary`, `Array` sin tipo,
   `get()`); Godot 4.7 trata esa inferencia como error en este proyecto.

## Simulación y presentación

```
main.gd ──input──▶ CombatWorld (Tickable)
                     ├── PlayerSim
                     └── DummySim[]
Arena / Actors / HUD ◀── leen estado y señales
```

- Simulación: `game/sim/`, `combat/`, `core/tickable.gd`.
- Presentación: `game/actors/`, `game/world/`, `game/vfx/`, `game/ui/`,
  `ui/debug_overlay.gd`.
- Si un efecto necesita cambiar el juego, no lo hace el VFX: emite una señal o
  pide el cambio a la simulación en el tick siguiente.

## Añadir una habilidad

1. Si usa una forma existente (`cone`, `line`, `circle`), basta con un objeto
   nuevo en `data/skills/<clase>.json` (esquema en `combat/skill_catalog.gd`).
   `tests/test_skill_catalog.gd` valida el esquema y que coste/cooldown
   coincidan con el Skill Book de `combat/warrior_kit.gd`.
2. Pon su `unlock_level` (nivel al que se desbloquea; también en la entrada del
   Skill Book de `combat/warrior_kit.gd`: un test comprueba que coincidan), marca
   `implemented: true` en el JSON **y** en la entrada del Skill Book, y
   añade su id a `IMPLEMENTED_SKILLS` en `tests/test_warrior_data.gd` y
   `combat/tests/test_warrior.gd`.
3. Si necesita una forma o una mecánica nueva (estado, proyectil, canalizado),
   impleméntala una vez en `PlayerSim` dentro de `step()` y deja que el dato la
   active; no hagas código por skill.
4. Expón lo necesario en `snapshot()` si afecta a la red.
5. VFX/SFX en `Arena` y el actor; el actor solo consume señales.
6. Checks en `tests/test_skills.gd` (daño, coste, cooldown, forma, borde).
7. Actualiza `docs/design/WARRIOR.md` y `docs/ARCHITECTURE.md` si aplica.

## Tests

Antes de dar algo por terminado:

```powershell
pwsh -File tools/run_tests.ps1
```

- Añade una suite nueva a `tools/run_tests.ps1` **y** a `tools/run_tests.sh`.
- Los tests son scripts `SceneTree` que salen con 0/1. No abren ventana.
- No ajustes un test para tapar un fallo real; corrige la simulación o el dato.
  Si el test estaba mal planteado, documenta por qué cambia.

## Assets y licencias

- Usa solo assets con licencia leída y registrada en `docs/ASSET_REGISTRY.md` y
  `assets/ASSET_REGISTRY.json`.
- El arte del Warrior es LPC (`assets/pixel/lpc/`); los créditos por archivo
  están en `assets/pixel/lpc/CREDITS.csv`.
- SFX: `assets/audio/sfx/ninja/` (CC0). Fuente: `assets/fonts/m5x7.ttf` (CC0).
- No edites los PNG originales del LPC; el `LpcComposer` compone en memoria.
- `new assets/` son packs crudos: están ignorados por git y por Godot
  (`.gdignore`). No los referencies desde el juego.
- No redistribuyas packs crudos como biblioteca independiente.

## Carpetas que no se tocan

- `new assets/` (si existe en tu copia local) es material de origen, no
  contenido del juego.

## Estilo

- Indentación con **tabs** en archivos nuevos de `game/`, `tests/` y `combat/`.
  Respeta el estilo del archivo que edites.
- Comentarios y documentación en español; identificadores y API en inglés.
- Nombres de archivos en `snake_case`.
- Nada de dependencias externas ni addons sin justificar.

## Git

- Trabaja en una rama descriptiva (`overhaul/...`, `feat/...`).
- Commits pequeños y con intención: separar reestructuración de assets de
  cambios de gameplay.
- No reescribas historia publicada. Lo que deja de usarse se elimina con un
  commit explicado (el historial lo conserva).
