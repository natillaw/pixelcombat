# Registro de decisiones — Tactical Summoners

**Autoridad máxima del proyecto.** Si otro documento contradice este, manda este. Un conflicto se reporta; no se resuelve en silencio.
**Consolidado:** 2026-10-30 desde `docs/archive/infos/docs/ai-context/DECISIONS.md` (D-001…D-022), `DESIGN_GAPS.md`, `REFERENCE_SYSTEMS.md`, `HANDOFF_LOG.md`, `SESSION_SUMMARY.md`, el prompt maestro del usuario (2026-10-30) y las imágenes de referencia. Nada se ha eliminado: lo retirado está en la sección SUSTITUIDAS.

| Estado | Significado | ¿Se implementa? |
|---|---|---|
| **CONFIRMADA** | Aprobada explícitamente por el dueño | Sí, cuando el roadmap lo indique |
| **PENDIENTE** | Idea del dueño o del proyecto que requiere decisión o detalle | **No.** Preguntar primero |
| **CANDIDATA** | Propuesta de agente o inspiración, no aprobada | No |
| **DIFERIDA** | Aprobada en principio, fuera del alcance actual | No hasta reactivarla |
| **SUSTITUIDA** | Reemplazada; solo historia | Nunca |

Qué está *implementado* no se registra aquí: ver `docs/IMPLEMENTATION_STATUS.md`.

---

## 1. CONFIRMADAS

### D-001 — Free-first (2026-10-27)
El gameplay central funciona sin APIs, suscripciones ni assets de pago. La generación procedural y el diálogo por defecto se basan en código/datos; una IA opcional nunca es dependencia del núcleo.

### D-002 — IP original
Inspiración amplia de sistemas, nunca expresión protegida. No se copian personajes, nombres, diálogos, arte, mapas, logos, música ni historia de *Pick Me Up: Infinite Gacha* (ni de otras referencias). Lista de nombres prohibidos: `docs/specs/REFERENCE_INSPIRATION.md`.

### D-004 — Identidad persistente
Todo héroe/mundo tiene ID estable. Apariencia, stats, origen e historia no se re-generan al cargar. Se guarda el resultado generado (snapshot versionado), no solo la semilla.

### D-005 — Prototipo local antes que backend
Validar el bucle localmente; mantener límites de servicio limpios para persistencia online futura.

### D-007 — Dirección de arte: pixel art 2D (actualizada 2026-10-28)
Pixel art 2D original: siluetas legibles, paleta limitada y cohesiva, telegrafías claras, UI legible, sprites modulares. Probar un héroe, un enemigo, un tileset y un panel antes de producir/importar en masa. (Sustituye la dirección 3D/low-poly.)

### D-008 — Nada de assets en masa antes de la prueba de arte
Probar primero un héroe, enemigo, arma, prop, tile e icono: estilo, escala, animación, rendimiento y licencia.

### D-009 — Flujo script-first en Godot (2026-10-27)
Escenas, nodos, configuración, setup de assets y pruebas se automatizan con scripts/CLI siempre que sea práctico. Generadores idempotentes; inspeccionar y preservar trabajo existente; verificar resultados.

### D-011 — Muerte permanente (2026-10-28)
> Excepción: el Máster (D-080) no muere; vuelve herido.
Un héroe que llega a 0 PV en misión muere para siempre en esa partida. Se preservan su registro, historia, destino del equipo y entrada en el memorial; nunca se re-genera ni se borra en silencio. Sin resurrección en el primer prototipo. Avisar antes del despliegue y definir resultados de retirada/derrota.

### D-012 — Atributos iniciales; fórmulas provisionales (2026-10-28)
Atributos: Fuerza (FUE), Agilidad (AGI), Vitalidad (VIT), Intelecto (INT), Temple (TEM). Fórmulas propuestas (placeholder para pruebas de balance): PV = 40 + 10×VIT; daño físico = poder del arma + 2×FUE; poder mágico = poder del foco + 2×INT; defensa física = armadura + floor(VIT/2); iniciativa = AGI + TEM; energía = 3 + floor(TEM/3); precisión 85% + AGI% (con tope); evasión 2×AGI% (con tope). El estrés es un medidor de combate aparte, no un sexto atributo.

### D-013 — La identidad del personaje es la primera prioridad (2026-10-28)
Personalidad, trasfondo, habilidades y recuerdos persistentes van antes que amplitud de mundo, simulación de base o volumen de contenido. La personalidad afecta reacciones, eventos de relación y reglas de comportamiento limitadas, sin quitar el control al jugador.

### D-014 — Control RTS híbrido y mapas de misión continuos (2026-10-28)
Tiempo real **sin pausa ni cámara lenta**. Héroes autónomos (navegan y atacan) + órdenes directas del jugador + activación directa de habilidades. Cámara cenital de grupo por defecto. Exploración, interacción, combate y extracción comparten mapa. Misiones con objetivos distintos de "matar a todos". Jefes con mecánicas legibles y contrajuego, no solo más PV. Las órdenes directas son fiables y nunca se deniegan por una tirada de obediencia.
> La cláusula de D-014 "generación de mundo diferida, mapa fijo" queda **sustituida por D-026** (2026-10-30).

### D-015 — Foco de cámara con 1–5 y panel contextual (2026-10-28)
> El cambio de héroe con 1-5 queda **sustituido por D-080** (2026-11-01): solo se controla al Máster.
1–5 selecciona al héroe desplegado y la cámara lo sigue suavemente; aparecen su retrato, vitales, habilidades y órdenes. La simulación nunca se pausa. `Tab` vuelve a vista de grupo; `G` selecciona el escuadrón. Ranura vacía o muerta = mensaje claro, nunca seleccionar otro héroe en silencio.

### D-016 — Trust, Obedience y Composure separados (2026-10-28)
Trust (relación a largo plazo con el comandante/compañía), Obedience (disciplina de mando a largo plazo), Composure (estado a corto plazo en misión) + vínculos/rivalidades entre pares. Se guardan y muestran desde el inicio. En el MVP solo cambios deterministas por eventos y **ningún rechazo aleatorio de órdenes normales**. Efectos de comportamiento complejos, diferidos hasta que el control sea fiable.

### D-017 — Escuadrón de cinco, definitivo (2026-10-28, usuario explícito)
El escuadrón es de 5, también en la primera vertical slice. No proponer 3. El alcance se controla con una habilidad por héroe, comportamientos placeholder y mapa simple, no recortando el escuadrón. Roster de prueba ≥ 6. Las teclas 1–5 son obligatorias.

### D-018 — Síntesis, Sacrificio y Promoción (dirección aprobada, números abiertos) (2026-10-28)
- **Síntesis:** consumir un héroe para mejorar otro; deliberadamente con pérdidas; irreversible.
- **Sacrificio:** consumir un héroe para obtener materiales (interpretación del agente: ver P-12).
- **Promoción:** subir de tier con materiales; desbloquea capacidades (ranura de habilidad, opción de clase, tope de nivel, potencial).
- La identidad nunca cambia (ID, nombre, semilla, personalidad, historia). Un héroe sacrificado va al memorial con causa "sacrificed".
- Nombres originales; todos los números configurables y versionados. Spec completa: `docs/specs/HEROES_AND_SUMMONING.md` §14.
- Memoria desbloqueada al promocionar: ver P-11.

### D-019 — "No-hands Godot" (2026-10-28, dueño)
El dueño no opera el editor de Godot. Los agentes implementan escenas, nodos, recursos, importaciones y animaciones por script (GDScript, `@tool`, Godot headless) y PowerShell para archivos/git/herramientas, y los conectan ellos mismos. El dueño solo ejecuta un comando y reporta la salida. Nunca responder "abre el editor y haz clic".

### D-020 — Las animaciones que faltan se hacen en código, sin arte nuevo (2026-10-28, dueño)
La hoja de Tiny Pixel Fantasy (576×384 por capa, 12×8 frames de 48 px) tiene: movimiento en 4 direcciones, lunge lateral de 4 frames (filas 5-6, cols 2-5), pose tumbado de 2 frames por lado (filas 5-6, cols 0-1) y poses sueltas (señalar, mano alzada, agachado). NO tiene: hit, cast, arco, ataque arriba/abajo, muerte multi-frame, correr, bloquear, interactuar ni victoria. Se construyen en código: hit = destello blanco + retroceso; muerte = frames tumbado + caída/fundido; cast/arco = poses señalar/mano alzada + proyectil o efecto aparte; ataque arriba/abajo = lunge lateral + tween. Frames dibujados a mano solo como pulido opcional posterior, solo si la EULA lo permite y para TODAS las capas.

### D-021 — Equipo: muchas armas/armaduras de varios packs; el aspecto base no da stats (2026-10-28, dueño)
- Vendrán más clases y muchas variantes de armas/armaduras, de packs adicionales.
- Ropa/pelo base del generador = cosméticos, **sin stats**. Todos los stats vienen de objetos.
- La armadura equipada **reemplaza** (oculta) la capa base correspondiente; nunca se dibuja encima. El aspecto base guardado nunca cambia.
- Cada pack nuevo necesita: misma rejilla de 48 px o un mapa de frames por pack, estilo coherente, entrada de licencia y una entrada de datos por objeto (id, slot, archivo de capa, stats, clases permitidas).
- Abierto: ver P-14.

### D-023 — Los sprites originales de héroes no se modifican (2026-10-30, dueño; prompt de auditoría §6)
Los sprites de héroes son de **Tiny Pixel Fantasy – Character Generator by Caz**. No se reemplazan, redibujan ni modifican destructivamente (`assets/sprites/**`). Las mejoras preservan su identidad visual y se hacen con animaciones compatibles, efectos, interacciones y retratos derivados.

### D-024 — Solo assets gratuitos y con licencia registrada (2026-10-30, dueño)
Todo recurso nuevo debe ser gratuito, con su licencia leída y registrada en `docs/ASSET_REGISTRY.md` antes de usarse. (Refuerza D-001 y D-008.)

### D-025 — Estabilizar antes de ampliar (2026-10-30, dueño)
No se añaden sistemas nuevos encima de la base actual hasta reparar los errores de la auditoría (`audit/`) y tener pruebas ejecutadas con evidencia. Orden: memoria del proyecto → reparar el juego → construir lo que falta. Nada de reescrituras completas sin justificación demostrada.

### D-026 — Pisos de la torre generados proceduralmente (2026-10-30, dueño; resuelve P-01)
Los pisos de la torre se generan proceduralmente. Reglas obligatorias: semilla + versión del generador, validación de navegación y **snapshot persistido** (D-004; nunca regenerar un piso guardado con otro generador). Sustituye a D-003 y a la cláusula "mapa fijo" de D-014. Referencia visual: `docs/specs/reference/procedural_map_reference.jpg`. Biomas: siguen PENDIENTES (P-03).

### D-027 — Torre de 100 pisos; los pisos 1-10 son el primer alcance (2026-10-30, dueño; resuelve P-02)
La meta es una torre de 100 pisos. El primer alcance jugable son los pisos 1-10, con un jefe en el piso 10. Siguen abiertos: progreso y repetición de pisos, recompensas, desbloqueos cada 10 pisos (P-02b) y el diseño del jefe (P-25).

### D-028 — Clases base: las del código (2026-10-30, dueño; resuelve P-06)
Commoner, Warrior, Rogue, Ranger, Cleric y Mage (más Novice como estado "sin clase"). La biblioteca de habilidades (P-10) deberá adaptarse a estas clases; Thief, Spearman y Archer quedan como nombres antiguos (sus habilidades se conservan como ideas para reasignar). Clases avanzadas: siguen PENDIENTES (P-07).

### D-029 — 7 estrellas y 70 niveles (2026-10-30, dueño; resuelve P-08)
7★ con 70 niveles: una estrella por cada 10 niveles (star_gate = ceil(nivel/10), como en la biblioteca de habilidades). Sustituye a la escala del código (5★, topes 10/20/40/60/80). Implementarlo exige cambiar `HeroTables.MAX_STARS`/`STAR_DATA`, las odds de los banners (7 entradas), los colores de estrella, la migración de guardados (subir `SAVE_VERSION`) y las pruebas. Es una tarea de la Fase 5, no antes de la reparación (D-025). Nombres de rareza: siguen PENDIENTES (P-09).

### D-030 — El juego empieza en el pueblo; el pueblo se construye (2026-10-30, dueño; resuelve P-04 y parte de P-22)
Lo primero que ve el jugador es **la base = el pueblo**, no un menú. Desde el pueblo se hace todo lo demás (invocar, héroes, escuadrón, torre, memorial, gestión). El pueblo es un **mapa fijo y persistente** (siempre el mismo). Se **construye y mejora** con edificios: herrería, hospital, alquimia, etc. Implementación inicial (v3): vista cenital como el resto del juego (el estilo isométrico de la imagen de referencia queda como opción futura), edificios definidos en `scripts/data/town_tables.gd`, coste en materiales, niveles 0 (sin construir) a máx. Efectos concretos de herrería y alquimia esperan al equipo/crafting (P-19, P-20); bonus por profesión sigue PENDIENTE (P-05).

### D-031 — Pisos 1-10 desbloqueados y con bioma de bosque (2026-10-30, dueño; resuelve P-03 para 1-10 y P-02b por ahora)
Todos los pisos 1-10 están desbloqueados (son los que hay por ahora). Bioma: **bosque**, "nada loco". Implementación (v4): claros de hierba con flores, senderos de tierra en los pasillos, muros de árboles; criaturas de bosque del pack Voxel Dungeon por piso (slimes, ratas, murciélagos, arañas, setas, goblins, hobgoblins, orcos, gólems; jefe orco en el piso 10). Tamaños de piso reducidos a 40-60 celdas para que sean jugables y ligeros. Progreso real de la torre (desbloqueo, recompensas por piso) sigue PENDIENTE (P-02b).

### D-032 — Héroes con autonomía total en el pueblo; ficha al hacer clic (2026-10-30, dueño)
En el pueblo cada héroe decide qué hacer (pasear, visitar edificios, entrenar, trabajar, descansar, charlar), según su personalidad y su trabajo. Es solo visual hasta que existan los sistemas de entrenamiento, etc. Al hacer clic en un héroe se abre su ficha: equipo, colores, stats, personalidad, relaciones, recuerdos y actividad actual.

### D-033 — Progreso rápido de torre y profesiones expertas (2026-10-30, dueño: "sí")
- Completar un piso da recompensa (gemas, piedras, materiales, libros; números provisionales en `Game.complete_floor`) y queda registrado (`tower_cleared`). Todos los pisos 1-10 siguen desbloqueados.
- Profesiones: un experto produce ×2 en su edificio (cocina: chef/granjero/pescador/cazador; taller: leñador/minero/cantero/constructor/ingeniero/herrero; hospital: médico/sacerdote/alquimista; taberna: artista/mercader). Tabla en `TownTables` ("experts").
- El dueño pide un **sistema de profesiones mucho más sólido**: esta es solo la primera capa; el diseño completo sigue PENDIENTE (P-05).

