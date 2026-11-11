# Tactical Summoners — Proyecto maestro

Visión del juego y lista de todos sus sistemas, con su estado de decisión. Las decisiones con texto completo están en `docs/DECISIONS.md`; el detalle de cada sistema, en `docs/specs/`; lo que existe de verdad, en `docs/IMPLEMENTATION_STATUS.md`.
(Consolidado de `PROJECT_BIBLE.md`, `CURRENT_STATE.md`, `SESSION_HANDOFF_PROMPT.md` y el prompt del dueño del 2026-10-30. Originales en `docs/archive/`.)

## 1. Concepto
RPG táctico de fantasía persistente, original, en **pixel art 2D**. El jugador invoca héroes generados individualmente, cuyas personalidades, historias y habilidades los hacen únicos. Forma un roster, elige un **escuadrón de 5** para misiones en los pisos de una torre y dirige a los héroes en **tiempo real sin pausa**, desde una cámara cenital de grupo. El jugador da órdenes de movimiento, objetivo, formación e interacción, y activa habilidades. Los héroes se mueven y combaten de forma autónoma. Las misiones mezclan combate, exploración, investigación, rescate, defensa y extracción. Las consecuencias pesan: relaciones, recuerdos, heridas y **muerte permanente** con memorial.
Inspiración solo a nivel de sistemas amplios (*Pick Me Up, Infinite Gacha*, juegos de gestión/expediciones y RTS clásicos), nunca de su expresión protegida (D-002).

## 2. Pilares
1. La preparación táctica importa tanto como la rareza.
2. Los héroes procedurales son variados, coherentes y persistentes.
3. Los héroes conservan identidad, relaciones, recuerdos y consecuencias.
4. Base, economía, equipo y expediciones se refuerzan entre sí.
5. La simulación funciona sin LLM ni APIs de pago.
6. Primero local; después persistencia online y sistemas sociales asíncronos.
7. Solo IP original.
8. Inspeccionar y preservar el trabajo existente antes de editar.

## 3. Bucle principal
Abrir el refugio/HQ → revisar héroes, personalidades, historias y habilidades → elegir un escuadrón de 5 para un piso de la torre → entrar en un mapa continuo en tiempo real → dar órdenes y activar habilidades mientras los héroes actúan solos → completar el objetivo y decidir si extraer o seguir más hondo → volver con recompensas, heridas, relaciones y posibles pérdidas permanentes → preservar la crónica y preparar la siguiente expedición.

