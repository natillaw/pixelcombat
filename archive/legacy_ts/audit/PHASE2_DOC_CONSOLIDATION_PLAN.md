> **EJECUTADO el 2026-10-30** con autorización del dueño ("haz lo que te parezca mejor"). Respuestas aplicadas a §9: (1) se aceptan `AGENTS.md` en raíz y `docs/specs/`; (2) el protocolo de claims/STATE_HASH se archiva (P-28 pendiente de confirmar); (3) **nada se eliminó**: los 4 archivos generados/duplicados también se archivaron; solo se quitaron 2 `.jpg.import` generados por Godot; (4) docs nuevos en español, specs movidas intactas en inglés con una cabecera de estado. Verificación de no pérdida: `python audit/check_idea_inventory.py` → 110 ideas, 0 sin destino (`audit/IDEA_INVENTORY.md`).

# Fase 2 — Plan de consolidación documental (PROPUESTA, no ejecutada)

**Estado:** solo plan. No se ha movido, fusionado, archivado ni borrado ningún archivo. No se toca código, escenas, assets ni tests.
**Objetivo:** una única fuente de verdad que Claude y Gemini puedan leer por partes, sin perder ninguna idea, aunque todavía no esté implementada.

---

## 1. Principios
1. **Ninguna idea se pierde por no estar implementada.** Toda idea pasa al registro de decisiones con un estado.
2. **Nada histórico se presenta como vigente.** Lo sustituido queda marcado como "Sustituido por D-xxx", con su motivo.
3. **Nada sin aprobar se convierte en requisito.** Lo que nunca confirmaste queda como PENDIENTE o CANDIDATA.
4. **El estado del código solo se describe con evidencia.** Comando + salida, o "no verificado".
5. **Lectura mínima.** Siempre se carga `CLAUDE.md` (≤ 80 líneas). El resto se consulta bajo demanda según un índice.
6. **Archivar ≠ borrar.** Lo retirado va a `docs/archive/`, que se queda en Git y no se lee por defecto. Los borrados reales solo afectan a archivos generados o duplicados exactos, y cada uno lleva su justificación.

## 2. Estados de cada idea o decisión
| Estado | Significado | ¿Los agentes lo implementan? |
|---|---|---|
| **CONFIRMADA** | Aprobada por ti explícitamente | Sí, cuando el roadmap lo indique |
| **PENDIENTE** | Idea tuya o del proyecto que necesita tu decisión o detalles | No; preguntan |
| **CANDIDATA** | Propuesta de un agente o inspiración de referencia, no aprobada | No |
| **SUSTITUIDA** | Reemplazada por otra decisión | Nunca; se conserva solo como historia |
| **DIFERIDA** | Aprobada, pero fuera del alcance actual | No hasta reactivarla |

El estado de implementación (implementado / parcial / defectuoso / no implementado / no verificado) se lleva por separado en `IMPLEMENTATION_STATUS.md`. Así "decidido" y "hecho" no vuelven a mezclarse.