### D-034 — Misiones por tipo de piso (2026-10-30)
Implementados 7 tipos (combate, recuperación, rescate, exploración, supervivencia, defensa, jefe) según `TowerExpedition`. El jefe del piso 10 (Jefe Orco) es la primera versión: más vida, golpe telegrafiado más amplio y lento; fases y mecánicas de arena (P-25) siguen pendientes.

### D-035 — Atributos híbridos (2026-10-30, dueño; resuelve C-2 del combate)
FUE/AGI/VIT/INT/TEM son la base de cada héroe (perfil por clase + crecimiento por nivel + estrellas + variación personal + rasgos). Los stats de combate se **derivan** de ellos en un solo sitio (`CombatRules.derive`): vida (40 + 10×VIT), poder físico (2×FUE + arma de clase), poder mágico (2×INT + foco de clase), armadura, resistencia mágica (TEM), velocidad y cadencia (AGI), probabilidad de crítico (AGI), energía (3 + TEM/3) y resistencia a estados (TEM). Los héroes existentes se migran automáticamente (los atributos se calculan desde sus datos guardados, sin nueva tirada).

### D-036 — Incapacitación, agonía y rescate (2026-10-30, dueño; resuelve P-13 y matiza D-011)
A 0 PV un héroe **cae** (no muere): agonía visible de 20 s. Otro héroe con la orden **Rescue** (clic derecho sobre el caído) lo levanta tras 2,5 s de canalización, que se interrumpe si el rescatador recibe daño o se aleja; vuelve con el 25 % de vida y el estado **Herido** (−20 % de vida máxima durante el resto de la misión). Si la agonía expira, muerte permanente (D-011 sigue vigente). Golpes recibidos en el suelo restan 5 s de agonía. Si todo el escuadrón cae, la misión fracasa y los caídos mueren. Rematar caídos: no por ahora (opción descartada).
> Matizada por D-082 (2026-11-01): agonía de 120 s, levantar en 4 s manteniendo F junto al caído (el Máster) o por iniciativa de la IA; ya no con clic derecho.

### D-037 — Azar: solo críticos (2026-10-30, dueño; resuelve C-1)
Los golpes que alcanzan siempre conectan: sin fallos ni variación de daño. Hay críticos con probabilidad (base 5 % + AGI; luego equipo) y multiplicador ×1,5, mostrados con número grande. La esquiva aleatoria de D-012 queda descartada.

### D-038 — Pushes de la rama autorizados (2026-10-30, dueño)
Commit + push solo a la rama de trabajo de Claude cada vez que se termina un bloque, para que GitHub ejecute pruebas y capturas. Nunca merge a `main` sin permiso.

### D-039 — Ranuras de equipo y raids (2026-10-30, dueño, prompt de combate)
- Ranuras: arma principal, arma secundaria o escudo (las armas a dos manos ocupan ambas), casco, pechera, guantes, pantalones, botas, 2 anillos, amuleto y accesorio especial. Al morir, el héroe pierde su equipo con él. Los legendarios y míticos tienen identidad y efectos propios. (Implementación en la fase de progresión; sin valores inventados.)
- El grupo habitual es de 5 (D-017); habrá encuentros especiales (raids) de hasta 10 héroes. La arquitectura no debe fijar el tamaño del grupo en 5 en más sitios.

### D-040 — Teclas de combate (2026-10-30, dueño; resuelve C-6)
Habilidades en **Q/W/E/R**. Órdenes: **A** atacar avanzando, **H** mantener posición, **F** seguir, **C** reagrupar, **X** retirada, **S** parar, **M** mapa; 1-5 / Tab / G sin cambios. Todas las órdenes tienen también botón en el panel. Clic derecho contextual (atacar / rescatar / mover).

### D-041 — Recurso de habilidades por clase (2026-10-30, dueño)
Cada clase gestiona su propio recurso, además de los enfriamientos: **Furia** (Warrior: sube al golpear y al recibir daño, baja fuera de combate), **Concentración** (Rogue y Ranger: se regenera de forma constante), **Maná** (Mage y Cleric: reserva grande según INT/TEM, regeneración lenta). Commoner/Novice usan **Aguante** (como la Concentración) de forma provisional. Números en datos.

### D-042 — Interrupciones solo por control (2026-10-30, dueño)
Una carga o canalización (de héroes, enemigos o jefes) solo se corta con aturdimiento, empuje o habilidades marcadas como "interrumpir". El daño normal no interrumpe. Excepción ya decidida: el rescate (D-036) sí se corta al recibir daño.

### D-043 — Los héroes nacen con 1 habilidad activa (2026-10-30, dueño; matiza D-022)
Cada héroe empieza con **una** activa de su clase. Las demás (hasta 4 activas en Q/W/E/R, más la definitiva de D-022 en el futuro) se **aprenden**: al subir de nivel, entrenando y con **libros de habilidades**, entre otras vías. Las habilidades aprendidas se guardan en el héroe. (El entrenamiento y los libros de habilidades llegarán con sus sistemas; el aprendizaje por nivel, en la fase 3.)

### D-044 — Habilidad inicial al azar dentro de la clase (2026-10-30, dueño)
Cada clase tiene un grupo de habilidades "de inicio"; el héroe recibe una elegida con su semilla (RNG aparte, sin alterar el resto de la generación, D-004). Los héroes ya guardados reciben la suya con la misma regla al cargar.

### D-045 — Aprender por nivel = elegir 1 entre 2-3 (2026-10-30, dueño)
En ciertos niveles (5, 10, 20 y siguientes) el héroe ofrece 2-3 habilidades de su clase y el jugador elige una; las no elegidas se pueden aprender después con libros o entrenamiento. Las elecciones pendientes se guardan.

### D-046 — Fuentes de libros de habilidades (2026-10-30, dueño)
Botín de la torre (el jefe del piso 10, uno garantizado), un edificio nuevo del pueblo (**Biblioteca**: materiales → libro de la clase elegida), recompensas fijas de algunas misiones (rescate, exploración) y **secretos** (habilidades secretas que solo se aprenden por eventos o descubrimientos).

---

### D-047 — Tiempo del pueblo mixto (2026-10-30, dueño)
El reloj del pueblo corre despacio mientras el jugador está en el pueblo y salta por días al volver de la torre. Sin esperas de tiempo real fuera del juego ni aceleración con gemas. Detalle técnico en `docs/design/HQ_PROFESSIONS_RESEARCH.md` §4.5 (simulación por ciclos, independiente de la escena).

### D-048 — Solo construyen héroes con profesión de constructor (2026-10-30, dueño)
Cada obra (construir o mejorar) necesita un héroe asignado con la profesión de constructor (principal o secundaria). El número de obras simultáneas = constructores disponibles. Riesgo anotado: al empezar sin ningún constructor el pueblo queda bloqueado; se preguntará cómo evitarlo.

### D-049 — Profesión principal + secundaria (2026-10-30, dueño; matiza P-05)
Cada héroe tiene como máximo 2 profesiones con nivel y experiencia. Cambiar exige olvidar una. La vida pasada se convierte en la profesión principal inicial.

### D-050 — Colocación libre en cuadrícula (2026-10-30, dueño; matiza D-030)
Colocar, mover y demoler edificios sobre una cuadrícula con vista previa válida/inválida, comprobación de espacio y de un camino libre hasta la puerta. Los edificios actuales conservan su sitio al migrar. El terreno se amplía con el edificio central.

---

### D-051 — Obediencia mínima para órdenes y control (2026-10-30, dueño; matiza D-016)
Un héroe con **Obediencia por debajo de un umbral** (dato: `CombatRules.OBEY_MIN`, 25) **no acata órdenes directas ni se deja controlar**: actúa en autónomo y la UI dice por qué. Es determinista, nunca una tirada: sigue valiendo que las órdenes "no se rechazan al azar". Por encima del umbral, las órdenes se cumplen siempre.

### D-052 — La esquiva automática es una tirada pequeña según AGI y nivel (2026-10-30, dueño; acota G-07)
La IA ya no sale siempre de los círculos telegrafiados. Por cada golpe telegrafiado que le apunta, el héroe autónomo tira **una vez** contra una probabilidad derivada de AGI y nivel (`CombatRules.auto_dodge_chance`), que es **≈0 a nivel 1** y baja en el early game. Si falla, recibe el golpe. Mover al héroe a mano sigue siendo la forma fiable de esquivar. No contradice D-037: un golpe que alcanza siempre conecta; lo que se tira es si el héroe reacciona.

### D-053 — Enfocar es controlar (2026-10-30, dueño; matiza D-015)
> Sustituida en cuanto a 1-5 por D-080 (2026-11-01): el único héroe que se toma bajo control es el Máster.
1-5 (y Shift+1-5 para 6-10 en raids) enfoca **y toma el control directo** de ese héroe: el clic derecho mueve o ataca solo con él, Q/W/E/R usan sus habilidades apuntadas al cursor y su autonomía deja de contradecir al jugador (no esquiva ni se aparta por su cuenta). Los demás siguen en autónomo. Tab devuelve la vista de grupo y la autonomía. Con D-051, un héroe sin obediencia no se puede controlar. Las reglas del héroe (alcance, arma, habilidades) son las mismas para el jugador y la IA.

### D-054 — El daño de los proyectiles se aplica al impactar (2026-10-30, dueño)
Flechas, orbes y proyectiles de habilidades hacen daño cuando llegan, no cuando se disparan. Si el objetivo ya murió, el proyectil no hace nada.

### D-055 — Cohesión visual de criaturas por copias procesadas (2026-10-30, dueño)
Los sprites de héroes no se tocan (D-023). Para que las criaturas de otros packs encajen (contorno oscuro como los héroes), un script genera **copias** con el contorno corregido en una carpeta aparte; los PNG originales y sus licencias no cambian. Guía: `docs/specs/ART_DIRECTION.md`.

### D-056 — Expediciones reales autorizadas (2026-10-30, dueño; tarea de roadmap para D-025)
Autorizadas como trabajo actual: fog of war (visible / explorado / nunca explorado, la visión es de los héroes y no de la cámara, lo explorado se guarda), mapas más grandes con zonas y encuentros (objetivo de 10-30 min por piso), control directo (D-053), dificultad sin inflar la vida (composición, roles, esquiva D-052) y héroes visibles en el pueblo.

### D-057 — Construcción libre, cerca del pueblo (2026-10-31, dueño; matiza D-050)
Los edificios nuevos se colocan donde el jugador quiera (estilo Clash of Clans): no hay parcelas reservadas para lo que no se ha construido. Única regla de forma: a ≤ `TownTables.NEAR_CELLS` (3) celdas de otro edificio, sin tapar la plaza ni cortar caminos. Mover edificios (D-050) sigue la misma regla.

### D-058 — Vertical slice de 5 pisos (2026-10-31, dueño; prompt "vertical slice")
- Cuenta nueva: bienvenida breve + 10 summons gratis (banner `starter`: 72/26/2 % de 1-3★, sin 4-5★) con al menos un constructor y al menos 4 clases de combate. El pueblo empieza con la puerta de la torre, 2 dormitorios de 5 camas, el Summoner's Hall y el círculo de invocación (decisión tomada aquí: el Hall limita los niveles y el círculo es el origen de las invocaciones; reversible en `TownTables` "start").
- Expediciones: botín recolectado y caído se conserva al completar o al escapar; se pierde si cae todo el escuadrón. Completar da recompensa, XP de finalización y MVP; escapar no.
- Promoción = **ascensión** en el Santuario de Ascensión: nivel máximo del rango + materiales de la torre, con probabilidad (base + Suerte + nivel del santuario + pity, segura tras 3 fallos). Sustituye al pago con "stones".
- Entrenamiento: solo héroes de 2★ o más, una habilidad de clase elegida entre 3 por cada estrella por encima de 1.
- Los pisos 1-5 son los pulidos; 6-10 siguen accesibles sin ajustar.

### D-059 — El héroe controlado ataca solo con Q, apuntando con el ratón (2026-10-31, dueño; matiza D-040 y D-053)
El héroe que controla el jugador **nunca ataca automáticamente**. Su ataque básico es **Q** hacia el cursor (mantener Q repite al ritmo de su velocidad de ataque): a distancia, el proyectil vuela hacia el cursor hasta su alcance y golpea al primer enemigo visible de su línea (los árboles lo paran); cuerpo a cuerpo, un golpe en abanico hacia el cursor (puede fallar). Mismo arma, alcance, daño e intervalo que la IA. El clic derecho del héroe controlado solo mueve. Las habilidades pasan a **W/E/R** y solo hay **3 ranuras** de habilidad activa (antes 4 en Q/W/E/R; matiza D-043). Una cuarta habilidad ya aprendida sigue conocida y puede equiparse en lugar de otra. Los héroes autónomos siguen atacando solos.

### D-060 — 8 ranuras de equipo activas ahora, 11 en el futuro (2026-10-31, dueño; matiza D-039)
Activas: arma principal, mano secundaria/escudo, cabeza, pecho, piernas, pies, anillo y amuleto (`ItemDefs.ACTIVE_SLOTS`; coinciden con los 8 marcos de Dragon Regalia). Manos, segundo anillo y accesorio especial existen en los datos y el guardado, pero están bloqueados ("próximamente"): no se equipan ni salen en botín o forja hasta abrirlos.

### D-061 — Síntesis y sacrificio (2026-10-31, dueño: "implementa"; resuelve P-12 y fija G-21/G-22 con números provisionales)
- **Síntesis:** un héroe objetivo absorbe de 1 a 3 héroes fuente. Recibe el 30 % de la experiencia total que acumularon (40 % si son de su misma clase), sin superar su tope de nivel, y **+1 permanente** al atributo más alto de cada fuente de su misma clase. No se transfieren habilidades.
- **Sacrificio:** un héroe se convierte en materiales según sus estrellas y su clase (`ProgressionDefs.SACRIFICE`). Se pueden sacrificar todas las estrellas.
- **Reglas comunes (spec §14):**
  - Pantalla de confirmación con lo que se gana y se pierde.
  - Guardado previo.
  - Transaccional.
  - Las fuentes van al memorial con causa "sacrificed" y conservan su identidad.
  - No se puede usar a un héroe muerto ni a uno en una expedición.
  - Avisa si quedarían menos de 5 héroes desplegables.
  - Los testigos no cambian su Trust (por defecto, sin efecto).
  - Eventos `synthesized`, `received_synthesis` y `sacrificed`.
- P-11 (memoria al promocionar) sigue PENDIENTE.

### D-062 — Esc abre un menú sin pausar; 5★ por ahora (2026-10-31, dueño)
Esc abre el menú del juego (opciones, volver al pueblo o al título) y la simulación sigue corriendo (D-014). El techo de estrellas se queda en 5★; la migración a 7★ (D-029) se aplaza.

### D-063 — Interfaz y arte unificados (2026-10-31, dueño; prompt de UI y arte)
- Resolución base **640×360** con escalado entero: ×2 a 1280×720, ×3 a 1920×1080, ×4 a 2560×1440.
- Las licencias de Raven Fantasy Icons, Enemy_Animations_Set, 2D Pixel Dungeon y m6x11 **las tiene el dueño**: se usan y se registran así.
- Cute_Fantasy (no comercial) e items.zip (de origen desconocido) no se usan.
- Teclas según D-059.

