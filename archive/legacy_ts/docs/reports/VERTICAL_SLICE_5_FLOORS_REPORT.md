# Informe — Vertical slice jugable: 5 pisos + pueblo + progresión

Fecha: 2026-10-31 · Pruebas con Godot **4.6.2** y **4.7.2** · Sin repositorio Git (no hay commit ni ZIP).
Decisiones: **D-057** (construcción libre cerca del pueblo) y **D-058** (reglas del slice). Se construye sobre el trabajo de expediciones (D-051…D-056).

## 1. Qué existía antes (auditado)

| Sistema | Estado encontrado |
|---|---|
| Invocación, generación de héroes, profesiones (D-049) | Funcionaban: héroes procedurales, profesiones por vida pasada, constructor (D-048). |
| Pueblo vivo | Funcionaba (8 héroes caminando y trabajando, verificado). Parecía vacío por los motivos del informe de expediciones. |
| Edificios | Una partida nueva empezaba con **17 edificios ya construidos**. Dormitorios de 6 camas. Las parcelas de lo no construido estaban fijas en el mapa. |
| Almacén global | Existía `Game.hq_outputs` (recursos) + `stash` (equipo) + equipar/desequipar. Las pociones se llevan en la bolsa del héroe, que sale del almacén global y vuelve a él. |
| Crafting | Existía: recetas por profesión (fundir, forjar arma y armadura, medicina, pociones, antídotos). |
| Expediciones | **No daban XP** (la única fuente eran los libros). Sin drops de criaturas, sin recolección, sin escape voluntario, sin MVP. La recompensa era una lista fija al completar. |
| Promoción | Instantánea pagando "stones", sin edificio ni azar. |
| Entrenamiento | "Train" = libros por XP. Sin entrenamiento de habilidades. |

## 2. Problemas encontrados

1. Una cuenta nueva no tenía flujo de bienvenida: el pueblo salía vacío y sin explicación.
2. Había progresión que no se podía jugar: sin XP de expedición nadie llegaba a nivel 10.
3. El pueblo inicial lo tenía todo construido, así que la Torre no alimentaba nada.
4. Las parcelas reservadas impedían colocar edificios libremente.
5. Las migraciones de guardados viejos leían los niveles iniciales **actuales**. Al cambiarlos, los guardados antiguos habrían perdido edificios. Corregido con `TownTables.PRE_SLICE_TOWN`.

## 3. Qué se corrigió o construyó

| Área | Archivos |
|---|---|
| Bienvenida + 10 summons | `scripts/ui/welcome_screen.gd`, `Game.starter_summons()`, banner `starter` (`summon_config.gd`), `main.gd` (cuenta nueva → bienvenida) |
| Pueblo inicial y dormitorios | `TownTables` (niveles iniciales, camas `[0,5,7,9,11,13]`, `dorm_4`, `training_grounds`, `ascension`) |
| Construcción libre | `Game.place_and_build`, `placement_block` con cercanía, `TownMap.is_placed`, menú **Build** y fantasma en `town_screen.gd`, `town_view.gd` |
| Recursos, drops, recolección | `EconomyDefs.RESOURCES` (8 drops) y `NODES`, `EnemyDefs.DROPS`, `GatherNode`, `ProceduralMap.resource_nodes` (en el snapshot) |
| Escape y resultados | `SandboxScreen.extract()` / `extract_block()`, `Mission.ESCAPED`, registro de botín, `Game.finish_expedition`, pantalla de resultados |
| MVP y XP | `scripts/core/expedition_results.gd`, `ProgressionDefs`, `SandboxHero.contrib` / `credit()` |
| Ascensión y entrenamiento | `Game.attempt_promotion` / `promotion_chance` / `promotion_block`, `train_skill` / `training_options`, `HeroData.luck()`, `ascension_fails`, `trained_skills` |
| Pisos 1–5 | `TowerExpedition.FLOORS` (misión, jefe, nodos, intro); botones con información en la puerta de la torre |
| Guardado | v10: `onboarded`, campos nuevos del héroe, snapshot de pisos; los guardados existentes se marcan `onboarded` |

## 4. Nueva partida

