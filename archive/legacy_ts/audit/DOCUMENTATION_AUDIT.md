# Auditoría de documentación

Rutas relativas a la raíz del repo. "Fecha" = fecha declarada en el documento. Estados: Vigente · Parcialmente vigente · Histórico · Duplicado · Obsoleto · Contradictorio · Pendiente de verificar.

## 1. Inventario y clasificación

| Documento | Contenido | Estado | Contradicciones | Acción propuesta |
|---|---|---|---|---|
| `README.md` | "Drop C"; cómo ejecutar; mapa de archivos; controles | Obsoleto | Dice 7 suites (hay 12); "Godot 4.x/4.4.1"; omite HQ, Torre, profesiones | Reescribir como README corto que apunte a la fuente de verdad |
| `GEMINI.md` | Protocolo Gemini; importa `infos/AGENTS.md`; reglas GDScript | Parcialmente vigente | "Godot 4.4"; menciona `tools/gen_skill_library.py`, `scripts/data/skill_library_data.gd`, `docs/SKILL_LIBRARY.md`, `tools/sync/ts_sync.py` (no existen en esas rutas); "procedural worlds deferred" implícito | Corregir rutas; mantener reglas GDScript (útiles) |
| `.gemini/settings.json` | Carga `GEMINI.md` | Vigente | — | Mantener |
| `.gemini/commands/ts/start.toml` | Lee `infos/CONTEXT_LITE.md` | Vigente | Contexto lite está desactualizado (ver abajo) | Mantener; regenerar lite |
| `.gemini/commands/ts/finish.toml` | Log + regenerar contexto | Parcialmente vigente | Pide actualizar `docs/ai-context/CURRENT_STATE.md` (ruta real `infos/docs/...`) | Corregir ruta |
| `.gemini/commands/ts/test.toml` | Ejecuta `Run-Tests.ps1` | Vigente | — | Mantener |
| `.gemini/commands/ts/skill.toml` | Edita `tools/gen_skill_library.py` | Obsoleto | El generador y `test_skill_library.gd` no existen | Archivar o reescribir cuando exista la librería |
| `.geminiignore` | Ignora png/zip/import | Vigente | No ignora `assets/source_packs` metadata JSON | Ampliar |
| `infos/CLAUDE.md` | "Follow AGENTS.md in this repo root" | Contradictorio | Está en `infos/`, no en la raíz; `AGENTS.md` tampoco está en la raíz. Claude Code no lo carga automáticamente | Crear `CLAUDE.md` en raíz (fase 2) |
| `infos/.github/copilot-instructions.md` | Copia exacta de CLAUDE.md (título "# CLAUDE.md") | Duplicado | Copilot solo lo lee en `.github/` de la raíz | Mover o eliminar (fase 2, con autorización) |
| `infos/AGENTS.md` | Protocolo multiagente, autoridad documental | Parcialmente vigente | Rutas `tools/sync/…`, `docs/ai-context/…` relativas a raíz inexistentes; "Procedural worlds are deferred" vs código; exige `commit and push` cada sesión | Reescribir con rutas reales; decidir si se mantiene el protocolo de claims |
| `infos/README.md` | Starter pack v1.7 | Histórico | "planning documentation… Godot project is separate" (ya no es cierto) | Archivar |
| `infos/SESSION_HANDOFF_PROMPT.md` | Prompts lite/short/full | Histórico | "The current ZIP is planning documentation, not a verified Godot project"; mundos diferidos | Archivar |
| `infos/SESSION_SUMMARY.md` (2026-10-29) | Informe de Gemini: "All 11 suites PASS", Godot 4.6.2, fases 0-4 completas | **Contradictorio / no fiable** | Run-Tests tiene 12 suites; F-003/4/5 impiden PASS; describe "agony timer", "enemy roles frontliner/ranged/support", "Tower Expedition mode", "attack orders" que no existen; dice que la producción del HQ usa profesiones (falso, F-009) | Marcar como no verificado; no usar como evidencia |
| `infos/CONTEXT_LITE.md` (STATE_HASH 20c12560f902) | Contexto generado | Obsoleto | Hash distinto del bundle; contenido = CURRENT_STATE de 10-28 | Regenerar tras reescritura; idealmente dejar de versionar |
| `infos/CONTEXT_BUNDLE.md` (STATE_HASH 24c74c6b8b84, 2 351 líneas) | Concatenación de todos los docs | Duplicado | Contiene todas las contradicciones; ~100 KB | No versionar; generar bajo demanda |
| `infos/docs/ai-context/CURRENT_STATE.md` | Estado, decisiones verificadas, drops B/C, fases 2 y procedural | Contradictorio | Cabecera 10-28 "Phase 1", "Godot 4.4.1"; sección "Verified implementation state" dice que no hay código; luego añade "12 suites pass"; "Procedural world generation is deferred" y a la vez "Procedural Generation Repair" | Reescribir desde cero con evidencia |
| `…/IMPLEMENTATION_STATUS.md` (10-29) | Implementado/falta | Parcialmente vigente | "7 suites", "v1/v2/v3" (save es v5), "Godot 4.4.x" | Fusionar en nuevo CURRENT_STATE |
| `…/DECISIONS.md` | D-001…D-022 | **Vigente (autoridad máxima)** pero incompleto | D-003/D-014 (mundos diferidos) contradicen código y prompt actual; D-022 describe archivos inexistentes; conflicto abierto 5 vs 7 estrellas | Añadir decisiones nuevas (Torre, HQ, profesiones, clases) con aprobación del usuario |
| `…/PROJECT_BIBLE.md` | Visión, pilares, alcance | Parcialmente vigente | Base/economía/crafting están en "Systems scope" pero "deferred" en ROADMAP/DESIGN_GAPS | Mantener visión; actualizar alcance |
| `…/ROADMAP.md` | Fases 0-7 | Obsoleto | Casillas no reflejan código (p. ej. "autonomous basic attacks" sin marcar); nota "project.godot says 4.4, README says 4.7" invertida; "Current next task: Phase 0" | Sustituir por `MASTER_REPAIR_ROADMAP` aprobado |
| `…/CHANGELOG.md` | Historial | Histórico | Orden cronológico roto; termina en Drop B (no recoge trabajo de Gemini) | Congelar como histórico |
| `…/HANDOFF_LOG.md` | Log append-only | Histórico | Entradas Gemini "passed all 9 suites" sin salida adjunta; entrada 02:15 de Claude (skill library) cuyo resultado no está en el repo | Congelar; no usar como evidencia |
| `…/TASK_BOARD.md` | T-001…T-032 | Obsoleto | T-007…T-013 "claimed (awaiting owner test run)" desde 10-28; T-022/T-024 "open" pese a existir `Import-Asset.ps1` y sprites de enemigos; T-001 "open" pese a existir Git | Reconstruir desde el roadmap nuevo |
| `…/AGENT_SYNC.md` | Protocolo v1.6 | Parcialmente vigente | STATE_HASH sobre `docs/ai-context` (raíz real `infos/`) | Simplificar |
| `…/RULES_LITE.md` | Reglas binding | Parcialmente vigente | "Procedural worlds deferred (fixed map)" | Actualizar tras nueva decisión |
| `…/DESIGN_GAPS.md` | Preguntas abiertas | Parcialmente vigente | Numeración duplicada (dos "20"); "Explicitly deferred: procedural world, base simulation, professions/crafting, large tower campaign" contradice código y prompt actual | Revisar con usuario |
| `…/CONTROL_AND_REALTIME_MISSIONS.md` | Spec de control | **Vigente** | Ninguna interna; gran parte no implementada (órdenes, off-screen indicators) | Mantener como spec |
| `…/COMBAT_AND_STATS.md` | Spec combate | Vigente | Atributos FUE…TEM no implementados | Mantener |
| `…/SUMMONS_AND_HERO_GENERATION.md` | Spec héroes/social | Vigente | Rarezas "Common…Legendary" vs código 1-5★; 8 dimensiones de personalidad no implementadas | Mantener; decidir rarezas |
| `…/REFERENCE_SYSTEMS.md` | Matriz de inspiración PMU | Vigente (referencia) | — | Mantener bajo demanda |
| `…/SKILL_LIBRARY.md` (955 líneas) | 130 skills generadas | Contradictorio | Clases Novice/Warrior/Thief/Spearman/Archer/Mage; el código usa Commoner/Warrior/Rogue/Ranger/Cleric/Mage; el generador no existe | Pendiente de decisión: regenerar o archivar |
| `…/ASSET_MANIFEST.md` | Candidatos y licencias | Obsoleto | No registra SpritePilot, KILN, Sprite Kitchen, Voxel Dungeon, Pixel Crawler; "Owner pack UNKNOWN" (ya se sabe: Caz) | Unificar con `assets/ASSET_REGISTRY.json` |
| `…/ART_DIRECTION.md` | Dirección pixel art | Vigente | Menciona "turn/target telegraphs" (resto turn-based, menor) | Mantener |
| `assets/CREDITS.md` | Créditos generados | Parcialmente vigente | Solo Pixel Crawler; falta Caz (requisito propio del manifest) y packs CC0/otros | Regenerar |
| `assets/sprites/EULA_READ_ME.txt` | Enlace a EULA de Caz | Pendiente de verificar | Texto de la EULA no está en el repo | Guardar copia de la EULA |
| `infos/IMAGEN … HEADQUARTERS ….jpg` | Referencia visual de HQ isométrico | Vigente como requisito visual | Es captura de un juego comercial de terceros | Solo referencia interna (D-002) |
| `infos/IMAGEN … MAPA PROCEDURAL.jpg` | Referencia de mapa procedural con biomas (agua, hierba, lava, magia), puertas, salas | Vigente como requisito visual | Contradice "mundos diferidos" | Registrar como decisión |
| `Apply-DropD.ps1`, `tools/Update-Project.ps1`, `tools/manifest.json` | Instaladores de "drops" por ZIP | Obsoleto | Flujo pre-Git; "expect 8 suites" | Archivar |
| `infos/tools/audit/Audit-GodotProject.ps1` | Script T-001 | Histórico | Nunca ejecutado (HANDOFF_LOG) | Archivar |
| `infos/tools/sync/ts_sync.py` | start/claim/log/bundle/lite/check | Pendiente de verificar | Funciona solo con raíz `infos/` (busca `docs/ai-context` subiendo directorios); comandos documentados con ruta `tools/sync/` | Decidir si se mantiene |