## 3. Estructura objetivo (la tuya, con dos ajustes)
```
CLAUDE.md                     reglas de trabajo de Claude (siempre cargado)
GEMINI.md                     reglas de trabajo de Gemini (siempre cargado por Gemini)
AGENTS.md                     ← ajuste 1: reglas comunes a ambos agentes; CLAUDE.md y GEMINI.md lo importan
README.md                     qué es el juego, cómo abrirlo y probarlo (humano)
docs/
  MASTER_PROJECT.md           visión + todos los sistemas, cada uno con estado de decisión
  DECISIONS.md                registro D-xxx: confirmadas, pendientes, candidatas, sustituidas
  IMPLEMENTATION_STATUS.md    qué existe de verdad, con evidencia y último resultado de pruebas
  ARCHITECTURE.md             módulos, flujo de datos, guardado, convenciones
  DEVELOPMENT_ROADMAP.md      orden de trabajo (A–H de la auditoría, una vez aprobado)
  ASSET_REGISTRY.md           assets, licencias, uso, regla de Caz
  specs/                      ← ajuste 2: detalle por sistema, solo bajo demanda
    CONTROL_AND_MISSIONS.md
    HEROES_AND_SUMMONING.md
    COMBAT_AND_STATS.md
    SKILLS.md                 (banco de 130 habilidades)
    TOWER_AND_WORLD.md        (nuevo: recoge ideas de torre, pisos, biomas y procedural)
    HQ_AND_ECONOMY.md         (nuevo: HQ, profesiones, producción, construcción, crafting)
    ITEMS_AND_LOOT.md         (nuevo: equipo, inventario, loot, afijos, sets)
    ART_DIRECTION.md
    REFERENCE_INSPIRATION.md  (matriz PMU + reglas de nombres)
    reference/                (las 2 imágenes de referencia)
  archive/                    historia; nunca se lee salvo petición expresa
audit/                        informes (ya hechos)
.claude/skills/, .claude/agents/   (Fase 2b, ver §8)
```
**Por qué los dos ajustes:**
- `AGENTS.md` en la raíz evita copiar las mismas reglas en `CLAUDE.md` y en `GEMINI.md`, que es lo que hoy genera divergencias. Si prefieres no tenerlo, las reglas comunes se duplican en ambos archivos.
- `docs/specs/` resuelve el problema de que, si todo va a `MASTER_PROJECT.md`, este acaba siendo otro documento de 2 000 líneas. Así `MASTER_PROJECT` queda como índice y resumen (~300 líneas), y el detalle está en cada spec.

## 4. Mapa archivo por archivo
Acciones posibles: **FUSIONAR** (el contenido pasa al destino), **MOVER** (se reubica igual), **ARCHIVAR** (a `docs/archive/`), **ELIMINAR** (solo duplicados exactos o archivos generados), **CONSERVAR**.

