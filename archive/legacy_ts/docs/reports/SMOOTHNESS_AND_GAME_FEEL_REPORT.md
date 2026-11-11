# Informe — Smoothness, game feel, escala y presentación del combate

Fecha: 2026-10-30 · Godot usado: **4.6.2.stable** (el proyecto declara 4.7; no hay 4.7 instalado) · El directorio **no es un repositorio Git**: no hay commit ni ZIP. Copia de seguridad de `scripts/`, `tests/` y `docs/` previa a los cambios en el scratchpad de la sesión.

## 1. Estado inicial

Antes de tocar nada: **21/21 suites PASS** (`tools/Run-Tests.ps1`). El juego funcionaba, pero se sentía rígido y engañoso en estos puntos (medidos o leídos en el código, no supuestos):

| Área | Estado inicial |
|---|---|
| Movimiento de héroe | Velocidad constante y parada instantánea. En cada waypoint se perdía el sobrante del paso, lo que daba micro-tirones. El facing de 4 direcciones cambiaba en cuanto \|dx\| ≷ \|dy\|, así que en diagonal los frames lado/frente alternaban. Cada vez que se acababa el path se colaba un frame de idle entre un repath y el siguiente (parpadeo idle/walk). La velocidad de la animación de caminar no dependía de la velocidad real. |
| Pathfinding | A* sobre celdas de 48 px en 8 direcciones, sin suavizado: rutas en escalera ("zigzag"). |
| Enemigos | **Todos los tipos con las mismas stats, alcance, radio y peso**. Un gólem (3,5× la altura del héroe) tenía la hitbox, el golpe de 44 px y la separación de una rata (0,5×). Se movían a velocidad constante y con giro instantáneo. |
| Escala de VFX de área | `tools/measure_scale.gd`: el semiancho visual de los efectos de área era **10–48 px para radios de daño de 75–140 px**. La explosión cubría un 20–40 % del área real. La única pista honesta era un arco de 0,35 s. |
| Orden de render | `_world` **sin y-sort**: los enemigos siempre se dibujaban encima de los héroes (por orden de creación) y todos los VFX en z 20, incluidos los golpes "de suelo". Las zonas persistentes (`CombatZone`, z −1) quedaban **por debajo del suelo** (mapa en z 0). |
| Cámara | `lerp(k = delta·6)` dependiente del framerate. Zoom de grupo recalculado cada frame (el zoom "respiraba" al caminar). Sin límites de mapa (se veía el vacío gris). Sin shake. |
| Timing ataque ↔ daño | El daño del ataque básico se aplicaba en el mismo frame en que **empezaba** la animación: no había anticipación. |
| Feedback | Sin hit stop, sin shake, sin sombras. El knockback era un teletransporte de 8 px por paso. El número era blanco para todos los bandos y salía "0" cuando el escudo absorbía el golpe entero. |
| Muerte de héroe | Un cadáver de 1,5 s, idéntico al de un enemigo. |
| Simulación | Ticks de física a 60 Hz sin interpolación: en monitores de más de 60 Hz las unidades se mueven a saltos. |

## 2. Problemas detectados (priorizados)

1. VFX de área mucho más pequeños que su hitbox (mentía sobre el área de efecto).
2. Ausencia de clases de tamaño: gólem = rata en hitbox, alcance, peso y knockback.
3. Sin y-sort y zonas ocultas bajo el suelo.
4. Movimiento robótico: zigzag, tirones en waypoints, facing parpadeante, parpadeo idle/walk.
5. Daño del ataque básico sin anticipación.
6. Cámara dependiente del framerate, zoom que respira, sin límites.
7. Impacto sin feedback diferenciado (crítico, bloqueo, golpe pesado, jefe).
8. Muerte permanente sin tratamiento especial.
9. Sin herramientas de debug visual.

## 3. Cambios realizados (archivo por archivo)

