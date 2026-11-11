# Auditoría del combate (Fase 0) — 2026-10-30

Código auditado: commit `eab56c5`. Evidencia de ejecución: CI de GitHub con Godot 4.7.1, 15/15 suites PASS. Las suites `combat`, `mission`, `sandbox`, `tower` y `animation` tocan el combate, pero solo comprueban lo básico (ver §4).

## 1. Qué existe hoy (y en qué archivo)
| Pieza | Estado | Dónde | Notas |
|---|---|---|---|
| Unidades | Dos clases separadas sin base común | `scripts/sandbox/sandbox_hero.gd` (326 líneas), `sandbox_enemy.gd` (198) | `hp`, `take_damage`, destello y muerte están duplicados. La lógica de combate está mezclada con el dibujo (`_draw`) y la animación |
| Fórmulas | 3 funciones | `scripts/sandbox/combat_rules.gd` | Daño = poder − DEF/2 (mínimo 1). Poder = `max(atk, mag)`: **no distingue daño físico de mágico**. Sin armadura/resistencias diferenciadas, críticos, precisión ni penetración |
| Stats | hp/atk/mag/def/spd | `scripts/data/hero_tables.gd`, `HeroData.get_stats()` | Los atributos D-012 (FUE/AGI/VIT/INT/TEM) **no existen** (F-017) |
| Ataque básico | Instantáneo | `SandboxHero.combat_tick` | Cuerpo a cuerpo 52 px, a distancia 190 px. **Sin proyectiles ni línea de visión**: se dispara a través de los árboles |
| Habilidades | 1 por clase | `skill_tables.gd` | 4 tipos (`target`, `target_aoe`, `self_aoe`, `self_heal`). Sin coste, tiempo de lanzamiento ni interrupción. **Q dispara la habilidad de todos los héroes seleccionados a la vez** |
| Pasivas | 16, solo como datos | `HeroTables.PASSIVES` | Ninguna tiene efecto. El texto viene del diseño por turnos ("front row", "each turn") (F-016) |
| Banco de habilidades | 130 ideas | `docs/specs/SKILLS.md` | Están escritas para las clases antiguas (Thief/Spearman/Archer) |
| Estados alterados | No existen | — | Ni veneno, aturdimiento, escudos, ralentización ni sangrado |
| Órdenes | Mover, parar, habilidad | `sandbox_screen.gd` | El clic derecho sobre un enemigo **solo mueve**, no ataca. Faltan: atacar, prioridad, mantener, seguir, reagrupar, interactuar, explorar, retirada y rescate. Sin indicadores de destino ni mensajes de "orden no válida" |
| Autonomía | Mínima | `SandboxHero.combat_tick` | Busca el enemigo más cercano en 260 px. No mantiene distancia según su rol (el arquero se acerca y se queda quieto), **no esquiva los ataques telegrafiados** y no protege a nadie |
| IA enemiga | 1 máquina de estados para todos | `SandboxEnemy.tick` | IDLE → CHASE → WINDUP (círculo, 0,7 s) → RECOVER. **Todos los tipos tienen los mismos stats y el mismo comportamiento**; solo cambia el sprite |
| Rendimiento | Riesgo | `SandboxEnemy._step_toward` | **Cada enemigo calcula una ruta A\* en cada frame.** Con 14 o más enemigos en mapas de 60×56 es caro para una gráfica integrada |
| Colisiones | Parciales | `SandboxScreen._separate` | Solo separa héroes entre sí. Los enemigos se amontonan y se meten dentro de los héroes |
| Jefe | Multiplicador de stats | `SandboxEnemy.make_boss` (v5) | ×8 de vida, ×1,6 de ataque, golpe más amplio. Sin fases, patrones, invocaciones ni puntos débiles |
| Muerte | Instantánea y permanente | `take_damage` → `Game.record_death` | **No hay incapacitación, agonía ni rescate.** `SESSION_SUMMARY` decía que existía; era falso (F-037) |
| Equipo | No existe | — | El arma que lleva el sprite (`held`) es solo cosmética (D-021) |
| Presentación | Básica | `hero_anim.gd`, `combat_vfx.gd` | Golpes, lanzamientos, impactos y muertes con tweens; efectos SpritePilot. Sin números de daño, barras de lanzamiento, iconos de estado ni indicadores de alcance. **Las animaciones de ataque y de recibir daño de las criaturas voxel existen en el pack, pero no se usan** |

## 2. Problemas de arquitectura que hay que corregir antes de ampliar
1. **Falta una base común para las unidades.** Héroes y enemigos deben compartir vida, stats, estados, daño y muerte. Si no, cada mecánica nueva habrá que escribirla dos veces.
2. **La simulación está mezclada con la presentación.** `_draw`, las animaciones y la lógica viven en el mismo nodo. Además, la simulación no se puede probar por lotes (100 combates sin dibujar).
3. **No hay un camino único para el daño.** Hace falta un `DamageInfo`, con origen, tipo, cantidad, si es crítico y etiquetas, que pase por un único resolutor y emita eventos. Las pasivas, el equipo, los escudos y los estados deben enchufarse en ese camino.
4. **El rendimiento de la IA.** Hay que recalcular rutas solo cada cierto tiempo (0,3–0,5 s) o cuando el objetivo se mueve más de una casilla, y repartir el trabajo de la IA entre frames.
5. **El tamaño del escuadrón está fijo en 5.** `PARTY_SIZE = 5`, teclas 1–5 y arrays de 5. Las raids de 10 que pides exigen no fijarlo en más sitios. No hace falta implementarlas ahora.

