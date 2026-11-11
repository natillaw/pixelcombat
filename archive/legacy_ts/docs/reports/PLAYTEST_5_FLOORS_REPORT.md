# Prueba de juego automática: pueblo + pisos 1-5 (2026-10-31)

Rama: `ccr-cb2bbfa2-cg889y` (contenido de `feat/ui-and-art-unification`). Godot 4.7.2 Linux headless.

## Cómo se probó
- `tools/run_tests.sh` (con los finales de línea corregidos en una copia): **24/24 PASS**.
- `tests/playthrough_bot.tscn`: un "jugador" automático. Hace lo siguiente:
  - crea una cuenta nueva, recibe las 10 invocaciones iniciales y construye el pueblo;
  - asigna trabajos, equipa el botín, elige habilidades y lee los libros;
  - juega los pisos 1-5 con órdenes de jugador: attack-move, W/E/R, rescatar, recoger, llevar la reliquia y escapar con X;
  - no usa trucos de daño. Si falla un piso, repite el anterior para subir de nivel.
  - Variables: `PT_FROM` (piso inicial), `PT_ATTEMPTS`, `PT_TRACE`.
  - Ventaja que el bot tiene sobre un jugador: conoce la posición de los objetivos a través de la niebla. Por eso los tiempos medidos son un **mínimo**.
- Muestra: 17 cuentas nuevas y 93 intentos de piso. Resultado: 81 éxitos, 7 bloqueos (piso 4) y 1 escape. Aparte hay 11 intentos del piso 5 con héroes de nivel 1, de los que 9 terminaron en escape.
- Diagnósticos de apoyo:

  | Archivo | Qué comprueba |
  |---|---|
  | `tests/diag_pockets` | Celdas libres sin ruta en los mapas |
  | `tests/diag_trap` | Que un empujón atrapa a un héroe |
  | `tests/diag_reach` | Qué se puede alcanzar desde la entrada |
  | `tests/diag_clues` | Dónde aparecen las pistas de exploración |
  | `tests/diag_exploit` | Bucle de invocar y sacrificar |
  | `tests/diag_perf` | Coste del minimapa, de la lógica y de la niebla |

## Errores
| # | Gravedad | Qué pasa | Evidencia | Causa / arreglo propuesto |
|---|---|---|---|---|
| B1 | **Crítica** | La escuadra (o un enemigo) queda atrapada y un piso de "combate" no se puede terminar: solo queda escapar. | 2 de 17 cuentas: el piso 4 queda en TIMEOUT con 5-6 enemigos vivos en los 3 intentos ("squad stuck near (82, 63)"). `diag_pockets`: los 30 mapas generados (6 cuentas × 5 pisos) tienen entre 8 y 25 celdas libres a las que A* no llega, y muchas tocan el mapa solo en diagonal. `diag_trap`: un empujón de 12 px mete a un héroe en una de esas celdas y luego `find_path` devuelve vacío. | `_nudge`, `_nudge_any` y `_push` solo comprueban el punto de destino, y A* usa `DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES`, así que se entra cruzando una esquina pero no se puede salir. Arreglo: (a) al generar el mapa, rellenar con árboles las celdas que no se alcanzan desde la entrada; (b) en los empujones, no permitir pasar una esquina en diagonal. |
| B2 | Alta | `tools/run_tests.sh` tiene finales CRLF y en Linux/CI no arranca (`set: -: invalid option`). | Primera ejecución aquí. Hay 22 archivos con CRLF (20 `.gd`, el `.sh` y el `.ps1`). | Añadir `.gitattributes` (`*.sh text eol=lf`) y normalizar. Además, el CI solo se activa en `main` y `claude/**`: `feat/ui-and-art-unification` y esta rama nunca pasaron por el CI. |
| B3 | Media | El minimapa recorre todas las celdas del mapa en cada fotograma. | `diag_perf`: 6,6 ms por fotograma en el piso 5, alrededor del 40 % del presupuesto a 60 FPS, antes de dibujar nada. La lógica de juego cuesta 0,85 ms por tick y la niebla 1,7 ms. | Dibujar el mapa una vez en una textura y redibujar solo cuando cambie la niebla. Importa para el iGPU Ryzen. |
| B4 | Baja | `ERROR: Lambda capture at index 0 was freed` en la consola. | Aparece al salir de la misión con golpes en vuelo. Los temporizadores de `sandbox_hero.gd` (`_area_flash_later`, `_feel_later`, `_fx_later`), `CombatVFX._later` y `CombatFeel.freeze` capturan nodos que ya se liberaron. | No rompe nada, pero ensucia el registro. Conectar con un `Callable` del propio nodo (que se desconecta solo) o usar `weakref`. |
| B5 | Sin confirmar | En una cuenta nueva que entró directamente al piso 5, la escuadra no se movió en 30 min (0 bajas). | Visto 1 vez en unos 15 intentos y no reproducido. | Puede ser B1 en la zona de salida. |