| Archivo | Cambio |
|---|---|
| `scripts/sandbox/combat_rules.gd` | Tabla `SIZE` (small/standard/large/huge: cuerpo, masa, alcance, wind-up, aceleración, giro), `CREATURE_SIZE`, `size_class_of()`, `HERO_BODY`, `BOSS_MASS_MULT`. Son datos, no UI (AGENTS.md). |
| `scripts/combat/combat_feel.gd` (nuevo) | `CombatFeel`: shake por categoría, *impact freeze* local de sprites, deslizamiento de knockback y `AreaFlash` (elipse en el suelo con el radio real). |
| `scripts/combat/feel_camera.gd` (nuevo) | `FeelCamera`: suavizado exponencial independiente del framerate (posición 9/s, zoom 4/s, más lento para no marear), límites de mapa y shake direccional por `offset` (no mueve la posición real de la cámara). |
| `scripts/combat/combat_debug_draw.gd` (nuevo) | Overlay F3, solo en builds de debug. |
| `scripts/core/nav_map.gd` | `smooth_path()`: elimina los waypoints que se pueden saltar con una línea libre de 24 px de ancho (cuerpo + margen). Afecta a misiones y al pueblo. |
| `scripts/sandbox/sandbox_hero.gd` | `_walk()`: aceleración a velocidad máxima en 0,07 s, el sobrante del paso se arrastra al siguiente waypoint, llegada suavizada en los últimos 10 px, gracia de 0,12 s antes del idle y velocidad de la animación de caminar ligada a la velocidad real. Facing con histéresis (×1,3). Pre-roll del ataque (0,12 s). Crítico → freeze + shake pequeño. Knockback dividido por la masa del objetivo + deslizamiento. Dash con deslizamiento. Skills de área: `area_burst` + `AreaFlash` del radio real + shake según el peso de la skill. Caído → shake medio. Muerte → shake grande + nombre + cadáver más largo. Sombra de contacto. |
| `scripts/sandbox/sandbox_enemy.gd` | `apply_size()` al crear el tipo; `make_boss()` marca `is_boss`, multiplica la masa ×2,5 y el cuerpo ×1,5. Aceleración y giro limitados según el tamaño. Velocidad de la animación de correr ligada a la velocidad real. Los golpes ligeros solo hacen flash en las criaturas pesadas (`STAGGER_PCT`). Golpe de jefe → shake medio + freeze; criatura pesada → shake pequeño. Muerte pesada → polvo + shake. Sombra, barra de vida sobre la cabeza real, telegrafía con disco interior que se llena hasta el impacto. `pick_distance()`: el clic sigue al cuerpo. |
| `scripts/sandbox/sandbox_screen.gd` | `_world.y_sort_enabled`. Capas: suelo −10 < zonas −5 < efectos de suelo −4 < unidades 0 < efectos aéreos 20 < textos 50. `FeelCamera` avanzando en el tick de física con look-ahead (0,18 s de velocidad, máx. 28 px) al seguir a un héroe. Histéresis del 6 % en el zoom de grupo. Separación de enemigos por suma de cuerpos y reparto por masa. Clic de ataque sobre la cápsula del cuerpo. **Interpolación de física activada solo mientras la misión está abierta** (`SceneTree.physics_interpolation`) y restaurada al salir. F3 = overlay de debug. |
| `scripts/sandbox/combat_vfx.gd` | `GROUND_FX` en z −4 (bajo las unidades). `area_scale()` (tope ×1,6 para no "bloquear" el pixel art). `area_burst()`: una copia en el centro + un anillo de hasta 6 copias a 0,62 r con un escalonado de 25 ms. Sprites de VFX sin interpolación de física (se animan en idle). |
| `scripts/sandbox/hero_anim.gd` | Fases anticipación (0,10 s o 0,03 s) → ejecución (0,05 s) → recuperación (0,16 s) con easing. Muerte: se apaga el color, aparece "X has fallen" y el cadáver se mantiene 2,4 s y se desvanece en 1,4 s. |
| `scripts/sandbox/enemy_sprites.gd` | `art_height()` (alto opaco medido y cacheado). Cadáver sin interpolación. |
| `scripts/combat/combatant.gd` | Colores del número: crítico dorado, daño a héroes rojo-anaranjado, a enemigos blanco, "block" azul si el escudo lo absorbe todo. |
| `scripts/combat/floating_text.gd` | *Pop* de escala (×1,5 en críticos, ×1,15 en el resto), subida rápida y luego lenta, deriva lateral y duración opcional. |
| `tools/measure_scale.gd` (nuevo) | Auditoría de escala headless (héroe, criaturas, VFX de área frente al radio). |
| `tests/capture_feel.tscn/.gd` (nuevo) | Capturas: fila de escala + 5 skills de área al impactar. |
| `tests/bench_feel.tscn/.gd` (nuevo) | Coste del tick con 5 héroes contra 40+ criaturas. |
| `tests/smoke_sandbox.gd` | La comprobación "path > 2 waypoints" pasa a ser "**ningún waypoint ni tramo atraviesa un muro**", que es lo que quería decir; con el suavizado, una ruta recta válida tiene menos waypoints. |