| Archivo actual | Acción | Destino | Qué se conserva / qué se retira |
|---|---|---|---|
| `README.md` | Reescribir | `README.md` | Instrucciones de ejecución y controles. Se retira "Drop C" y "7 suites" |
| `GEMINI.md` | Reescribir | `GEMINI.md` | Reglas GDScript aprendidas (pasan a `AGENTS.md`). Se corrigen las rutas y se retira la mención a `gen_skill_library` |
| `.gemini/settings.json` | Conservar | — | — |
| `.gemini/commands/ts/start,finish,test.toml` | Actualizar | mismas rutas | Rutas nuevas. `finish` deja de regenerar los bundles |
| `.gemini/commands/ts/skill.toml` | Archivar | `docs/archive/gemini/` | Depende de un generador inexistente |
| `.geminiignore` | Actualizar | — | Ignorar `docs/archive/`, `audit/` y `assets/` |
| `infos/CLAUDE.md` | Eliminar | → `CLAUDE.md` raíz | Contenido trivial (redirección); se reemplaza |
| `infos/.github/copilot-instructions.md` | Eliminar | — | Duplicado exacto de `infos/CLAUDE.md`, en una ruta que Copilot no lee |
| `infos/AGENTS.md` | Fusionar | `AGENTS.md` raíz | Orden de autoridad, regla "no afirmar sin ejecutar", no secretos, no-hands Godot. Se retira el protocolo de claims y STATE_HASH (pendiente de tu decisión, §9) |
| `infos/README.md` | Archivar | `docs/archive/` | Historia del starter pack |
| `infos/SESSION_HANDOFF_PROMPT.md` | Archivar | `docs/archive/` | La "regla script-first" ya está en D-009 y D-019 |
| `infos/SESSION_SUMMARY.md` | Archivar con aviso | `docs/archive/` | Se marca "NO VERIFICADO; contiene afirmaciones falsas (F-006, F-037)". Las ideas que contiene (rescate con temporizador de agonía, roles de enemigo, secretos, legado) se extraen como PENDIENTE a `DECISIONS.md` |
| `infos/CONTEXT_LITE.md`, `infos/CONTEXT_BUNDLE.md` | Eliminar | — | Generados automáticamente, desactualizados y contradictorios. Se regeneran si alguna vez hacen falta |
| `infos/docs/ai-context/DECISIONS.md` | Fusionar | `docs/DECISIONS.md` | **Todo** D-001…D-022 conservado, con estado nuevo (ver §5) |
| `…/PROJECT_BIBLE.md` | Fusionar | `docs/MASTER_PROJECT.md` | Visión, pilares, bucle, reglas técnicas, definición de "hecho" |
| `…/CURRENT_STATE.md` | Fusionar + archivar | `IMPLEMENTATION_STATUS.md` | Solo lo verificable. El original se archiva |
| `…/IMPLEMENTATION_STATUS.md` (viejo) | Fusionar + archivar | `docs/IMPLEMENTATION_STATUS.md` | Se reescribe con la evidencia de la auditoría |
| `…/ROADMAP.md` | Fusionar + archivar | `DEVELOPMENT_ROADMAP.md` | Criterios "Done when" de cada fase y prioridades "if behind schedule". Las casillas viejas se archivan |
| `…/TASK_BOARD.md` | Archivar | `docs/archive/` | Las tareas T-014…T-032 no hechas pasan como ítems del roadmap |
| `…/HANDOFF_LOG.md`, `…/CHANGELOG.md` | Archivar | `docs/archive/` | Historia. Las decisiones que solo aparecen ahí (clases, profesiones) se extraen a `DECISIONS.md` como PENDIENTE |
| `…/AGENT_SYNC.md`, `…/RULES_LITE.md` | Fusionar + archivar | `AGENTS.md` | Reglas útiles (evidencia sobre afirmaciones, tareas pequeñas) |
| `…/DESIGN_GAPS.md` | Fusionar | `DECISIONS.md` (PENDIENTES) + specs | Las 26 preguntas abiertas se conservan una a una |
| `…/CONTROL_AND_REALTIME_MISSIONS.md` | Mover | `specs/CONTROL_AND_MISSIONS.md` | Íntegro |
| `…/SUMMONS_AND_HERO_GENERATION.md` | Mover | `specs/HEROES_AND_SUMMONING.md` | Íntegro; se marca §11 como "ilustrativo" |
| `…/COMBAT_AND_STATS.md` | Mover | `specs/COMBAT_AND_STATS.md` | Íntegro |
| `…/SKILL_LIBRARY.md` | Mover | `specs/SKILLS.md` | Las 130 habilidades se conservan como **banco de ideas** (7 implementadas en el viejo sandbox, 124 spec), con un aviso de que las clases son las antiguas (PENDIENTE C-03) |
| `…/REFERENCE_SYSTEMS.md` | Mover | `specs/REFERENCE_INSPIRATION.md` | Íntegro, incluidas las reglas de nombres prohibidos |
| `…/ASSET_MANIFEST.md` + `assets/ASSET_REGISTRY.json` + `assets/CREDITS.md` | Fusionar | `docs/ASSET_REGISTRY.md` | Candidatos investigados, licencias leídas, regla de Caz. El JSON y CREDITS se conservan porque los genera `Import-Asset.ps1`; el `.md` es la vista humana |
| `docs/art/ART_DIRECTION.md` | Mover | `specs/ART_DIRECTION.md` | Íntegro |
| 2 imágenes `infos/IMAGEN…jpg` | Mover | `specs/reference/` | Nombres cortos; la imagen del HQ se marca como "referencia de terceros, no se envía" |
| `infos/tools/sync/ts_sync.py` | Archivar | `docs/archive/tools/` | Depende del protocolo de claims |
| `infos/tools/audit/Audit-GodotProject.ps1` | Archivar | `docs/archive/tools/` | Nunca ejecutado; superado por la auditoría |
| `Apply-DropD.ps1`, `tools/Update-Project.ps1`, `tools/manifest.json` | Archivar | `docs/archive/tools/` | Flujo de "drops" por ZIP, anterior a Git |
| `tools/Run-Tests.ps1`, `Import-Asset.ps1`, `prepare_crawler.py`, `contact_sheet.py`, `scan_packs.py`, `unpack_assets.py` | Conservar | `tools/` | Se documentan en `ARCHITECTURE.md` |

