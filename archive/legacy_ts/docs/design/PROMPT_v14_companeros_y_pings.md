# Prompt — v14: compañeros autónomos, pings y personalidad en combate

Pégalo tal cual en Claude Code, abierto en la carpeta del proyecto (`tactical-summoners`).

---

## Contexto

Proyecto Tactical Summoners (Godot 4.7, GDScript, UI por código). Lee primero `CLAUDE.md` y `AGENTS.md` y respeta sus reglas: inspecciona antes de cambiar, números en datos, nada de PASS sin salida citada, no hagas push a `main`.

El dueño decidió cambiar el modelo de control de las expediciones (torre y Wilds). **Ya no hay RTS de grupo.** El jugador maneja siempre a **un** héroe y es el "máster" que da la voz a los otros 4. Esos 4 son autónomos: siguen su clase, sus habilidades, sus rasgos y su compostura, y obedecen **pings** al estilo de League of Legends. Inspiración: el manhwa *Pick Me Up, Infinite Gacha* (los héroes tienen voluntad propia y el máster los dirige).

Antes de escribir código, lee y entiende estos archivos:
- `scripts/sandbox/sandbox_screen.gd`: `select_slot`, `select_only`, `_set_controlled`, `group_view`, `order_context`, `_input`, `_process`, las órdenes `*_selected` y el arrastre de selección.
- `scripts/sandbox/sandbox_hero.gd`: `combat_tick`, `_auto_skill`, `_auto_kind`, `_try_dodge`, `_stay_near_anchor`, `leash`, `chase_radius`, `aggression`, `is_explorer`, `aimed_attack`, `ANCHOR_LEASH`, `AUTO_EVERY`, `AUTO_HEAL_BELOW`.
- `scripts/sandbox/combat_rules.gd`: `auto_dodge_chance`, `OBEY_MIN`.
- `scripts/sandbox/sandbox_enemy.gd`: telegrafía, lanzamientos y `focus`.
- `scripts/ui/expedition_hud.gd`: panel de órdenes, retratos y minimapa.
- `scripts/combat/combat_debug_draw.gd` (F3), `scripts/sandbox/hero_chatter.gd`.
- `scripts/core/hero_data.gd`: trust, obedience, composure, rasgos y relaciones.
- `scripts/data/hero_tables.gd`: rasgos y `AGGRESSION`.
- `tests/playthrough_bot*`, `tools/run_tests.sh`, `tools/Run-Tests.ps1`.
- `docs/DECISIONS.md`: D-014, D-015, D-016, D-051, D-052, D-053, D-059, D-065.
- `docs/specs/CONTROL_AND_MISSIONS.md`.

## Decisiones del dueño (regístralas en `docs/DECISIONS.md` como D-067 en adelante)

1. **Un solo héroe controlado, siempre.**
   - Al empezar la misión se maneja el héroe de la ranura 1.
   - 1-5 cambia de héroe (Shift+1-5 para 6-10 en raids).
   - Si el héroe manejado cae, el control pasa solo al siguiente vivo que obedezca, con un aviso.
   - **Se eliminan** la selección múltiple (arrastre y G), el attack-move de grupo (A), seguir (F) y parar (S).
   - Tab deja de soltar el control: ahora solo cambia la cámara a la vista de grupo.
2. **El ataque básico sigue siendo Q**, apuntado al cursor (D-059 se mantiene).
   - El clic derecho solo mueve.
   - Habilidades en W/E/R, solo del héroe manejado.
   - **Sin asistencia de puntería.**
   - **Sin inmunidad al pánico ni aura del comandante** para el héroe manejado.