## 4. Sistema de escala

La unidad de referencia es el héroe: 31 px opacos de alto y cuerpo de 11 px. Cada criatura se clasifica por su **alto opaco medido** (`tools/measure_scale.gd`), no por el tamaño del frame:

| Clase | Rango de alto vs. héroe | Ejemplos medidos | Cuerpo | Masa | Alcance | Wind-up | Acel. | Giro |
|---|---|---|---|---|---|---|---|---|
| small | < 0,8 | rata 0,52, slime 0,65, murciélago 0,65 | 9 | 0,7 | ×0,85 | ×0,85 | 0,05 s | 30 rad/s |
| standard | 0,8–1,5 | orcos/esqueletos PC ≈1,0, setas 1,03, araña 1,16, goblin 1,35 | 12 | 1 | ×1 | ×1 | 0,10 s | 16 |
| large | 1,5–2,5 | orc_brute 1,81, orc_chieftain 1,81 | 17 | 2 | ×1,2 | ×1,15 | 0,22 s | 8 |
| huge | > 2,5 | gólem 3,48 | 28 | 4 | ×1,5 | ×1,3 | 0,35 s | 5 |
| jefe | clase + ×1,5 de sprite | Orc Chieftain (≈2,7) | ×1,5 | ×2,5 | (make_boss) | — | — | — |

Cada entidad separa sprite/escala visual, cuerpo (separación, hurtbox de debug, sombra), alcance del golpe, radio del golpe, telegrafía (que es exactamente el radio real), barra de vida a la altura real y área de clic. El jefe no se hace "gigante": hereda su clase y solo crece ×1,5. Los raid bosses no existen todavía.

## 5. Movimiento

- **Respuesta:** el héroe llega a su velocidad máxima en 0,07 s (≈4 ticks), con lo que el retraso apenas se nota. El coste real en tiempo de viaje es de ~0,035 s por orden.
- **Sin tirones:** el sobrante del paso pasa al siguiente waypoint.
- **Sin zigzag:** `smooth_path()` deja tramos rectos y solo gira en esquinas reales, con 12 px de holgura a cada lado.
- **Sin parpadeos:** histéresis del facing y gracia de idle de 0,12 s.
- **Enemigos con peso:** el gólem gira a 5 rad/s y tarda 0,35 s en alcanzar su velocidad; la rata acelera en 0,05 s y gira a 30 rad/s. La **velocidad máxima no cambia**. Si el giro limitado llevara a la criatura contra un muro, se fuerza la dirección deseada.

## 6. Animaciones

- Ataque básico en fases (anticipación → ejecución → recuperación) con easing. Con pre-roll, el golpe hacia delante coincide con el tick del daño.
- Velocidad del ciclo de caminar/correr ligada a la velocidad real (sin *moonwalk* al acelerar o al ir ralentizado).
- Las criaturas pesadas no interrumpen su animación por golpes pequeños.
- Muerte de héroe con tratamiento propio (ver §7).
- No se modificó ningún sprite (D-023); todo es tween, timing y modulate.