**Resultado:** pasamos de 26 `.md` dispersos (más 2 bundles de ~110 KB) a 4 archivos raíz + 6 centrales + 9 specs. Lectura obligatoria por tarea: `CLAUDE.md` + `AGENTS.md` (~6 KB) + 1 spec.

## 5. Registro de decisiones: clasificación propuesta
Se conservan todas. Este es el borrador de clasificación que revisarás antes de escribirlo.

### CONFIRMADAS (vigentes)
D-001 free-first · D-002 IP original · D-004 identidad persistente · D-005 local primero · D-007 pixel art 2D · D-008 sin importación masiva antes de la prueba de arte · D-009 script-first · D-011 muerte permanente · D-012 atributos FUE/AGI/VIT/INT/TEM (números provisionales) · D-013 identidad del personaje como prioridad · D-014 RTS híbrido sin pausa · D-015 cámara 1-5/Tab/G · D-016 Trust/Obedience/Composure separados · D-017 escuadrón de 5 · D-018 síntesis/sacrificio/promoción (dirección aprobada, números abiertos) · D-019 no-hands Godot · D-020 animaciones por código sin arte nuevo · D-021 equipo por capas, stats solo de los items · **Regla nueva a confirmar:** no modificar los sprites de Caz (tu prompt de auditoría, §6).

### SUSTITUIDAS (historia, nunca instrucción)
- Dirección de arte 3D/low-poly → sustituida por D-007.
- Combate por turnos y por filas → D-010 (sustituida por D-014). También se retiran los restos en el código, pero eso es Fase 3.
- "La primera vertical slice puede usar 3 héroes" → sustituida por D-017.
- Contador único de "loyalty" → sustituido por Trust/Obedience (D-016).
- "El ZIP es solo documentación, no hay proyecto Godot" → sustituido por el estado real del repo.