3. **Tres órdenes globales**, la "voz del máster", sin tirada y con prioridad sobre todo:
   - **Retirada** (X): mantiene el comportamiento de D-064, recoger al caído cercano.
   - **Reagrupar** (C): todos van junto al héroe manejado.
   - **Esperar** (H): todos se quedan donde están, defendiendo.
   - También como botones en la HUD.
   - **Provisional, pendiente de confirmar por el dueño:** valen incluso para héroes con Obediencia < 25. Ponlo como dato `CompanionDefs.GLOBAL_IGNORES_OBEDIENCE = true` y anótalo en `docs/design/DECISIONS_PENDING_USER.md`.
4. **Pings.**
   - **Shift + clic derecho rápido** = ping contextual:
     - enemigo → **Foco**;
     - suelo → **Vengan aquí**;
     - aliado caído → **Rescaten**;
     - aliado en pie → **Protéjanlo**;
     - objeto usable (altar, reliquia, palanca) → **Usen esto**.
   - **Shift + mantener clic derecho** (≥ 0,2 s) = rueda radial alrededor del cursor. Se elige moviendo el ratón y se confirma al soltar; Esc o soltar en el centro cancela. Opciones:
     - Vengan aquí;
     - Foco;
     - Peligro (se apartan de la zona y la evitan unos segundos);
     - Protejan a… (el aliado más cercano al punto);
     - Esperen aquí;
     - Exploren ahí.
   - **Quién responde:** no siempre los 4. Elige a los más adecuados según clase, rol, distancia y personalidad, con cupos en datos:
     - Foco: 2, primero los de distancia y el pícaro;
     - Protejan: 1-2, primero el tanque y el sanador;
     - Exploren: 1, primero el explorador;
     - Vengan aquí / Peligro / Esperen aquí: todos.
   - **Respuesta:** el héroe confirma con texto flotante corto ("¡Voy!", "¡Ese es mío!"). Si no puede, dice el motivo determinista: sin camino, caído, en pánico, en furia u Obediencia < 25.
   - **La obediencia cambia la rapidez de la respuesta**, nunca si responde (salvo el umbral de D-051).
   - **Cada ping se ve:** marcador animado en el mundo y en el minimapa, con duración en datos.
   - **Pings de vuelta (la IA avisa):**
     - el explorador que ve un grupo despierto marca **"enemigo avistado"**;
     - un héroe por debajo del 35 % de vida que recibe golpes pide **"¡ayuda!"**;
     - con límite de frecuencia por héroe.
5. **IA menos precisa, con tiradas justas.**
   - Las decisiones tácticas de la IA (interrumpir, curar, limpiar, provocar, escudo y la esquiva de D-052) tienen **tiempo de reacción** (base 0,6-1,2 s) y una **tirada**.
   - **Fallar la tirada significa reaccionar tarde**, no "no hacerlo nunca": se añade retraso y se reintenta en la siguiente ventana.
   - **Protección contra la mala suerte:** cada fallo sube la probabilidad siguiente de ese héroe para ese tipo de decisión. Nunca tres fallos seguidos. Se reinicia al acertar.
   - La probabilidad sale de: nivel, compostura actual, Trust (a más Trust, mejor reacción) y rasgos.
   - RNG con la semilla de la misión (determinista).
   - El héroe manejado no tira: decide el jugador.
   - La ficha del héroe muestra su fiabilidad ("Interrumpe 60 %, reacción 0,9 s") y de qué depende.
   - Al fallar, aparece "dudó…" corto sobre el héroe.
