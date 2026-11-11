# Auditoría técnica del código

Alcance: 24 scripts de juego (`scripts/`), 1 escena (`scenes/main.tscn`), 12 pruebas (`tests/`), herramientas (`tools/`). Análisis **estático**; Godot no estaba disponible. Los IDs remiten a `AUDIT_FINDINGS.json`.

## 1. Estructura y arquitectura actual
```
scenes/main.tscn → scripts/main.gd (Control raíz, cambia pantallas creadas por código)
autoload Game (scripts/autoload/game.gd, 461 líneas): moneda, gacha, roster, party, memorial,
                HQ, edificios, mapas de torre, guardado/carga/migración  ← "god object"
core/   HeroData (modelo + lógica social + XP + stats + serialización), HeroGenerator, Gacha,
        SpriteComposer, ProceduralMap, TowerExpedition
data/   HeroTables (clases, rasgos, pasivas, profesiones, nombres), SummonConfig
sandbox/ SandboxScreen (misión + input + cámara + UI + reglas de misión), SandboxHero, SandboxEnemy,
        SandboxMap, SandboxMapView, MapTiles, CombatRules, SkillTables, HeroAnim, CombatVFX,
        EnemySprites, HeroChatter, SandboxRelic, HQWorld
ui/     MainMenu, SummonScreen, RosterScreen, PartyScreen, HQScreen, MemorialScreen + widgets, UIKit
```
- 1 solo autoload; todo lo demás `class_name` + UI construida en código (coherente con D-019).
- Sin señales de dominio salvo `Game.changed` (global, redibuja pantallas completas).
- Sin dependencias circulares de carga detectadas; sí acoplamiento: `ProceduralMap` (core) lee `Game.PARTY_SIZE` (autoload) — F-026.
- Datos de balance fuera de la UI (bien), pero el "simulador" vive dentro de nodos (`SandboxScreen.tick`) y no es separable del renderizado como pide BIB.

## 2. Hallazgos de código (por severidad)

### HIGH
**F-001 · `HQWorld` no compila.** `scripts/sandbox/hq_world.gd:26-30`: `var composer := SpriteComposer.new()` y `composer.compose(h.appearance)`; `SpriteComposer` solo tiene `compose_frame`/`compose_sheet`/`pose_texture`/`build_frames` (`sprite_composer.gd`). El analizador de GDScript rechaza el método inexistente en una variable tipada. `main.gd:69` referencia `HQWorld.new()`, por lo que es probable que `main.gd` tampoco cargue → el juego arrancaría sin script raíz. **Confirmar en Godot; si se confirma, CRITICAL.** Además `HQWorld` usa `ProceduralMap.new(60,40,9999,1)` (piso 1 de mazmorra, no el layout HQ `floor<=0`), no dibuja muros y mueve héroes con `randf()` (F-027).

**F-002 · El modo Torre falla por tipos.** `SandboxScreen._ready` (`sandbox_screen.gd:60-68`) asigna un `ProceduralMap` a `map` (sin tipo) y luego lo pasa a parámetros tipados `SandboxMap`: `SandboxMapView._init(m: SandboxMap)`, `SandboxHero.combat_tick(..., map: SandboxMap)`, `SandboxEnemy.tick/_step_toward(..., map: SandboxMap)`, `MapTiles.bake(map: SandboxMap)`. `ProceduralMap` y `SandboxMap` son clases `RefCounted` sin herencia común → error de tipo en ejecución. Además, la UI nunca crea `SandboxScreen` con piso > 0 (`main.gd:63`), así que el modo Torre es inalcanzable para el jugador y sin pruebas que lo instancien.

**F-003 · La misión se completa al recoger el relicario.** `sandbox_screen.gd:89` coloca el relicario en `map.goal_cell`; en `SandboxMap` `goal_cell = GOAL_CELL = (36,12)`, que es también el punto de extracción (`:300`). `RELIC_CELL = (32,3)` está declarado y no se usa. Consecuencia: recoger = extraer = éxito instantáneo. Rompe `smoke_mission` y `smoke_sandbox` (ver `GODOT_TEST_REPORT.md`).

**F-004 · `smoke_combat.gd:28` referencia `SandboxScreen.ENEMY_CELLS`,** que no existe (está en `SandboxMap`). Error de compilación de la suite.

**F-005 · `test_deep_systems.gd:58` accede a `g.memorial[0]["id"]`;** las entradas del memorial usan `hero_id` (`game.gd:179-192`). Acceso a clave inexistente en `Dictionary` = error en ejecución; la suite no imprime "ALL PASSED".