### PENDIENTES (ideas tuyas o ya trabajadas, sin confirmar) — se conservan todas
| Tema | Origen | Pregunta que debes responder |
|---|---|---|
| Generación procedural de pisos | Tu prompt 2026-10-30, `ProceduralMap`, imagen de mapa | ¿Sustituye a D-003/D-014 ("mapa fijo")? |
| Torre de 100 pisos, con 10 como primer alcance | Tu prompt; `TowerExpedition` | ¿Confirmado? ¿Progreso por piso? |
| Biomas | Imagen de mapa (agua, hierba, lava, magia); 8 "theme families" del Bible | ¿Qué biomas en los 10 primeros pisos? |
| HQ explorable in-game (no un menú) | Imagen del HQ; `HQWorld` | ¿Vista isométrica o top-down? |
| Profesiones de vida pasada (20) | Gemini 10-29 | ¿Afectan a la producción/crafting? ¿Cómo? |
| Clases: Commoner + Warrior/Rogue/Ranger/Cleric/Mage | Gemini 10-28/29 | ¿Sustituyen a Thief/Spearman/Archer? |
| Clases avanzadas: Berserker/Assassin/Sniper/Templar/Sorcerer | HANDOFF 23:41 | ¿Confirmadas? |
| 5★/80 niveles vs 7★/70 niveles | D-022 | Elegir |
| Nombres de rareza (Common…Legendary vs estrellas) | SUMMONS §4 | Elegir |
| Biblioteca: 4 activas + 1 definitiva, nivel 1-70, ≥ 30 por clase | D-022 | ¿Sigue vigente con las clases nuevas? |
| Memoria desbloqueada al promocionar | D-018 "MAYBE" | Sí / no |
| Sacrificio = héroe → materiales | D-018 (interpretación del agente) | Confirmar el significado |
| Ropa interior por defecto vs cuerpo desnudo | D-021 | Elegir |
| Rescate de caídos con temporizador de agonía | SESSION_SUMMARY | ¿Es idea tuya? ¿Choca con D-011? |
| Secretos y cadenas de descubrimiento | SESSION_SUMMARY, código | Alcance |
| Legado tras la muerte | Tu prompt | Definir qué es |
| Expediciones | Bible pilar 4, tu prompt | Definir: ¿misiones de torre o envíos sin control directo? |
| Eventos de misión / objetivos que cambian | REFERENCE #9, tu prompt | Alcance |
| Jefes con fases y mecánicas de arena | D-014 (confirmado como principio) | Diseño del jefe del piso 10 |
| Inventario, loot procedural, afijos, sets, crafting | Tu prompt; Bible "crafting" | Necesitan spec propia (`specs/ITEMS_AND_LOOT.md`) |
| Construcción e instalaciones; edificios del pueblo, dormitorios como capacidad | Código; REFERENCE #8 | ¿Un único modelo de edificios? |
| Personalidad de 8 dimensiones + arquetipos | SUMMONS §6 (spec aprobada, no implementada) | Ninguna; solo orden en el roadmap |
| Diálogos de personalidad (chatter) | Gemini; ROADMAP fase 4 | ¿Plantillas por evento? |
| Multijugador asíncrono | D-006 | Sigue DIFERIDO |
| Política de duplicados, renombrar o liberar héroes | SUMMONS §9 | Elegir |
| Las 26 preguntas de DESIGN_GAPS | DESIGN_GAPS | Se conservan una a una |

### CANDIDATAS (inspiración, no requisitos)
REFERENCE_SYSTEMS #6, #8, #9, #10, #11, #12, #17 (clase exclusiva de invocación, instalaciones de promoción/conversión/archivo, objetivos cambiantes, opinión del héroe en subquests, regalos, jefes inmunes hasta activar un mecanismo, moneda abstracta única). Siguen DIFERIDAS: #7, #13, #15, #16, #18.

## 6. Garantía de no pérdida (cómo se verificará)
1. **Inventario de ideas:** antes de mover nada, extraer a `audit/IDEA_INVENTORY.md` cada decisión, idea, regla y pregunta abierta de los 26 `.md`, con su origen (archivo:línea).
2. **Trazabilidad:** cada entrada del inventario apunta a su destino (`DECISIONS.md#D-xxx` o `specs/…#sección`).
3. **Comprobación final:** un script lista las entradas sin destino; la consolidación no se da por terminada hasta que salga 0.
4. **Archivo, no borrado:** todo lo retirado queda en `docs/archive/` con un `README` que explica por qué ya no es vigente.
5. **Revisión:** te presento el diff (lista de movimientos + `DECISIONS.md` nuevo) antes de hacer commit.

