# Roadmap de desarrollo

Orden de trabajo vigente (D-025: estabilizar antes de ampliar). Detalle técnico de cada paso: `audit/MASTER_REPAIR_ROADMAP.md`; hallazgos: `audit/AUDIT_FINDINGS.json`.
Nada se marca hecho sin evidencia de ejecución. Las tareas de sistemas PENDIENTES no empiezan hasta que el dueño responda la P-xx correspondiente (`docs/DECISIONS.md`).

## Fase 1 — Auditoría ✅ (2026-10-30, `audit/`)
## Fase 2 — Memoria del proyecto ✅ (2026-10-30: esta estructura de docs)
Pendiente de la Fase 2b: skills y agentes de `.claude/` (ver `audit/CLAUDE_SETUP_RECOMMENDATIONS.md`).

## Fase 3 — Reparar lo que impide trabajar (bloque A)
- [ ] Ejecución real: import + 12 suites + arranque de `main.tscn` (o Godot headless en la nube / CI).
- [ ] F-001 `HQWorld` compila.
- [ ] F-003 relicario fuera de la extracción (+ F-013).
- [ ] F-004 / F-005 referencias de pruebas.
- [ ] F-007 promoción de `class.none`.
- [ ] Registrar la salida en `IMPLEMENTATION_STATUS.md`.
**Hecho cuando:** 12/12 PASS con salida y el juego arranca.

## Fase 4 — Arquitectura (bloque C)
Interfaz común de mapa (F-002) · pisos como snapshot (F-014) · versionado del generador + fixture (F-008) · un modelo de edificios y un registro de historia (F-009, F-025) · separar servicios de `Game` y `MissionController` · quitar restos de filas/turnos (F-016) · RNG inyectado (F-027).

## Fase 5 — Fundamentos incompletos (bloque D)
Atributos D-012 (F-017) · órdenes completas + feedback (F-018) · misiones por tipo (F-020) · Composure/Trust por eventos, rescate/secretos en juego (F-019) · mensajes de invocación (F-015) · aviso del escuadrón de prueba (F-034).
Migración a 7★ / 70 niveles (D-029) y ajuste a las clases de D-028. Requiere respuesta: P-09 (nombres de rareza).

## Fase 6 — Validación en Godot (bloque E)
CI headless · pruebas nuevas (`audit/GODOT_TEST_REPORT.md` §4) · capturas automáticas · prueba de rendimiento con mapas grandes.

## Fase 7 — Gameplay (bloque F), según se confirmen las PENDIENTES
| Bloque | Depende de |
|---|---|
| Torre: selección de piso, progreso, pisos 1-10, jefe del piso 10 | D-026, D-027; P-02b, P-25 |
| Biomas y eventos de misión | P-03, P-18 |
| HQ explorable, construcción, producción por profesión | P-04, P-05, P-22, P-23 |
| Síntesis / sacrificio / promoción por tiers (antiguas T-014…T-020) | D-018, G-21…G-26, P-11, P-12 |
| Equipo por capas (antigua T-030), inventario, loot, afijos, sets | D-021, P-14, P-19 |
| Crafting y economía | P-20, P-21 |
| Biblioteca de habilidades 4+1 (antigua T-031) | P-10 (adaptada a las clases de D-028) |
| Personalidad de 8 dimensiones, diálogo por eventos, relaciones con consecuencias | Spec confirmada; P-24 |
| Secretos, legado, expediciones | P-15, P-16, P-17 |

## Fase 8 — Visual y contenido (bloque G)
Prueba de estilo D-008 por pack · deduplicar assets (F-021) · VFX (F-012; antiguas T-027/T-032) · arte de UI e iconos (T-026) · retratos derivados de Caz · audio (T-028) · fuente pixel (T-029) · enemigos con roles cuerpo a cuerpo / a distancia / soporte (spec de combate).

## Fase 9 — Pulido (bloque H)
Rendimiento del HUD (F-028), cachés, bakes por chunks, indentación (F-024), accesibilidad (no depender solo del color).

## Prioridades si hay retraso (heredadas del roadmap anterior)
1. Control RTS híbrido determinista, navegación y objetivos correctos.
2. Identidad persistente de los héroes (personalidad, historia, habilidades).
3. Muerte permanente, memorial e integridad del guardado.
4. Bucle de misión corto completo.
5. Claridad visual y feedback.
6. Contenido y sistemas adicionales.
