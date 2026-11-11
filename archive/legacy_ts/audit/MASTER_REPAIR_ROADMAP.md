# Roadmap maestro de reparación

Principio: estabilizar antes de ampliar; no reescribir. Cada paso cita hallazgos de `AUDIT_FINDINGS.json`. Nada está aprobado hasta que el usuario lo autorice.

## A. Errores que impiden trabajar
1. **Obtener una ejecución real** de import + 12 suites + arranque de `main.tscn` (comandos en `GODOT_TEST_REPORT.md` §5) o habilitar Godot headless en el entorno cloud. Sin esto, todo lo demás es estimación.
2. F-001 `HQWorld`: usar la API real de `SpriteComposer` (p. ej. `build_frames`/`pose_texture`) y el layout HQ.
3. F-003 Relicario en `RELIC_CELL`/celda de objetivo distinta de la extracción; usar `map.goal_cell` como extracción (F-013).
4. F-004 y F-005: corregir referencias en pruebas (`SandboxMap.ENEMY_CELLS`, `hero_id`).
5. F-007: pool de promoción no vacío o guardia `pool.is_empty()`; migración de clases antiguas.
6. Volver a ejecutar; registrar la salida en el repo (CI o `docs/STATE.md`).
**Hecho cuando:** 12/12 PASS con salida adjunta y el juego arranca.

## B. Contradicciones y documentación
1. Usuario confirma las 8 decisiones de `DESIGN_TRUTH.md` §3 → nuevas D-0xx.
2. Crear `CLAUDE.md` en la raíz y reorganizar `docs/` (ver `CLAUDE_SETUP_RECOMMENDATIONS.md`); archivar (no borrar) históricos (F-011, F-030).
3. Un solo `STATE.md` con evidencia; retirar afirmaciones no verificadas (F-006, F-037).
4. Registro único de assets y licencias, EULA de Caz guardada (F-022).
**Hecho cuando:** un agente nuevo puede empezar leyendo solo `CLAUDE.md` + 1 spec.

## C. Arquitectura
1. Interfaz común de mapa (`NavMap`) que implementen `SandboxMap` y `ProceduralMap`; quitar constantes de `SandboxMap` en código genérico (F-002, F-013).
2. Persistir pisos como snapshot (`grid_rows` + versión de generador) (F-014).
3. Versionar `HeroGenerator` (subir `VERSION`, guardar versión en `summon_log`, fixture golden) (F-008).
4. Unificar `hq_facilities`/`town_buildings` y `events`/`memories` (F-009, F-025).
5. Extraer de `Game` servicios puros manteniendo la fachada; extraer `MissionController` de `SandboxScreen`.
6. Quitar restos de filas/turnos (F-016); RNG determinista inyectado (F-027).

## D. Sistemas fundamentales incompletos
1. Atributos FUE/AGI/VIT/INT/TEM (D-012) con migración (F-017).
2. Órdenes: atacar, attack-move, mantener, seguir, interactuar, retirada + feedback de ranura muerta (F-018).
3. Misiones data-driven por tipo (recuperar, rescatar, defender, sobrevivir, explorar) (F-020).
4. Composure/Trust por eventos de misión; integrar rescate/secretos en juego (F-019).
5. Resolver 5★/7★ y conjunto de clases (F-033, C-03/04).
6. Mensajes de error correctos en invocación (F-015).

## E. Integración y validación en Godot
1. CI headless con versión fijada; runner Bash.
2. Pruebas nuevas listadas en `GODOT_TEST_REPORT.md` §4.
3. Captura de pantalla automatizada (renderer real) para validar animaciones/tiles.
4. Prueba de rendimiento con piso 160×160 (F-014).

## F. Sistemas de gameplay (tras A-E y decisiones de B)
Torre (selección de piso, progreso guardado, 10 pisos), HQ jugable con producción por profesión, síntesis/sacrificio/promoción (D-018), equipo como capas (D-021), inventario/loot/afijos/sets/crafting (solo con spec aprobada), biblioteca de skills (D-022), jefe del piso 10, eventos y secretos integrados.

## G. Mejoras visuales y contenido
Prueba de estilo D-008 por pack; reducción de assets duplicados (F-021); VFX con ruta válida (F-012); biomas (IMG-MAP); HQ isométrico/in-game (IMG-HQ); retratos derivados de Caz; audio y fuente.

## H. Pulido y optimización
Panel sin reconstrucción por frame (F-028), caché de VFX, bake de mapas por chunks, indentación uniforme (F-024), accesibilidad (no depender del color).

## Dependencias clave
`A1 → todo` · `B1 → C1, D3, F` · `C1 → D3, F(Torre)` · `C3 → cualquier cambio del generador` · `D1 → F(equipo/skills)`.