### D-064 — Balance y lógica tras el playtest de 5 pisos (2026-10-31, dueño: "arregla también el balance del juego y cosas ilógicas 6 a 16")
Números provisionales, en datos, medidos con `tests/playthrough_bot` (informe `docs/reports/PLAYTEST_5_FLOORS_REPORT.md`):
- **Pisos para una primera partida a ciegas de 10-15 min** (D-056): ~1,7× el área, con la misma densidad de criaturas y recursos. Las pistas de exploración van a 3 salas distintas.
- ~~**Fuerza por piso** (`scale`): 1,0 / 1,25 / 1,45 / 1,65 / 1,35 (piso de jefe) y de 1,8 a 2,4 en los pisos 6-10.~~ Sustituida por D-065 (+10 % por piso; la dificultad viene de las mecánicas).
- **Jefe con fases** (resuelve en parte P-25, para todos los jefes): al 60 % llama a su banda (despierta a los cercanos y se unen 2), y al 30 % llama a 3 más y se enfurece (+25 % de daño, preparación ×0,8).
- **Invocar**: 300 gemas iniciales y 100 por invocación (×10: 900).
- **Economía**:
  - ~~Los pisos pagan 40 + 20 × piso en materiales.~~ Sustituido por D-066: los materiales salen de los Wilds.
  - Santuario de Ascensión con Salón 1 y coste 60.
  - Taller: coste 30 y 2 puestos.
  - Almacén base de 300 por recurso.
  - Aviso en el registro del pueblo cuando se acumulan madera y piedra sin un taller que las use.
- **Combate**:
  - Alcance a distancia 165.
  - Furia: empieza en 30, se enfría a 3/s y sube 10 por golpe.
- **Retirada (X)**: cada héroe recoge primero al caído más cercano a ≤ 260 px y luego los dos van a la salida. D-036 se mantiene: quien quede en el suelo lejos de la salida muere.
- **Limpiar el piso**: con ≤ 3 criaturas, o si todas las que quedan están dormidas, se marcan en el minimapa.

### D-065 — Pisos que obligan a pensar (2026-10-31, dueño: "el jugador tiene que pensar muy bien cómo usar los héroes")
La dificultad sale de **mecánicas**, no de inflar vida y daño. La fuerza de las criaturas vuelve a +10 % por piso, y la escala por piso de D-064 queda **sustituida**.

**Héroes autónomos.** Un héroe que no controla el jugador usa sus habilidades solo, respetando coste y recarga, en este orden:
1. Curar a un aliado por debajo del 60 % de vida.
2. Interrumpir a una criatura que lanza algo.
3. Provocar si un aliado herido recibe golpes.
4. Escudo.
5. Limpiar estados.
6. Atacar.

La tecla **T** pasa los héroes seleccionados a habilidades "manuales" (solo W/E/R). Así el jugador decide quién va libre y quién actúa solo cuando lo manda.

**Criaturas con clases y habilidades.** Los roles funcionan como clases: escaramuzador, luchador, bruto, defensor, arquero, curandero/chamán, más los vigías que asigna el piso. Cada lanzamiento se anuncia (un anillo sobre el lanzador, o el área marcada en el suelo) y un aturdimiento o una interrupción lo corta.

| Habilidad | Quién | Efecto |
|---|---|---|
| Mend | curanderos | Cura al más herido |
| Ward | chamanes | Escudo a un aliado, al jefe primero |
| Rally | comandantes | +30 % de daño a los cercanos |
| Slam | brutos | Golpe en área con aturdimiento |
| Spore Cloud | hongos | Nube de veneno |
| Aimed Shot | arqueros | Disparo cargado contra un héroe |

**Por piso.** Las habilidades de apoyo enemigas aparecen desde el piso 2.

| Piso | Mecánica |
|---|---|
| 1 | Golpes anunciados |
| 2 | Curanderos detrás de la línea |
| 3 | Quien lleva la reliquia va al 60 % de velocidad, no ataca ni lanza, y las criaturas lo notan al doble de distancia |
| 4 | En cada grupo despierto, el más rápido es vigía: al ver a la escuadra huye a avisar al grupo más cercano |
| 5 | El jefe trae 2 chamanes. Mientras vive uno, recibe un 40 % menos de daño. Sus escudos se rompen con un aturdimiento. Además conserva las fases de D-064 |

**Medición.** Se comparan dos bots, uno "a lo loco" y uno "táctico", en varias cuentas (`tests/playthrough_bot`, `PT_STYLE`). Un piso está bien diseñado cuando el estilo táctico rinde claramente mejor que el loco. El juicio final es del dueño jugando.

### D-066 — Los Wilds: mazmorra repetible para farmear; la torre es el reto (2026-10-31, dueño)
Respuestas del dueño: el freno es el nivel del pueblo más la dificultad; **cambiado por Nathaniel 2026-10-31:** el pueblo ya no bloquea pisos; si la torre los tiene abiertos se entra, y el nivel del Salón es solo una recomendación. La dificultad sale del contenido (enemigos que pegan fuerte, IA táctica): sin gear es muy difícil, no imposible; el nivel de los Wilds sigue a la torre; la muerte es permanente; cuanto más hondo, más riesgo y más recompensa.

**Los Wilds** (`scripts/data/dungeon_defs.gd`)
- Mazmorra procedural fuera de la torre, con un **mapa nuevo en cada entrada** que nunca se guarda (no le aplica D-026).
- **Nivel:** 1 + (piso más alto superado / 10). El nivel 1 son "The Overgrown Wilds" y el 2 "The Ashen Quarries", cada uno con otro bioma, otros enemigos y más recursos.
- **Sin misión:** se sale por la entrada (X) y se conserva lo que se lleva. Si cae toda la escuadra se pierde todo, y la muerte es permanente (D-011).
- **Profundidad:** cuanto más lejos de la entrada, más fuertes los enemigos (×1,0 / 1,0 / 1,3 / 1,6) y más ricos los puntos (×0,8 / 1,0 / 1,6 / 2,4).
- **Recursos:** madera, piedra, mineral, hierbas y partes de criaturas. En las salas profundas hay **cachés ocultas** de materiales de construcción.
- Una salida a los Wilds pasa medio día en el pueblo; un piso de la torre, un día entero.

**La torre**
- Sin puntos de recolección, y sus criaturas no sueltan partes.
- La primera vez que se supera un piso paga gemas, piedras, libros, **equipo** (como mínimo poco común; raro en los pisos de jefe y en los múltiplos de 5) y dos rarezas que los Wilds nunca dan:
  - **Acero estelar:** forja fina en la herrería (nivel 3 de herrero; el objeto sale como mínimo raro y con +3 de nivel).
  - **Esencia espiritual:** ascensiones a 3★ y superiores.
- Repetir un piso ya superado paga muy poco (10 gemas y 1 objeto).
- **Cada piso pide un nivel del Salón del Invocador:**

  | Pisos | 1-2 | 3-4 | 5-6 | 7-8 | 9-10 |
  |---|---|---|---|---|---|
  | Salón | 1 | 2 | 3 | 4 | 5 |

  El pueblo crece con lo que se saca de los Wilds, así que la torre se sube entre salidas a farmear, no en un día.

### D-067 — Balance desafiante: IA táctica, jefes de raid, XP lenta, sin llaves de edificio (2026-10-31, dueño)
- Wilds y pisos 4-10 con IA táctica (foco en healer/backline/aislado, AoE contra grupos, "caller" que trae refuerzos). Jefes con torbellino, meteoro, Marca de Condena, Ritual interrumpible y enrage duro (`EnemyDefs`).
- XP medida contra el nivel del héroe (`ProgressionDefs`): piso normal ≈ 0,5 nivel; MVP + secreto ≈ 1; Wilds ×0,4.
- Los pisos no se bloquean por edificios (nota en D-066). Hook de resistencias: P-29.

### D-068 — Prompt maestro: bandidos, party por piso, amenaza, modificadores (2026-10-31, dueño)
- **Party por piso** (1-5; nunca más de 5; raids de 10 héroes = backlog). Sustituye la regla fija de 5 de D-017 dentro de la torre: el escuadrón sigue teniendo 5 plazas y entran las primeras N.
- La banda de **bandidos** (Tiny Pixel Fantasy + capas `accessory`/`mask`) ocupa los pisos 1-10 en lugar de las criaturas del bosque de D-031. Las Wilds conservan sus criaturas.
- Presupuesto de **amenaza** por piso (`EnemyDefs.THREAT`), un **modificador** por piso desde el 3 (`FloorMods`), misión **escape** (piso 4) y rescate con tiempo (piso 6). Sabotaje en el piso 7: 3 tótems con guardia que reviven a los caídos (`FloorMods`).

### D-069 — El Barón Carmesí y el altar (2026-10-31, dueño; resuelve P-25)
Inmune mientras dura su escudo; 2 héroes canalizan 8 s en un altar del mismo mapa → 20 s vulnerable. Fases: 1 altar; 2 altares (ambos); el altar cambia de sitio tras cada ventana. Adds hacia el altar, onda carmesí hacia el altar al caer el escudo, pistas sutiles. Números en `AltarDefs`. El Barón usa la hoja ya escalada ×2 (`BanditArt`).

### D-070 — Botín, economía y expediciones offline (2026-10-31, dueño; resuelve P-17)
- Los pisos sueltan **pocos materiales raros** (T2), llaves `key_`, equipo procedural y cofre de misión (`LootDefs`, `LootService` con semilla). Los materiales del pueblo siguen saliendo de las Wilds (D-066). **Se conservan las gemas** como moneda de invocación; no hay oro todavía.
- IDs del prompt mapeados a los del repo: `cur_mana_shard`→gemas, `mat_wild_herb`→`herb`, `mat_old_bone`→`bone`, `mat_worn_leather`→`hide`, `mat_copper_ore`→`ore`, `mat_weak_essence`→`essence`, `key_guardian_core`→`core`, `con_potion_minor`→`potion`.
- **Expediciones offline** desde el piso 5 (`ExpeditionDefs`): 3 cargas al día, 55% del botín, nunca `key_` ni primer clear, duración piso × 20 min, héroes ocupados. `FLOOR_GAP`, `RISK` y `STORAGE_LIMIT` existen pero desactivadas.
- **Mercader** con 3 ofertas que rotan cada día (`MerchantDefs`). Pity: se mantiene el del repo (4★ en 10, 5★ en 80). Sueldo de héroes: no implementado (pregunta abierta).

### D-071 — Ir "a lo loco" no debe ganar; dash tipo Souls (2026-10-31, dueño)
- Lo telegrafiado es letal y **perfora armadura** (`EnemyDefs.TELEGRAPH_MULT/KIND`): el gear no sustituye a esquivar. Golpe lento y legible ×1,6 (`HEAVY_*`), AoE contra grupos ×2,0, sanadores enemigos más rápidos.
- **Dash** (Espacio; `CombatRules.DASH_*`): 92 px, i-frames 0,26 s, enfriamiento 1,6 s. Animación sin frames nuevos: estirado e inclinación, estelas del propio frame que se desvanecen, polvo y aplastado al aterrizar. Un buen jugador puede esquivarlo todo; la IA autónoma solo a veces (12-55 %, a veces hacia un lado malo).
- Guerreros: intervalo de ataque básico ×0,7. Piso 3: oleadas que marchan al santuario y crecen.

### D-072 — Overhaul LPC: escala del mundo (D-B, 2026-10-31, dueño: "Todo a ×1")
Rejilla lógica de 32 px. Todo el arte se dibuja a ×1: personajes LPC (frame de 64 px), objetos de CraftPix y tiles de 16 px (2×2 por celda). Nunca escalado no entero ni ×2 de tiles: misma densidad de píxel en todo. Sustituye la referencia de escala de D-055 por el humano LPC. Pendientes del overhaul: estilo de UI (A Dragon Regalia / B CraftPix) y pesos humano/elfo (propuesta 80/20); D-A, D-C..D-G se registran al cerrar sus fases.

**Revisión de D-072 (dueño, 2026-10-31: "los personajes se ven muy grandes en proporción al mapa"):** los packs de CraftPix están dibujados para personajes de ~16×32 px; los LPC miden ~48 px. El arte del **mundo** (suelo, edificios, interiores, props) va a **×2 respecto a los personajes** (escalado entero) y el mapa crece en proporción. Interiores ya a ×2; pueblo, pisos y Wilds: pendiente (TileMap en vez de imagen horneada).

### D-073 — Overhaul LPC: atuendo inicial único (D-C, 2026-10-31, aprobado en el prompt del overhaul)
`LpcWardrobe.STARTER_OUTFIT`: camisa de manga larga `tan`, pantalón `brown`, zapatos básicos `leather` (sin cinturón: la pieza de LPC no trae animaciones). Arma visual por clase en `STARTER_WEAPON_BY_CLASS` (espada arming de acero, daga, bastón simple, arco normal), sin stats. Los héroes usan los cuerpos adultos `male` y `female` (la camisa no existe para `muscular`).

### D-074 — Overhaul LPC: personajes en LPC (D-A) y razas de héroe (D-F) (2026-10-31, prompt del overhaul aprobado por el dueño)
- Los héroes se dibujan con LPC (`LpcComposer`). Sustituye D-023 para héroes y el "Master prompt H" (ya no todo humano es TPF). Los PNG de Caz no se borran ni se modifican: quedan como respaldo y el aspecto TPF se guarda en `appearance` (legado).
- `HeroGenerator.VERSION = 4`: `look` LPC desde `hero_seed ^ 0x4C5043`; nombre, clase, rasgos, pasivas y Trust de las semillas viejas no cambian (fixture de 200 semillas). Guardado v13: héroes del roster y del memorial reciben su `look` desde la semilla.
- Razas de héroe: humano y elfo, 80/20 (`SummonConfig.RACE_WEIGHTS`; confirmado por el dueño el 2026-10-31).

### D-075 — Overhaul LPC: estilo de UI (2026-10-31, dueño: "B: CraftPix basic")
Se adopta el pack CraftPix "basic pixel art UI for RPG" como el único estilo de UI; Dragon Regalia se retira cuando se haga el cambio (fase 6). No se mezclan los dos.

### D-076 — Overhaul LPC: bandidos en LPC (D-E, 2026-10-31, prompt del overhaul)
Los bandidos son humanos LPC con un atuendo fijo por tipo (`LpcFactions.BANDIT`) y el color de facción **maroon** (pañuelo, capucha o capa) sobre cuero oscuro. Dentro de un tipo solo varían cuerpo, piel, pelo y barba (4 variantes). Ningún héroe lleva ese color (test con 1000 semillas). Sustituye el arte TPF de los bandidos (D-070 en cuanto al arte); los presets TPF quedan sin uso. Tamaño del Barón (dueño, 2026-10-31: "a+b"): hoja ×2 **y** aura carmesí que late (`BanditArt.BARON_SCALE`, `SandboxEnemy._add_aura`).

