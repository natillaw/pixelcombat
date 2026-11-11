# Investigación — Cuartel general, profesiones, construcción y vida del pueblo

Fecha: 2026-10-30. Estado: **investigación y propuesta**. Nada de este documento está implementado salvo lo que la §1 marca como "existe".

## 0. Cómo se hizo y qué límites tiene
- **Fuentes consultadas.** Solo se usó la búsqueda web; sus resúmenes citan los wikis de la comunidad. Al intentar abrir directamente las páginas (`clashofclans.fandom.com`, `darkestdungeon.wiki.gg`), la red de la sesión las bloqueó (`ENOTFOUND`).
  - Por eso lo marcado como **[confirmado]** procede de esos resúmenes de búsqueda, con la fuente enlazada.
  - Si quieres que lo verifique página a página, hay que añadir esos dominios a la lista permitida del entorno.
- **Etiquetas:**
  - **[confirmado]**: mecánica del juego de referencia según la fuente.
  - **[interpretación]**: lo que yo deduzco.
  - **[propuesta]**: idea para Tactical Summoners.
- **Fuentes consultadas** (los resúmenes de búsqueda):
  - Clash of Clans:
    - [Builder (CoC Wiki)](https://clashofclans.fandom.com/wiki/Builder)
    - [Introducción a CoC: edificios y recursos (Low End Mac)](https://lowendmac.com/2015/introduction-to-clash-of-clans-part-2-buildings-and-resources/)
    - [Lista de niveles máximos TH18](https://clashguideswithdusk.net/2026/07/th18-max-levels-list-clash-of-clans/)
    - [Blog oficial "Battle Builders"](https://clashofclans.com/blog/game-updates/battle-builders.html)
    - [Guía del 6.º constructor](https://afkgaming.com/gaming/general/clash-of-clans-how-to-unlock-the-6th-builder)
  - Darkest Dungeon:
    - [Sanitarium](https://darkestdungeon.wiki.gg/wiki/Sanitarium)
    - [Disease](https://darkestdungeon.wiki.gg/wiki/Disease)
    - [Quirks](https://darkestdungeon.wiki.gg/wiki/Quirks)
    - [Town](https://darkestdungeon.wiki.gg/wiki/Town)
    - [Creeping Cough](https://darkestdungeon.fandom.com/wiki/Creeping_Cough)
    - [Gamepressure: Sanitarium](https://gamepressure.com/darkestdungeon/sanitarium/z575b7)
  - RimWorld:
    - [Work](https://rimworldwiki.com/wiki/Work)
    - [Skills](https://rimworldwiki.com/wiki/Skills)
    - [Passion](https://rimworldwiki.com/wiki/Passion)
    - [Incapable](https://rimworldwiki.com/wiki/Incapable)
  - Dwarf Fortress:
    - [Bedroom design](https://dwarffortresswiki.org/Bedroom%20design)
    - [Room (DF2014)](https://dwarffortresswiki.org/DF2014:Room)
    - [Job](https://dwarffortresswiki.org/Job)
- **Pendiente de investigar** con acceso a la web completa:
  - La tabla oficial de niveles máximos por Ayuntamiento de CoC.
  - Las cifras exactas de estrés del Darkest Dungeon original.
  - Las necesidades de RimWorld.
  - Los detalles de los tiempos de construcción de CoC.

## 1. Qué existe hoy en el código (auditoría)
| Pieza | Estado real | Dónde |
|---|---|---|
| Edificios | Un solo modelo, D-030: 15 edificios con nivel 0 (sin construir) hasta el máximo, coste en materiales y **posición fija** en un mapa de 34×22. **No hay colocación libre.** | `scripts/data/town_tables.gd`, `scripts/sandbox/town_map.gd` |
| Construir y mejorar | Es instantáneo: paga materiales y sube el nivel. No hay constructores ni tiempo. | `Game.build_or_upgrade` |
| Recursos | `hq_outputs` = {food, materials, medicine}. Gemas, piedras y libros van aparte. **Solo se consumen los materiales** (en construcción y en la Biblioteca). Comida y medicina se acumulan sin uso. | `game.gd` |
| Producción | "Turno de HQ" manual (un botón): cada trabajador asignado produce `produces × nivel`, y ×2 si su profesión de vida pasada es "experta". Sin tiempo, sin consumo y sin límite de trabajadores. | `Game.process_headquarters_turn`, `hq_screen.gd` |
| Profesiones | Una por héroe (`profession`, vida pasada), de 20 tipos. Solo influyen en el ×2 de producción. Sin nivel ni experiencia (P-05). | `HeroTables.PROFESSIONS`, `HeroData.profession` |
| Asignación | `hq_assignment` (un edificio), `activity_state` (texto). No hay máquina de estados. | `HeroData` |
| Alojamiento | `max_hero_capacity()` = 5 + 5 × nivel de cada dormitorio. Bloquea la invocación (`can_summon`). No asigna camas. | `game.gd` |
| Héroes en el pueblo | Pasean con autonomía y van a su edificio asignado. Clic → panel del héroe. | `town_hero.gd`, `town_view.gd`, `hero_info_panel.gd` |
| Relaciones y memorias | Existen (`update_relationship`, `add_memory`). El turno de HQ las alimenta (+1 entre compañeros de edificio). | `HeroData` |
| Inventario y equipo | **No existen** (P-19). El equipo es cosmético (D-021). | — |
| Crafting, enfermedades, investigación | **No existen** (P-20). | — |
| Tiempo del pueblo | **No existe**: no hay reloj ni simulación al volver de la torre. | — |
| Duplicados | `HQWorld` ya se retiró; queda `hq_screen.gd` como pantalla de asignación. Asignar con `HQScreen` o desde el pueblo usa el mismo campo (`hq_assignment`), así que **no hay datos duplicados**, solo dos interfaces. | — |

**Conclusión:** la base actual es un **esqueleto útil**: edificios, niveles, trabajadores y un mapa con héroes vivos. Pero:
- La economía es casi decorativa: producción sin consumo y comida y medicina sin uso.
- No hay tiempo, camas, recetas, inventario, enfermedades ni investigación.

Todo lo nuevo debe **ampliar** `TownTables`, `HeroData`, `Game` y el `TownMap`, no crear sistemas paralelos.

## 2. Referencias: cómo funcionan y qué adaptamos

### A. Clash of Clans — construcción y progresión
**[confirmado]**
- El **Ayuntamiento** es el edificio central. Su nivel limita el nivel máximo de los demás edificios y desbloquea edificios nuevos.
  - Ejemplo: en TH18, Laboratory 16 y Blacksmith 10.
  - Los requisitos se muestran por nivel de Ayuntamiento.
- Los **constructores** son la capacidad de obra. Hay hasta 5 en la aldea principal (el 6.º exige condiciones especiales).
  - Se compran con gemas (monetización).
  - No hace falta tenerlos todos para subir el Ayuntamiento.
- Desde TH14 las cabañas de constructor se pueden mejorar y defienden.
- **[interpretación, estándar del género]** Cada constructor se ocupa de una obra a la vez, y la obra tarda un tiempo real. No pude confirmarlo en la página del wiki por el bloqueo de red.

**Principios que adaptamos [propuesta]:**
1. Un edificio central con identidad propia (§4.1) que fija el **techo de nivel** del resto y abre edificios nuevos. Así la progresión es legible.
2. **Capacidad de obra limitada**: el número de obras simultáneas, no la espera, es el recurso escaso.
3. Información siempre visible:
   - "Qué necesito para desbloquear X": requisito de nivel central, materiales y profesional.
   - Una vista de pueblo que resuma obras en curso, trabajadores y problemas.
4. Cada mejora debe cambiar algo **mecánico** (capacidad, receta, calidad o plazas), no solo un número.

**Qué NO copiamos:**
- Las esperas de horas o días en tiempo real.
- Acelerar con gemas.
- Comprar constructores con moneda premium.
- La defensa PvP de la base.

El tiempo de obra será **tiempo de simulación del pueblo** (§6), no tiempo del reloj real.

### B. Darkest Dungeon — enfermedad, estrés y mantenimiento
**[confirmado]**
- **Sanatorio:**
  - Trata rarezas (quirks) y enfermedades a cambio de oro.
  - Sus mejoras añaden **plazas de tratamiento** y abaratan el coste.
  - "Medical Devices" a veces cura varias enfermedades a la vez.
  - Un héroe en tratamiento de enfermedad no puede tratar rarezas esa misma semana.
- **Contagio de enfermedades:**
  - Al final de una expedición, la probabilidad es 32% − 33% × resistencia a enfermedades, con un mínimo del 5% (wiki).
  - También se contraen por ataques enemigos y por curiosidades del entorno.
  - Las enfermedades son **rarezas negativas especiales** que se curan en el Sanatorio. Las rarezas normales son rasgos.
- **Estrés:**
  - Se trata en la **Taberna** y la **Abadía**, con actividades de distinto tipo.
  - Algunos héroes **rechazan** un tipo de actividad: religiosos y no religiosos, o rarezas como "Tippler", que solo bebe.
  - La Taberna tiene más riesgo de efectos secundarios negativos, pero también más positivos.
  - Ciertas rarezas bloquean el alivio del estrés hasta curarlas.
- Un héroe que se trata **no está disponible** para la siguiente expedición.

**Principios que adaptamos [propuesta]:**
- **Enfermedad ≠ herida ≠ rasgo:**
  - La herida es corta y sale del combate (ya existe `wounded`, D-036).
  - La enfermedad dura varios días, tiene identidad y tratamiento.
  - El rasgo es la personalidad y es permanente.
- **Plazas limitadas** de tratamiento: una cama ocupada se reserva hasta el alta.
- Cada actividad de bienestar va **según la personalidad**, y los rasgos pueden excluir actividades. **El resultado no siempre es positivo** (puede haber conflictos).
- El hospital con médico cura más rápido y trata más enfermedades. Sin médico, solo hay **reposo básico**.

**Qué NO copiamos:**
- El oro como único coste.
- La tirada de enfermedad al final de cada expedición sin causa visible: aquí la causa será **un enemigo, un entorno o un evento concreto, y se mostrará**.
- Las "semanas" como turno: aquí habrá días de simulación.

### C. RimWorld / Dwarf Fortress — colonia
**[confirmado]**
- **RimWorld:**
  - Cada colono tiene **prioridades de trabajo** de 1 a 4 por tipo de trabajo. A igual prioridad, gana el que está más a la izquierda.
  - Hay un modo simple (sí/no) y un modo manual.
  - Las **habilidades** son independientes de los tipos de trabajo. Algunos trabajos no tienen habilidad (acarrear, limpiar).
  - La **pasión** multiplica la experiencia (35%, 100% o 150%) y da ánimo al trabajar en lo que gusta.
  - Hay **incapacidades**: algunos colonos nunca hacen ciertos trabajos.
  - La interfaz marca con un borde rojo al colono poco hábil.
- **Dwarf Fortress:**
  - Las **labores** se agrupan en "work details"; las labores con herramienta son exclusivas.
  - Basta una cama para dormir, pero el enano quiere **su propio cuarto**: cama, cofre y armario, unas 3 casillas.
  - La **calidad del cuarto** (valor de suelo, paredes y muebles) da pensamientos felices.
  - Dormir sin cama da pensamientos tristes.

**Principios que adaptamos [propuesta]:**
1. **Habilidad profesional ≠ puesto.** El héroe tiene niveles en profesiones; el edificio tiene **puestos** que piden una profesión.
2. **Pasión o preferencia** = afinidad del héroe por una profesión. Puede venir de la vida pasada o de un rasgo. Acelera el aprendizaje y da ánimo.
3. **Prioridades simples:** trabajo principal, trabajo secundario y descanso. Sin una matriz 1–4 de 20 columnas, porque los héroes son pocos y con nombre.
4. **Capacidad ≠ calidad en el alojamiento:** las plazas cuentan, y la calidad del dormitorio afecta al descanso.
5. **Falta de personal visible:** un puesto vacío o un trabajador sin habilidad se señalan en rojo en el panel del edificio.

**Qué NO copiamos:**
- La microgestión de acarreo y limpieza.
- Las necesidades como 10 barras.
- El diseño de habitaciones casilla a casilla: el valor del cuarto sale del nivel del edificio y de mejoras discretas.

## 3. Sistemas que tienen que conectarse
```
Torre/expediciones ──loot, materiales raros, enfermedades, libros──▶ Almacén / Hospital
Almacén ──materias primas──▶ Herrería / Alquimia / Cocina / Taller ──productos──▶ Almacén / Inventario
Inventario ──equipo──▶ Héroe (combate, D-039)        Cocina ──comida──▶ Población (necesidad) y provisiones
Hospital ◀──medicina── Alquimia      Hospital ──alta──▶ Héroe disponible
Taberna ──estrés↓ ánimo↑ relaciones (sistema existente)──▶ Héroe
Investigación ──recetas/mejoras──▶ todos los edificios        Centro de mando ──techo de niveles, desbloqueos──▶ todos
Dormitorios ──plazas──▶ límite de invocación (ya existe) + descanso
Reloj del pueblo ──ciclos──▶ todo lo anterior (sin depender de que la escena esté abierta)
```

## 4. Propuesta de diseño (resumen; las decisiones grandes están en §7)

### 4.1 El edificio central: el "Salón del Invocador" [propuesta]
- Reemplaza al Ayuntamiento actual (`town_hall`), conservando su nivel en la migración.
- Narrativa: es el círculo donde el Invocador ancla a los héroes a este mundo; cuanto más fuerte es el ancla, más puede sostener el pueblo.
- Su nivel (1–5 para el primer alcance) fija:
  - el **techo de nivel** del resto de edificios;
  - **qué edificios** se pueden construir;
  - el número de **obras simultáneas**;
  - la **expansión del terreno**, si se aprueba la colocación libre.

### 4.2 Profesiones [propuesta]
**Datos:**
- `ProfessionDefs` como tabla de datos: id, nombre, familia, edificios donde trabaja, recetas que puede hacer por nivel y atributo que la apoya.
- En el héroe, `HeroData.professions = {prof_id: {"lvl": int, "xp": int}}`.
- La vida pasada actual da el nivel inicial de esa profesión y la pasión.
- **No se crea otro HeroData.**

**Primer lote** (lo mínimo para que funcionen las cadenas del prompt): herrero, carpintero/constructor, médico, herbolario/alquimista, cocinero, agricultor/recolector, minero/leñador, investigador/erudito, tabernero.
- El resto (armero, cirujano, cartógrafo, runólogo…) se añade como datos más adelante.

**Eficiencia y calidad** (documentadas, deterministas salvo un margen pequeño de suerte):
- `eficiencia = base_puesto × (0.5 + 0.1 × nivel_prof) × herramientas × salud × (1 − fatiga/200)`.
- `calidad = nivel_prof + nivel_edificio + bonus_material + bonus_receta + d(−1..+1)`.
- La calidad se limita por la receta y por el menor de nivel_prof y nivel_edificio + 1. Así, **un edificio alto con un aprendiz no produce obras maestras**, y al revés tampoco.

**Aprender:** un héroe sin la profesión puede ocupar un puesto "aprendiz" (eficiencia 0,3, solo recetas básicas) y gana experiencia. Con maestro en el edificio, aprende más rápido.

### 4.3 Edificios del primer alcance [propuesta]
Los niveles y cifras son provisionales y van en los datos.

| Edificio | Función real | Puestos | Entradas → salidas | Qué cambia al mejorar |
|---|---|---|---|---|
| Salón del Invocador | Progresión central | Administrador (opcional) | — | Techo de nivel, desbloqueos, obras simultáneas |
| Dormitorio (pequeño/estándar/grande) | Plazas y descanso | — | Comida (mantenimiento) | Plazas 4/6/8 y calidad del descanso |
| Almacén | Capacidad por categoría y registro de entradas y salidas | — | — | Capacidad |
| Granja / huerto | Ingredientes y hierbas | Agricultor | — → grano, hierba | Rendimiento, nuevos cultivos |
| Leñera / cantera (o mina) | Madera, piedra, mineral | Leñador, minero | — → madera, piedra, mineral | Rendimiento |
| Cocina | Comidas y provisiones | Cocinero | Grano, carne → comida, provisiones | Recetas, menos desperdicio |
| Taller / carpintería | Herramientas, componentes, obra | Carpintero | Madera → tablas, herramientas | Recetas, velocidad de obra |
| Herrería | Armas, armaduras, reparación | Herrero (y armero más tarde) | Mineral, carbón → lingote → equipo | Recetas, techo de calidad |
| Alquimia | Pociones, antídotos, medicina | Alquimista, herbolario | Hierba → medicina, poción | Recetas |
| Hospital | Heridas y enfermedades | Médico (cirujano más tarde) | Medicina | Camas, enfermedades que trata |
| Taberna | Estrés, ánimo, relaciones | Tabernero, cocinero | Comida, bebida | Plazas, actividades |
| Salón de investigación | Proyectos | Investigador | Materiales, notas de la torre | Proyectos en paralelo |
| Sala de entrenamiento | Experiencia y práctica | Maestro de armas | — | Plazas, techo de nivel entrenable |
| Biblioteca (ya existe) | Libros de habilidad (D-046) | Erudito | Materiales → libro | Coste |
| Memorial (ya existe) | Recuerdo de los caídos | — | — | — |

**Decoración:** se marca explícitamente `decor: true` y no tiene función.

### 4.4 Dormitorios y población [propuesta]
**Estados del héroe** (máquina de estados única, `HeroData.activity`): `idle`, `working`, `resting`, `socializing`, `training`, `in_treatment`, `deployed` y `dead` (memorial).
- Son **exclusivos entre sí**.
- **La cama es aparte del estado:** cada héroe vivo tiene `bed` (id de dormitorio), también si está desplegado u hospitalizado.

**Reglas:**
- `capacidad = Σ plazas de los dormitorios`.
- La invocación se **bloquea** si no hay plaza libre y se explica por qué. Ya ocurre hoy, pero sin camas concretas.
- **Nunca** se expulsa ni se mata a un héroe por falta de camas.
- **Calidad** del dormitorio (por nivel): multiplica la recuperación de fatiga y da un pequeño extra de ánimo.
- Si existiera sobrepoblación por migración o eventos, el héroe sin cama duerme "en el suelo": descansa menos y su ánimo baja. Nunca se borra.

**Cifras propuestas** para el primer alcance de 10 pisos:
- Dormitorio pequeño 4 → 6 → 8 plazas por nivel.
- Con 3 dormitorios al nivel central 5 salen unos 24 héroes. Basta para varios escuadrones de 5 y trabajadores.
- Más adelante, un "Barracón" o "Residencia" de 12 plazas.

### 4.5 Tiempo y simulación [propuesta]
- **Reloj del pueblo** en días y ciclos (por ejemplo, 4 ciclos al día: mañana, tarde, noche y madrugada).
- **Cuándo avanza:** el tiempo **no** depende del reloj real. Avanza:
  1. al volver de una expedición, según la duración del piso (`elapsed` del combate × un factor);
  2. con un botón de "pasar el día" en el pueblo;
  3. opcionalmente, mientras se pasea por el pueblo.
- **Motor:** `TownSim.advance(cycles)` en `scripts/core/`:
  - es puro y determinista, con su propia semilla guardada;
  - no depende de ninguna escena;
  - procesa cada ciclo en el orden **necesidades → trabajo/producción → tratamientos → investigación → obras → eventos sociales**;
  - corre en lote (O(héroes + edificios) por ciclo), así que 100 ciclos con 60 héroes cuestan milisegundos.
- **Al volver de la torre:** un **informe** con lo que pasó (producción, altas, obras terminadas, enfermedades y eventos), con un tope de líneas.

### 4.6 Enfermedades (primer lote) [propuesta]
- Cada una se define como datos: causas, probabilidad, gravedad, efecto en atributos o derivados, días de duración, si se contagia, tratamiento (profesión, medicina, días) y qué pasa si se ignora.
- Ejemplos: fiebre del pantano (de mordiscos o del agua), infección de herida (de un héroe herido sin tratar), tos de las cuevas, intoxicación (veneno persistente) y agotamiento (exceso de trabajo y descanso).
- **Visibilidad:** la causa siempre aparece en el informe y en la memoria del héroe ("Lo mordió una rata en el piso 4").

### 4.7 Taberna, estrés y ánimo [propuesta]
- **Solo 3 valores nuevos por héroe:**
  - `stress` (0–100, sube en combate y por muertes cercanas);
  - `fatigue` (0–100, sube con el trabajo y baja con el descanso);
  - `mood`, derivado y no guardado: depende de estrés, fatiga, comida, cama, relaciones y rasgos.
- **Ya existen y no se duplican:** Composure (la serenidad en misión, D-016) y Trust/Obedience.
- **Actividades** según el rasgo: charla en grupo (sociable), rincón tranquilo (reservado), juegos y apuestas (competitivo; puede crear rivalidad) y brindis por los caídos (tras una muerte).
- Cada actividad tiene un efecto y un **riesgo determinista según los rasgos**.
- Usa `update_relationship` y `add_memory`. **Solo se guardan las memorias significativas**: por encima de un umbral de importancia, con el tope actual de 50.

### 4.8 Investigación [propuesta]
- **Proyectos independientes con requisitos**: un grafo pequeño, unos 15 en el primer alcance, en lugar de un árbol gigante.
- Cada proyecto desbloquea algo concreto: una receta, una mejora de un edificio o un tratamiento.
- Coste: días de investigador más materiales u objetos de la torre (por ejemplo, "garra de orco").

### 4.9 Arquitectura técnica [propuesta]
| Pieza | Tipo | Archivo |
|---|---|---|
| Definiciones estáticas: edificios, profesiones, recetas, enfermedades, proyectos, actividades | Tablas `const` (mismo estilo que `HeroTables`, `SkillDefs`), fáciles de pasar luego a `.tres` | `scripts/data/town_tables.gd` (ampliado), `profession_defs.gd`, `recipe_defs.gd`, `disease_defs.gd`, `research_defs.gd` |
| Estado de la partida | Diccionarios en `Game`: `town_buildings` (ampliado a `{level, pos, workers, queue}`), `storage` (sustituye a `hq_outputs`, con categorías y reservas), `town_clock`, `research`, `construction`; y en `HeroData`: `professions`, `activity`, `bed`, `diseases`, `stress`, `fatigue` | `game.gd`, `hero_data.gd` |
| Simulación | `TownSim` (estático y puro: recibe un estado y avanza ciclos) | `scripts/core/town_sim.gd` |
| Inventario único | `Game.inventory`, el mismo que usarán el loot y el equipo (P-19, D-039) | `game.gd` |
| UI | `town_screen` (mundo) y paneles por edificio. **Sin lógica económica.** | `scripts/ui/` |

**Guardado:** `SAVE_VERSION` 9 con migración. Datos que se convierten y no se pierden:
- `hq_outputs` → `storage`.
- `town_hall` → `summoner_hall`.
- `profession` → `professions[prof] = {lvl: 2}`.
- `hq_assignment` → `workers` del edificio.

### 4.10 Orden de implementación (según las dependencias reales)
1. **Núcleo:**
   - `TownSim` y el reloj;
   - el estado `activity` y la cama;
   - `storage` con registro de entradas y salidas;
   - `professions` con experiencia;
   - la migración v9;
   - las pruebas por lotes.
2. **Población:** dormitorios con plazas y calidad, y el bloqueo de invocación explicado. Va pronto porque es prioridad tuya y es pequeño.
3. **Construcción:**
   - Salón del Invocador con techo y desbloqueos;
   - obras con tiempo de simulación y límite simultáneo;
   - colocación, si la apruebas.
4. **Producción:** granja, leñera y mina → cocina, taller y herrería, con recetas y calidad. Necesita el **inventario mínimo** de P-19: preguntaré.
5. **Medicina:** enfermedades, hospital con camas, médicos y medicinas, y la conexión con la torre.
6. **Vida social:** estrés, fatiga y actividades de la taberna.
7. **Investigación.**
8. Interfaz del mundo, animaciones e informe al volver.
9. Balance: simulación de 200 días en la CI y rendimiento con 60 héroes.

## 5. Riesgos y rendimiento
- **Héroes en el mapa:**
  - Hoy cada héroe del pueblo es un nodo con pathfinding A\*.
  - Con 60 héroes hay que limitar los visibles (por ejemplo, 25 a la vez) y repartir la búsqueda de rutas entre frames, como ya se hace en combate (0,4 s).
  - **La simulación no necesita nodos.**
- **Explosión de datos:** las memorias y eventos tienen tope (50/100). El informe de vuelta se resume.
- **Economía:** hay riesgo de bucles infinitos (producir algo que se vende por más de lo que cuesta). Hay que validar en la CI que ninguna receta devuelve más valor que sus entradas.
- **Migración:** el formato actual de `town_buildings` es id → nivel. Pasar a diccionarios exige migrar con cuidado y probarlo con guardados v5–v8.
- **Alcance:** es el sistema más grande del juego. Hay que hacerlo por fases y con pruebas en cada una (D-025).

## 6. Lo que este documento NO decide
Las decisiones de la §7 son tuyas. Hasta que respondas, solo implemento lo que no depende de ellas.

## 7. Decisiones que necesitan tu aprobación (se preguntarán poco a poco)
1. **Constructores:** ¿héroes con profesión o trabajadores independientes?
2. **Profesiones por héroe:** ¿una principal y una secundaria, o varias con nivel?
3. **Tiempo del pueblo:** ¿cómo avanza? (pregunta nueva, necesaria para casi todo).
4. **Colocación libre en cuadrícula** o parcelas fijas como ahora.
5. Niveles por edificio y techo del Salón.
6. Hospital: ¿varias enfermedades a la vez?
7. ¿Contagio entre héroes?
8. Taberna: ¿actividades individuales y grupales?
9. ¿Equilibrio trabajo/descanso automático o con prioridades?
10. ¿Qué pasa con la producción cuando el trabajador se va de expedición?
11. Investigación: ¿árbol o proyectos?
12. ¿Límite de trabajadores por edificio?
13. Automatización con mucha población.
14. Edificios obligatorios u opcionales.
15. **Inventario y equipo (P-19):** ¿se diseña ya en su forma mínima para que la herrería fabrique algo real?