## 7. Combate y feedback

| Evento | Feedback |
|---|---|
| Golpe básico ligero | Flash + número; **sin** freeze ni shake |
| Crítico | Número dorado grande con pop, VFX "crit", freeze de 50 ms en atacante y objetivo, shake pequeño en la dirección del golpe |
| Golpe absorbido por el escudo | "block" en azul (antes "0") |
| Daño a un héroe | Número rojo-anaranjado (se distingue del daño infligido) |
| Curación | Verde con "+" (sin cambios) |
| Golpe de criatura pesada | Shake pequeño |
| Golpe de jefe | Shake medio + freeze de 90 ms del jefe |
| Knockback | Distancia ÷ masa (gólem: 70 → 17 px; jefe grande: 70 → 14 px) + deslizamiento de 0,16 s; masa ≥ 3 → "stagger" |
| Héroe caído | Shake medio |
| Muerte permanente | Shake grande, el color se apaga, "*Nombre* has fallen", cadáver 2,4 s + 1,4 s de fundido. El memorial lo sigue escribiendo `SandboxScreen._on_hero_died` (sin cambios) |
| Muerte de criatura pesada | Polvo a escala del cuerpo + shake |

**Hit stop y D-014.** D-014 prohíbe pausar o ralentizar la simulación. Por eso el "hit stop" implementado es **local y solo visual**: `CombatFeel.freeze` detiene el frame y el tween de pose de los sprites implicados durante 50–90 ms, mientras la simulación, los cooldowns y las demás unidades siguen. **Pregunta para el dueño:** ¿encaja esto en D-014? Si no, basta con vaciar `CombatFeel.FREEZE`.

## 8. Skills

- **Tamaño:** antes, un efecto de área cubría el 20–40 % del radio. Ahora `area_burst()` pone una copia central (×0,7–×1,6) y un anillo de copias a 0,62 r. Ejemplos medidos: earthshatter, radio 120: semiancho central de 51 px más 3 copias a 74 px, que llegan a ~110 px; chain_burn, radio 140: 4 copias.
- **Hitbox legible:** `AreaFlash` dibuja en el suelo **exactamente el radio de daño** durante 0,45 s, con el anillo llegando al borde en 80 ms. El arte es decoración alrededor; el anillo es la verdad.
- **Capas:** los slams, ondas, polvo y círculos van bajo las unidades; los tajos y chispas, encima.
- **Timing:** los efectos de impacto ya esperaban la llegada del proyectil; el flash y el shake de área ahora también. **Diferencia que queda:** el daño de skills y de proyectiles básicos se aplica al disparar, antes de que el proyectil llegue (hasta ~0,3 s). Cambiarlo altera el gameplay (DPS, objetivos que mueren en vuelo), así que lo dejo como pregunta (§12).
- **Peso por skill:** shake pequeño si radio ≥ 90 o casteo ≥ 0,8 s; medio si radio ≥ 110 y casteo ≥ 1 s. Las skills personales y de objetivo único no hacen shake.

## 9. Cámara

- Suavizado exponencial (independiente del framerate) en el tick de física e interpolado igual que el mundo.
- Zoom más lento que la posición; histéresis del 6 % en la vista de grupo.
- Look-ahead moderado al seguir a un héroe (1–5).
- Límites del mapa: no se ve el vacío; si el mapa es más pequeño que la vista (overview M), se centra.
- Shake con intensidad, duración, dirección y curva cuadrática; no se acumula. `CombatFeel.shake_scale` sirve de multiplicador de accesibilidad (0 = sin shake) y queda pendiente de exponerse en Opciones. El clic tiene en cuenta el `offset` del shake.

## 10. Rendimiento (resultados reales)

`tests/bench_feel.tscn`, headless, en la máquina de desarrollo (no en el Ryzen 5 5600GT): 5 héroes contra 40 criaturas añadidas en el piso 8, skills cada segundo, 1200 ticks.