## 4. Sistemas (estado de decisión → dónde está el detalle)
| Sistema | Decisión | Detalle |
|---|---|---|
| Invocación (banners, odds visibles, pity, log con semilla) | CONFIRMADA (números provisionales) | `specs/HEROES_AND_SUMMONING.md` §2-3, §10 |
| Generación de héroes (ID estable, semilla versionada, snapshot) | CONFIRMADA (D-004) | `specs/HEROES_AND_SUMMONING.md` §5 |
| Personalidad (8 dimensiones + arquetipo + 1-3 rasgos) | CONFIRMADA como spec | `specs/HEROES_AND_SUMMONING.md` §6 |
| Historia individual, metas, miedos | CONFIRMADA como spec | idem §5 |
| Trust / Obedience / Composure | CONFIRMADA (D-016) | idem §7 |
| Relaciones (vínculos/rivalidades) | CONFIRMADA (D-016) | idem §7-8 |
| Memoria de eventos | CONFIRMADA | idem §8 |
| Profesiones de vida pasada | PENDIENTE (P-05) | `specs/HQ_AND_ECONOMY.md` |
| Clases y promociones | Dirección CONFIRMADA (D-018); clases base CONFIRMADAS (D-028); avanzadas PENDIENTES (P-07) | `specs/HEROES_AND_SUMMONING.md` §14 |
| Rarezas / estrellas / niveles | 7★ y 70 niveles CONFIRMADO (D-029); nombres de rareza PENDIENTES (P-09) | — |
| Síntesis y sacrificio | CONFIRMADA (D-018); números abiertos | idem §14 |
| Muerte permanente y memorial | CONFIRMADA (D-011) | `specs/COMBAT_AND_STATS.md` |
| Legado | PENDIENTE (P-16) | — |
| Control RTS híbrido, cámara 1-5/Tab/G | CONFIRMADA (D-014, D-015) | `specs/CONTROL_AND_MISSIONS.md` |
| Combate en tiempo real y atributos FUE/AGI/VIT/INT/TEM | CONFIRMADA (D-012, números provisionales) | `specs/COMBAT_AND_STATS.md` |
| Habilidades (biblioteca 4+1) | PENDIENTE (P-10); banco de 130 ideas | `specs/SKILLS.md` |
| Misiones con objetivos variados | CONFIRMADA (D-014) | `specs/CONTROL_AND_MISSIONS.md` §9 |
| Eventos de misión | PENDIENTE (P-18) | `specs/TOWER_AND_WORLD.md` |
| Jefes con fases y mecánicas | Principio CONFIRMADO; diseño PENDIENTE (P-25) | `specs/CONTROL_AND_MISSIONS.md` §10 |
| Torre (100 pisos, 10 iniciales) | CONFIRMADA (D-027); progreso PENDIENTE (P-02b) | `specs/TOWER_AND_WORLD.md` |
| Generación procedural de pisos | CONFIRMADA (D-026) | `specs/TOWER_AND_WORLD.md` |
| Biomas | PENDIENTE (P-03) | `specs/TOWER_AND_WORLD.md` |
| Secretos | PENDIENTE (P-15) | `specs/TOWER_AND_WORLD.md` |
| Expediciones | PENDIENTE (P-17) | `specs/TOWER_AND_WORLD.md` |
| Headquarters explorable | PENDIENTE (P-04) | `specs/HQ_AND_ECONOMY.md` |
| Construcción, instalaciones, producción | PENDIENTE (P-22, P-23) | `specs/HQ_AND_ECONOMY.md` |
| Economía y recursos | PENDIENTE (P-21) | `specs/HQ_AND_ECONOMY.md` |
| Crafting | PENDIENTE (P-20) | `specs/HQ_AND_ECONOMY.md` |
| Equipo por capas, stats solo de objetos | CONFIRMADA (D-021) | `specs/ITEMS_AND_LOOT.md` |
| Inventario, loot, afijos, sets | PENDIENTE (P-19) | `specs/ITEMS_AND_LOOT.md` |
| Arte, animaciones, VFX, UI | CONFIRMADA (D-007, D-020, D-023) | `specs/ART_DIRECTION.md` |
| Guardado versionado y atómico | CONFIRMADA (D-004) | `docs/ARCHITECTURE.md` |
| Progreso offline, multijugador asíncrono, diálogo LLM | DIFERIDA | `docs/DECISIONS.md` §4 |

## 5. Reglas de generación procedural (Bible; vigentes para héroes y para los pisos de la torre, D-026)
1. Semilla y versión del generador.
2. Perfil del mundo y paleta temática.
3. Grafo de biomas/regiones, facciones y tensiones.
4. Recursos, familias de enemigos, encuentros y eventos.
5. Visuales a partir de assets modulares compatibles.
6. Validar navegación, combinaciones, dificultad y contenido faltante.
7. **Persistir el resultado generado**; nunca depender de regenerar contenido antiguo con una versión nueva del generador.

Para los héroes en pixel art: piezas de sprite curadas, variantes de paleta y capas de equipo, sin generar arte nuevo por héroe. Se persisten los IDs de las piezas y las paletas.

## 6. Reglas técnicas
- Separar datos, simulación, presentación, persistencia y UI. La simulación debe ser determinista y comprobable sin renderizar.
- GDScript tipado, IDs estables, esquemas de guardado versionados.
- Tablas de balance fuera de los scripts de UI.
- Pruebas para generación determinista, combate, economía, recompensas offline y guardado/carga.
- Commits pequeños; registrar versiones del motor y de los plugins.
- Ninguna dependencia de pago sin aprobación. Nada de importación masiva antes de la prueba de arte (D-008).
- Nunca borrar datos en silencio ante un error.

## 7. Definición de "hecho"
Funciona en el proyecto real, cumple los criterios de aceptación, los casos límite están probados, la persistencia está verificada si aplica, la documentación está actualizada y todos los assets tienen licencia compatible. **Nada se marca hecho sin ejecutarlo** (comando + salida).

## 8. Primer alcance jugable (vigente, de Bible/CTRL §11)
- Roster ≥ 6 héroes generados; se despliegan 5.
- Un mapa con un objetivo no de combate y al menos un enemigo; se puede completar sin matar a todos.
- 1–5 / Tab / G; mover, atacar objetivo, attack-move, mantener, seguir, interactuar, retirada/extracción.
- Una habilidad única por héroe; Trust/Obedience/Composure visibles.
- Muerte permanente y memorial; guardar y cargar la identidad, stats, habilidades, resultado, equipo y memorial.
- Explorador que revela un punto mientras el resto actúa solo.