Total inspeccionados: 37 (los 26 `.md`, 5 configuraciones de Gemini, 2 imágenes, EULA, y 3 scripts de flujo documental).

## 2. Documentación faltante / referenciada pero inexistente
- `tools/gen_skill_library.py`, `scripts/data/skill_library_data.gd`, `scripts/sandbox/skill_library.gd` (`SkillLibrary`), `tests/test_skill_library.gd`, `docs/SKILL_LIST.txt` (D-022, GEMINI.md, skill.toml).
- `docs/ai-context/AUDIT_T001.md` (HANDOFF_LOG 19:11).
- El "Mega Prompt" citado en comentarios de código (`game.gd:206`, `tower_expedition.gd:3`, `hq_world.gd:3`) no está en el repo: sus requisitos solo existen como código.
- `tools/last_test_run.txt` (ignorado por `.gitignore`): no hay ninguna evidencia de ejecución de pruebas en el repo.
- Documentación del sistema de HQ, profesiones, Torre y clases nuevas: no existe spec ni decisión.

## 3. Contradicciones (24)
| # | Tema | Fuente A | Fuente B | Resolución propuesta |
|---|---|---|---|---|
| C-01 | Mundos procedurales | D-003, D-014, RULES_LITE, AGENTS: diferidos, mapa fijo | Código `ProceduralMap`+`TowerExpedition`; CURRENT_STATE "Procedural Generation Repair"; prompt actual: Torre 100 pisos, biomas; imagen de referencia | **Pendiente de confirmación**: la evidencia más reciente (prompt del usuario 2026-10-30) favorece generación procedural; falta D-xxx |
| C-02 | Base/profesiones/crafting | DESIGN_GAPS 20 y ROADMAP "Deferred" | Código HQ/profesiones (Gemini 10-29); prompt actual | Igual que C-01 |
| C-03 | Clases | SKILL_LIBRARY/D-022: Novice/Warrior/Thief/Spearman/Archer/Mage | Código: Commoner/Warrior/Rogue/Ranger/Cleric/Mage (+Novice) | Código más reciente (HANDOFF 23:41/00:15); confirmar con usuario |
| C-04 | Clases avanzadas | HANDOFF 23:41: Berserker/Assassin/Sniper/Templar/Sorcerer | `PROMOTION_CLASS_POOL := []` | No implementado; pendiente |
| C-05 | Estrellas/niveles | Código 5★, caps 10/20/40/60/80 | Dueño (D-022): 7★, 70 niveles | Pendiente (abierto desde 10-28) |
| C-06 | Rarezas | SUMMONS §4: Common…Legendary | Código: 1-5 estrellas | Pendiente |
| C-07 | Atributos | D-012: FUE/AGI/VIT/INT/TEM | Código: hp/atk/mag/def/spd | D-012 manda; código pendiente |
| C-08 | Versión de Godot | Docs: 4.4 / 4.4.1 / 4.6.2 / "4.x" | `project.godot`: 4.7; `main.tscn` usa `unique_id` (formato ≥4.6) | Verificar versión instalada en Windows |
| C-09 | Número de suites | README 7, Apply-DropD 8, HANDOFF 9, CURRENT_STATE 10/12, SESSION_SUMMARY 11 | `Run-Tests.ps1`: 12 | Run-Tests manda |
| C-10 | Versión de guardado | IMPLEMENTATION_STATUS v3, SESSION_SUMMARY v4 | `SAVE_VERSION := 5` | Código manda |
| C-11 | Resultado de pruebas | "ALL PASS" (Gemini, SESSION_SUMMARY) | Análisis estático: 4 suites fallan | No hay evidencia; re-ejecutar |
| C-12 | Producción HQ | SESSION_SUMMARY/CURRENT_STATE: usa profesiones | `process_headquarters_turn` ignora `profession` | Código manda (bug) |
| C-13 | Filas de formación | D-010/D-014: sin rangos | `party_screen.gd` FRONT/BACK ROW; pasivas "front row/each turn/same row" | D-010 manda; limpiar |
| C-14 | Ubicación del relicario | Docs/README: sala lejana (32,3) | Código: en `goal_cell` = salida | Docs mandan (bug) |
| C-15 | Rutas de agentes | AGENTS/CLAUDE: raíz | Archivos en `infos/` | Reubicar |
| C-16 | Estado del proyecto | infos/README, HANDOFF_PROMPT: "no hay proyecto Godot" | Proyecto existe en Git | Histórico |
| C-17 | T-001 Git | TASK_BOARD open | Repo en GitHub | Cerrar |
| C-18 | T-022/T-024 | TASK_BOARD open | `Import-Asset.ps1`, sprites de enemigos integrados | Verificar y cerrar |
| C-19 | Escuadrón de prueba | DECISIONS changelog v1.4 "slice may use three" | D-017 cinco | D-017 manda (ya marcado) |
| C-20 | Pasivas | `PASSIVES` "read in the next drop" | Ningún código las lee | No implementado |
| C-21 | Héroes de Caz | ASSET_MANIFEST "pack UNKNOWN" | README/código: Tiny Pixel Fantasy de Caz | Actualizar |
| C-22 | Flujo Git | AGENTS: commit+push cada sesión | GEMINI: pedir antes de push | Unificar |
| C-23 | DESIGN_GAPS 20 duplicado | Dos ítems "20" | — | Renumerar |
| C-24 | Contexto lite vs bundle | STATE_HASH 20c12560f902 | 24c74c6b8b84 | Generados en momentos distintos; no versionar |

## 4. Requisitos históricos que desaparecieron o nunca llegaron al código (no descartar)
- Off-screen ally indicators, Explorer/Scout reveal, attack-move, hold, follow, interact, retreat (CONTROL §3-5).
- Advertencia antes de desplegar + reglas de retirada/party wipe (D-011).
- Síntesis, sacrificio, promoción por tiers con desbloqueos (D-018, Phase 3B).
- Personalidad de 8 dimensiones, arquetipos, metas/miedos (SUMMONS §6).
- Equipo como capas que reemplazan la base; stats solo desde items (D-021).
- 4 activas + 1 definitiva, niveles 1-70 (D-022).
- Diálogo por plantillas basado en eventos (ROADMAP fase 4).
- Async multiplayer (D-006) — fuera de alcance actual pero no anulado.