### D-077 — Biblioteca de ítems (2026-10-31, dueño; resuelve P-19 y parte de P-20)
- **Tiers por material, 10 pisos cada uno** (todos en datos): T1 cobre/hierro (1-10), T2 acero (11-20), T3 plata/mithril (21-30), T4 oro rúnico (31-40), T5 obsidiana/dracónico (41-50).
- **Slots:** se añade **trinket** a los 8 activos (sin segundo anillo por ahora).
- **Rarezas:** normal (blanco), poco común (verde), raro (azul), épico (morado), legendario (naranja), único (rojo). Afijos 0/1/2/3/4 (únicos: fijos a mano). Stats base ×1,0/1,1/1,2/1,35/1,5.
- **Afijos:** biblioteca de buenos y malos; el 15 % de las piezas trae un afijo maldito siempre junto a uno bueno reforzado; las normales nunca traen malos.
- **Drop vs crafteo:** el drop es temático del enemigo (bandido: dagas, capuchas, cuero; orco: hachas, tribal; no muerto: hueso), con afijos aleatorios hasta legendario. El herrero hace una línea limpia por material, stats predecibles, 1 afijo a elegir entre 3 y como máximo raro. Joyas (anillos, amuletos, trinkets): **joyero** (propuesta). Pociones y consumibles: solo alquimia. Nunca coinciden un ítem de drop y uno de herrero.
- **Únicos:** solo en misiones secretas (objetivo oculto por piso), 1-2 % al completarla, uno por cuenta para siempre; se pierde si muere el héroe que lo lleva; en el alijo se conserva.
- **Consumibles:** poción menor y mayor, antídoto, elixires de fuerza, velocidad y defensa. La bomba de fuego se aparca (necesitaría otra tecla).
- **Requisitos:** nivel mínimo por tier (T1 1, T2 10, T3 20...) y requisitos de clase leves (un mago no lleva un hacha a dos manos). Sin durabilidad.
- **Sets del herrero:** el set completo de cada tier da bonificaciones.
- **Arte:** pieza LPC cuando existe; ícono del pack más parecido. Anillos, amuletos y trinkets: solo ícono.

### D-078 — Oficios con maestro y aptitud (2026-11-01, dueño)
- En la herrería (`TownTables.SPECIALIST_ONLY`) solo trabajan herreros. Otros aprenden como **aprendices**: solo junto a un maestro (nivel 1+), en un puesto propio, sin producir.
- Cada héroe tiene una **aptitud oculta** por oficio, fija desde la invocación (`AptitudeDefs`): atributos base ponderados + rasgos + tirada con su semilla. Tiers: incompatible (10 %), torpe (25 %), normal (35 %), talentoso (20 %), prodigio (10 %).
- Progreso por hora = base × tier × maestro × rand(0,7-1,3); avances bruscos y frustraciones diarias; el incompatible abandona tras 8 h y el pueblo lo recuerda; al graduarse empieza en nivel 0-3 según su talento.
- La aptitud se ve como "???" hasta que el maestro lo observa 6 h. Las 10 primeras invocaciones traen siempre un herrero. Guardado v15.
- Para una segunda pasada: orientador para evaluar talentos, perks de oficio, "buen mentor" y compatibilidad de personalidades.

### D-080 — El Máster: personaje del jugador y único héroe controlado (2026-11-01, dueño; sustituye el cambio de héroe con 1-5 de D-015/D-017/D-053)
(D-079 queda reservado para el soft block de la torre, que sigue en propuesta.)
- **Control:** el jugador ya no cambia de héroe con 1-5. Controla solo a su personaje, el **Máster**; los otros 4 del escuadrón van en autónomo (se guiarán con pings en una tarea posterior). Tab da la vista de grupo sin soltar al Máster; G sigue seleccionando el escuadrón para órdenes de grupo. El cambio 1-5 queda aislado tras `MasterDefs.DEBUG_HERO_SWITCH` (apagado) y sigue funcionando en escuadrones sin Máster (escuadrón de prueba, tests).
- **Creación:** Título → Nueva partida → **Crear personaje** (`MasterCreator`) → bienvenida y las 10 invocaciones. "Continuar" con un guardado sin Máster abre el creador una vez, sin tocar el roster. Pestañas: identidad (nombre + apellido, máx. 16; trasfondo fijo "Antiguo Máster"), apariencia (solo opciones LPC que existen: raza humano/elfo, cuerpo, piel, ojos, peinado, color de pelo, barba; hay una sola cabeza por cuerpo), clase (las 6 clases de nacimiento con rol y habilidad inicial) y un rasgo.
- **Ropa:** la misma ropa sencilla de cualquier invocado (`LpcWardrobe.STARTER_OUTFIT`); luego cambia con el equipo.
- **Datos:** el Máster es un `HeroData` con `is_master = true` (no hay sistema paralelo), de 3★ (rareza media, `MasterDefs.STARS`), con Confianza y Obediencia 100 y sin dones de invocación. Crece con los mismos niveles, ascensiones y síntesis (puede absorber a otros, nunca ser absorbido).
- **Reglas:** no se puede sacrificar, absorber, vender, poner a trabajar ni mandar a expediciones offline. Siempre ocupa el hueco 1 del escuadrón (Máster + 4). Duerme en el Salón (no ocupa cama de dormitorio). En los pisos de 1 héroe entra solo él.
- **Muerte (excepción a D-011):** el Máster no muere. Cae y se le puede rescatar (D-036); si se agota su agonía o el escuadrón sale sin él, la expedición fracasa y vuelve **herido** (`master_wounded`: −15 % a todos los atributos durante 24 h del pueblo, `EconomyDefs.DISEASES`). Los demás vuelven con él; si no queda nadie en pie, D-036 se aplica a los demás caídos.
- **Rasgos (dueño, 2026-11-01):** ningún rasgo es gratis. Los 7 que solo tenían ventaja (valiente, prudente, leal, bondadoso, curioso, honorable, alegre) reciben un −3 % (placeholder). Como los atributos se calculan desde los rasgos, también afecta a los héroes que ya tienen esos rasgos.
- Guardado v17 (`is_master`, `first_name`, `surname`). Pruebas: `tests/smoke_master.gd`.

### D-081 — El Máster como líder: Comandos, Liderazgo, pánico, vínculo, memorias, espejo y hardcore (2026-11-01, dueño)
Principio: el Máster es un **líder, no el carry**. Su daño propio va ×0,85 (`MasterDefs.DAMAGE_MULT`) y su valor está en mejorar a los demás. Todos los números están en `MasterDefs` / `MasterMemories` y son placeholders.
- **Sin elfos para el Máster** (por ahora solo humano). Un Máster guardado como elfo pasa a humano y conserva el resto del look. Los invocados no cambian.
- **Comandos** (exclusivos del Máster, barra aparte en el HUD, teclas **1 2 3**, que D-080 dejó libres; dueño: Z/X/C chocaba con Retirada y Reagrupar): ¡Concentren fuego! (nivel 1, 60 s: atacan al enemigo más cercano al cursor, +15 % de daño durante 6 s), ¡Reagrúpense! (nivel 5, 45 s: vuelven al Máster, −20 % de daño recibido durante 5 s) y ¡Aguanten! (nivel 10, 90 s: quita el pánico, +40 de Compostura). Solo responden los héroes dentro del radio con Obediencia efectiva ≥ `OBEY_MIN`; es un umbral, nunca una tirada (D-016). Las memorias pueden dar comandos nuevos (la estructura existe; aún no hay ninguno diseñado).
- **Liderazgo** (solo el Máster, se ve en su hoja): 5 + 1 por nivel + puntos de memorias, con rendimientos decrecientes (frac = L/(L+40)). Da el radio de los comandos y de los futuros pings (`MasterRules.leadership_radius()`, 160-320 px), hasta +15 de Obediencia y hasta un 40 % menos de Compostura perdida a quien esté dentro del radio.
- **Pánico mínimo** (dueño: no existía): la Compostura (por misión, vuelve a 100) baja de forma determinista cuando cae un aliado (−15), cae el Máster (−30), muere un aliado (−25) o la propia vida baja del 25 % (−20). Por debajo de 30, el héroe entra en pánico 6 s: no actúa, corre hacia el Máster y no obedece. Al salir vuelve a 45. El Máster nunca entra en pánico.
- **Vínculo Máster-héroe** (`bond_master`, 0-100, empieza en 30; se registra en los eventos del héroe): +4 al superar un piso juntos, +8 si el Máster lo rescata, +5 al MVP; −6 a todos si muere un aliado en una expedición con el Máster y −15 más si se le abandonó caído. Tramos: Desconfiado (<25, −10 Obediencia), Receloso, Leal (+5) y Devoto (≥75, +10, y corre por su cuenta a levantar al Máster caído). El vínculo también reduce la Compostura que se pierde cuando cae el Máster. Se ve en la ficha (barra + tramo).
- **Memorias del Antiguo Máster** (`MasterMemories`, memory_01..10, texto TODO de lore): vencer al jefe de cada décimo piso desbloquea una sola vez la del piso (escena en el resultado + pestaña "Memorias" en la hoja del Máster, con "???" para las bloqueadas). Recompensa: Liderazgo o una pasiva. Dialogic no está instalado, así que se usa un panel con UIKit.
- **Espejo** en el Salón del Invocador: reabre solo la pestaña de Apariencia del creador (sin raza). No cambia clase, rasgo, nombre ni trasfondo. Gratis (no hay oro, D-070).
- **Hardcore** (casilla del creador, solo al crear la partida; se guarda y no se puede cambiar): si el Máster se desangra o se queda atrás, muere de verdad (memorial) y la partida queda **marcada como terminada** (no se borra), con una pantalla de fin (pisos, héroes, caídos, tiempo jugado). Calavera en el HUD y junto a "Continuar". Fuera de hardcore sigue D-080 (vuelve herido).
- Guardado v18. Pruebas: `tests/smoke_master.gd` (sección D-081).

### D-082 — Combate e IA: autonomía arreglada, IA por capas, pings, revivir con F, bots, bandidos por rol y armas por clase (2026-11-01, dueño: "Tarea 3")
El jugador solo maneja al Máster; los otros 4 actúan solos y se guían con **pings** y **Comandos**. Todos los números están en `AiDefs` (nuevo) o `CombatRules`, son placeholders, y toda la aleatoriedad nueva usa el `combat_rng` con semilla de cada unidad (preparado para el núcleo determinista de la próxima tarea). LimboAI no está en `addons/`: la IA es una máquina de estados en GDScript con la misma estructura por capas.
- **Bug de autonomía (causa real):** con Máster, `select_all()` dejaba a los 5 seleccionados; cada clic derecho para mover al Máster (y su repetición cada 0,12 s al mantenerlo) daba una orden `move` también a los otros 4 (sin objetivo, sin skills, sin esquivar), y H/F/X les daban hold/follow/retreat que **nunca caducaban**. Ahora, con Máster, la selección es solo el Máster; las teclas de escuadrón se convierten en pings y toda orden de ping caduca (`PING_ORDER_TIME`, 14 s) y vuelve a Auto.
- **IA por capas** (mayor a menor): 1 supervivencia (pánico, esquivar, pociones, replegarse herido), 2 órdenes (pings y Comandos), 3 rol (tanque: al frente y protege al más débil; DPS: foco en un objetivo; clérigo: atrás y cura; explorador: delante y a distancia; plebeyo: apoya y evita el frente), 4 personalidad (temerario delante, prudente detrás y lento para atacar, leal pegado al Máster). Decide cada 0,2-0,8 s según la Compostura; error de puntería en grados por AGI/Compostura (×2 con pánico); a veces (7 %) elige un objetivo que no es el ideal. Todos usan sus skills (D-065) al decidir.
- **Pings** (solo con Máster): Mayús+clic = ping rápido contextual (enemigo → atacar, nodo → recolectar, caído → levantar, suelo → ir ahí); mantener Mayús+clic 0,25 s = **rueda** con 8 pings (Ven/reagrúpense, Atacar aquí, Defender esta zona, Explorar, Recolectar, ¡Peligro!/retirada, Enemigo avistado —visible para todos 8 s—, Ayuda/levantar) y un anillo exterior con los 3 Comandos (mismo efecto y cooldown que sus teclas). Por defecto va a toda la party; clic en un retrato = solo a ese héroe (una vez). Cada héroe contesta con una frase (`HeroChatter.ping_line`) y obedece tras un retraso según personalidad y si está dentro de `leadership_radius()`; con Obediencia efectiva (Liderazgo + vínculo − penalización por spam) < `OBEY_MIN` no obedece y lo dice; el temerario con vida > 50 % ignora la retirada. **Todo determinista** (D-016: nunca una tirada). Anti-spam: más de 4 pings en 5 s cuesta 6 de Obediencia por ping (tope 40), se recupera 2/s. Marcadores en el mapa (`PingMarker`) con icono y color por tipo. A + clic = ping de ataque; H = defender aquí; C = reagruparse; X = el Máster se retira y la party recibe "reagrúpense"; S = todos vuelven a Auto. **Seguir pasa de F a V.**
- **Revivir (cambia D-036):** la agonía pasa de 20 a **120 s** (contador m:ss sobre el héroe y en su retrato) y levantar tarda **4 s**. Interacción en **F** (dueño, 2026-11-01: QWER solo combate; toda interacción —revivir, recolectar, cofres, edificios, portal— en F): junto a un caído aparece "Mantén F"; mantener F 4 s lo levanta; un golpe lo interrumpe. El Máster ya no levanta con clic derecho; recolecta solo con F (los autónomos siguen recogiendo solos). F en la salida = escapar. La IA levanta a los caídos por su cuenta (prioridad: clérigo > plebeyo > tanque > resto; + vínculo ≥ 50 con el caído; + bondadoso/leal; nunca con un enemigo encima) y el ping "Ayuda" sobre un caído manda a levantarlo. Sigue: golpes en el suelo restan 5 s; muerte permanente si se agota (D-011).
- **Bandidos por rol** (`AiDefs.BANDIT_AI`): bruto/matón = va por la mayor amenaza recibida (`threat`, hook para el aggro completo); degollador = va por el clérigo o el mago salvo provocación; arquero = mantiene 120 px y busca línea de visión; mago = Bola de fuego interrumpible y se aparta antes si lo presionan; capitán = líder que inspira (+15 % de daño) a los cercanos. Huir con <25 % de vida (35 %, una tirada), **cuerno** (un bandido por grupo despierta a todo lo dormido a 520 px a los 5 s de alerta o al bajar del 60 %), emboscadas (ya existían), **moral**: si muere el líder, cada bandido a 320 px tira un 50 % para huir 6 s.
- **Armas:** sin elfos en las invocaciones (`RACE_WEIGHTS` solo humano; los elfos de partidas guardadas conservan su aspecto). Explorador: arco LPC normal (ya era `weapon_bow` = `bow_normal`); recurvo, largo y ballesta reservados a ítems. El disparo básico es un **proyectil real** (`ArrowShot`): tensar 0,3 s, sale hacia donde estaba el objetivo al soltar (más el error de puntería) y lo puede esquivar moviéndose; alcance 230 px (nunca más de lo que el héroe ve), flecha que rota con la trayectoria, estela leve y queda clavada 0,6 s. Pícaro: **2 dagas**, golpe izquierda y 0,15 s después derecha, cada uno al 55 %, efectos al golpear en cada golpe y ritmo un 12 % más rápido (`CombatRules.CLASS_RHYTHM`): con sus propios atributos rinde entre el 86 % y el 112 % del DPS de un guerrero de su nivel (niveles 1, 5 y 10). **Armadura plana:** además del porcentaje, cada golpe físico pierde 0,25 × armadura (mín. 1), así que las dagas rinden menos contra blindados (59 % frente a 68 % de la espada con armadura 8).
- **Bots de prueba** (`tests/master_bot.gd`, `tests/smoke_bots.tscn`): "a lo loco" y "táctico" manejan solo al Máster y mandan con pings, Comandos y skills; corren solos y escriben `tests/out/bot_stats.csv` (resultado, tiempo, muertes, caídas, pings, Comandos, skills, levantados). `playthrough_bot` usa el mismo `MasterBot` (sin órdenes directas a los otros héroes).
- **Conflictos señalados al dueño:** (1) el prompt pedía Comandos en Z/X/C; se mantienen en **1 2 3** (D-081 los movió porque Z/X/C chocaban con Retirada y Reagrupar). (2) La imperfección de la IA (error de puntería, objetivo no ideal, huida y moral de bandidos) añade azar más allá de "solo críticos" (D-037); se limita a la IA y va con semilla. (3) La armadura plana afecta a todos los golpes físicos, también a los que reciben los héroes.
- Fuera de alcance (tareas siguientes): aggro/threat completo, sigilo, percepción, sinergias, recursos de clase, campamento, party frames y el refactor del núcleo. Pruebas: `tests/smoke_ai.gd`, `tests/smoke_bots.gd`.