**F-007 · División por cero en promoción.** `HeroTables.PROMOTION_CLASS_POOL := []` y `HeroGenerator.apply_promotion` hace `pool[rng.randi() % pool.size()]` si la clase es `class.none` y estrellas ≥ 3 (`hero_generator.gd:58-60`). Los héroes nuevos nunca son `class.none`, pero `HeroData.from_dict` convierte en `class.none` cualquier clase desconocida (`hero_data.gd:286-287`), p. ej. las clases eliminadas por la refactorización de clases (Thief/Spearman/Archer…). Un guardado antiguo promovido a 3★ → error.

**F-008 · Determinismo del generador roto sin subir versión.** `hero_generator.gd:33-34` inserta la tirada de `profession` antes de `variance` y Trust/Obedience; las tablas de clases y pesos cambiaron (Gemini 23:41/00:15). `VERSION` sigue en 2 y el comentario de la línea 39 afirma que "existing seeds keep their looks, class, traits and Trust". El `summon_log` promete reproducir cada tirada a partir de su semilla: ya no es cierto para heroes v2 anteriores. La prueba que lo vigilaba (`test_summons.gd` §11) se reduce a comprobar el número de versión (tautológica). Los héroes guardados no se ven afectados porque se guarda el snapshot (D-004 cumplido para héroes).

**F-009 · Producción del HQ no usa profesiones; sistemas paralelos.** `game.gd:266-302` produce cantidades fijas por instalación; `profession` no se lee. `hq_facilities` (niveles) no se usa en ningún cálculo. `town_buildings` (con `kitchen`, `infirmary`, `blacksmith`) duplica conceptos de `hq_facilities` y solo sirve para la capacidad de roster; `upgrade_building` no tiene llamador en la UI.

**F-010 · Biblioteca de skills (D-022) ausente.** No existen `tools/gen_skill_library.py`, `scripts/data/skill_library_data.gd`, `SkillLibrary`, `SandboxHero.equip_skill` ni `tests/test_skill_library.gd`. El juego usa `SkillTables` (1 skill por clase). `SKILL_LIBRARY.md` describe otras clases.

**F-032 · Contradicción de diseño en el código** (ver DESIGN_TRUTH): `ProceduralMap`, `TowerExpedition`, `HQWorld`, `town_buildings` implementan requisitos de un "Mega Prompt" no versionado que contradice D-003/D-014.

### MEDIUM
- **F-012 · VFX con ruta inexistente.** `sandbox_hero.gd:150` pide `res://assets/packs/spritepilot-combat-pack/16px/sword-slash-16px_strip7.png`; el archivo real está en `assets/packs/spritepilot-combat-pack/spritepilot-combat-pack/16px/…` (carpeta anidada). `CombatVFX.create_strip_frames` devuelve `null` en silencio → nunca hay VFX. La ruta usada coincide con la estructura de `assets/source_packs/`, lo que sugiere confusión entre las dos copias. Además construye `SpriteFrames` nuevos en cada ataque (sin caché).
- **F-013 · Constante en lugar de dato del mapa.** `sandbox_screen.gd:300` y `sandbox_map_view.gd:52` usan `SandboxMap.GOAL_CELL` en vez de `map.goal_cell`.
- **F-014 · Pisos guardados como semilla.** `game.gd:246-263` guarda `grid_rows` pero al cargar regenera desde la semilla (ignora `grid_rows`), sin versión de generador → viola D-004 cuando cambie `ProceduralMap`. Mapas de 80-160 celdas × 48 px → `MapTiles.bake` crearía imágenes de hasta 7680×7680 RGBA (~236 MB) y el `_draw` de respaldo emite >100 000 llamadas de dibujo por redibujado.
- **F-015 · Mensaje erróneo al invocar.** `Game.pull` devuelve `[]` también si se supera la capacidad (`can_summon`, cap 15 por defecto); `summon_screen.gd:86` muestra siempre "Not enough gems." Con 2000 gemas iniciales, la segunda tirada x10 falla con ese mensaje teniendo gemas.
- **F-016 · Restos de combate por turnos/filas.** `party_screen.gd:3,68-72` (FRONT/BACK ROW), `game.gd:9` comentario de filas, `HeroTables.PASSIVES` ("front row", "each turn", "same row", "first turn") — contrario a D-010. Ninguna pasiva tiene efecto en juego.
- **F-017 · Atributos D-012 no implementados.** Stats `hp/atk/mag/def/spd`; `power()` y daño usan `max(atk, mag)`.
- **F-018 · Órdenes y feedback incompletos.** Faltan atacar objetivo, attack-move, mantener, seguir, interactuar, retirada (CTRL §5); pulsar la tecla de un héroe muerto no da mensaje (`select_slot` retorna en silencio; D-015 lo exige).
- **F-019 · Social estático en misión.** Composure nunca cambia; Trust solo por `ally_fell`; `rescue_hero`, `cooperate_with`, `discover_secret` solo se invocan desde pruebas.
- **F-020 · Tipos de misión sin lógica.** `TowerExpedition.FLOORS[*].mission` (combat/retrieval/rescue/exploration/survival/defense/boss) no se usa; siempre "Recover the relic". `HeroChatter` siempre habla del relicario.
- **F-033 · 5★ vs 7★** sin resolver; `MAX_STARS` y `rates` acoplados (`SummonConfig.validate` exige `rates.size()==MAX_STARS`).
- **F-034 · Escuadrón de prueba silencioso.** Si el party tiene <5 héroes se despliega un escuadrón de semillas fijas sin aviso ni recompensas (`sandbox_screen.gd:106-111`).
- **F-035 · Calidad de pruebas.** Comprobaciones tautológicas (`treasure_cells.size() >= 0`, versión en lugar de aspecto), sin pruebas de: modo Torre en `SandboxScreen`, `HQWorld`, `HQScreen`, `MainMenu`/`main.tscn`, carga de guardado v4→v5, `promote` con `class.none`.