## 7. Borrador de `CLAUDE.md` (raíz)
```markdown
# Tactical Summoners — instrucciones para Claude
@AGENTS.md

## Qué es
RTS táctico híbrido 2D pixel art en Godot <versión verificada>. Invocas héroes únicos y persistentes,
eliges 5 y los diriges en tiempo real (sin pausa) por los pisos de una torre.

## Antes de cualquier tarea
1. Lee docs/IMPLEMENTATION_STATUS.md (solo la sección del sistema que tocas).
2. Lee la spec del sistema (índice abajo). No leas docs/archive/ ni audit/ salvo que se pida.
3. Si una idea está PENDIENTE o CANDIDATA en docs/DECISIONS.md, no la implementes: pregunta.

## Índice bajo demanda
Visión y sistemas → docs/MASTER_PROJECT.md · Decisiones → docs/DECISIONS.md
Arquitectura → docs/ARCHITECTURE.md · Orden de trabajo → docs/DEVELOPMENT_ROADMAP.md
Control/misiones → docs/specs/CONTROL_AND_MISSIONS.md · Héroes → docs/specs/HEROES_AND_SUMMONING.md
Combate → docs/specs/COMBAT_AND_STATS.md · Skills → docs/specs/SKILLS.md · Torre → docs/specs/TOWER_AND_WORLD.md
HQ/economía → docs/specs/HQ_AND_ECONOMY.md · Items → docs/specs/ITEMS_AND_LOOT.md · Arte → docs/specs/ART_DIRECTION.md
Assets/licencias → docs/ASSET_REGISTRY.md

## Pruebas
<comando Linux> / Windows: powershell -ExecutionPolicy Bypass -File tools\Run-Tests.ps1
Nunca escribas "PASS" sin pegar la salida. Si no puedes ejecutar, escribe "NO VERIFICADO".

## Git
Una rama por tarea. Commits pequeños con ID (F-0xx / T-0xx). No push a main ni merge sin permiso.
Al terminar: actualiza IMPLEMENTATION_STATUS solo con lo verificado.
```

## 8. Borrador de `AGENTS.md` (común) y de `GEMINI.md`
**`AGENTS.md`** (≤ 60 líneas):
- Reglas duras: sin pausa · 5 héroes · órdenes nunca rechazadas al azar · muerte permanente · sin re-roll · Trust/Obedience/Composure separados · sprites de Caz intactos · solo assets gratuitos registrados · IP original · script-first / no-hands.
- Orden de autoridad: `DECISIONS.md` > specs > `MASTER_PROJECT.md` > roadmap > chat. Un conflicto se reporta y no se resuelve en silencio.
- Evidencia: el código ejecutado y probado manda para "qué existe"; la spec manda para "qué debe existir".
- Convenciones GDScript (las de `GEMINI.md` actual).
- Prohibido: secretos en archivos, borrar sin permiso, push sin permiso.

**`GEMINI.md`:** `@./AGENTS.md` + rol de Gemini (revisor independiente: ejecutar pruebas, revisar PRs contra `DECISIONS.md`, no implementar en la misma rama que audita) + entorno Windows/PowerShell + comandos `/ts:*` actualizados.

**Fase 2b (después, con tu permiso):** `.claude/skills/` (`godot-test`, `hero-data-change`, `asset-import`, `gdscript-conventions`) y `.claude/agents/` (`godot-tester`, `doc-keeper`, `reviewer`), según `CLAUDE_SETUP_RECOMMENDATIONS.md`.

## 9. Decisiones que necesito de ti antes de ejecutar
1. ¿Aceptas los dos ajustes de §3 (`AGENTS.md` en la raíz y `docs/specs/`)?
2. ¿Retiramos el protocolo multiagente de claims, STATE_HASH y `ts_sync.py` (se archiva) y pasamos a ramas + PRs?
3. ¿Se pueden **eliminar** de verdad `CONTEXT_BUNDLE.md`, `CONTEXT_LITE.md`, `infos/CLAUDE.md` e `infos/.github/copilot-instructions.md` (generados o duplicados), o prefieres archivarlos también?
4. ¿Idioma de la documentación nueva: español, inglés, o specs en inglés y resúmenes en español?
5. Las respuestas a las PENDIENTES de §5 pueden darse después: en la consolidación quedarán marcadas como PENDIENTE, sin decidir nada por ti.

## 10. Fuera de alcance de la Fase 2
Código, escenas, tests, assets (incluidos los 117 MB duplicados), `project.godot`, sistemas de juego. Todo eso se queda para la Fase 3 y siguientes, según `MASTER_REPAIR_ROADMAP.md`.