6. **Compostura viva y pánico.**
   - Durante la expedición cada héroe tiene `composure_live`, que empieza en su Composure.
   - **Baja** con: aliado caído o muerto a la vista, vida baja, grito o fase de jefe, rodeado (≥ 3 enemigos cerca) y aislado (sin aliados cerca).
   - **Sube** con: muertes de enemigos, aliado con vínculo cerca, ping "Protejan" recibido y curación recibida.
   - **Tirada de pánico al ver caer o morir a alguien:** solo tiran los que lo ven (visión de la niebla). La probabilidad depende de su compostura, sus rasgos y su vínculo con el caído (amigo: más reacción, que puede ser furia; rival: menos).
   - **Resultado según el rasgo:**
     - **Pánico:** huye hacia el grupo o el héroe manejado durante 5-8 s, sin atacar.
     - **Furia:** +25 % de daño hecho y +25 % de daño recibido; ignora los pings normales (no los globales).
     - **Firme:** sin efecto, y lo dice.
   - **Anti-cascada:** como máximo 1 héroe en pánico a la vez, y unos segundos sin volver a tirar después.
   - **Héroe manejado (provisional, anótalo como pendiente):** tira igual, pero si le toca pánico no se le quita el control. Recibe un malus visible: temblor, −20 % de velocidad de ataque mientras dure.
   - Este punto matiza D-016: el pánico es una excepción **anunciada y con causa visible**, nunca una tirada oculta que cancele órdenes rutinarias.
7. **Cada rasgo con su pro y su contra** en combate. Tabla de datos `TRAIT_COMBAT` con los 16 rasgos. Ejemplos:
   - **Cobarde:** más pánico, pero detecta y evita las zonas telegrafiadas antes y avisa de peligros a más distancia.
   - **Temerario:** puede atacar grupos dormidos por su cuenta, pero nunca entra en pánico (solo en furia o firme) y pega más al cargar.
   - **Cauto:** se queda cerca y tarda más en responder a Foco, pero reacciona mejor a las curas y a la esquiva.
   - **Protector:** prioriza al aliado más débil y responde rápido a "Protejan", pero sigue menos a Foco.
   - Ningún rasgo debe ser solo negativo.
8. **Autonomía libre** (sustituye la correa al héroe manejado, `ANCHOR_LEASH`).
   - **Radio de grupo** en datos (≈ 1 pantalla) alrededor del centro del escuadrón.
   - **Según la personalidad:**
     - el explorador revela la niebla dentro del radio y, **al ver enemigos, se detiene y hace ping** en vez de atacar;
     - los agresivos atacan a los enemigos despiertos que ven;
     - solo los temerarios atacan grupos dormidos sin ping;
     - los cautos se quedan cerca del héroe manejado.
   - **Los pings y las órdenes globales mandan por encima de todo.**
   - **Icono de intención** sobre la cabeza: explorando, foco, protegiendo, pánico, furia, esperando, rescatando.
   - Frases cortas según la personalidad (`hero_chatter.gd`).
   - **Flechas en el borde de la pantalla** para los aliados fuera de cámara, y retrato con el icono de estado.
9. **Interruptores en datos**, en un archivo nuevo `scripts/data/companion_defs.gd` con todos los números:
   - `AI_ROLLS`, `PANIC`, `FREE_AUTONOMY`, `AI_PINGS_BACK`.
   - Cada sistema se puede apagar para aislar problemas.
   - El overlay F3 y un registro de combate muestran cada tirada con su motivo, por ejemplo: `Mara: interrumpir 62 % → tarde (+0,5 s), 2.º intento 80 %`.
10. **Bug conocido que debe desaparecer:** G + clic derecho a un enemigo con un héroe controlado le daba una orden de ataque que `combat_tick` anulaba. Con la selección múltiple eliminada no debe poder reproducirse; añade una prueba que lo confirme.

**Fuera de alcance:** expediciones automáticas (el dueño las descartó), PvP y cambios de economía.

## Fases (una versión por fase; no empieces la siguiente sin que la anterior pase todo)

| Fase | Contenido | Versión |
|---|---|---|
| 1 | Puntos 1, 2, 3, 5 y 10 + `companion_defs.gd` con interruptores + F3 y registro | v14a |
| 2 | Punto 4: pings rápidos, rueda, respuesta y pings de vuelta | v14b |
| 3 | Puntos 6 y 7: compostura viva, pánico y rasgos | v14c |
| 4 | Punto 8: autonomía libre, iconos e indicadores | v14d |

