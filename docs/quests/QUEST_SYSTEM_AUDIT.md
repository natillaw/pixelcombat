# Auditoria del proyecto para el sistema de misiones (Fase 0)

Estado a 2026-11-12. Motor: Godot 4.7.2 (`gl_compatibility`). Idioma del proyecto: comentarios y docs en
espanol, identificadores en ingles. El proyecto se llama **PixelCombat** (el prompt lo llama "Combat Tower").

## Lo que ya existe y se reutiliza

| Pieza | Donde | Que hace hoy |
|---|---|---|
| Misiones de piso | `game/mission.gd`, `game/world/mission_gen.gd`, `combat/mission_catalog.gd`, `data/missions.json` | Cada piso sortea 1 mision principal (+1 opcional) con tipos clear, hunt, slay, collect, activate, explore, rescue, destroy, survive, relic. `MissionGen` coloca todo lo necesario para que sea **posible** (garantia de factibilidad). Pisos x5: doble mision + 2 minijefes (+ limite de tiempo opcional). Pisos x10: jefe con prueba (sellos, oleadas, elites). |
| Determinismo | `TowerGenerator.generate(floor, world_seed, visit, forced, with_elite)` | Terreno fijo por piso; el contenido (misiones, enemigos, nodos) se resortea por visita con semilla. |
| Tablon del Gremio | `game/bounties.gd`, `data/bounties.json`, `game/services.gd` | 3 encargos deterministas (`world_seed` + `bounty_serial`), maximo 3 activos, progreso por eventos (kill, material, piso) y cobro. |
| Guardado | `game/save_game.gd` (JSON v1, 3 ranuras), `PlayerSim.export_state/import_state`, `TowerState.to_dict` | Persiste jugador, torre y encargos; carga tolerante a datos que faltan. |
| Eventos | senales de `CombatWorld` (`enemy_killed`, `interacted`, `resource_gathered`...) y `PlayerSim.material_gained` | La sesion los escucha y alimenta misiones y encargos. |
| Recompensas | `ItemGen`, `ItemCatalog`, `ConsumableCatalog`, XP por piso, cofres | `Services`/`Bounties` entregan oro, XP, consumibles y skills (instructora). |
| Elite errante | `TowerCatalog.elite_floor`, `MissionGen.add_wandering_elite` | Ya es un "evento secreto" (una vez por partida). |
| UI | `MenuKit`, `ServicePanel`, `UiStyle` (CraftPix), HUD de objetivos | Ventanas con filas y pestanas; objetivos a la derecha del HUD. |
| Datos | JSON + catalogos con validacion y suites de tests (`tools/run_tests.sh`) | Convencion del proyecto: contenido en `data/*.json`, tests por archivo de datos. |

## Diferencias entre el prompt y lo hablado/construido antes

1. **Formato de datos**: el prompt propone Resources `.tres`; el proyecto es 100 % JSON + catalogos validados (reglas de AGENTS.md: contenido dirigido por datos, tests por JSON). Propongo **mantener JSON** (misma validacion, diff legible, editable por ti sin Godot) y que las clases `QuestDefinition`/`QuestInstance` sean objetos GDScript que se cargan de `data/quests/*.json`.
2. **Ya hay un sistema de misiones**: no se parte de cero. El prompt describe un sistema mas general (categorias, cadenas, flags, secretos, recompensas con tablas). Propongo **no reescribir** `Mission`/`MissionGen`: las misiones de piso son la "mision principal del piso" y se migran a `QuestDefinition` solo cuando haga falta; el nuevo marco gobierna *secundarias, dinamicas, secretas, cadenas y principales de historia*.
3. **Tablon**: el prompt quiere el tablon "antes de entrar al piso" con 2-3 ofertas compatibles con el piso. Hoy el tablon del Gremio ofrece 3 encargos globales (no ligados a un piso). Propongo que el tablon pase a ofrecer encargos **del piso que vas a subir** (compatibles con sus enemigos/bioma) y que sus ofertas se guarden por piso y por partida (sin rerolls).
4. **Limite de 3 secundarias**: coincide con el `max_active = 3` actual. Las principales y secretas quedan fuera del limite, como pide el prompt.
5. **Alcance de pisos**: lo hablado es **no hacer nada despues del piso 10** hasta pulir los primeros 10. El prompt habla de 100 pisos; el marco sera valido para 100 (datos con `floor_min/floor_max`) pero **el contenido de ejemplo y las pruebas solo cubriran los pisos 1-10** (tier 1: Bosque del Cuervo, bandidos y bestias).
6. **Fases**: el prompt pide parar tras la auditoria para presentar resultados. Como pediste avanzar sin esperar, sigo por fases, cada una con tests y commit; las decisiones grandes se anotan aqui.
7. **Documentos**: el prompt pide `QUEST_SYSTEM_*.md` en la raiz; los dejo en `docs/quests/` (como el resto de la documentacion) y el changelog en `docs/ROADMAP.md`.
8. **Autoloads**: el prompt sugiere managers; el proyecto solo tiene 3 autoloads y la simulacion vive en `CombatWorld` (regla: solo cambia en `step()`). Propongo que el marco sea un conjunto de clases sin autoload, propiedad de `GameSession` (igual que `Mission`/`Bounties`), para no romper determinismo ni la futura red.
9. **Recompensas**: ya existen oro/XP/consumibles/skills/items; el prompt anade tablas ponderadas y paquetes con semilla. Se construira `RewardGenerator` (puro, sin tocar el inventario) y `RewardManager` (entrega) reutilizando `ItemGen`/`ConsumableCatalog`.

## Huecos reales (lo que el marco nuevo anade)

World flags y decisiones, cadenas (lineales, ramificadas, condicionales), eventos secretos con condiciones
(AND/OR/secuencias), misiones dinamicas durante la exploracion, categorias de mision adicionales (desafio,
investigacion, escolta, social), estados Locked/Available/Active/Completed/Failed/Abandoned/Claimed,
proteccion de repeticion, tablas de recompensa, historial y UI de diario/seguimiento.

## Plan de integracion propuesto (por fases, solo pisos 1-10 en contenido)

1. Arquitectura y modelos de datos (JSON + clases): `QuestDefinition`, `QuestInstance`, `ObjectiveDefinition/Instance`, `RewardDefinition`, `RewardPackage`, `WorldFlags`, `QuestChainDefinition`, `SecretEventDefinition`.
2. `QuestLibrary` (carga, filtros, validacion) + `SeedManager`.
3. `QuestGenerator`/`QuestDirector`/`QuestValidator` con pesos de rareza, proteccion de repeticion y persistencia por piso.
4. Rastreo de objetivos por eventos (bus `GameEvents` en la sesion) con manejadores reutilizables.
5. `QuestManager` (estados, limite de 3, abandono, cobro sin duplicados).
6. Narrativa: flags, cadenas, ramas; eventos secretos.
7. Recompensas: tablas, generador determinista, gestor.
8. Tablon por piso y misiones dinamicas; UI (tablon, diario, seguimiento, avisos).
9. Guardado versionado y migracion; tests por modulo; documentacion final.
