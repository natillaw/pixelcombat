# Tactical Summoners — instrucciones para Claude Code
@AGENTS.md

## Qué es
RPG táctico en pixel art 2D sobre Godot 4.7 (según `project.godot`; versión instalada sin verificar), escrito en GDScript con la UI construida por código. Se invocan héroes únicos y persistentes, se eligen 5 y se dirigen en tiempo real, sin pausa, por los pisos de una torre.
Fase actual: **reparación** (ver `docs/DEVELOPMENT_ROADMAP.md`). Hay errores conocidos en `audit/AUDIT_FINDINGS.json`.

## Antes de cualquier tarea
1. Lee en `docs/IMPLEMENTATION_STATUS.md` solo la fila del sistema que vas a tocar.
2. Lee la spec de ese sistema (índice abajo). No cargues todos los documentos.
3. Si la tarea toca una idea PENDIENTE (P-xx en `docs/DECISIONS.md`), pregunta antes de implementar.
4. No leas `docs/archive/` ni `audit/` salvo que la tarea lo pida.

## Índice bajo demanda
| Necesito… | Archivo |
|---|---|
| Visión y lista de sistemas | `docs/MASTER_PROJECT.md` |
| Si algo está decidido | `docs/DECISIONS.md` |
| Cómo está hecho el código | `docs/ARCHITECTURE.md` |
| Qué hacer y en qué orden | `docs/DEVELOPMENT_ROADMAP.md` |
| Control, cámara, órdenes, misiones, jefes | `docs/specs/CONTROL_AND_MISSIONS.md` |
| Héroes, invocación, personalidad, social, síntesis/promoción | `docs/specs/HEROES_AND_SUMMONING.md` |
| Combate y atributos | `docs/specs/COMBAT_AND_STATS.md` |
| Habilidades (banco de 130) | `docs/specs/SKILLS.md` |
| Torre, procedural, biomas, eventos, secretos | `docs/specs/TOWER_AND_WORLD.md` |
| HQ, profesiones, construcción, economía, crafting | `docs/specs/HQ_AND_ECONOMY.md` |
| Equipo, inventario, loot, afijos, sets | `docs/specs/ITEMS_AND_LOOT.md` |
| Arte y animación | `docs/specs/ART_DIRECTION.md` |
| Assets y licencias | `docs/ASSET_REGISTRY.md` |
| Fallos conocidos | `audit/AUDIT_FINDINGS.json` (busca por ID) |

## Pruebas
- Windows: `powershell -ExecutionPolicy Bypass -File tools\Run-Tests.ps1 [-Godot "C:\ruta\Godot_console.exe"]` → `tools\last_test_run.txt`.
- Headless genérico: `godot --headless --path . --import` y luego `godot --headless --path . --script res://tests/<suite>.gd` o `godot --headless --path . res://tests/<smoke>.tscn --quit-after 3000`.
- **Sin Godot local (sesiones en la nube):** cada push a la rama ejecuta `.github/workflows/godot-ci.yml` en GitHub (todas las suites + capturas de pantalla). Lee el resultado con la skill `godot-test`.
- Nunca supongas un PASS: cita la salida o el enlace de la ejecución.

## Versiones
Cada entrega probable se registra en `docs/VERSIONS.md` (commit + ZIP descargable + qué probar). Skills del proyecto: `.claude/skills/` (`godot-test`, `hero-data-change`, `asset-import`); agentes: `.claude/agents/` (`godot-tester`, `doc-keeper`, `reviewer`).

## Al terminar
Resume qué cambiaste, qué ejecutaste (con su salida) y qué quedó sin verificar. Actualiza `docs/IMPLEMENTATION_STATUS.md` solo con evidencia. No hagas push a `main` ni merge sin permiso.
