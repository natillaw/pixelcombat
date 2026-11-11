# AGENTS.md

Guía para agentes y personas que trabajen en **Reflections**. Léela antes de
tocar código o assets.

## Contexto

Reflections es un action RPG top-down de clases con identidad fija: sin gacha,
sin builds y sin variantes. El único corte jugable hoy es el **Warrior** en un
patio de entrenamiento. Godot 4.7.2, renderer `gl_compatibility`.

## Reglas de arquitectura (no romper)

1. **La simulación solo cambia dentro de un tick fijo.** El único `Tickable`
   registrado en `TickManager` es `CombatWorld`. `WarriorSim` y `DummySim` solo
   mutan dentro de `step()`.
2. **Presentación ≠ simulación.** `Arena`, `WarriorActor`, `DummyActor`, VFX,
   cámara y `GameHud` leen estado o escuchan señales; nunca escriben posición,
   vida, Rage, cooldowns ni estado de ataque.
3. **Determinismo.** Nada de `randf()` global ni `Time` dentro de la simulación.
   Usa el RNG del `CombatWorld`/`WarriorSim`, sembrado y avanzado por tick.
4. **Input como comando.** El input del jugador se empaqueta en `InputMessage`
   (`move_dir`, `aim_dir`, `actions`) y se entrega una vez por tick. Esto es lo
   que permite que el netcode futuro reutilice la misma simulación.
5. **Números de balance en datos.** Los valores del Warrior viven en
   `combat/warrior_kit.gd`; la simulación los lee, no los duplica. La UI no
   contiene números de combate.
6. **Un `class_name` por archivo**, GDScript tipado. Evita `:=` cuando la
   expresión devuelve `Variant` (acceso a `Dictionary`, `Array` sin tipo,
   `get()`); Godot 4.7 trata esa inferencia como error en este proyecto.

## Simulación y presentación

```
main.gd ──input──▶ CombatWorld (Tickable)
                     ├── WarriorSim
                     └── DummySim[]
Arena / Actors / HUD ◀── leen estado y señales
```

- Simulación: `game/sim/`, `combat/`, `core/tickable.gd`.
- Presentación: `game/actors/`, `game/world/`, `game/vfx/`, `game/ui/`,
  `ui/debug_overlay.gd`.
- Si un efecto necesita cambiar el juego, no lo hace el VFX: emite una señal o
  pide el cambio a la simulación en el tick siguiente.

## Añadir una habilidad

1. Define el dato en `combat/warrior_kit.gd` (`implemented = false` hasta que
   esté jugable).
2. Implementa el estado y la resolución en `WarriorSim` dentro de `step()`.
3. Expón lo necesario en `snapshot()` si afecta a la red.
4. Añade VFX/SFX en `Arena` y el actor; el actor solo consume señales.
5. Añade checks a `tests/test_warrior_sim.gd` (daño, coste, cooldown, borde) y,
   si cambia el contrato de diseño, a `tests/test_warrior_data.gd`.
6. Actualiza `docs/design/WARRIOR.md` y `docs/ARCHITECTURE.md` si aplica.

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

- `archive/legacy_ts/` es histórico. No lo importes ni lo reactives.
- `new assets/` es material de origen, no contenido del juego.

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
- No borres historia: lo que deja de usarse se archiva.