| | Media `tick()` | Peor `tick()` | Nodos |
|---|---|---|---|
| Antes (scripts originales) | 0,656 ms | 3,345 ms | 420 |
| Después | 0,866 ms | 3,508 ms | 438 |

Las dos ejecuciones no son idénticas: el mapa procedural es aleatorio en cada `new_game()` y terminaron con 26 y 43 enemigos vivos, respectivamente. Ambas quedan muy por debajo de los 16,6 ms de un frame. **No se midió el render** (FPS con GPU integrada); headless no dibuja. Pooling de VFX: no hace falta por ahora (≤ 7 sprites extra por skill de área).

## 11. Pruebas

| Qué | Comando | Resultado |
|---|---|---|
| Baseline antes de cambiar | `tools/Run-Tests.ps1` | 21/21 PASS |
| Tras los cambios (1.ª ejecución) | ídem | 20/21: `sandbox` falló en "path > 2 waypoints" (el suavizado dejó 2 waypoints válidos). Test corregido para comprobar tramos sin muros |
| Final | ídem | **21/21 PASS** (`tools/last_test_run.txt`). Suites `sandbox`, `orders`, `tower` y `boot` repetidas tras añadir los límites de cámara: PASS |
| Escala | `godot --headless --path . --script res://tools/measure_scale.gd` | Tabla de §4 |
| Capturas antes/después | `godot --path . --resolution 1280x720 res://tests/capture_feel.tscn` | Revisadas a mano: sombras, barras sobre la cabeza, anillo del radio real y copias de área (earthshatter, frost_nova) visibles; sin vacío gris tras los límites |
| Rendimiento | `godot --headless --path . res://tests/bench_feel.tscn` | §10 |

**No verificado** (necesita jugar a mano con ventana):
- Que la interpolación de física se vea fluida en un monitor de más de 60 Hz, y que los nodos animados en idle (sprites, VFX, textos) no tiemblen con ella activa. Godot avisaba de que la Camera2D pasaba a modo física; lo resolví forzando ese modo. Para revertir: quitar `get_tree().physics_interpolation = true` en `SandboxScreen._ready`.
- Las sensaciones subjetivas (peso del gólem, intensidad del shake, freeze) y el overlay F3 en una partida real.
- Que las zonas (`CombatZone`) se vean ahora en partida. El fallo de capas se dedujo del código y no se capturó antes/después.

## 12. Problemas pendientes y preguntas al dueño

1. **D-014 y el freeze local** (§7): ¿aceptable? Recomendación: sí, porque no toca el tiempo de juego.
2. **Daño al impactar el proyectil:** hoy el daño llega al disparar. Opciones: (a) dejarlo así; (b) aplicarlo al impactar, solo en proyectiles. Recomiendo (b), pero cambia el gameplay y los tests de combate: necesita decisión.
3. **Cambios con efecto en el gameplay** (deliberados, en datos y reversibles): alcance, radio y wind-up según el tamaño de la criatura; knockback ÷ masa; separación por cuerpo; paths suavizados (más cortos); aceleración del héroe (~0,035 s por orden). Las stats de daño y vida **no** se tocaron. Los enemigos siguen compartiendo stats por tipo (Fase 8, "enemigos con roles").
4. **Pixel art:** con el zoom fraccionario (0,75–2,5) y filtro nearest puede haber shimmer. No activé `snap_2d_transforms_to_pixel` ni el zoom entero sin probarlo a mano. Propuesta: probar zooms enteros (1, 2, 3) en la vista de héroe.
5. Sin audio (T-028): el feedback es solo visual.
6. `shake_scale` no está en una pantalla de opciones.
7. Los raid bosses y los mini-jefes no existen; la tabla admite añadir clases.
8. El ataque básico sigue igual para todas las armas (la misma duración de fases): no hay diferencias de timing por arma.
9. `docs/VERSIONS.md` no se actualizó: no hay repositorio Git, así que no hay commit ni ZIP que registrar.