### D-082b — Arreglos tras D-082: cámara, pantalla completa, party al entrar, densidad, kit blanco, escudo y dos dagas (2026-11-01, dueño: "Tarea 3.5")
- **Cámara** (`CameraDefs`): nunca cambia el zoom sola (antes, en vista de grupo, se alejaba a 0,5 al separarse los héroes: eso pixelaba). Zoom solo en pasos enteros (×1, ×2 con la rueda) sobre el escalado entero del proyecto (640×360 ×2/×3/×4). Bloqueada en el Máster por defecto; **Y** alterna con cámara libre (bordes, flechas, arrastre con botón central; limitada al mapa y a lo explorado). **B mantenida** centra en el Máster (dueño: Espacio sigue siendo el dash de D-071). **F1-F5** centran en cada miembro (F1 = Máster), doble pulsación = seguirlo. El overlay de depuración pasa de F3 a **F10**. Marcadores en los bordes para héroes y pings fuera de vista (clic = saltar). Encuadre: el Máster centrado en la zona que no tapa el HUD, adelanto leve y nunca a menos del 25 % del alto del borde inferior visible.
- **Pantalla completa** con F11 o Alt+Enter y en Opciones, guardada en `settings.cfg`; en ventana, opción de confinar el ratón.
- **Party al entrar (bug):** el piso 1 admite 1 héroe (D-068, `"party": 1`), pero la torre decía "Recommended: 5 heroes" (`RECOMMENDED_HEROES`, otra constante). Ahora hay una sola fuente (`TowerExpedition.squad_report`): el botón dice el tamaño del escuadrón, antes de entrar se avisa si faltan o sobran héroes (Completar la party / Entrar igual) y se despliega exactamente eso. Una party más corta que el piso ya no se convierte en un escuadrón de prueba que no guarda nada.
- **Densidad:** mínimo de encuentros por piso (6 o el 60 % de las salas tras la entrada) y ninguna sala a más de 900 px de un grupo (`EnemyDefs.ENCOUNTER_*`); patrullas de relleno deterministas, también en pisos ya guardados al cargarlos. Todos los enemigos alcanzables.
- **Kit inicial blanco** (`ItemDefs.STARTER_*`, guardado v19): todos los héroes y el Máster llevan como ítems reales la misma ropa sencilla (sin stats) y el arma de su clase con stats mínimos: guerrero espada + escudo redondo de madera, pícaro 2 dagas, explorador arco LPC normal, mago y clérigo bastón, plebeyo garrote (se ve como la maza: el garrote LPC solo existe en animación sobredimensionada). La migración equipa el kit en huecos vacíos. Lo que se ve es lo equipado (sin arma, no hay arma en el sprite). El kit nunca sale como botín ni se fabrica.
- **Escudo** (solo guerreros por ahora): 10 % de bloquear un golpe frontal (arco de 120°), que pierde el 50 %; muestra "Bloqueado" en gris. **Dos dagas**: el doble golpe requiere la daga de la mano secundaria (sin ella, un golpe); el segundo golpe usa la otra mano (sprite reflejado de frente/espalda).
- **Rueda de pings** al ~60 %.
- No resuelto: los textos del mundo (nombres, barras, números flotantes) siguen dibujados en el mundo, no en una capa de UI aparte; con la cámara a escala entera se leen bien, pero el zoom ×2 los agranda. Pruebas: `tests/smoke_fixes.gd`; capturas: `tests/capture_kit.tscn`.

### D-083 — Simulador de combate headless configurable (2026-11-01, dueño: "Tarea 4")
Herramienta para balancear sin jugar: `godot --headless --path . -s res://tools/sim/run_sim.gd -- --config tools/sim/configs/<archivo>.json` (uso completo en `tools/sim/README.md`). No añade nada al juego.
- **Corre el juego de verdad:** un `SandboxScreen` real por run, avanzado con `tick(1/tick_hz)` a paso fijo; el `MasterBot` de D-082 maneja solo al Máster (pings, Comandos, skills, levantar con F); los otros 4 son la IA del juego. `SimMode.on` (`scripts/core/sim_mode.gd`) apaga sprites, efectos, números flotantes, arte del mapa, dibujo de la niebla, HUD y pantalla de resultados; la niebla sigue limitando lo que se ve. En el juego `SimMode` está apagado y todos sus valores son neutros.
- **Configs** JSON con comentarios: pisos, runs/semillas, bot (`tactico`/`loco` + umbral de retirada, pings, Comandos, skills, error de puntería…), party (Máster y héroes con clase, nivel, estrellas o rareza —alias de estrellas, P-09 sigue pendiente—, rasgos, atributos, skills), gear (presets de `gear_presets.json` con ítems reales de `ItemDefs`, o lista de ítems; propiedades al azar con `ItemGen` y `gear_seed`), multiplicadores de enemigos y **overrides** de cualquier constante (`Clase.CONSTANTE` o una clave de una tabla). Todo se valida antes de jugar (`SIM ERROR: …`).
- **Overrides sin tocar el código:** GDScript pliega las constantes al compilar, así que no se pueden cambiar en marcha. El simulador escribe un pack con copias parcheadas de los scripts y cada proceso lo carga antes de que compile el juego; el repo nunca se escribe. Cada proceso informa del valor real que tiene (si no coincide, error).
- **Barridos y A/B:** `sweep` (constante o ruta de la config, rango o lista) y `compare` (variantes sobre la misma base), combinables. Los runs se reparten en procesos paralelos.
- **Salida** en `docs/reports/sim/<fecha>_<nombre>/`: `runs.csv`, `heroes.csv`, `results.json` y `resumen.md` (victoria, duración, derribos, muertes, daño/curación/daño recibido por clase, recursos e ítems, motivo de derrota, media ± desviación, velocidad) con alertas: loco ≥ táctico, piso imposible (< 10 %) o trivial (> 95 %).
- **Reproducibilidad (arreglado):** las criaturas sembraban sus dados con el id de instancia (cambia cada vez) → ahora con la semilla del run y el orden de aparición; el lado del altar del Barón usaba `randf()` → semilla; el `_rng` de la expedición y los dados de cada héroe mezclan la semilla del run (en el juego `run_seed` = 0: sin cambio). Misma config y semilla → mismos runs, aunque los juegue otro proceso (`--check-determinism`, suite `sim`).
- Cambios pequeños fuera de `tools/sim`: `MasterBot` con parámetros (valores por defecto = D-082) y `MasterBot.mission_goal` (antes en `playthrough_bot`); `_separate_enemies` descarta pares lejanos sin raíz cuadrada (mismo resultado, más rápido).
- **Suites que fallaban** (`expedition`, `ui full`, `map safety`): eran pruebas viejas, no fallos del juego. (1) D-082b despliega el tamaño de party del piso también al escuadrón de prueba: el piso 1 admite 1 héroe y las pruebas usaban 5 → pasan al piso 5. (2) La migración v9 → v12 borra a propósito los pisos guardados (v12, torre de bandidos) y la prueba esperaba los de v10. (3) "Alejar la cámara no revela nada" corría toda la simulación y desde D-082 los héroes exploran solos → solo cámara + niebla. (4) El jefe del piso 5 ya no es "Grove Warlord" → se lee de la config. (5) `EdgeIndicators` creaba un `Rect2` negativo el primer frame (tamaño 0) → sale sin marcadores hasta tener tamaño.
- Hallazgos del primer informe (pisos 1-10, kit blanco, nivel 1, 10 runs por estilo): en `docs/reports/sim/2026-11-01_floors1-10_kit_blanco/resumen.md`. El dueño decide qué tocar.

### D-084 — Balance de los pisos 1-10 y simulador con progreso, builds y bots sin mapa (2026-11-01, dueño)
- **Dueño:** el piso 9 dura más (supervivencia 300 s con oleadas que atacan); los Comandos/pings **no** dan buff de daño; **ningún bot conoce el mapa** (exploran con la niebla, saltando callejones sin salida); el equipo debe subir **un poco** la victoria, no mucho; un héroe no rescatado muere para siempre; en pisos en solitario derribo = fallido; nivel y equipo dependen del pueblo de cada jugador (perfiles lento/medio/rápido para probar).
- **Juego:** ruido de combate (`AiDefs.NOISE_RADIUS` 260: pelear despierta grupos cercanos, sin cadena); rodeado (≥3 enemigos a 72 px → ×1,25 daño recibido); golpes avisados más fuertes (`TELEGRAPH_MULT` 1,6, `HEAVY_MULT` 1,9); capitán inspira ×1,25 y chamanes protegen ×0,5; Curar del clérigo ×3,0 cada 4 s; piso 2 con vigías; piso 3 aguante 210 s y oleadas mayores; piso 6 límite 600 s; piso 9 `survive_time` 300 y oleadas.
- **Bots:** el loco no esquiva; el táctico espera al grupo antes de atraer a otro (3 s), se repliega hacia los aliados (solo, no se retira) y abandona solo con 1 en pie.
- **Simulador:** `progress` + `progress_profiles.json`, `gear_style` (mix/def/atk, presets `tierN_def/atk`), `matrix` (clase del Máster × party × equipo × bot), alerta de ventaja táctica < 30 pts y tabla por dimensión.
- **Sin verificar:** el balance resultante (la simulación completa se cortó por tiempo). Pendiente correrla en el PC del dueño y ajustar.

### D-090 — Combate y sistemas tácticos: aggro, sigilo, recursos, campamento, sinergias y skills por clase (2026-11-02, dueño: "Pista A")
Ronda paralela (pistas A/C/D). Números en `AiDefs`, `CombatRules`, `SkillDefs`, `CampDefs` (nuevo) y `SynergyDefs` (nuevo); todo placeholder. Pruebas: `tests/smoke_pista_a.tscn`.
- **Aggro:** cada criatura tiene tabla de amenaza (daño ×1; curar a un aliado junto a la pelea ×0,5 a las criaturas que ya luchan; guerrero ×2). Las criaturas sin rol especial, el bruto, el líder, el mago y el chamán siguen la tabla y solo cambian de objetivo si otro héroe supera al actual un 10 %. War Cry provoca **3,5 s** y deja al guerrero primero (×1,1 sobre el máximo). El degollador va por clérigo/mago salvo provocado; el arquero, al héroe que tiene a tiro con línea limpia. `SandboxEnemy.attention()`, `threat_of()`, `threat_ranking()` para la UI; sobre cada enemigo se dibuja el número del héroe al que va (anillo rojo si está provocado).
- **Niebla y sigilo:** visión = base de clase (`CLASS_VISION`) + percepción ((INT+TEM)/10, máx. 3) + ítems. Detección = percepción enemiga × (1 − sigilo), mínimo 35 %; sigilo = clase (pícaro 0,35, arquero 0,25) + ítems + **matorral** (+0,4). Una criatura que aún no pelea necesita línea de visión: árboles y muros ocultan (los proyectiles ya se paraban en ellos). Matorrales nuevos (`BushField`): celdas transitables al borde del bosque, con semilla del mapa, arte del pack CraftPix de arbustos; el héroe dentro se ve semitransparente.
- **Recursos:** furia 0–100 (sube al pegar y al recibir, baja fuera de combate), **energía** del pícaro 100 (+10/s siempre) con **combo** hasta 5 (cada ataque básico y las skills "combo" suman; los remates Eviscerar y Golpe en el riñón exigen ≥1, los gastan todos y escalan ×(1 + 0,25 × puntos)), **concentración** del arquero (5/s moviéndose, 14/s quieto) + **flechas finitas** (60 + las "arrows" de la bolsa; se recupera el 75 % de las clavadas en cadáveres; sin flechas pega cuerpo a cuerpo al 50 %), **maná** que vuelve poco a poco fuera de combate (1,5/s; dueño, 2026-11-02) y 1/s en combate, **plebeyo sin recurso** (sus skills solo tienen enfriamiento). `resource_value()`, `resource_max()`, `resource_kind()`, `combo_points()`, `arrows_left()`. La IA respeta costes y espera 3 puntos para rematar.
- **Campamento:** la vida no se regenera fuera de combate (ya no lo hacía) y el maná solo poco a poco; acampar es la forma de recuperarse del todo. Ping **"Acampar aquí"** (9.º de la rueda): kit (`camp_kit`, ítem de la pista D; mientras no exista, 1 kit de prueba por expedición), sin criaturas despiertas a 320 px, 25 s; al terminar cada héroe junto al fuego come su comida ("food" de su bolsa) → vida y maná llenos + "Bien comido" 240 s (sin comida, 60 %). La fogata hace que las criaturas a 480 px detecten ×1,6. Se interrumpe si una criatura despierta llega a 220 px o un campista recibe daño (el kit se pierde). El bot táctico acampa con la party por debajo del 55 % (o un mago sin maná); el loco nunca.
- **Sinergias** (`SynergyDefs`, 16): combos (aturdir → crítico del pícaro; congelar → quebrar ×1,5 con golpe físico, Nova de escarcha ahora congela; provocar → el área de los demás no da amenaza; marca del arquero visible en la niebla), formación (flanqueo +15 % crítico; espalda con espalda: mitad de pérdida de Compostura; muro de 2 guerreros: paran los disparos a los de detrás al 50 %), vínculos (rivales +8 % daño; mentor 8+ niveles +5 % crítico al aprendiz; amigos −8 % daño recibido; incompatibles −Compostura cerca, también por rasgos opuestos), exploración (dos exploradores comparten +1 de visión; pícaro + arquero descubren emboscadas), campamento (ex-cocinero: comida ×2 de duración; ex-artista: +20 Compostura y −10 % daño), recolección (dos en una veta: **solo definida**, efecto de la pista C en `gather_node`). **Códice**: "¡Sinergia descubierta!" la primera vez, "???" las no descubiertas, guardado en `Game.synergy_codex` (sin subir `SAVE_VERSION`: un guardado sin el campo carga vacío). Botón "Códice de sinergias" en la pestaña Skills de la ficha.
- **Skills por clase:** elección de 1 entre 3 en los niveles **2, 5 y luego cada 5** (las no elegidas se pierden en esa elección); pantalla `SkillChoiceScreen` (icono, coste, enfriamiento, alcance, descripción) desde la ficha del héroe. Con `bonus_skill_choice` (tomo, pista D) sale una opción más. **Q sigue siendo el ataque básico** (D-059) y hay **3 activas en W E R** (`MAX_SLOTS` 3): las "4 en QWER" del prompt = ataque básico + 3 skills (dueño, 2026-11-02).
> Matizada por D-142 (2026-11-02): solo Q al empezar y elecciones en 2, 5 y 10; solo tres skills interrumpen; sin flanqueo, espalda con espalda ni muro de escudos; marca +15 %.
- **Dependencias:** ítems `camp_kit`, `arrows` y el campo `bonus_skill_choice` (pista D: se usan si existen); efecto de "Dos en una veta" y el HUD de recursos/combo/atención (pista C: las funciones están expuestas).