`Game.new_game()` deja `onboarded = false` y 0 héroes. `main.gd` abre `WelcomeScreen`: 4 frases (eres el Maestro; la Torre es peligrosa y quien cae ahí no vuelve; los invocados y el pueblo crecen; "The rest, you will have to find out for yourself."). Después, "Begin the summoning" → 10 summons → tarjetas (estrellas, clase, profesiones; el constructor resaltado) → pueblo. "Reset save" en el menú también lleva a la bienvenida.

## 5. Los primeros 10 summons

- Son summons reales (`_generate_unique` + `_accept_summon`, con registro y eventos) con el banner `starter`: **72 % 1★, 26 % 2★, 2 % 3★, 0 % 4–5★**. No consumen gemas ni tocan el pity de la cuenta.
- **Red 1, viabilidad:** si los summons que quedan ya no pueden alcanzar 4 clases de combate, una tirada que no es de combate se repite (mismas estrellas). Apariencia, personalidad, historia y profesiones siguen siendo aleatorias.
- **Red 2, constructor:** si nadie sabe construir, el héroe con menos profesiones aprende Builder (nivel 1); puede ser cualquiera, por ejemplo un plebeyo. El primer constructor empieza asignado a la obra.
- Solo ocurre una vez por cuenta (`onboarded`).

## 6. Dormitorios y capacidad

5 camas por dormitorio a nivel 1 (7/9/11/13 en niveles siguientes), 2 dormitorios iniciales: **capacidad 10**, que los 10 summons llenan. Para invocar más hace falta construir o mejorar dormitorios (`dorm_3` con el Hall de nivel 1, `dorm_4` con el de nivel 2). Un héroe muerto sale del registro y del pueblo (probado). Los que están de expedición pasan el día fuera (`deployed`).

## 7. Inventario global

Un solo inventario del Maestro: `hq_outputs` (recursos, drops, consumibles) + `stash` (equipo). Equipar va del stash al héroe y desequipar, del héroe al stash. El botín de la expedición se acumula en un registro temporal que se vuelca a `hq_outputs` al volver. Los héroes no tienen mochila de recursos; la "bolsa" solo lleva pociones y antídotos sacados del inventario global y devueltos a él.

## 8. Recursos

- **Básicos:** ore, stone, wood, herb, grain (además de materials, ingot, food, medicine, potion, antidote).
- **Drops de criaturas:**
  - hide, fang (rata, murciélago)
  - gel (slimes)
  - spore (setas)
  - silk, venom (araña)
  - bone (goblin, hobgoblin, orco)
  - core (gólem, jefe)
- **Nodos de recolección:** vetas de mineral, troncos y matas de hierbas en salas de pisos v2 (6 en el piso 1, 12 en el piso 2). Un héroe al lado y fuera de combate recolecta en 1,5 s; los exploradores autónomos van a por los nodos visibles cercanos. Los nodos reaparecen en cada expedición (el mapa es persistente; los recursos, no).

## 9 y 10. Edificios y cómo funcionan

| Edificio | Requisito | Qué hace |
|---|---|---|
| Summoner's Hall, círculo de invocación, puerta de la torre, 2 dormitorios | Iniciales | Corazón (limita niveles y asigna trabajo), invocar, entrar a la torre, camas |
| Herrería | Hall 1, 40 materiales | Un **herrero** funde mineral en lingotes y forja armas y armaduras (nivel ≥1 / ≥2). Un aprendiz no puede forjar (probado) |
| Cocina, granja, aserradero, mina, taller, almacén | Hall 1 | Producción existente por profesión |
| Training Grounds | Hall 1, 60 | Entrenamiento de habilidades (§14) |
| Laboratorio de alquimia | Hall 1, 60 | Un **alquimista** prepara pociones, antídotos y medicina con hierbas |
| Hospital, taberna | Hall 1 | Existentes |
| Santuario de Ascensión | Hall 2, 90 | Promoción (§15) |
| Biblioteca, dormitorio 4 | Hall 2 | Existentes / capacidad |

