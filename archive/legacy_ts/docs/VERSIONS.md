# Versiones para probar

Cada versión es un commit concreto de la rama `claude/tactical-summoners-audit-b3sqpo`. Puedes descargar cualquiera en ZIP, sin Git, con el enlace de la tabla, y probarlas cuando estés en casa.
Las pruebas automáticas se ejecutan en GitHub (Godot 4.7.1 Linux) con cada push. Pestaña **Actions** del repo → la ejecución → **Summary** (resultado).
**Capturas de la última versión (se ven en el móvil):** https://github.com/natillaw/tactical-summoners/tree/ci-screenshots/claude_tactical-summoners-audit-b3sqpo (abre `README.md` para verlas todas).

| Versión | Commit | Descargar | Qué contiene | Pruebas automáticas (Godot 4.7.1) |
|---|---|---|---|---|
| **v1** | `1bea618` | [ZIP](https://github.com/natillaw/tactical-summoners/archive/1bea618fb02e7d006e9912dc14ef6a7eb63ad10f.zip) | Auditoría + documentación consolidada + CI. **El código del juego es el original** (`509218b`) | **6/12 PASS** — [ejecución](https://github.com/natillaw/tactical-summoners/actions/runs/41113420228). Fallan: sandbox, combat, mission, animation, art, deep systems |
| **v2** | `fb3ee7c` | [ZIP](https://github.com/natillaw/tactical-summoners/archive/fb3ee7cbbd8fdf62a11830d7f14cc1031f9cea23.zip) | Fase 3: reparaciones F-001…F-005, F-007, F-013, F-038 + 2 suites nuevas | **14/14 PASS** — [ejecución](https://github.com/natillaw/tactical-summoners/actions/runs/41113770886) |
| **v3** | (ver el último commit de la rama) | [ZIP de la rama](https://github.com/natillaw/tactical-summoners/archive/refs/heads/claude/tactical-summoners-audit-b3sqpo.zip) | **El juego empieza en el pueblo** (D-030): 14 edificios, construir/mejorar con materiales, héroes paseando; Puerta de la Torre → entrenamiento o pisos 1-10; VFX de los packs en combate | **15/15 PASS** — [ejecución](https://github.com/natillaw/tactical-summoners/actions/runs/41116908580) |
| **v4** | `cf32596` | [ZIP](https://github.com/natillaw/tactical-summoners/archive/cf32596.zip) | Pisos 1-10 de **bosque** procedural con criaturas de bosque; pueblo con casas, árboles, flores y pozo; héroes autónomos en el pueblo; ficha del héroe al hacer clic; tecla M = mapa completo | **15/15 PASS** + capturas de los pisos 1-5 |
| **v5** | `e3f4f3a` | [ZIP](https://github.com/natillaw/tactical-summoners/archive/e3f4f3a.zip) | **Arte de Caz** en pueblo y pisos; 7 tipos de misión (combate, relicario, rescate, exploración, supervivencia, defensa, jefe); jefe orco en el piso 10; recompensas por piso; profesiones expertas ×2; claros irregulares | **15/15 PASS** + capturas pisos 1-5 y 10 |
| **v6** | `72c2f04` | [ZIP](https://github.com/natillaw/tactical-summoners/archive/72c2f04.zip) | **Combate fase 1**: base común de unidades, atributos FUE/AGI/VIT/INT/TEM con efecto real, daño físico/mágico/verdadero, armadura y resistencia mágica, críticos, estados (veneno, quemadura, sangrado, aturdimiento, raíz, lentitud, debilidad, escudo, herido), caída + agonía 20 s + rescate, clic derecho contextual, números de daño | **16/16 PASS** |
| **v7** | `5ab21e7` | [ZIP](https://github.com/natillaw/tactical-summoners/archive/5ab21e7.zip) | **Combate fase 2**: órdenes atacar avanzando (A), mantener (H), seguir (F), reagrupar (C), retirada (X), parar (S) con botones; línea de visión (los árboles bloquean disparos); arqueros/magos retroceden si se les acercan; los héroes esquivan solos los golpes telegrafiados | **17/17 PASS** |
| **v8** | `ed3c5a7` | [ZIP](https://github.com/natillaw/tactical-summoners/archive/ed3c5a7.zip) | **Combate fase 3**: habilidades como datos (≈45), recurso por clase (Furia, Foco, Maná, Aguante), teclas **Q W E R** con botones, tiempos de lanzamiento (solo los rompe un aturdimiento), interrupciones, provocar, empujar, carga, teletransporte, zonas, estados Marcado y Regeneración; nacen con 1 habilidad y eligen 1 de 2-3 en niveles 5/10/20…; libros de habilidad (jefe, rescate, exploración, botín) y **Biblioteca**; guardado v8 | **18/18 PASS** — [ejecución](https://github.com/natillaw/tactical-summoners/actions/runs/41147327096) |
| **v9** | `6558c35` | [ZIP](https://github.com/natillaw/tactical-summoners/archive/6558c35.zip) | **Cuartel general vivo:** reloj del pueblo, profesiones con nivel, trabajo con recetas (granja, tala, mina, cocina, taller, herrería, alquimia), almacén, camas reales, hambre/fatiga/estrés, hospital con médicos y enfermedades, taberna, obras por constructores con techo del Salón, mover edificios; **equipo** con rarezas, afijos, únicos y sets, botín y forja; guardado v9 | **20/20 PASS** — [ejecución](https://github.com/natillaw/tactical-summoners/actions/runs/41150421537) |
| **v10** | `7bd7712` | [ZIP](https://github.com/natillaw/tactical-summoners/archive/7bd7712.zip) | **Animaciones de combate con los packs:** ataques por arma (tajos, flechas y bolas que vuelan), círculo mágico al lanzar, impactos y áreas propios de cada habilidad, auras de estado, zonas de humo/trampa/santuario, criaturas que atacan y se encogen con sus animaciones reales; arreglo del recorte de criaturas pequeñas y grandes; orcos voxel en los pisos 7-10 | **21/21 PASS** — [ejecución](https://github.com/natillaw/tactical-summoners/actions/runs/41152812930) |
| **v11** | rama `feat/ui-and-art-unification` | [ZIP de la rama](https://github.com/natillaw/tactical-summoners/archive/refs/heads/feat/ui-and-art-unification.zip) | **UI y arte unificados:** pantalla de título, base 640×360 pixel-perfect, fuentes pixel, paneles y botones del kit, música y sonidos, HUD de expedición con minimapa, menú Esc sin pausa, revelación de invocación, ficha con pestañas, inventario, 8 ranuras de equipo, síntesis y sacrificio, criaturas normalizadas y jefe Grove Warlord (piso 5). Historia de Git nueva (repo v10) | **24/24 PASS** en local (Godot 4.7.2, `tools/last_test_run.txt`) |
| **v12** | rama `ccr-cb2bbfa2-cg889y` | [ZIP de la rama](https://github.com/natillaw/tactical-summoners/archive/refs/heads/ccr-cb2bbfa2-cg889y.zip) | v11 unido a la historia de `main` + **playtest automático de 5 pisos** y arreglos: héroes atrapados (B1), CI en Linux (B2), minimapa (B3), errores de consola (B4), últimos enemigos marcados (B6), nombre del jefe (B7), pistas repartidas, **pisos ~1,7× más grandes** para una primera partida de 10-15 min. Informe: `docs/reports/PLAYTEST_5_FLOORS_REPORT.md` | **25/25 PASS** — [ejecución](https://github.com/natillaw/tactical-summoners/actions/runs/41224031814) (Godot 4.7.2) |
| **v13** | sin commit (carpeta local `tactical-summoners-v13`, no es repo git) | — | **Balance:** Wilds con packs por rol (tanque+distancia+sanador), IA táctica y callers; jefes de piso 5/10 con mecánicas de raid y enrage; daño por piso +22%/piso; XP lenta (piso normal ≈0,5 nivel, MVP+secreto ≈1); pisos sin bloqueo por edificio; P-29 registrada. Bot: `PT_MATRIX=1 [PT_N PT_PROFILE PT_ONLY PT_CSV]`. Pendiente: LOCO con mejoras gana 100% en Wilds; pisos 1-3 sin diferencia de muertes. | Local Godot 4.7.2: 10 suites ALL PASSED (logs en `tests/out/`) |
| **v14** | rama local `feat/master-prompt-bandits` (git init local, sin remoto) | — | **Prompt maestro:** bandidos TPF (capas accessory/mask, 8 tipos, Barón ×2), bosque con tileset del dueño + campamentos, loot de pisos (`LootDefs`), party por piso, amenaza, modificadores, escape, Barón Carmesí con altar, expediciones offline, mercader, save v11, simulador. Sabotaje del piso 7 y ritmo de gemas hechos (commit 975f229). Pendiente: mural de pista. | Local Godot 4.7.2: 22 suites ALL PASSED (logs en `tests/out/`) |
| **v15** | rama `ccr-7d17ca4c-os56aa` | [ZIP de la rama](https://github.com/natillaw/tactical-summoners/archive/refs/heads/ccr-7d17ca4c-os56aa.zip) | **Pase visual (D-141):** árboles/rocas/troncos tapan a los héroes, cámara más cerca, botín con icono y aura de rareza, portal de salida y santuario, nueva pantalla de título (una sola partida), opciones ampliadas, pueblo con barra de recursos, dock con nombres, plaza decorada y héroes con emociones; Construir con imágenes; paneles de edificio; Memorial; inventario; escuadrón sin filas; ficha del héroe con ranuras | Local Godot 4.7.2 Linux: 35/35 suites PASS (tras arreglar `mission`) |
| **v16** | rama `ccr-8a10e84a-r95vxi` | [ZIP de la rama](https://github.com/natillaw/tactical-summoners/archive/refs/heads/ccr-8a10e84a-r95vxi.zip) | **D-142:** héroes solo con Q y elección de W/E/R en 2, 5 y 10; solo Emboscada, Disparo de interrupción y Contrahechizo cortan lanzamientos (el aturdimiento pausa la carga); Resurrección del clérigo en F (4 s); sin flanqueo, espalda con espalda ni muro de escudos; marca del arquero +15 %; gear por criatura 3 %/20 % y hacha épica fija del jefe del piso 10; frases de héroes en español | **35/35 PASS** — [ejecución](https://github.com/natillaw/tactical-summoners/actions/runs/41493339346) (Godot 4.7.2, CI) |
| **v17** | rama `ccr-37e545ac-klc1ys` (`4dd15ac`) | [ZIP de la rama](https://github.com/natillaw/tactical-summoners/archive/refs/heads/ccr-37e545ac-klc1ys.zip) | **D-143/D-144:** tiempo (pueblo 20 min = 1 día, torre 20 min = 2 días), sin "Pasar día", 1 obra por constructor; pociones solo de alquimia con CD 5 min y tecla D del Máster; comidas según nivel de cocina; 6 joyas nuevas y 8 trinkets con pasiva por clase; pueblo con cámara en el Máster (clic camina, F entra, Máster visible dentro); crafteo solo por encargo (básicos automáticos) | **35/35 PASS** — [ejecución](https://github.com/natillaw/tactical-summoners/actions/runs/41499142215) (Godot 4.7.2, CI) |
| **v18** | rama `ccr-8a10e84a-r95vxi` | [ZIP de la rama](https://github.com/natillaw/tactical-summoners/archive/refs/heads/ccr-8a10e84a-r95vxi.zip) | **D-145:** telegrafías en cono, línea y círculo; bolas de fuego, flechas y meteoros visibles al soltarse; juice propio de ataques enemigos; barras de vida de criaturas con estela | **35/35 PASS** — [ejecución](https://github.com/natillaw/tactical-summoners/actions/runs/41496667638) |
| **v19** | rama `main` | [ZIP de main](https://github.com/natillaw/tactical-summoners/archive/refs/heads/main.zip) | **D-146:** consola de desarrollo (tecla bajo Esc, `/key`, `/help`): god, fly, pisos goto/reset/respawn, objetivos, spawn, IA, niebla, pueblo, quicksave aparte; partida marcada "cheated" (save v21) | Local Godot 4.7.2 Linux: **36/36 PASS** (`tools/last_test_run.txt`) |

## Qué probar a mano en cada versión (en Windows, con el editor o F5)
### v1 (estado original, como referencia)
- Al abrir el Sandbox **no aparecen héroes** y sale un error en la consola (F-038, confirmado en GitHub).
- "Living Headquarters → Explore Base" da error (F-001).

### v17 (D-143, D-144)
1. Pueblo: la cámara sigue al Máster. Clic en el suelo = camina; clic en un edificio = va a la puerta y entra (o F en la puerta). Dentro se ve al Máster.
2. Ya no hay botón "Pasar día". Un día de pueblo dura 20 min reales; 20 min en la torre = 2 días.
3. Alquimia: sin encargo no fabrica nada. Libro de recetas → Crear: el alquimista lo hace con tiempo y materiales.
4. En un piso: con poción en la mochila, D cura al Máster; otra vez antes de 5 min dice el tiempo que falta.
5. Cocina nivel 3: aparece el caldo de hueso; nivel 4, el festín.
6. Joyería: nuevas joyas y runas; el tooltip de una runa muestra su pasiva y su clase.
7. Dos obras a la vez con un solo constructor: la segunda se rechaza.
### v18 (D-145)
1. Piso con brutos: su golpe marca un cono delante; el Slam un cono grande. Arqueros: una línea; magos bandidos: círculo y bola de fuego que vuela.
2. Al terminar la marca se ve la skill (flecha, bola, meteoro) y el daño llega al impactar.
3. Barra de vida de una criatura: baja de golpe y la parte blanca se vacía después.

### v16 (D-142)
1. Crea o invoca un héroe nuevo: en la ficha (Skills) no tiene activas, solo Q. Súbelo a nivel 2, 5 y 10: cada vez elige 1 de 3; a partir del 10 no hay más elecciones.
2. Con un pícaro/arquero/mago con Emboscada / Disparo de interrupción / Contrahechizo: corta el lanzamiento de un chamán o del jefe. Un aturdimiento ya no lo corta (solo lo pausa).
3. Con un Máster clérigo, junto a un caído: "Mantén F: Resurrección" (4 s).
4. Códice de sinergias: ya no aparecen Flanqueo, Espalda con espalda ni Muro de escudos. Marca del arquero: el objetivo se ve en la niebla.
5. Piso 10: el jefe suelta un hacha épica (morada) además de su botín. Las criaturas normales sueltan gear muy rara vez.
6. Pueblo y pisos: las frases de los héroes salen en español.

### v15 (D-141)
1. Título: "Continuar" (o "Comenzar" sin partida); ya no hay "Nueva partida". Opciones → Pantalla → Modo "Pantalla completa". Si juegas con F5 desde el editor, la ventana va incrustada y no puede ir a pantalla completa: usa `tools\Play.ps1` o desactiva "Embed game" en la pestaña Game del editor.
2. Pueblo: barra de recursos con iconos arriba, botones con nombre abajo; héroes por la plaza (fuente, bancos, emociones).
3. Construir: tarjetas con imagen. Clic en un dormitorio: camas dibujadas y residentes con cara.
4. Piso 3: camina detrás de un árbol (debe taparte); mata algo que suelte botín (icono que rebota con aura); la SALIDA es un portal y el santuario una piedra rúnica al lado.
5. Memorial, Inventario, Escuadrón y la ficha de un héroe (Resumen y Equipo).

### v13 (D-065, D-066)
1. Puerta de la Torre: arriba **The Overgrown Wilds** (repetible). Entra: mapa nuevo cada vez, sin misión; recoge (las **cachés doradas** están en las salas lejanas) y vuelve a la entrada con X.
2. Los pisos 3 y 5 aparecen bloqueados hasta subir el Salón (2 y 3). Los pisos ya no tienen puntos de recolección; al superarlos dan equipo, **acero estelar** y **esencia**.
3. En los pisos: curanderos que se pueden cortar con un aturdimiento, el portador de la reliquia lento y perseguido, vigías en el piso 4 y chamanes del jefe en el 5.
4. Pulsa **T** con un héroe seleccionado para alternar sus habilidades automáticas o manuales.

### v12
1. Empieza una partida nueva y entra al piso 1 sin mirar nada más: la primera vez debería durar unos 10-15 min explorando con niebla.
2. Piso 2: las 3 pistas están en salas distintas y alejadas.
3. Piso 1 o 4: cuando quedan 3 enemigos (o solo emboscados dormidos), aparecen marcados con un cuadrado rojo en el minimapa y el objetivo dice "marked on the map".
4. Piso 5: el objetivo dice "defeat Grove Warlord".
5. Mira si el juego va más fluido en tu Ryzen (el minimapa ya no recalcula todo el mapa en cada fotograma).

### v11
1. Abre el juego: pantalla de título con el portal. **New game** → bienvenida → la invocación se revela carta a carta (clic salta una, Skip todas) → resumen → Done.
2. Pueblo: arriba los recursos con iconos; a la derecha los botones rápidos (menú, invocar, héroes, grupo, inventario, construir, torre, memorial, pasar día). Prueba **Build** y coloca un edificio.
3. Héroes → clic en uno: pestañas Summary, Skills, Equipment (8 ranuras), Progression (ascensión, **síntesis** marcando héroes y **sacrificio** con confirmación), Profession, Relations.
4. Inventario: pasa el ratón por un objeto (▲▼ contra el héroe elegido); clic = equipar, clic derecho = reciclar.
5. Entra a un piso: abajo a la izquierda el grupo, en el centro **Q** (ataque) y **W/E/R**, a la derecha las órdenes; arriba a la derecha el minimapa (clic = mirar allí). El piso 5 tiene al Grove Warlord.
6. **Esc** abre el menú y el juego **sigue corriendo**. En Options cambia volúmenes, temblor, tamaño de ventana ×2/×3/×4 y pantalla completa.
7. Termina o escapa: pantalla de resultados con MVP.
8. Escucha la música (título, pueblo, piso, jefe, resultados) y los sonidos de los botones.

### v10
1. Entra a un piso. Cada clase golpea a su manera: el guerrero con un tajo, el pícaro con un corte curvo, el explorador lanza flechas que vuelan, el mago bolas arcanas y el clérigo golpes de maza.
2. Usa las habilidades (Q): las que tardan en lanzarse muestran un círculo mágico bajo el héroe; la bola de fuego vuela y explota, el rayo sagrado cae del cielo, la lluvia de flechas cae sobre la zona…
3. Los enemigos levantan el arma (o muerden o embisten) justo antes de golpear y se encogen al recibir daño. Las ratas, murciélagos y slimes ya no se ven cortados.
4. Quemado = llamas, envenenado = burbujas verdes, aturdido = estrellas, escudo = burbuja azul.

### v9
1. En el pueblo, arriba aparecen el **día y la hora** y los recursos. El tiempo corre (1 hora cada 30 s) o pulsa **Pass a day**.
2. Invoca héroes. Clic en la **Granja**, la **Mina**, la **Cocina**… → "Assign" para poner trabajadores. Elige qué hacen (por ejemplo, "Dig ore" en la mina, "Smelt iron" y luego "Forge a weapon" en la herrería).
3. Si un edificio no produce, aparece un **"!" rojo**; su panel dice por qué (falta material, nadie cualificado, almacén lleno…).
4. En el **Salón del Invocador** asigna constructores y luego pulsa "Upgrade" en cualquier edificio: la obra avanza con el tiempo.
5. Clic en un héroe: profesiones, hambre, fatiga y estrés, enfermedades, cama, **equipo** (Equip/Scrap desde el almacén) y bolsa (+potion).
6. Juega un piso: al volver pasa un día, aparece el botín en el resultado y algún héroe puede volver herido o enfermo → el **Hospital** (necesita un médico y medicina).
7. Botón "Move building": mueve un edificio (verde = se puede; clic derecho o Esc para cancelar).

### v8
1. Selecciona un héroe: el panel muestra sus habilidades en **Q W E R**, con su estado (lista, enfriamiento o recurso insuficiente). Debajo de la vida hay una barra de recurso (roja = Furia, amarilla = Foco, azul = Maná, verde = Aguante).
2. Pulsa Q (o el botón): las habilidades con lanzamiento muestran una barra amarilla encima del héroe; si lo aturden, se cancela y se le devuelve el coste. Si no puede usarla, aparece el motivo sobre su cabeza.
3. Un guerrero empieza sin Furia y la gana pegando y recibiendo golpes; los demás regeneran.
4. Clic en un héroe en el pueblo → sección **Skills**: si ha subido a nivel 5, 10… elige 1 de las opciones; botón "→Q" para cambiar el orden; "Read book" si tienes un libro de su clase.
5. Construye la **Biblioteca** (abajo a la derecha del pueblo, 70 materiales) y transcribe un libro de la clase que elijas (80 materiales).
6. Partidas antiguas: tus héroes conservan todo y reciben su habilidad inicial, más las elecciones de los niveles que ya tenían.

### v7
1. Selecciona héroes y prueba **A + clic** (avanzan peleando), **H** (se plantan), **F** (siguen al héroe enfocado con 1-5), **C** (se reagrupan), **X** (corren a EXTRACT sin pelear), **S** (paran). También hay botones en el panel.
2. La lista del escuadrón muestra qué orden tiene cada héroe y la agonía de los caídos.
3. Un arquero o mago no dispara a través de los árboles; si un enemigo se le pega, retrocede.
4. Cuando un enemigo marca su círculo rojo, los héroes en automático salen de él (si les da tiempo).

### v6
1. En un piso, deja que un héroe caiga: queda en el suelo con un anillo rojo y "DOWN 20s". Selecciona otro héroe y haz **clic derecho sobre el caído**: va, canaliza 2,5 s y lo levanta (si le pegan mientras tanto, se interrumpe).
2. **Clic derecho sobre un enemigo** = atacarlo (lo persigue); sobre el suelo = moverse. Aparece un anillo de confirmación.
3. Números de daño flotantes; los críticos salen en amarillo con "!".
4. Ficha del héroe (clic en el pueblo): FUE/AGI/VIT/INT/TEM, ataque físico/mágico, armadura, resistencia, crítico, cadencia.

### v5
1. Pueblo con el pack de Caz: casas con tejado de paja/teja, fuente en la plaza, farolas, árboles; muñecos de entrenamiento y diana en el cuartel, tumbas en el memorial.
2. Pisos: F1 limpiar el piso · F2 limpiar · F3 relicario · F4 limpiar · F5 rescatar aldeano · F6 explorar 3 pistas · F7 limpiar · F8 sobrevivir 75 s · F9 defender el santuario 60 s · F10 matar al Jefe Orco.
3. Al ganar con tu escuadrón real: gemas, piedras, materiales (para construir) y libros.
4. Asigna en el Ayuntamiento un chef a la cocina o un minero al taller: producen el doble (la ficha del héroe dice "Expert at").

### v4
1. En el pueblo, mira a los héroes: pasean, entran en edificios, entrenan frente al cuartel, descansan en la plaza y hablan entre ellos (bocadillos).
2. **Clic en un héroe**: ficha con retrato, stats, Trust/Obedience/Composure, personalidad, equipo, colores de cada parte del sprite, relaciones, recuerdos y qué está haciendo.
3. Tower Gate → F1…F10: cada piso es un bosque distinto (claros, senderos y muros de árboles) con criaturas según el piso (slimes, ratas, murciélagos, setas, goblins…). Pulsa **M** para ver el mapa entero.

### v3
1. Al abrir el juego aparece **el pueblo**. Arrastra para moverte, rueda para zoom.
2. Clic en un edificio: **Enter** (Summoning Circle → invocar, Barracks → héroes, War Room → escuadrón, Memorial, Town Hall → asignar trabajos y pasar turno) o **Build/Upgrade** con materiales (Alchemy Lab empieza sin construir).
3. **Tower Gate** → "Training ground" (el mapa fijo de siempre) o pisos **F1–F10**.
4. En combate deberías ver tajos, flechas, curación, explosiones y zarpazos de los packs SpritePilot.
5. El botón **Menu** lleva al menú de depuración (gemas, piedras, libros, borrar partida).

### v2
1. Menú → **Sandbox**: aparecen 5 héroes. Prueba las teclas 1-5, Tab y G, el clic izquierdo y el clic derecho.
2. El **relicario** está en la sala lejana de arriba a la derecha y la salida (EXTRACT) está en otro sitio. Recogerlo ya no termina la misión: hay que llevarlo a EXTRACT.
3. Living Headquarters → **Explore Base**: se ven los héroes en el HQ (todavía sin decorado, P-04).
4. Invocar, ver el Roster, montar el Party (5) y volver al Sandbox con tu escuadrón real.
5. Si algo falla, dime la versión, qué hiciste y qué viste (una foto de la pantalla sirve).
Aún no hay un botón para jugar los pisos de la torre. Se prueban automáticamente (suite `tower`), pero el selector de piso está en la Fase 7.

## Problemas visuales conocidos (vistos en las capturas de v2; pendientes)
- **F-039** HQ explorable: los héroes se amontonan en 5 puntos, no hay suelo/paredes dibujados y la cabecera tapa la barra superior. Se arregla junto con el diseño del HQ in-game (P-04).
- **F-040** Sandbox: con la formación cerrada, los números de ranura y las barras de vida de héroes vecinos se solapan.