### D-110 — Pista C: juice modular por perfil (2026-11-02, dueño, prompt 04C)
- `JuiceProfile` (Resource, `.tres` en `assets/juice/`, generados por `tools/build_juice_profiles.gd` desde `JuiceDefs`; un `.tres` editado manda sobre la tabla): destello 2-4 frames, partículas `CPUParticles2D` de 2 px en la dirección del golpe (segundo color opcional: brasas, esquirlas), sacudida del sprite en píxeles enteros (y rebote del atacante), squash/stretch, temblor de cámara ≤ 2 px, freeze 0,03-0,05 s solo de render, id de sonido (hook `JuicePlayer.on_sound`, sin audio todavía) y "pesado".
- **Filtro:** temblor + freeze solo en jefes, críticos, el golpe que remata y skills pesadas; golpe normal = destello + partículas + sacudida leve. El daño en el tiempo nunca tiembla. `CombatFeel.SHAKE` baja a 1 / 1,5 / 2 px y `FREEZE` a ≤ 0,05 s; el golpe normal de una criatura común ya no mueve la cámara (`CombatFeel.shake_allowed`).
- Perfil por cada skill de `SkillDefs` (46) y por ataque básico de cada clase; tipos de reserva: enemigo, bandido, jefe, DoT, bloqueo, muerte. Bola de fuego `#FF4400` a 0,6 con brasas, escarcha azul con esquirlas, rayo blanco-azul, chispas doradas que suben (clérigo), astillas y destello del disparo tensado (arquero, id `class.ranger` hasta el renombre).
- **Enganche:** una línea en `Combatant.take_hit` (tras el número) y otra en `Combatant.die`, más `JuicePlayer.pop` en el cadáver (`EnemySprites.spawn_death`). Skill vs básico se deduce leyendo `blows` y `_firing` del héroe (sin tocar `sandbox_hero`). Los DoT llevan la etiqueta `"dot"` (solo aspecto).
- **No hecho:** "la animación de ataque arranca al instante al pulsar (estilo Hades)" y "anticipación en las animaciones": viven en `sandbox_hero`/`hero_anim` (lógica de combate, fuera de la pista C).

### D-111 — Pista C: party frames estilo WoW (2026-11-02)
- Columna en el borde izquierdo (`PartyFrames`): retrato, nombre, vida, recurso, estados, contador de agonía (m:ss, X si murió), borde rojo si una criatura lo tiene de objetivo (`enemy.focus`, o `target_of()` de la pista A si existe), clic = ese héroe recibe el próximo ping (`select_slot`). Lee `resource_value/resource_max` de la pista A si existen; si no, `res/res_max`.
- `SmoothBar`: baja al instante, el trozo blanco espera 0,3 s y se drena; la curación llena en 0,35 s con chispas; verde → amarillo (≤ 60 %) → rojo (≤ 25 %). El retrato destella y hace "punch" al recibir daño. Misma barra en la del jefe. Las barras sobre la cabeza de cada criatura se dibujan en `sandbox_enemy._draw` (fuera de la pista C): **pendiente**.

### D-112 — Pista C: números flotantes (2026-11-02)
- Pop + arco alterno izquierda/derecha + apilado (no se solapan) + desvanecido; tamaño según el daño (×1 / ×1,5 / ×2) solo si está implicado el Máster o el daño es a la party. Blanco normal, naranja crítico (grande y temblando), verde cura, morado DoT, azul maná, gris esquivado/bloqueado, rojo-anaranjado daño a la party. `FloatingText.compact` reduce todos (falta el interruptor en Opciones).
- Capa propia `WorldTextLayer` (z 60) para los textos del mundo; posiciones en píxeles enteros; textos traducidos con `StringsEs.tx`.

### D-113 — Pista C: mundo vivo (2026-11-02)
- `assets/shaders/wind_sway.gdshader`, reutilizable: modo sprite (la copa se mece, la base quieta, desfase por posición; listo para la pista B en el pueblo) y modo mapa horneado (solo píxeles de copa se desplazan 1 texel en rachas). `Ambience.wind_material()`. Aplicado al mapa horneado de la expedición.
- `WorldLife`: sombras de nubes, pájaros que huyen al acercarse un héroe, polvo al frenar/girar (ignora teleports); `Ambience.add_dust` (motas). Las hojas, luciérnagas, luces con parpadeo y la viñeta ya existían (fase 8) y se mantienen.
- **No hecho:** hierba que se aparta al pisarla (la hierba está horneada en una textura; necesita hierba como sprites), agua animada (los pisos 1-10 son bosque sin agua), luciérnagas solo de noche (la expedición no tiene ciclo día/noche).

### D-114 — Pista C: cámara (2026-11-02)
- Adelanto leve hacia donde va el objetivo (≤ 14 px, con retardo), por `offset` junto al temblor: la posición real de la cámara, los límites y los tests de encuadre no cambian.
- **Conflicto (se reporta):** el prompt pide "zoom leve en jefes", pero D-082b dice que la cámara nunca hace zoom por sí sola. No implementado hasta que el dueño decida.

### D-115 — Pista C: tirones al entrar (2026-11-02)
- Pantallas pesadas (`sandbox`, `town`): cortina "Cargando..." un par de frames antes de construir, para que el clic responda al instante (en headless se construye directo, como antes). Fundido al cambiar de pantalla.
- `ForestArt.bake` guarda los 3 últimos pisos horneados (volver a entrar o reintentar no hornea de nuevo). Los sprites LPC compuestos ya tenían caché (`LpcComposer`/`SpriteComposer`).
- **Sin verificar:** no se midió el tirón en el PC del dueño (headless no dibuja). La carga en segundo plano real (hilo) no se hizo: el horneado usa `Image` y nodos en el hilo principal.

### D-116 — Pista C: UI (2026-11-02)
- La ventana de fin de misión/retirada medía 360×230 px de scroll + botón de 360 px en una vista de 640×360 (tapaba la pantalla): ahora 300×150 y botón de 130 px, con entrada suavizada (`UIKit.pop_in`).
- Botones que reaccionan (crecen al pasar el ratón, "punch" al pulsar; `UIKit.react`), fundidos entre pantallas (`UIKit.fade_in`).

### D-117 — Pista C: recolección por cargas (2026-11-02)
- `GatherNode`: 3-6 cargas (fijas por posición, `GatherDefs`); cada ciclo de 5 s da 1 carga (su parte de lo que guarda: el total no cambia), con animación en bucle (sacudida del nodo + astillas/esquirlas/hojas cada 0,7 s) y pips de cargas encima; al vaciarse se desvanece. Irse del nodo reinicia el ciclo en curso.
- Sinergia "dos en una mena" (`two_on_ore`): solo si existe `SynergyDefs` de la pista A (más rápido, probabilidad por ciclo de romperla). Si no existe, no hace nada.
- **No hecho:** animaciones del héroe al minar/talar/recoger/abrir cofres/canalizar altar/levantar a un caído (son del héroe: `hero_anim`/`sandbox_hero`). El nodo sí se anima.

### D-120 — Por qué los enemigos no soltaban nada y botín en el cuerpo (2026-11-02, dueño: "Pista D")
- **Causa:** en la torre cada criatura solo tiraba la tabla `LootDefs.FLOORS[n].drops` (4-6 % de un material) y todo el equipo salía al **completar** el piso, directo al alijo. En partida, un enemigo muerto no dejaba nada (como mucho un número flotante de "+1 esencia" muy de vez en cuando).
- **Ahora** (`LootService.body_loot`, con la semilla de la expedición): cada cuerpo puede llevar equipo según su rango (`LootDefs.CREATURE_ITEM_CHANCE`: normal 10 %, élite —líder, chamán o pregonero— 35 %, jefe 100 % y 2 piezas), los materiales/llaves de siempre y, raramente, un libro (D-129). La recompensa por completar el piso no cambia.
- Todo se queda **en el cuerpo** (`LootBag`) hasta que alguien lo saquea. Al ganar, el escuadrón barre los cuerpos a ≤ 260 px (`END_SWEEP`: el piso puede acabar en el acto al caer el jefe). Lo que quede en el suelo se pierde.

### D-121 — Saquear con F (2026-11-02, dueño)
- El cuerpo con botín **brilla** con el color de su mejor ítem (dorado si solo hay materiales) y chispas; oculto en la niebla no explorada. Junto a él aparece "Mantén F: saquear" y un anillo que se llena: **mantener F 1 s** (`LOOT_HOLD`, a ≤ 44 px) abre la **ventana de botín** (`LootWindow`): el juego no se pausa (D-014) y se cierra al alejarse. "Coger" / "Cogerlo todo".
- Cambio localizado en `SandboxScreen`: `_tick_master_loot` dentro de `_tick_interact` (levantar a un aliado tiene prioridad) y funciones nuevas al final del archivo.
- Los héroes autónomos que no pelean saquean el cuerpo que pisan (1,2 s, `AUTO_LOOT_*`), solo a su mochila. El `MasterBot` camina a los cuerpos cercanos (≤ 220 px) y mantiene F (`bot.loot` en el simulador).

### D-122 — Stats: base fija + 1-2 propiedades por rareza (2026-11-02, dueño; cambia el número de afijos de D-077)
Base fija (sin tirada) + verde 1 propiedad, azul/morado/naranja 2, cada vez más fuertes (`RARITIES.quality`: ×1,0 / 1,1 / 1,3 / 1,55 sobre el rango). Antes (D-077) épico 3 y legendario 4 afijos. Los afijos malditos de D-077 siguen igual. Con `ItemGen` y semilla.

### D-123 — Rarezas y basura gris (2026-11-02, dueño)
Gris **basura** (no se equipa; "Desmontar toda la basura" en el inventario → materiales, `LootDefs.SALVAGE_JUNK`), blanco común, verde poco común, azul raro, morado épico, naranja legendario, rojo único (solo misiones supersecretas o eventos, como D-077). El color sale de `ItemDefs.RARITIES`: borde e icono tintado en las casillas, nombre coloreado en la ventana de botín y en el alijo, brillo del cuerpo y texto flotante para verde o mejor. La basura sale en el 35 % de los ítems de criaturas normales con nombre gastado ("Daga doblada").

### D-124 — Mochila por héroe (2026-11-02, dueño)
- Cada héroe lleva una mochila de 4 casillas (`PACK_SLOTS`) + la bolsa equipada (nuevo hueco **bolsa**: zurrón +2, mochila +4; se ven a la espalda). Las hace el **peletero**; nunca salen de cuerpos.
- Al salir (éxito o huida) todo pasa al alijo del Máster (`Game.deliver_packs`; si el alijo está lleno, se queda en la torre y se avisa). Si un héroe **cae**, su mochila cae con él al suelo (cualquiera la recoge); si muere y nadie la recoge, se pierde. Expedición fallida = mochilas perdidas. La pantalla de resultados lo lista.

### D-125 — Rasgo avaricioso (`trait.greedy`, "Codicioso") (2026-11-02, dueño)
Ventaja: +25 % de probabilidad de ítem por cada avaricioso en el escuadrón (máx. +50 %) y saquea desde el doble de distancia. Pega: al volver, cada ítem de su mochila tiene un 25 % de **quedárselo** (`HeroData.hoard`). El Máster lo descubre con un 40 % ("X intentó quedarse Y" en el registro del pueblo y en resultados). En el inventario: **Confiscar** (vuelve al alijo; Confianza −8, Obediencia +4) o castigarlo por síntesis en el Salón. El Máster nunca retiene. No hay oro todavía (D-070): el "+% oro" queda para cuando exista.

### D-126 — Armadura por clase y oficios de equipo (2026-11-02, dueño)
- Cada pieza de armadura tiene peso (`BASES.armor`): **placa** (yelmo, cota, guanteletes, grebas) → herrería → guerrero; **cuero** (gorro, armadura, pantalón, botas) → peletería → pícaro y arquero; **tela** (capucha, túnica, pantalón tejido, sandalias) → sastrería → mago y clérigo. `ItemLibrary.ARMOR_BY_CLASS`: el guerrero también lleva cuero; el plebeyo cuero y tela. Las subclases futuras añaden su línea. Escudos, joyas y la ropa inicial no tienen regla.
- Oficios nuevos `leatherworker` (peletero) y `tailor` (sastre). Pasado: cazador → peletero, sastre → sastre (antes cocinero/carpintero; solo afecta a héroes nuevos). Sin edificio propio aún (el pueblo es de la pista B): trabajan en el **taller** (`LINES.fallback`) hasta que `TownTables` tenga `tannery`/`tailor`.
- Las recetas viejas `forge_weapon/forge_armor` del herrero solo hacen metal.

### D-127 — Arcos y escudos LPC reservados, ahora ítems (2026-11-02, dueño; completa D-082)
Arco recurvo, arco largo (great) y ballesta (arquero; el largo y la ballesta disparan más lento y pegan más), escudo de cometa y de bronce (spartan); el escudo genérico ya bloquea y se ve (escudo redondo). Se fabrican (taller, herrería) y salen de cuerpos (temas de `THEMES`). Arte importado con `tools/lpc_extras_items.py` (CC-BY-SA/OGA-BY/GPL, créditos en `assets/pixel/lpc/CREDITS.csv`), también mochilas y pantalones teñidos.