- **Construcción:** el menú **Build** (barra superior del pueblo) lista lo no construido con su precio y lo que lo impide. Eliges el edificio y un sitio a ≤3 celdas de otro edificio (fantasma verde/rojo), se pagan los materiales y los constructores lo levantan (6 h de constructor por nivel; el reloj del pueblo avanza 30 s reales por hora o 24 h por expedición). Construir es imposible sin constructor asignado (D-048).
- **El pueblo importa sin bloqueos:** nada impide entrar a un piso. Sin herrería no hay equipo nuevo; sin alquimia, menos pociones; sin santuario, nadie pasa de nivel 10 en 1★; sin dormitorios, no hay más héroes.

## 11. Los 5 pisos

Procedurales v2, con semilla por cuenta y snapshot persistente (D-026). Bioma bosque (D-031). Conocidos antes de entrar: la puerta de la torre muestra nombre, misión, dificultad, si ya se completó y, en el tooltip, la intro, los héroes recomendados (5) y si se ha explorado.

| Piso | Misión | Identidad |
|---|---|---|
| 1 Forest Edge | combat (fácil) | Introducción: niebla, primeros grupos (slime, ratas, seta curandera), 6 nodos |
| 2 Mossy Trail | **exploration** (encontrar 3 marcadores) | Más grande, 12 nodos (madera y mineral): "la torre alimenta el pueblo" |
| 3 Mushroom Hollow | **retrieval** (encontrar la reliquia, llevarla a la salida y escapar) | Variación de misión, arañas a distancia |
| 4 Goblin Camp | combat (normal) | Grupos de goblins con arqueras y curanderas: el equipo, las pociones y el entrenamiento se notan |
| 5 Warlord's Grove | **boss** (difícil) | El **Goblin Warlord** (hobgoblin jefe) espera en el objetivo con su guardia, tras 28 criaturas |

El jefe usa `boss_name` del piso (`make_boss(name)`): en el piso 5 aparece como "Goblin Warlord".

## 12. Extracción

Botón **Extract** en el panel de órdenes. Se puede escapar cuando todos los héroes en pie están a ≤1,8× el radio de extracción (la entrada). Los caídos lejos de la salida se quedan atrás y mueren (D-036). Al escapar se conserva el botín de recolección y drops, pero no hay recompensa de finalización, ni completado del piso, ni XP de finalización, ni MVP. Sí se conserva la XP de las criaturas abatidas. Si cae todo el escuadrón, el botín se pierde.

## 13. MVP y XP (`ProgressionDefs`, `ExpeditionResults`)

- **Contribución por héroe:** daño, eliminaciones, curación, escudos, rescates, celdas descubiertas (fog), objetivo (reliquia, marcadores, santuario), recolección y daño recibido. Cada categoría se normaliza por el total del escuadrón y se pondera (curación 1,0, objetivo 1,0, daño 1,0, exploración 0,7…). Así, un clérigo o un explorador pueden ser MVP (probado: un curandero gana a quien hizo 6 eliminaciones).
- **XP de cada superviviente** = finalización (solo al completar: 80 + 60 × piso) + parte de la XP de las criaturas (Σ vida máx. × 0,2), repartida en un 60 % a partes iguales y un 40 % según contribución.
- **Bonus del MVP** = lo que le falta para su siguiente nivel en la curva (`40 + 6·nivel²`), con un tope de 3× la XP de finalización. Equivale a "un nivel" sin romper la curva.
- **Medido** (`smoke_slice`): piso 1 completado con 5 héroes de nivel 1 → todos pasan a nivel 3–4; MVP +45 XP.
- Los héroes caídos no reciben XP.

## 14. Entrenamiento

Training Grounds, solo para héroes de **2★ o más**: por cada estrella por encima de 1 pueden aprender **una** habilidad de su clase, **eligiendo** entre 3 ofrecidas (deterministas por héroe; coste: 25 materiales + 1 lingote). Los de 1★ crecen por experiencia. Las elecciones de habilidad al subir de nivel (D-045) y los libros (D-046) siguen igual. Arquitectura preparada para alas por clase: un solo edificio por ahora.

## 15. Promoción (ascensión)