## 3. Contradicciones encontradas
| # | Contradicción | Fuentes | Necesita decisión |
|---|---|---|---|
| C-1 | Críticos y azar | La spec de combate dice "evitar críticos y variación aleatoria en el primer prototipo"; tu prompt de combate pide probabilidad de crítico | Sí (pregunta 3) |
| C-2 | Atributos | D-012 confirma FUE/AGI/VIT/INT/TEM; el código usa hp/atk/mag/def/spd | Sí (pregunta 1) |
| C-3 | Incapacitación | D-011 dice "a 0 PV muere"; tu prompt pide agonía y rescate (P-13 estaba pendiente) | Sí (pregunta 2) |
| C-4 | Ranuras de equipo | D-021 no define ranuras; tu prompt lista 10 (arma, secundaria/escudo, casco, pechera, guantes, pantalones, botas, 2 anillos, amuleto, accesorio) | No: las registro como decisión tuya (Fase 6) |
| C-5 | Tamaño del grupo | D-017 fija 5; tu prompt añade raids de 10 como encuentros especiales | No: lo registro; la arquitectura no fijará el 5 en más sitios |
| C-6 | Teclas | La spec de control pone R = retirada y Q/W/E/R = habilidades | Sí, en la Fase 3 (no bloquea ahora) |

## 4. Qué comprueban de verdad las pruebas de combate
`smoke_combat`, `smoke_mission`, `smoke_tower` y `smoke_anim` comprueban la fórmula de daño, el ataque automático, la esquiva del telegrafiado, que la habilidad respeta su enfriamiento, la muerte, las misiones y las poses. **No comprueban:** distintos tipos de daño, estados, líneas de visión, IA por roles, rendimiento con muchas unidades ni balance (duración de combates). Faltará un **simulador de combate sin dibujado** que ejecute N combates y mida cuánto tardan en morir los enemigos y cuántos héroes caen, y que se ejecute en la CI.

## 5. Plan por fases (adaptado al código real)
| Fase | Contenido | Depende de |
|---|---|---|
| **1. Núcleo** | `Combatant` (base común de héroes y enemigos) · `CombatStats` (atributos → stats derivados) · `DamageInfo` + `CombatResolver` (físico/mágico, armadura y resistencias, crítico si lo apruebas) · estados alterados como datos (veneno, quemadura, sangrado, aturdimiento, ralentización, raíz, debilidad, escudo) · incapacitación y rescate (según tu respuesta) · rutas recalculadas por intervalos · separación entre todas las unidades · simulador sin dibujado + pruebas | Preguntas 1–3 |
| **2. Control táctico** | Órdenes como máquina de estados (mover, atacar, prioridad, atacar avanzando, mantener, seguir, reagrupar, retirada, rescatar, interactuar, parar) · clic derecho contextual · marcadores y motivo cuando una orden no es válida · distancia según el rol · esquiva autónoma de telegrafiados acotada (D-014) · línea de visión con los árboles | Fase 1 |
| **3. Habilidades y clases** | `SkillDef` como datos (coste, enfriamiento, lanzamiento, alcance, objetivos, efectos que se combinan: daño, curación, escudo, estado, carga, empuje, zona, invocación) · kit por clase (Warrior, Rogue, Ranger, Cleric, Mage, Commoner) usando el banco de 130 · interrupciones · pasivas reales | Preguntas de la Fase 3 |
| **4. IA enemiga** | Arquetipos (bruto, hostigador, arquero, lanzador, sanador, invocador, guardián, asesino) con selección de objetivo por rol · alerta, patrulla, emboscada y huida · niveles de IA según su coste · animaciones de ataque y daño de las criaturas voxel | Fases 1–3 |
| **5. Encuentros y jefes** | Formas de telegrafiado compartidas (círculo, cono, línea, anillo, zona persistente) · élite/campeón como modificadores · Jefe Orco con 2–3 fases, invocaciones y ventana de vulnerabilidad | Fase 4 |
| **6. Progresión** | Ranuras de equipo (C-4) y cadena de modificadores ya enchufada al resolutor; sin valores inventados | Diseño de loot (P-19) |
| **7. Presentación** | Números de daño y curación, iconos de estado, barra de lanzamiento, indicadores de alcance, proyectiles, críticos, escudos | Fases 1–5 |
| **8. Balance** | Simulaciones en la CI, rendimiento con más de 30 unidades, ajustes | Todo |

## 6. Lo que NO se cambia
Generación de héroes, memoria, relaciones, muerte permanente y memorial, misiones, pueblo y sprites de Caz.