### D-128 — Consumibles para otras pistas (2026-11-02, dueño)
`LootDefs.CONSUMABLES` es la lista de lo que cabe en la bolsa (antes, una lista fija en `Game.pack_consumable`). Comidas con buff (se comen al entrar, toda la expedición): estofado (+10 % vida máx.) y asado especiado (+8 % ataque y magia), en la cocina. **Kit de campamento** (peletero) y **carcaj de flechas** (taller): se fabrican y se llevan; los usará la pista A (campamento, munición). Comprar flechas: pendiente del mercader (pueblo).

### D-129 — Libros (2026-11-02, dueño)
Drop raro de élites (3 %) y jefes (30 %), al almacén del pueblo; se usan desde el inventario: **libro de experiencia** (un nivel entero), **tomo de habilidad** (`HeroData.bonus_skill_choice` +1, lo lee la pista A), **manual de oficio** (+1 nivel de una profesión; la pista B lo apuntará a aldeanos), **plano maestro** (llama a `Game.apply_master_plan` si existe —pista B—; si no, se guarda). Distinto de los libros de entrenamiento (`Game.books`, XP fija).
Guardado: campos nuevos con valores por defecto (`hoard`, `bonus_skill_choice`, hueco `bag`); **sin subir `SAVE_VERSION`** (se sube en el merge). Pruebas: `tests/smoke_loot.gd`; captura: `tests/capture_loot.tscn`.

### D-130 — Sim Lab: interfaz para el simulador (2026-11-02, dueño: "Sim Lab")
Escena de herramienta `res://tools/sim/sim_lab.tscn` (botón **Sim Lab** en la fila Debug del menú principal, o `godot --path . res://tools/sim/sim_lab.tscn`). No reimplementa nada: arma la config JSON de D-083/D-084, lanza `run_sim.gd` como proceso aparte (`OS.execute_with_pipe`, lectura en hilos: la UI no se congela) y lee `results.json`.
- **Config (izquierda):** pisos (casillas desde `TowerExpedition.FLOORS` o rango), bot táctico/loco/ambos + avanzado, party de 5 filas (clases de `HeroTables`/`MasterDefs`, rarezas, rasgos, skills filtradas con `SkillDefs.usable_by`, gear de `gear_presets.json` o lista de ítems de `ItemDefs.BASES`), aleatorio por fila y party, **arquetipos** en `tools/sim/configs/archetypes.json` (D-131, ampliable), progreso + gear_style, sliders de enemigos, overrides con autocompletado de constantes numéricas de `scripts/data|sandbox|core|combat`, sweep, runs/semilla/workers/max_time, Rápido (5) y Completo; guardar/cargar/duplicar en `tools/sim/configs/`.
- **Resultados (derecha, D-132):** barra de progreso (líneas `[n/total runs]` del simulador, por lote de runs) y Cancelar; tabla por piso (rojo < 10 %, verde 40–80 %, gris > 95 %); táctico vs loco con diferencia y alerta < 30 pts; daño/curación/daño recibido por héroe; historial (`docs/reports/sim/*/results.json`), comparar 2 por piso; abrir carpeta del reporte.
- **Cambio mínimo en el simulador (D-133):** `--cancel-file <ruta>`: si el archivo aparece, el padre mata a sus workers y sale con `SIM ERROR: cancelled`. Los errores de validación son los mismos `SIM ERROR` del simulador, mostrados en la UI (más 3 comprobaciones previas: sin pisos, sweep sin parámetro o paso ≤ 0).
- **Prueba (D-134):** `godot --headless --path . -s res://tools/sim/sim_lab_smoke.gd` (abre la escena, 2 runs del piso 1, lee el resultado). No está en `Run-Tests.ps1`.
- Fuera de `tools/sim`: botón en `scripts/ui/main_menu.gd` y textos en `strings_es.gd`. No añade mecánicas al juego (no hace falta comparar floors1-10 antes/después).

### D-140 — Integración de las pistas paralelas, arquero (03b) y guardado v20 (2026-11-02, dueño: "Merge de pistas paralelas")
Rama `feat/integracion` desde `feat/d083-headless-sim`; merges en orden Sim Lab (D-130), pista A (D-090), pista D (D-120), pista C (D-110).
- **Conflictos:** textos y DECISIONS (se conservan todos los bloques, por ID); `master_bot.gd`: con campamento en marcha se queda sentado, luego saquea (D-121) y después pide acampar si la escuadra está agotada (D-090); `tools/sim`: claves de bot `camp`, `camp_below` y `loot`, estadísticas y tablas de las dos pistas, `--cancel-file` y armadura por clase conviven; `Run-Tests.ps1`/`run_tests.sh` con las suites `pista a`, `loot` y `juice`.
- **Conexiones entre pistas:** `camp_kit` y `arrows` (ítems de D) los leen el campamento y el carcaj de A; `bonus_skill_choice` (D) da la opción extra de A; `resource_value`/`resource_max` (A) los leen las party frames (C); la sinergia de recolección de C apuntaba a `two_on_ore` y ahora usa `gather_pair` ("Dos en una veta", `mult` = velocidad). La clave de texto "Opening" chocaba (sinergia de A / verbo de C): el verbo de C pasa a "Opening the cache".
- **03b:** el explorador/ranger pasa a **arquero** (`class.archer`, "Archer"/"Arquero"). `HeroTables.canonical_class` acepta `class.ranger`/`class.explorador` en guardados; el simulador acepta `ranger`, `explorador`, `arquero` y `archer`. Mismo peso y orden en `BIRTH_CLASS_WEIGHTS`: las semillas dan los mismos héroes.
- **Guardado v20:** `synergy_codex` vacío; por héroe (y en las instantáneas del memorial) clase migrada, `hoard` = [], `bonus_skill_choice` = 0 y `bonus` = false en elecciones pendientes. C y el Sim Lab no guardan nada.

### D-141 — Pase visual e interfaz (2026-11-02, dueño: lista de capturas "OK vamos a fixear bugs e implementar mejoras visuales")
- **Una sola partida** (dueño: "no hay 'nueva partida', solo tienes 1 partida, no se puede reiniciar"): el título ofrece **Continuar** o, sin partida, **Comenzar**. Solo una partida hardcore terminada (D-081) puede **Empezar de nuevo**. El botón de depuración "Reset save" del menú de depuración se mantiene (no es del juego final).
- **Sin filas delantera/trasera** en el escuadrón (dueño: "ya no es un juego de turnos y filas"): 5 puestos en línea (el 1, el Máster). El orden de `Game.party` no cambia.
- **Cámara de los pisos más cerca:** zoom inicial 1,5 (pasos 1 / 1,5 / 2). Pueblo: zoom inicial 1.
- **Capas:** árboles, rocas, troncos, arbustos, campamentos y el portal de salida son sprites ordenados por Y (antes horneados en el suelo: los héroes les pasaban por encima). Pueblo: edificios, anillo de árboles y decorado de la plaza también.
- **Botín en el suelo:** icono real del objeto con aura del color de su rareza, rebote al caer, destellos y haz de luz desde raro.
- **Salida y santuario legibles:** portal animado con "SALIDA"; el santuario es una piedra rúnica al lado del portal (antes encima) con su zona punteada.
- **Iconos de equipo por base** (`ItemIcons.RPG`, pack `rpg_icons` autorizado por el dueño): ya no salen espadas para todo.
- **Opciones:** Pantalla (ventana / completa / exclusiva, tamaño, VSync, límite y contador de FPS, ratón), Sonido (general, música, efectos, interfaz, silenciar en segundo plano), Juego (idioma, temblor, efectos, números de daño). La pantalla completa no funciona **dentro de la pestaña Game del editor** (ventana incrustada): el menú lo avisa; `tools/Play.ps1` abre el juego en su propia ventana.
- Rediseños: título, barra de recursos y barra inferior con nombres en el pueblo, menú Construir con imagen y emblema de cada edificio, paneles de edificio, Memorial (jardín de lápidas con epitafios), inventario (muñeco + mochila), ficha del héroe con ranuras de equipo.
- Héroes del pueblo: el tiempo libre se queda en la plaza (radio 8×5 celdas), van a la fuente, se sientan en los bancos y muestran emociones. **Necesidades y deseos propios: pendiente de diseño → P-30.**

### D-142 — Skills Q + 3, interruptores, Resurrección, sinergias, botín y frases en español (2026-11-02, dueño; matiza D-090, D-044, D-042, D-120)
- **Skills:** los héroes **empiezan solo con Q** (ataque básico, D-059); ya no nacen con una activa (sustituye D-044; `HeroGenerator.VERSION` 6). Eligen **1 de 3** en los niveles **2, 5 y 10** para **W, E y R** (`SkillDefs.CHOICE_LEVELS`); no hay más elecciones después: **máximo 4 activas** (Q + 3). Los héroes guardados conservan las skills que ya tenían (D-004). Libros y Campo de entrenamiento siguen enseñando skills, pero los huecos activos siguen siendo 3.
- **Interrupciones:** solo **Emboscada** (pícaro, `ambush`), **Disparo de interrupción** (arquero, `interrupt_shot`) y **Contrahechizo** (mago, `counterspell`) cortan un lanzamiento (`SkillDefs.INTERRUPTERS`); nuevas, en el grupo de elección de su clase. Ninguna otra skill lleva el efecto `interrupt`; un **aturdimiento pausa** la carga de una criatura (ya no la rompe) y un empujón tampoco la rompe (cambia D-042). La IA solo usa esas tres para cortar. El aturdimiento sigue rompiendo el escudo de un jefe (D-065).
- **Resurrección del clérigo:** no ocupa W/E/R; es la acción de **F** del clérigo (`SkillDefs.F_ACTIONS`): canaliza **4 s** junto a un caído (un golpe la corta) y lo levanta con el 25 % de vida, igual que el levantar común de D-082 pero con su nombre ("Mantén F: Resurrección"). Solo sirve en la agonía: tras la muerte permanente no hay vuelta (D-011).
- **Sinergias:** se quitan **flanqueo**, **espalda con espalda** y **muro de escudos** (quedan 13). La **marca del arquero** revela al objetivo en la niebla y el grupo le hace **+15 %** de daño (`marked` in_dmg 1,15; antes +25 %).
- **Botín:** gear por criatura **3 % normal** y **20 % élite** (antes 10 % / 35 %). El jefe del **piso 10** suelta **siempre un hacha épica** (morada; base `greataxe`), además de su botín normal (`LootDefs.BOSS_GUARANTEED`).
- **Frases de héroes** en español: entrada a piso, pueblo, respuestas a pings y el altar del Barón (`StringsEs.ES_D142`); `SandboxHero.say` y `TownHero._say` traducen.

### D-143 — Progresión pueblo ↔ torre (2026-11-02, dueño: "que el jugador no pueda progresar tanto en la torre si descuida su pueblo, pero no bloquearlo")
- **Tiempo:** pueblo 20 min reales = 1 día (`EconomyDefs.REAL_SECONDS_PER_HOUR` 50). Torre y Tierras Salvajes: 20 min = 2 días (`TOWER_SECONDS_PER_HOUR` 25, `expedition_hours(segundos)`, mínimo 1 h). **Sin botón "Pasar día"** (pueblo y HQ): saltar tiempo mientras se craftea o construye era trampa. Crafteo, obras y hospital ya consumen horas de trabajo (`work`, `work_left`).
- **Obras:** una obra a la vez por constructor (`Game.builder_count`, mínimo 1).
- **Pociones:** solo de alquimia (los cofres de los pisos 1-2 ya no dan pociones). Enfriamiento de 5 min por héroe (`LootDefs.HEAL_POTION_CD`); los héroes beben solos por debajo del 25 %; el Máster solo con la tecla **D** (el bot del simulador la pulsa por él).
- **Cocina:** las comidas de expedición dependen del nivel de la cocina (`blvl`): guiso Nv1, asado Nv2, caldo de hueso Nv3 (+12 % armadura y resistencia mágica), festín del cazador Nv4.
- **Joyería:** 6 joyas nuevas con estadística propia (anillos de rubí, zafiro y hierro; colgantes del corazón y del sol; cadena veloz) + afijos al azar. **Trinkets** con pasiva por probabilidad, una o más por clase (runa de sangre: 5 % al golpear te curas el daño del golpe; baluarte, sombra, halcón, maná, piedad, espinas, trébol). La pasiva solo funciona para sus clases. Iconos del pack rpg_icons.
- Las enfermedades siguen como estaban (bajan atributos; la herida infectada solo se cura en el hospital).

### D-144 — Pueblo con el Máster y crafteo por encargo (2026-11-02, dueño: "el pueblo debería estar en cámara del máster… si quiero una poción debo ir a craftear con los materiales")
- **Cámara siempre en el Máster** en el pueblo (sin cámara libre ni arrastre). Clic en el suelo: el Máster camina. Clic en un edificio: camina hasta la puerta y entra; **F** en una puerta también entra. El interior muestra al Máster junto a la puerta. Sin Máster (cuentas viejas, pruebas) se mantiene la vista directa.
- **Encargo + artesano:** dentro del edificio, el libro de recetas encarga N piezas (`Game.order_craft`); el héroe artesano asignado las fabrica con su tiempo de trabajo. Sin artesano no se hace nada.
- **Solo lo básico es automático** (`EconomyDefs.AUTO_RECIPES`: grano, hierbas, leña, piedra, mineral, comida del pueblo, materiales, lingotes) y los servicios (hospital, taberna). Pociones, medicina, antídotos, elixires, comidas de expedición, equipo, joyas, bolsas y flechas **solo por encargo**; terminado el encargo el banco descansa. "Crear todo" = lo que pagan los materiales del almacén.
- El hospital sigue admitiendo enfermos solo (D-047); la medicina ahora sale solo por encargo en la alquimia.
### D-145 — Telegrafías variadas, skills de criatura visibles y juice de ataques enemigos (2026-11-02, dueño)
- **Formas:** el golpe básico marca **círculo** (en el objetivo), **cono** (delante de la criatura) o **línea** (desde la criatura a través del objetivo) según su rol (`EnemyDefs.strike_shape`): magos/chamanes círculo, arqueros/escupidores línea, brutos y guardias cono, el resto círculo pequeño. Las skills llevan su propio `shape`: Golpe brutal (Slam) = cono de 120°, Disparo apuntado = línea; el resto, círculo. Solo recibe quien sigue dentro de la forma (`SandboxEnemy.in_telegraph`); los héroes esquivan según la forma.
- **La skill se ve al soltarse** (`look` en `EnemyDefs.SKILLS`): bola de fuego que vuela y explota, flecha a lo largo de la línea, meteoro desde el cielo, nube de esporas, golpe de suelo; el daño llega cuando el proyectil llega. Bandidos con ataque propio (`CombatVFX.ENEMY_FX`): arquero flechas, mago bolas de fuego, chamán orbes, brutos tajos.
- **Juice:** perfiles propios para cada skill de criatura y cada disparo básico (`JuiceDefs.ENEMY`, ids `eskill.*`), leídos por `JuicePlayer.resolve`. Skills de héroe: todas tienen perfil (comprobado por `juice`).
- **Barras de vida de criaturas:** bajan al instante, la parte blanca espera 0,3 s y se drena; destello blanco al recibir (cierra el pendiente de D-111).