En el **Santuario de Ascensión**, con el héroe al nivel máximo de su rango (1★: nivel 10) y materiales de la torre: 1→2★ pide 30 materiales, 4 pieles, 3 geles y 2 sedas (pisos 1–3). Los rangos siguientes piden huesos, esporas, veneno, núcleos y lingotes. El botón "Ascend (N %)" del panel del héroe muestra la probabilidad, la Suerte y lo que falta.

## 16. Azar y protecciones

| Azar | Protección |
|---|---|
| Estrellas de los primeros summons | Banner fijo sin 4–5★; mínimo 4 combatientes; constructor garantizado |
| Ascensión | Probabilidad = 50 % + 3 % × Suerte (1–10, fija por héroe, derivada de su semilla) + 4 % por nivel del santuario + 15 % por fallo previo. **Tras 3 fallos seguidos, éxito seguro.** Un fallo nunca quita niveles y devuelve el 50 % de los materiales de la torre. La Obediencia no interviene |
| Drops | Probabilidad por recurso y criatura (datos) |
| Esquiva autónoma | D-052 (≈0 a nivel 1) |
| Críticos | D-037 |

## 17. Pruebas ejecutadas

- `tests/smoke_slice.tscn`: **41/41**. Cubre:
  - cuenta nueva y bienvenida;
  - los 10 summons, el constructor, combatientes, sin 4–5★, una sola vez, capacidad 10;
  - colocación lejos rechazada, colocación cerca y construcción en ese sitio;
  - expedición al piso 1 con escape: drops + nodo en el registro, sin completar, botín conservado, sin MVP;
  - expedición completada: recompensa, MVP con bonus, XP para todos, pantalla de resultados;
  - MVP curandero;
  - aprendiz frente a herrero en la forja;
  - ascensión: santuario, probabilidad, pity, ascenso a 2★;
  - entrenamiento: 1★ bloqueado, 2★ elige 1 de 3, límite;
  - guardar y cargar todo.
- Pruebas antiguas adaptadas al nuevo inicio, sin bajar su exigencia:
  - `test_hq`, `test_deep_systems` y `test_simulation` preparan el pueblo completo (`debug_full_town`), porque prueban la producción, no el inicio.
  - `test_town` prueba el bloqueo del Hall con la biblioteca, porque la alquimia ahora pide Hall 1.
  - `smoke_tower` hace clic en la puerta de la torre.
- Batería completa (`tools/Run-Tests.ps1 -Godot <Godot 4.7.2>`): **23/23 PASS**, incluidas `expedition` y `slice`.
- Capturas con ventana (`tests/capture_slice.tscn`), revisadas: bienvenida, tarjetas de los 10 summons (3 constructores salieron de forma natural), pueblo inicial con el menú Build y el fantasma de colocación, piso 1 con niebla y pantalla de resultados (botín, recompensa, MVP, XP).
- Aviso inofensivo en el log: "Camera2D overridden to physics process mode". Lo emite la cámara del pueblo saliente al activarse la interpolación de la misión.

## 18. Qué no se pudo probar

- **Jugar el bucle completo a mano** con ventana (bienvenida → 5 pisos): las pruebas llaman a las mismas funciones que la UI, pero no hacen clic en la UI de Build ni en Ascend/Train.
- La duración real de los pisos 1–5 con un jugador humano.
- El equilibrio: cuántas expediciones hacen falta para nivel 10 (estimación: unas 8–10 de los pisos 1–3) y si la economía de comida aguanta sin cocina.
- La alquimia no se probó de nuevo de punta a punta en este slice; existía y la cubre `test_hq`. Solo cambió su requisito de Hall (de 2 a 1).

## 19. Pendiente para los pisos 6–100

- Ajustar los pisos 6–10 (siguen accesibles sin tocar), los biomas siguientes (P-03), los raids de 10 y las arenas.
- Alas de entrenamiento por clase y subclases; habilidades secretas o de misión.
- Calidad de crafteo según nivel del artesano y del edificio (la arquitectura existe; no hay herramientas ni calidad de material).
- Recursos de nodos persistentes o agotables según diseño; puntos de interés con lore y secretos.
- Pantalla de resultados con arte (hoy es texto bien organizado) y retratos del MVP.
- Una pantalla de opciones (shake, etc.).
- Migración a 7★ / 70 niveles (D-029): los costes de ascensión ya están por estrella destino.