### LOW
- **F-024** Indentación mixta: 9 archivos con tabulaciones (`hero_generator.gd`, `procedural_map.gd`, `hq_world.gd`, `sandbox_hero.gd`, `sandbox_map_view.gd`, `sandbox_screen.gd`, `hq_screen.gd`, `roster_screen.gd`, `ui_kit.gd`), resto con espacios; GEMINI.md exige espacios.
- **F-025** `add_memory` usa `Time.get_ticks_msec()` en el id (no determinista) y `time = event_seq` (no avanza con memorias); `update_relationship` tiene dos ramas iguales y el estado `unfamiliar` es inalcanzable tras la primera interacción.
- **F-026** `ProceduralMap`: `objective_cells` no se limpia entre reintentos; la rejilla de validación usa diagonal por defecto (distinta de la real); depende del autoload `Game`.
- **F-027** Aleatoriedad global no determinista (`randi()` en `HeroChatter`, `randf()` en `HQWorld`).
- **F-028** `SandboxScreen._process` reconstruye el texto del panel y recalcula `get_stats()` cada frame.
- **F-029** Versiones inconsistentes (Godot 4.4/4.6.2/4.7; 7-12 suites).
- **F-030** Scripts obsoletos de "drops" (`Apply-DropD.ps1`, `tools/Update-Project.ps1`, `tools/manifest.json`).

## 3. Duplicaciones e implementaciones paralelas
| Concepto | Implementaciones | Recomendación |
|---|---|---|
| Mapa navegable | `SandboxMap` (espacios) y `ProceduralMap` (tabs) — copia de `nearest_walkable`, `find_path`, `cell_of`… | Interfaz/clase base común (`NavMap`) |
| Instalaciones | `hq_facilities` vs `town_buildings` | Un solo modelo de edificios |
| Historial del héroe | `events` (ledger) vs `memories` | Un registro con vistas |
| Skills | `SkillTables` vs librería D-022 (inexistente) | Decidir una |
| Pack de assets | `assets/packs` vs `assets/source_packs` | Una copia (ver ASSET_AUDIT) |

## 4. Separación de responsabilidades (resumen; detalle en roadmap C)
- `Game` mezcla economía, roster, HQ, mapas y persistencia → separar en servicios puros (`RosterService`, `EconomyService`, `HQService`, `SaveService`) manteniendo `Game` como fachada. No es una reescritura: mover funciones existentes.
- `HeroData` mezcla modelo, reglas de stats y reglas sociales → mantener modelo; extraer `StatsService`/`SocialService` cuando se implemente D-012.
- `SandboxScreen` mezcla simulación, misión, input, cámara y HUD → extraer `MissionController` y la simulación (`tick`) para pruebas sin nodos.

## 5. Lo que está bien y conviene conservar
- Guardado atómico con verificación, `.bak` y migraciones encadenadas (`game.gd:342-461`).
- `Game.pull` transaccional (nada cambia si no se puede pagar).
- Seeds en hexadecimal para no perder precisión de 64 bits en JSON; `intify` para restaurar enteros.
- Validación de banners y callsigns deterministas.
- Animaciones derivadas en código respetando la hoja original (D-020) sin modificar los PNG de Caz.
- `nearest_walkable` + A* con snapping; separación anti-aglomeración que no empuja contra muros.