### D-146 — Consola de desarrollo con clave (2026-11-02, dueño: "consola de desarrollo para testear a mano los pisos 1–10 sin reiniciar la partida al morir")
- **Acceso:** la tecla bajo Esc (` / º, por posición física) abre y cierra la consola (autoload `DevConsole`). Abrirla no activa nada: solo acepta `/key <clave>`; lo demás responde "bloqueado". En el código solo está el **SHA-256** de la clave (`DevCommands.KEY_HASH`); la clave nunca sale en la consola, el historial ni los logs. Desbloqueo solo en memoria hasta cerrar el juego. 3 claves malas = 30 s bloqueada.
- **Marca:** desbloquear o usar cualquier cheat pone `Game.cheated = true` (guardado v21, nunca se borra salvo partida nueva) y añade una línea a `user://cheat_log.txt`.
- **Una capa:** `scripts/dev/dev_commands.gd` llama a las APIs de cada sistema (Game, SandboxScreen, Combatant, HeroData); no duplica reglas. Comandos: ver `/help`. `/revive` solo levanta a los derribados: los muertos siguen muertos (D-011). `/quicksave` usa `user://dev_quicksave.json`, nunca el guardado normal. `/floor goto|reset|respawn` reconstruyen la pantalla del piso (los nodos, oleadas, zonas y mecanismos del anterior se liberan con ella); misma seed (`Game.tower_maps`).
- `/god` (todo golpe hace 0) y `/fly` (línea recta a través de muros; al apagarlo el Máster sale a la celda libre más cercana) no dejan estado al apagarse y se mantienen al cambiar de piso.

## 2. PENDIENTES (ideas que se conservan; no implementar sin respuesta del dueño)

| ID | Tema | Lo que existe / origen | Pregunta abierta |
|---|---|---|---|
| P-01 | ~~Generación procedural de pisos/mundo~~ | **RESUELTA → D-026** (2026-10-30) | — |
| P-02 | ~~Torre de 100 pisos; primeros 10 como alcance inicial~~ | **RESUELTA → D-027** (2026-10-30) | — |
| P-02b | Progreso de la torre | D-027 | Repetición de pisos, recompensas por piso, desbloqueos cada 10 pisos (mazmorras, instalaciones, tope de nivel: REFERENCE #15) |
| P-03 | **Biomas** (pisos 1-10 → bosque, D-031; resto pendiente) | Imagen de mapa (piedra, agua profunda, hierba, lava, cristal mágico, puentes, puertas); 8 familias temáticas del Bible: Ashen/cursed kingdom, Verdant/overgrown wilds, Arcane/fractured reality, Umbral/abyssal depths, Storm/sky-isles, Forge/clockwork empire, Tidal/drowned civilization, Crystal/glass desert (etiquetas de trabajo) | ¿Qué biomas en los pisos 1-10? |
| P-04 | ~~HQ in-game explorable, no un menú~~ **RESUELTA → D-030** | Imagen `hq_ingame_reference_THIRD_PARTY.jpg` (sala con zonas etiquetadas, héroes paseando con bocadillos de diálogo); `HQWorld` (Mega Prompt) | ¿Vista isométrica o cenital? ¿Qué zonas? |
| P-05 | **Profesiones de vida pasada** | 20 profesiones en `HeroTables.PROFESSIONS` (granjero, chef, herrero, leñador, minero, constructor, médico, mercader, guardia, cazador, sastre, ingeniero, explorador, erudito, alquimista, sacerdote, pescador, mozo de cuadra, cantero, artista), cada una con bonus y acción improvisada (Gemini, 2026-10-29) | ¿Afectan a producción, crafting y/o combate? ¿Cómo? |
| P-06 | ~~Conjunto de clases base~~ | **RESUELTA → D-028** (2026-10-30) | — |
| P-07 | **Clases avanzadas por promoción** | Berserker, Assassin, Sniper, Templar, Sorcerer (HANDOFF 2026-10-28 23:41; no en código) | ¿Confirmadas? ¿Una por clase base? |
| P-08 | ~~Estrellas y niveles~~ | **RESUELTA → D-029** (2026-10-30) | — |
| P-09 | **Rarezas** | Spec: Common/Uncommon/Rare/Epic/Legendary (provisional). Código: 1-5★. Regla vigente: rareza ≠ personalidad ni moralidad | ¿Nombres o estrellas? |
| P-10 | **Biblioteca de habilidades (D-022)** | 130 habilidades en `docs/specs/SKILLS.md` (7 "implemented", 124 "spec"); regla 4 activas + 1 definitiva; nivel 1-70; ≥30 aprendibles y ≥20 exclusivas por clase de combate; cada skill con qué hace, cómo se juega en tiempo real, sinergia, etiquetas de enemigo; API prevista `SkillLibrary` + generador `tools/gen_skill_library.py` (**no existen en el repo**) | ¿Se mantiene la regla y se regenera para las clases de P-06? |
| P-11 | **Memoria desbloqueada al promocionar** | D-018 "MAYBE": revelaría un recuerdo ya guardado en la generación, nunca inventaría hechos | Sí/No |
| P-12 | ~~Significado de "sacrificio"~~ **Resuelta por D-061** (héroe → materiales) | — | — |
| P-13 | ~~Rescate de caídos~~ **RESUELTA → D-036** | Descrito en `SESSION_SUMMARY` (no existe en código); `rescue_hero()` existe solo como función de datos | ¿Es idea del dueño? ¿Cómo encaja con D-011? |
| P-14 | **Ropa interior por defecto vs cuerpo base** al equipar armaduras | D-021 | Elegir |
| P-15 | **Secretos y cadenas de descubrimiento** | `discover_secret()` idempotente, no heredable tras la muerte (solo datos + test) | Alcance y fuentes de secretos |
| P-16 | **Legado tras la muerte** | Prompt 2026-10-30; memorial existente | Definir qué deja un héroe muerto (reliquias, archivo, recuerdos en otros héroes…) |
| P-17 | ~~**Expediciones**~~ **RESUELTA → D-070** (offline) | Bible pilar 4 ("base, economía, equipo y expediciones se refuerzan"); prompt 2026-10-30 | ¿Son las misiones de torre o envíos sin control directo? |
| P-18 | **Eventos de misión / objetivos que cambian** | REFERENCE #9 (explorar → exterminar → escapar), prompt | Alcance |
| P-19 | **Inventario, loot procedural, afijos, sets** | Prompt 2026-10-30; Bible exige guardar inventario/equipo | Necesita spec: `docs/specs/ITEMS_AND_LOOT.md` |
| P-20 | **Crafting** | Bible "Base/economy: training, crafting, research, storage, production"; prompt | Recetas, estaciones, relación con profesiones |
| P-21 | **Economía y recursos** | Código: gemas, piedras de promoción, libros, comida, materiales, medicina; REFERENCE #17 moneda abstracta única (CANDIDATA) | Fuentes, sumideros, topes |
| P-22 | **Construcción e instalaciones** | Código: cocina/taller/enfermería/sala común con niveles; edificios de pueblo (ayuntamiento, 2 dormitorios, herrería, cocina, enfermería) donde cada dormitorio da +5 de capacidad; REFERENCE #8 (estación de promoción, casa de conversión, archivo de reliquias de caídos) | ¿Un único modelo? ¿Qué instalaciones? |
| P-23 | **Producción** | Código: cantidades fijas por trabajador; se pretendía bonificar por profesión | Reglas |
| P-24 | **Diálogo de personalidad ("chatter")** | `HeroChatter` (frases por rasgo al entrar al piso); Roadmap: plantillas deterministas por evento; LLM solo opcional para verbalizar (Bible) | ¿Plantillas por evento? |
| P-25 | ~~**Jefe del piso 10**~~ **RESUELTA → D-069** | Principios confirmados en D-014; fases genéricas de llamada y furia en D-064 | Mecánicas propias del jefe del piso 10 y de la arena |
| P-26 | **Política de duplicados, renombrar y liberar héroes** | Spec §9: recomendado = cada tirada es un héroe distinto, nombres repetidos con callsign (implementado) | Decidir si hay conversión en fragmentos, renombrado o liberación |
| P-27 | **Pasivas en tiempo real** | 16 pasivas con texto heredado de turnos/filas | Reescribir para tiempo real |
| P-28 | **Protocolo de agentes** | Antes: claims + STATE_HASH + `ts_sync.py` (archivado 2026-10-30). Ahora: ramas + PRs + evidencia | Confirmar el nuevo flujo |
| P-30 | **Vida propia en el pueblo** (PENDIENTE, dueño 2026-11-02: "deberían tener necesidades o querer cosas por gusto, se tienen que sentir como personas reales; inspiración: el manhwa *Pick Me Up, Infinite Gacha*") | Hoy: `TownSim` (hambre/fatiga/estrés, trabajo, cama, taberna, hospital) + pasatiempos de `TownHero` (pasear, fuente, banco, charlar, entrenar) con emociones | ¿Qué necesidades/deseos (comida favorita, dinero propio, regalos, aficiones, quejas, peticiones al Máster)? ¿Afectan a Trust/Obedience o solo son vida visual? |
| P-29 | **Resistencias elementales en el gear** (PENDIENTE, Nathaniel 2026-10-31) | "Resistencias elementales en el gear. Ej.: piso 80 'El Infierno', boss de fuego infernal; sin un mínimo de resistencia al fuego en el equipo, el boss elimina a la party. Debe dejar margen para estrategias de skill (esquivar, cortar casteos), no ser un check 100% duro." Hook sin contenido: `Combatant.resistances`, `DamageInfo.element`, `CombatRules.resolve` | Elementos, fuentes en el gear, mínimos por piso |

### Preguntas abiertas heredadas (de DESIGN_GAPS, todas conservadas)
**Durante el prototipo de control:** G-01 plataforma/entrada (teclado+ratón propuesto) · G-02 pathfinding, evitación y reparto alrededor del destino · G-03 semántica y bindings finales de órdenes · G-04 ajuste del ataque básico (alcance, wind-up, recuperación, intervalo, proyectil, línea de visión) · G-05 habilidades: energía vs cooldown, objetivo, interrupción, canalización · G-06 legibilidad sin pausa (duración de telegrafías, avisos, zoom, densidad del HUD) · G-07 esquiva automática de peligros letales telegrafiados (acotada y legible) · G-08 percepción enemiga (línea de visión, ruido, radio, persecución) · G-09 compleción de misión (objetivo, extracción, enemigos opcionales, extracción fallida, recompensas parciales) · G-10 muerte/lesión (cuándo se guarda la muerte, recuperación de equipo, coste de retirada, escuadrón entero caído) · G-11 qué rasgos afectan preferencias transparentes · G-12 economía de invocación (probabilidades, coste, pity, pools, duplicados) · G-13 stats y crecimiento (presupuesto inicial, potencial, subida de nivel, compatibilidad clase/skill) · G-14 estados alterados (duración, acumulación, resistencia, ticks, control de masas en tiempo real) · G-15 legibilidad de jefes.
**Crecimiento (D-018):** G-21 eficiencia de síntesis, qué se transfiere, topes, bonus por misma clase · G-22 tipos y cantidades de materiales del sacrificio; ¿se pueden sacrificar tiers altos? · G-23 número de tiers y tabla de desbloqueos · G-24 = P-11 · G-25 ¿sacrificios/muertes cambian el Trust de otros y cuánto? · G-26 fuente de materiales de promoción tras el prototipo.
**Antes de ampliar el arte:** G-16 resolución interna, tamaño de sprite/tile, paleta, convención de frames · G-17 estilo de retrato y cómo se compone y persiste la variación visual · G-18 fuentes de assets con licencia o plan de arte original.

---

## 3. CANDIDATAS (inspiración, no requisitos)
De `docs/specs/REFERENCE_INSPIRATION.md`: clase exclusiva de invocación / clases disponibles según tier de nacimiento (#6) · instalaciones de promoción, conversión y archivo de reliquias de caídos (#8) · máquina de estados de objetivos cambiantes (#9) · opinión del héroe visible en objetivos opcionales, sin cancelar órdenes (#10) · regalos que suben Trust (#11) · jefes inmunes hasta activar un mecanismo del campo (#12) · moneda abstracta única con nombre original (#17). Ideas de agentes: profesiones con "acción improvisada" de combate; diálogo de entrada por rasgo.

## 4. DIFERIDAS
- **D-006 — Multijugador asíncrono primero:** visitas, defensas en instantánea, invasiones, rankings, eventos. Tiempo real fuera del alcance inicial.
- Progreso offline (basado en timestamp, con tope, idempotente; hora de servidor cuando haya online).
- Diálogo con LLM opcional (validado, nunca decide estado del juego).
- REFERENCE #7 mazmorras diarias de materiales · #13 repetición de misiones · #16 invasiones con penalización · #18 pisos ocultos por subquests. (#14 multi-escuadrón: NO por ahora.)
- Fuera de alcance inicial (Bible): multijugador en tiempo real, mundo abierto continuo, LLM locales, APIs generativas de pago, campaña enorme hecha a mano, monetización, producción masiva de assets antes de validar estilo.

---

## 5. SUSTITUIDAS (historia; no implementar nunca)
| Antes | Sustituida por | Nota |
|---|---|---|
| Dirección de arte 3D estilizada / low-poly (2026-10-27) | D-007 | — |
| **D-010** Combate por turnos y por rangos/filas (2026-10-28) | D-014 | Restos en código: filas FRONT/BACK en `party_screen.gd`, pasivas con "turno/fila" (ver P-27) |
| "La primera vertical slice puede usar 3 héroes" (changelog v1.4) | D-017 | — |
| Contador único `loyalty` | D-016 (Trust + Obedience) | Migración v1→v2 en el guardado |
| "Loyalty" como medidor aparte | Diferido indefinidamente (spec §7) | Solapa con Trust/Obedience |
| **D-003** "Mundos procedurales diferidos; mazmorra fija" (2026-10-28) | **D-026** | Los héroes procedurales siguen siendo núcleo (parte vigente de D-003) |
| Escala 5★ / niveles 10-20-40-60-80 (código) | D-029 | Pendiente de migrar en la Fase 5 |
| Clases Thief / Spearman / Archer (biblioteca de skills) | D-028 | Sus habilidades se conservan como ideas en `docs/specs/SKILLS.md` |
| "El repo/ZIP es solo documentación; no hay proyecto Godot" | Estado real del repo | — |
| Teclas 1-5 para cambiar de héroe controlado (D-015, D-017, D-053) | D-080 | Solo se controla al Máster; el código queda tras `MasterDefs.DEBUG_HERO_SWITCH` |
| Protocolo multiagente con claims, STATE_HASH, CONTEXT_BUNDLE/LITE | Ramas + PR + evidencia (P-28) | Archivado en `docs/archive/infos/` |
| Instalación por "drops" ZIP (`Apply-DropD.ps1`, `Update-Project.ps1`) | Git | Archivado |