Al terminar cada fase:
- actualiza `docs/IMPLEMENTATION_STATUS.md` (solo con evidencia) y `docs/specs/CONTROL_AND_MISSIONS.md` (las teclas y el modelo nuevos);
- añade la entrada en `docs/VERSIONS.md` con una lista **"Qué probar a mano"** paso a paso para el dueño.

**Ojo:** la carpeta v13 no es un repo git. Si no hay git, trabaja en una copia o inicializa uno local; no pierdas el estado v13.

## Pruebas: todo desde la perspectiva del jugador

Regla: **cada punto implementado tiene al menos una prueba que lo ejercita como lo haría un jugador.** Eso significa eventos de entrada reales (`Input.parse_input_event` con `InputEventKey` / `InputEventMouseButton` / `InputEventMouseMotion`), nunca llamando directamente a la función interna. Las pruebas de reglas puras van aparte, como complemento.

### A. Suite nueva `tests/test_player_control.gd` (+ escena si hace falta)

Mapa pequeño y fijo, semilla fija, 5 héroes y enemigos colocados a mano. Casos mínimos (añade más si hace falta):

**Fase 1**
1. Al empezar, la ranura 1 está controlada y la cámara la sigue.
2. Pulsar 3 → controla el héroe 3. Los otros 4 tienen `controller == "ai"`.
3. Arrastrar con el ratón **no** selecciona a varios. G no hace nada (o muestra el aviso).
4. Clic derecho en el suelo → solo se mueve el héroe controlado.
5. Clic derecho sobre un enemigo → el héroe controlado **no** ataca, solo se mueve.
6. Mantener Q apuntando a un enemigo en la línea → recibe daño al ritmo de la velocidad de ataque. Apuntar al lado → falla.
7. W/E/R lanzan habilidades del controlado. Con otro héroe controlado, son las del nuevo.
8. Tab → la cámara cambia a la vista de grupo y el control **sigue** en el mismo héroe.
9. X / C / H → los 4 autónomos obedecen (salida, junto al controlado, quietos). Con `GLOBAL_IGNORES_OBEDIENCE` encendido, también un héroe con Obediencia 10.
10. El héroe controlado cae → el control pasa al siguiente vivo con aviso.
11. Tiradas de la IA: un chamán enemigo lanza → el autónomo con interrupción reacciona con retraso dentro del rango de datos. Forzando fallos (semilla), el tercer intento nunca falla. El registro de combate contiene la línea de la tirada.
12. Con `AI_ROLLS = false`, el comportamiento vuelve a ser el de v13 (comparación).
13. El bug de G + clic derecho no se puede reproducir.

**Fase 2**

14. Shift + clic rápido sobre un enemigo → ping Foco con marcador. Responden 2 héroes (primero los de distancia) y atacan a ese enemigo. Aparece la confirmación.
15. Shift + clic en el suelo → todos van ("Vengan aquí").
16. Shift + clic sobre un caído → uno va y lo rescata.
17. Shift + mantener ≥ 0,2 s → aparece la rueda. Mover el ratón hacia una opción y soltar ejecuta esa opción. Soltar en el centro o pulsar Esc cancela sin efecto.
18. Peligro → los héroes salen de la zona y no vuelven a entrar durante la duración.
19. Exploren ahí → va 1 explorador y revela niebla.
20. Un héroe con Obediencia < 25 responde con su motivo. Uno con poca obediencia responde más tarde que uno con mucha.
21. Pings de vuelta: el explorador que ve un grupo despierto genera el marcador "enemigo avistado". Un herido golpeado genera "¡ayuda!". Se respeta el límite de frecuencia.

**Fase 3**