## Balance y diseño
| # | Observación | Datos |
|---|---|---|
| D1 | Los pisos duran mucho menos de lo previsto en D-056 (10-30 min). | Ruta directa del bot: P1 ≈ 2-2,5 min, P2 ≈ 1-1,5, P3 ≈ 2, P4 ≈ 2,5-3, P5 ≈ 1-1,5. Un jugador que explore a ciegas tardará más, pero difícilmente 10 min. |
| D2 | Los pisos 1-4 son demasiado fáciles; el 5 es el único muro. | 0 muertes en más de 70 pisos 1-4 superados, con la vida mínima casi siempre por encima del 70 %. El piso 5 con héroes de nivel 8-9 se pasó en todas las cuentas. Con nivel 1 hubo 9 escapes en 11 intentos. |
| D3 | El jefe del piso 5 se puede ir a buscar directamente, sin hacer nada más. | Victorias con 4-12 de 28 enemigos muertos, en 1-1,5 min. El jefe no tiene fases ni habilidades, solo más vida y daño. |
| D4 | La misión de exploración se resuelve en un solo viaje. | `diag_clues`: las 3 pistas quedan a menos de 260 px del objetivo, porque se eligen de las últimas celdas de la lista. |
| D5 | Las gemas no limitan nada y permiten un bucle de invocar y sacrificar. | 2000 gemas iniciales y 10 por invocación dan 200 invocaciones. Con una sola cama libre, 150 invocaciones dieron 5 héroes de 5★ y 14 de 4★, y los sacrificios llenaron los materiales hasta el tope del almacén. Esto anula las "probabilidades iniciales" y la economía. |
| D6 | Los materiales son el cuello de botella y la ascensión llega tarde. | Primera ascensión: Salón 2 (120) + Santuario (90) + coste (30) = 240 materiales. Los héroes llegan al nivel 9-10 de 10 hacia el piso 5. En 8 días de juego el bot solo llegó al Salón 2 y nunca pudo ascender. El taller (1 puesto, unos 25 materiales al día) es casi la única fuente aparte de las recompensas de piso (30-70). |
| D7 | Los recursos recogidos casi no tienen uso. | Madera, piedra, mineral, pieles, colmillos y gel se acumulan. Solo sirven si existe el taller o el santuario. |
| D8 | Los arqueros dominan y los guerreros aportan poco. | Alcance de los héroes a distancia: 190; golpe a distancia enemigo: 150. Squads de 3-4 exploradores/arqueros barren los pisos. Los guerreros hacen poco daño y "not enough fury" aparece 50-130 veces por piso. |
| D9 | Escapar con X mata a los caídos que no están junto a la salida. | En el piso 5 con nivel 1, cada escape costó 3-4 muertes permanentes. Es coherente con D-036, pero muy duro: ¿no debería poder cargarse a un herido? (pregunta de diseño) |
| D10 | El almacén (150 por recurso) se llena pronto. | Para el día 5 las comidas están al tope y la cocina se para: hace falta el almacén muy temprano. |
| D11 | Los "experts" de `TownTables` usan los ids antiguos `occupation.*`, distintos de los ids de profesión (`lumberjack`…). | `best_workplaces("lumberjack")` devuelve vacío. Solo la ficha del héroe, que usa `h.profession`, lo aprovecha bien. |
| D12 | `Tiny Pixel Fantasy - Base Pack.zip` en la raíz duplica `assets/pixel/caz-base/`. | Ocupa 700 KB. Moverlo fuera del repo o a una carpeta de fuentes. |

