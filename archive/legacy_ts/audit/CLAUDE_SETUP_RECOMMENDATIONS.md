# Recomendaciones para trabajar con Claude Code

Objetivo: que una tarea pequeña requiera leer < 5 KB de contexto. Nada de esto se ha instalado ni configurado.

## 1. Problema actual
- Claude Code carga `CLAUDE.md` de la raíz (y `.claude/`); el único `CLAUDE.md` está en `infos/` y solo redirige a un `AGENTS.md` que tampoco está en la raíz → hoy Claude no recibe ninguna regla del proyecto automáticamente.
- El protocolo actual empuja a leer `CONTEXT_BUNDLE.md` (~100 KB) o 5-8 documentos por sesión, muchos obsoletos o contradictorios.

## 2. Estructura propuesta de `CLAUDE.md` (raíz, ≤ 80 líneas, siempre cargado)
1. Qué es el juego en 5 líneas + motor/versión verificada.
2. Reglas duras (no pausa, 5 héroes, no rechazo aleatorio de órdenes, muerte permanente, no re-roll, no tocar `assets/sprites/**` de Caz, solo assets gratuitos con licencia registrada, script-first).
3. Mapa del código (una línea por carpeta).
4. Cómo ejecutar pruebas (comando exacto) y regla "no afirmar PASS sin salida".
5. Flujo Git (rama por tarea, commit pequeño, no push sin permiso).
6. Índice de documentos bajo demanda (ruta + cuándo leerlo).
7. Convenciones GDScript (de `GEMINI.md`: espacios, tipado explícito con Variants, `class_name` únicos).

## 3. Documentación central (bajo demanda)
```
docs/
  STATE.md            ← estado verificado + último resultado de pruebas (sustituye CURRENT_STATE/IMPLEMENTATION_STATUS/SESSION_SUMMARY)
  DECISIONS.md        ← autoridad; decisiones nuevas incluidas
  ROADMAP.md          ← el MASTER_REPAIR_ROADMAP aprobado
  specs/CONTROL.md, specs/HEROES.md, specs/COMBAT.md, specs/TOWER.md, specs/HQ.md (nuevo), specs/ITEMS.md (nuevo)
  ASSETS.md           ← registro único de assets/licencias
  archive/            ← documentos históricos (handoff log, bundles, drops)
```
Cargar siempre: `CLAUDE.md`. Cargar al tocar un sistema: su spec + `STATE.md`. Nunca: `archive/`, bundles.

## 4. Skills (`.claude/skills/`)
| Skill | Propósito |
|---|---|
| `godot-test` | Ejecutar import + batería headless, resumir PASS/FAIL con líneas de error (Linux y Windows) |
| `gdscript-conventions` | Reglas de tipado/indentación y errores frecuentes de GDScript 4 |
| `hero-data-change` | Checklist para cambiar `HeroData`/generador: subir `SAVE_VERSION`/`VERSION`, migración, fixture golden |
| `asset-import` | Registrar pack (licencia, ruta, uso), prueba de estilo D-008, no tocar Caz |
| `audit-claim` | Plantilla de cierre de tarea: qué se ejecutó, salida, qué no se verificó |

## 5. Subagentes (`.claude/agents/`)
- `godot-tester` (solo Bash/Read): ejecuta pruebas y devuelve resumen corto → ahorra contexto principal.
- `doc-keeper`: actualiza `STATE.md`/`DECISIONS.md` a partir de un diff; nunca toca código.
- `reviewer`: revisa un diff contra reglas duras y specs (solo lectura).

## 6. MCPs compatibles con Godot (evaluar, no instalar aún)
- Existen servidores MCP comunitarios para Godot (lanzar editor/proyecto, ejecutar escenas, leer salida de depuración, consultar el árbol de escenas). Son de terceros: revisar código, licencia y permisos antes de usarlos. Para este proyecto basta en primera instancia con **Godot headless + skill `godot-test`**; un MCP aporta valor sobre todo para capturas de pantalla y verificación visual.
- Para verificación visual sin editor: escena de prueba que guarda `get_viewport().get_texture().get_image().save_png()` con renderer real (no headless) en Windows.

## 7. Automatización de pruebas
- Añadir un runner Bash equivalente a `Run-Tests.ps1` (`tools/run_tests.sh`) para Linux/CI.
- CI (GitHub Actions) con imagen de Godot headless fijando la versión exacta; publicar `last_test_run.txt` como artefacto. Esto elimina la dependencia de "el dueño ejecuta y pega la salida".
- Fixtures: hero golden, guardados v1-v5.

## 8. Flujo Git
- `main` protegida; una rama por tarea (`fix/F-003-relic`, etc.); PR con salida de pruebas en la descripción.
- Commits pequeños con ID de hallazgo/tarea. Prohibido declarar "PASS" sin artefacto de CI o salida pegada.
- No versionar archivos generados (`CONTEXT_BUNDLE.md`, `CONTEXT_LITE.md`).

## 9. Auditoría independiente con Gemini
- Gemini no implementa en la misma rama que audita: rol de **revisor** sobre PRs (lectura + ejecución de pruebas), usando `GEMINI.md` reducido que apunte a los mismos `docs/`.
- Ambos agentes comparten una única fuente de verdad (`docs/`) y un único formato de cierre (qué se ejecutó + salida).
- Retirar el sistema de claims/STATE_HASH si la coordinación pasa a ramas + PRs (reduce contexto y burocracia).