22. Un aliado cae a la vista de 3 héroes → tiran solo esos 3 (no el que está fuera de visión).
23. Anti-cascada: nunca hay 2 héroes en pánico a la vez.
24. Un héroe en pánico huye hacia el grupo, no ataca y se recupera en 5-8 s.
25. Un héroe en furia ignora Foco, pero obedece Retirada.
26. El héroe controlado en pánico **conserva el control** y muestra el malus.
27. `composure_live` sube y baja con cada evento de la lista.
28. Para cada rasgo de `TRAIT_COMBAT`, una prueba de su pro y otra de su contra.

**Fase 4**

29. El explorador autónomo se adentra en la niebla dentro del radio, se detiene al ver un grupo y hace ping sin atacar.
30. Un no temerario no ataca un grupo dormido sin ping; un temerario sí.
31. Ningún autónomo sale del radio de grupo sin un ping.
32. Iconos de intención correctos en cada estado. Flecha de borde visible con un aliado fuera de cámara.

### B. Capturas (revísalas tú y adjúntalas al informe)

Añade a `tests/capture_*`:
- rueda de pings abierta;
- marcador de cada tipo de ping (mundo y minimapa);
- texto de confirmación;
- icono de cada intención;
- pánico y furia;
- flechas de borde;
- ficha del héroe con la fiabilidad;
- overlay F3 con tiradas.

Mira cada captura y describe en el informe lo que se ve. Si algo no se lee a 640×360, arréglalo.

### C. Bot de juego: nuevos estilos en `tests/playthrough_bot`

`PT_STYLE`:
- **`loco`:** maneja al héroe 1, Q al enemigo más cercano, nunca usa pings ni órdenes globales.
- **`ia`:** maneja al héroe 1 lo justo para avanzar hacia el objetivo y no hace nada más (mide la IA sola).
- **`driver`:** maneja a un héroe con criterio (W/E/R, esquiva las zonas marcadas, cambia de héroe con 1-5 cuando otro tiene la herramienta adecuada), usa pings (Foco a curanderos y chamanes, Protejan al herido, Peligro sobre las áreas) y Retirada cuando hace falta.

El bot también debe **enviar eventos de entrada** para todo lo que pueda (teclas y ratón), no llamar a las funciones internas.

**Matriz** (`PT_MATRIX=1`):
- pisos 1-5 y Wilds nivel 1, con al menos 6 cuentas por estilo (sube `PT_N` si la varianza es alta);
- todas las combinaciones de interruptores relevantes: `AI_ROLLS` on/off y `PANIC` on/off como mínimo.

**Criterios de aceptación** (escribe la tabla en `docs/reports/COMPANIONS_AND_PINGS_REPORT.md`):
- **driver > ia > loco** en victorias, muertes permanentes y vida mínima, en todos los pisos y en los Wilds. Los pisos 1-3 ya no deben dar el mismo resultado para todos los estilos (era un fallo pendiente de la v13).
- Con `PANIC` encendido, ninguna partida de `driver` termina en espiral (≥ 3 héroes en pánico o furia encadenados que causen un wipe).
- Duración de un piso a ciegas en el rango de D-056 / D-064.
- Rendimiento: el coste de la IA y de los pings por tick no sube más de un 20 % frente a la v13 (`diag_perf`).

Si un criterio no se cumple, ajusta los datos de `companion_defs.gd`, vuelve a medir y documenta cada iteración. Si tras 3 iteraciones sigue sin cumplirse, para y explica por qué en el informe.

### D. Ejecución

- Todas las suites existentes deben seguir en PASS. Las que dependan de la selección múltiple o de A/F/S/G se actualizan al modelo nuevo; explica cada cambio.
- Ejecuta con `tools/run_tests.sh` o `tools\Run-Tests.ps1`, o con la CI si hay repo. **Cita la salida.**
- Al final de cada fase, el informe resume:
  - qué cambiaste;
  - qué ejecutaste, con su salida;
  - qué capturas revisaste y qué viste;
  - qué queda sin verificar a mano (sonido, sensación de la rueda con ratón real, FPS en el PC del dueño).
