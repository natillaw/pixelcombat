# Tactical Summoners — Resumen ejecutivo de auditoría (Fase 1)

**Fecha:** 2026-10-30 · **Tipo:** auditoría estática (solo lectura; no se modificó código, docs ni assets existentes)
**Repositorio:** `natillaw/tactical-summoners` · **Rama:** `claude/tactical-summoners-audit-b3sqpo` · **Commit auditado:** `509218b` ("Actualización de código desde gamedev1") · **Árbol de trabajo:** limpio antes de crear `audit/`.

## Entorno verificado
| Elemento | Estado |
|---|---|
| Raíz del proyecto | `/home/user/tactical-summoners` (`project.godot` en la raíz) |
| Historial Git | 3 commits (2026-10-29 → 2026-10-30). 20 830 archivos versionados, `.git` = 30 MB |
| Godot configurado | `project.godot` → `config/features=PackedStringArray("4.7")`, renderer `gl_compatibility`, autoload `Game` |
| Godot disponible | **NO** en el contenedor. Intenté descargar un binario portable a la carpeta temporal (fuera del repo) y el sistema de permisos lo **denegó**. No se ejecutó ninguna prueba. |
| Herramientas | Python 3, Node; sin PowerShell; sin Godot |

## Veredicto
El proyecto es un **prototipo vertical temprano con una base útil** (generación de héroes por semilla, gacha con pity, guardado atómico versionado con migraciones, sandbox RTS en tiempo real con selección/cámara/orden de mover, combate básico, muerte permanente + memorial). Sin embargo:

1. **La documentación de estado no es fiable.** `SESSION_SUMMARY.md`, `CURRENT_STATE.md` y `HANDOFF_LOG.md` afirman "11/12 suites PASS" y "vertical slice completo", pero el análisis estático demuestra que **al menos 4 suites no pueden pasar** con el código actual (F-003, F-004, F-005) y que varias funciones anunciadas no están integradas en el juego (F-009, F-020, F-037).
2. **Hay errores de compilación/ejecución demostrables por lectura de código**: `HQWorld` llama a un método inexistente (F-001), el modo Torre pasa `ProceduralMap` a parámetros tipados `SandboxMap` (F-002), y la misión del relicario se completa al recogerlo (F-003).
3. **El diseño vigente está partido en dos**: las decisiones escritas (D-003/D-014: "mundos procedurales diferidos, mapa fijo") contradicen el código añadido por el "Mega Prompt" (Torre de 10 pisos procedurales, HQ explorable) y el prompt maestro actual (Torre de 100 pisos, biomas, crafting, loot...). Ninguna decisión nueva registra este cambio (F-032).
4. **Instrucciones de agentes con rutas rotas**: `CLAUDE.md` está en `infos/`, no en la raíz, por lo que Claude Code no lo carga; `AGENTS.md` apunta a rutas que no existen en la raíz (F-011).
5. **Assets duplicados** (~104 MB en dos copias de los mismos packs + zips) y registro de licencias incompleto, incluida la EULA de Caz (F-021, F-022).

## Cifras
| Métrica | Valor |
|---|---|
| Documentos inspeccionados | 37 (26 `.md`, 4 `.toml`, 1 `settings.json`, 2 imágenes de referencia, 4 scripts de herramientas con documentación propia) |
| Scripts GDScript auditados | 36 (24 de juego + 12 de pruebas), ~4 800 líneas |
| Contradicciones documentales detectadas | 24 (ver `DOCUMENTATION_AUDIT.md` §3) |
| Hallazgos | **37**: CRITICAL 0 · HIGH 13 · MEDIUM 15 · LOW 7 · INFO 2 |
| Pruebas ejecutadas | 0 (Godot no disponible). 12 suites analizadas estáticamente: 4 fallarían con certeza, 1 depende de comportamiento no verificable, 7 sin fallo detectado |

> No hay hallazgos CRITICAL porque ninguno pudo **ejecutarse**. F-001 (error de compilación en `hq_world.gd`) probablemente impide arrancar `main.gd` (que referencia `HQWorld`); si se confirma en Godot debe subir a CRITICAL.

## Estado por sistema (resumen; detalle en `DESIGN_TRUTH.md`)
- **Implementado (sin ejecutar aquí):** gacha+pity+banners validados, generador de héroes por semilla, Trust/Obedience/Composure como campos, ledger de eventos, guardado atómico v5 + migraciones v1→v5, memorial/muerte permanente, cámara 1-5/Tab/G, selección y orden de mover, anti-aglomeración, ataques automáticos, 1 skill activa por clase, enemigos con telegrafía, sprites compuestos de Caz, sprites de enemigos/tiles Pixel Crawler.
- **Implementado pero defectuoso:** misión del relicario (F-003), modo Torre (F-002), HQ explorable (F-001), VFX de combate (F-012), determinismo del generador (F-008), promoción de héroes sin clase (F-007).
- **Parcial / solo datos:** memorias, relaciones, secretos, rescate/cooperación (solo llamados desde tests), profesiones (no afectan producción), HQ (producción fija), edificios de pueblo (sin UI), 10 pisos (solo etiquetas), pasivas (solo texto).
- **No implementado:** atributos FUE/AGI/VIT/INT/TEM, órdenes atacar/mantener/seguir/interactuar/retirada, personalidad de 8 dimensiones, síntesis/sacrificio, equipo/inventario/loot/afijos/sets/crafting, biomas, eventos, jefes, Torre de 100 pisos, audio, biblioteca de skills (D-022).

## Riesgos principales
1. Seguir construyendo sobre afirmaciones de "PASS" no reproducidas.
2. Dos "mapas" sin interfaz común (`SandboxMap` vs `ProceduralMap`) y sistemas paralelos (`hq_facilities` vs `town_buildings`).
3. Ruptura silenciosa de reproducibilidad de héroes por semilla.
4. Requisitos del usuario (Torre 100 pisos, crafting, etc.) sin decisión escrita: los agentes seguirán obedeciendo D-003 ("mundos diferidos") o ignorándolo.
5. Redistribución de packs con licencias que prohíben subirlos como pack independiente si el repo es o se vuelve público.

## Orden recomendado (detalle en `MASTER_REPAIR_ROADMAP.md`)
A. Obtener una ejecución real de las pruebas en Windows y reparar F-001..F-005 → B. Reescribir la fuente de verdad documental (una sola, en la raíz) y registrar decisiones nuevas → C. Interfaz común de mapa, unificar HQ, versionar generador → D. Completar órdenes/atributos/misiones → E. CI headless → F/G/H. Gameplay, contenido, pulido.

## Archivos creados
`audit/AUDIT_EXECUTIVE_SUMMARY.md`, `DOCUMENTATION_AUDIT.md`, `DESIGN_TRUTH.md`, `CODE_AUDIT.md`, `GODOT_TEST_REPORT.md`, `ASSET_AUDIT.md`, `CLAUDE_SETUP_RECOMMENDATIONS.md`, `MASTER_REPAIR_ROADMAP.md`, `AUDIT_FINDINGS.json`. No se ha hecho commit ni push.