## Sin verificar
- La imagen, el sonido y la música (headless).
- Clics reales en la UI de construcción, del inventario y de la ficha (solo las suites `ui full` y `boot`).
- FPS en el PC del dueño.
- Cuánto tarda un jugador humano explorando con niebla.

## Arreglos (2026-10-31, misma rama)
| # | Arreglo | Commit | Verificación |
|---|---|---|---|
| B2 | `.gitattributes` (LF en el repo) y archivos normalizados. El CI se activa en todas las ramas (salvo `ci-screenshots`) y usa Godot 4.7.2. | `95b5de3` | CI de esta rama: **25/25 PASS** ([ejecución 41224031814](https://github.com/natillaw/tactical-summoners/actions/runs/41224031814)), la primera vez que esta rama pasa por el CI. |
| B1 | `NavMap.seal_unreachable` convierte en muro toda celda a la que no se llega desde la entrada; se aplica al generar y al cargar un snapshot (los pisos guardados se arreglan sin cambiar nada alcanzable). `NavMap.can_step`: un empujón, un dash, una esquiva o el paso de una criatura no puede pasar por una esquina cerrada. | `d166e27`, `1f0db57` | Suite nueva `map safety`. `diag_pockets`: los mapas con bolsillos pasaron de 30/30 a 0/30. `diag_trap`: ya no queda ningún bolsillo donde probar. La primera versión de `can_step` era demasiado estricta y trababa a las criaturas en las curvas (0 de daño recibido en los pisos 1-4); se corrigió en `1f0db57`. |
| B3 | El terreno del minimapa es una imagen creada una vez por misión. | `d166e27` | `diag_perf` (piso 5): antes 6,6 ms en cada fotograma; ahora 2,9-4,9 ms una sola vez. La niebla solo repinta las celdas que cambian: 1,7 → 0,9-1,0 ms cada 0,15 s. |
| B4 | Los efectos con retraso usan tweens del propio nodo, que mueren con él. | `d166e27` | 0 líneas `Lambda capture` en 16 cuentas jugadas después del arreglo. |
| B5 | No se reprodujo en 8 intentos directos al piso 5 tras B1. La causa probable era un punto de recolección dentro de un bolsillo junto a la entrada, sumado a que el bot no lo descartaba. El bot ya descarta puntos inalcanzables. | — | 8/8 intentos con movimiento y combate normales. |
| B6 (nuevo) | En "Clear the floor", los últimos enemigos podían ser emboscados dormidos, invisibles incluso en salas exploradas, y el piso no se podía terminar. Ahora se marcan en el minimapa cuando quedan 3 o menos, o cuando todos los que quedan están dormidos. | `36c76c5` + siguiente | `map safety`. En el modo a ciegas desaparecieron los bloqueos por emboscados. |
| B7 (nuevo) | El objetivo del jefe decía "Orc Chieftain" también en el piso 5; ahora nombra al jefe del piso (Grove Warlord). | `36c76c5` | `map safety`. |
| D4 | Las 3 pistas de exploración van a 3 salas distintas, lo más lejos posible de la entrada y entre sí. | `36c76c5` | `map safety`: 81 celdas de separación mínima en el piso de prueba. |
| D1 | Pisos 1-10 un ~30 % más grandes por lado (~1,7× el área), con criaturas y puntos de recolección en la misma proporción. | `36c76c5` | Modo a ciegas del bot (`PT_BLIND=1`: solo sabe lo que reveló la niebla), 4 cuentas. Antes: P1 4,5-7 min, P2 6-7, P3 6-7, P4 7-8, P5 3,5-5,5. Después: P1 10-11,5, P2 8-13, P3 9-14, P4 9,5-15, P5 3,5-7. Una persona tardará algo más que el bot. Ir directo en una repetición sigue siendo corto (2-4 min). |

## Balance y lógica (2026-10-31, D-064)
| # | Cambio | Medido (bot con conocimiento del mapa, 4 cuentas nuevas) |
|---|---|---|
| D2 | Fuerza de las criaturas por piso: 1,0 / 1,25 / 1,45 / 1,65 / 1,35. | Vida mínima del piso 4: antes 70-100 %, ahora 35-85 %. Piso 5: 1-12 %, 1 muerte en 4 cuentas. Pisos 1-3 siguen siendo de entrada. |
| D3 | Jefe con fases: llama a su banda al 60 % y al 30 %, y se enfurece al 30 %. | Ir directo al jefe sigue siendo posible, pero cuesta casi toda la vida de la escuadra. `map safety` comprueba las fases. |
| D5 | 300 gemas iniciales y 100 por invocación (×10: 900). | El bucle de invocar y sacrificar ya no compensa: 100 gemas dan unos 36 materiales de media. |
| D6 | Los pisos pagan 40 + 20 × piso en materiales; el santuario pide Salón 1 y cuesta 60. | Tras el piso 4 el bot tenía 96-126 materiales libres (antes 0-26). |
| D7 | Taller a 30 con 2 puestos y aviso en el registro del pueblo cuando se acumulan madera y piedra. | — |
| D8 | Alcance a distancia de 190 a 165; la furia empieza en 30, se enfría a 3/s y sube 10 por golpe. | `skills`, `orders` y `combat core` PASS. |
| D9 | X recoge al caído más cercano (≤ 260 px) antes de huir. | `orders`: recoge, no se cancela con un segundo X y luego los dos huyen. |
| D10 | Almacén base de 300. | — |
| D11 | `best_workplaces` acepta los ids de profesión. | `town` PASS. |
| D12 | Se borró el zip duplicado de la raíz (sigue en el historial: `7c2c8a9`). | Los 311 PNG estaban en `assets/pixel/caz-base/`. |

Pruebas locales tras el balance: **25/25 PASS**.

## Mecánicas tácticas (D-065): bot "a lo loco" contra bot "táctico" (2026-10-31)
Las dos versiones del bot juegan con conocimiento del mapa, en cuentas nuevas, del piso 1 al 5, con hasta 3 intentos por piso; si fallan, repiten el piso anterior para subir de nivel. Las dos usan la autonomía nueva de los héroes (habilidades automáticas).
- **A lo loco:** ataca al enemigo más cercano y no hace nada más.
- **Táctico:** además mata primero a curanderos, chamanes y vigías, interrumpe lanzamientos con aturdimientos, saca a los héroes de las áreas marcadas, y el héroe con más vida lleva la reliquia mientras los demás lo escoltan.

### A lo loco: 4 accounts, highest floor cleared per account: [5, 4, 5, 4]
| Floor | attempts | won | won 1st try | escaped / failed / timeout | heroes lost | downs | avg time | lowest HP (median) |
|---|---|---|---|---|---|---|---|---|
| 1 | 4 | 4 | 4/4 | 0 / 0 / 0 | 0 | 0 | 3:36 | 54% |
| 2 | 4 | 4 | 4/4 | 0 / 0 / 0 | 0 | 0 | 2:33 | 100% |
| 3 | 4 | 4 | 4/4 | 0 / 0 / 0 | 0 | 1 | 3:50 | 67% |
| 4 | 5 | 4 | 3/4 | 0 / 0 / 1 | 0 | 0 | 10:02 | 62% |
| 5 | 8 | 2 | 2/4 | 2 / 4 / 0 | 29 | 29 | 2:27 | 2% |

### Táctico: 4 accounts, highest floor cleared per account: [5, 5, 5, 5]
| Floor | attempts | won | won 1st try | escaped / failed / timeout | heroes lost | downs | avg time | lowest HP (median) |
|---|---|---|---|---|---|---|---|---|
| 1 | 4 | 4 | 4/4 | 0 / 0 / 0 | 0 | 0 | 3:30 | 98% |
| 2 | 4 | 4 | 4/4 | 0 / 0 / 0 | 0 | 0 | 2:33 | 100% |
| 3 | 4 | 4 | 4/4 | 0 / 0 / 0 | 0 | 0 | 3:27 | 95% |
| 4 | 4 | 4 | 4/4 | 0 / 0 / 0 | 0 | 0 | 4:44 | 95% |
| 5 | 4 | 4 | 4/4 | 0 / 0 / 0 | 0 | 1 | 1:42 | 7% |


Lectura:
- **Piso 5:** a lo loco ganó 2 de 8 intentos y perdió 29 héroes para siempre (2 de las 4 cuentas no pasaron). El táctico ganó 4 de 4 a la primera sin perder a nadie. Las mecánicas del jefe (chamanes, escudo, Slam) premian pensar.
- **Piso 4:** a lo loco tardó el doble (10 min frente a 4:44) y tuvo un bloqueo; los vigías juntan grupos. El táctico terminó con más vida (95 % frente a 62 %).
- **Pisos 1-3:** casi no hay diferencia; los dos los pasan siempre. Los curanderos del piso 2 apenas pesan porque la misión de exploración no obliga a pelear, y el piso 3 solo se nota en la vida (67 % frente a 95 %). Es lo siguiente que hay que reforzar.
- Lo que el bot no mide: usar W/E/R a mano, colocar a los héroes y decidir a quién dejar libre con T. Eso lo tiene que probar una persona.

## Los Wilds y la torre como reto (D-066, 2026-10-31)
El bot ahora juega el ciclo nuevo. Si el siguiente piso pide un Salón más alto, va a los Wilds (recoge todo, cachés incluidas, y sale al cabo de unos 7 min, cuando no queda nada o si la escuadra está herida), mejora el Salón en cuanto puede y vuelve a la torre. 2 cuentas por estilo:

### A lo loco: 2 accounts, highest floor cleared per account: [5, 5]
| Floor | attempts | won | won 1st try | escaped / failed / timeout | heroes lost | downs | avg time | lowest HP (median) |
|---|---|---|---|---|---|---|---|---|
| 1 | 2 | 2 | 2/2 | 0 / 0 / 0 | 0 | 0 | 3:15 | 96% |
| 2 | 2 | 2 | 2/2 | 0 / 0 / 0 | 0 | 0 | 2:10 | 92% |
| 3 | 2 | 2 | 2/2 | 0 / 0 / 0 | 0 | 0 | 3:01 | 96% |
| 4 | 2 | 2 | 2/2 | 0 / 0 / 0 | 0 | 0 | 3:56 | 88% |
| 5 | 2 | 2 | 2/2 | 0 / 0 / 0 | 4 | 6 | 1:47 | 10% |

### Táctico: 2 accounts, highest floor cleared per account: [5, 5]
| Floor | attempts | won | won 1st try | escaped / failed / timeout | heroes lost | downs | avg time | lowest HP (median) |
|---|---|---|---|---|---|---|---|---|
| 1 | 2 | 2 | 2/2 | 0 / 0 / 0 | 0 | 0 | 3:09 | 92% |
| 2 | 2 | 2 | 2/2 | 0 / 0 / 0 | 0 | 0 | 2:23 | 88% |
| 3 | 2 | 2 | 2/2 | 0 / 0 / 0 | 0 | 0 | 3:32 | 100% |
| 4 | 2 | 2 | 2/2 | 0 / 0 / 0 | 0 | 0 | 4:29 | 98% |
| 5 | 2 | 2 | 2/2 | 0 / 0 / 0 | 1 | 2 | 1:45 | 78% |


- **Ritmo:** el piso 5 cae hacia el **día 14-15 del pueblo**, tras 5-6 salidas a los Wilds; antes de D-066, hacia el día 5-8. Los pisos 3 y 5 esperaron a que el Salón subiera de nivel.
- **Wilds:** cada salida dura 4-7 min y la vida mínima va del 35 al 100 %. Ningún héroe murió en ellos: con conocimiento del mapa, el nivel 1 todavía es bastante seguro. Si quieres más riesgo, hay dos palancas: más fuerza en la sala más honda o patrullas que cazan.
- **Piso 5:** a lo loco perdió 4 héroes en 2 cuentas; el táctico, 1.
