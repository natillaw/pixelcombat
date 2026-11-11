# Diseño de las cinco clases básicas
Documento de diseño, versión de trabajo 2.
Fecha: 5 de noviembre de 2026. Cambios respecto a la v1: recursos propios por clase, sin combos en los ataques básicos, sin builds predefinidas, curación híbrida confirmada y nueva pasiva del Warrior.
## 1. Estructura general del sistema de clases
Las cinco clases básicas son Warrior, Rogue, Ranger, Cleric y Mage.
Cada clase tiene:
Un arma característica fija.
Un estilo de combate propio.
Un recurso propio (Rage, Energy o Mana).
Dos ataques básicos, M1 y M2. Son simples, sin combos.
Un Skill Book de 15 habilidades normales.
Cinco espacios equipables para habilidades normales.
Un espacio de Special y uno de Ultimate.
Atributos principales y secundarios.
Posibilidad de evolucionar a una especialización permanente.
Las armas características no se intercambian entre clases. El equipo mejora estadísticas, rareza, propiedades y apariencia, pero no cambia el tipo de arma. Las evoluciones pueden conservar el arma original o adoptar una nueva.
Los combos en los ataques básicos quedan reservados para las clases evolucionadas. Las clases base solo tienen un golpe básico (M1) y un golpe secundario (M2).
### Controles
M1: ataque básico principal.
M2: ataque básico secundario.
S1 a S5: cinco habilidades normales elegidas del Skill Book.
SP: Special.
Ultimate: habilidad definitiva.
### Reglas del Skill Book
Cada clase tiene 15 habilidades normales. Las habilidades desbloqueadas permanecen disponibles.
No hay builds predefinidas. Cada jugador elige libremente sus cinco habilidades y juega como prefiera. El documento no recomienda combinaciones.
El loadout se cambia en la ciudad, zonas seguras y antes de entrar a una actividad. No se cambia durante un combate PvP.
Las habilidades se desbloquean por progresión, desafíos, jefes, misiones y secretos.
Las evoluciones tendrán habilidades propias y podrán heredar, restringir o transformar parte del catálogo de la clase base.
Cada habilidad debe aportar una decisión táctica distinta, no ser una copia con otro nombre o color.
## 2. Recursos por clase
Cada clase usa un recurso distinto. Para facilitar el balance, todos se diseñan sobre una escala de 0 a 100. Los valores son provisionales y requieren pruebas.

| Clase | Recurso | Cómo se obtiene |
| Warrior | Rage (Ira) | Empieza en 0. Se llena al golpear y al recibir golpes. Decae fuera de combate. |
| Rogue | Energy | Regeneración pasiva constante. |
| Ranger | Energy | Regeneración pasiva constante. A confirmar. |
| Cleric | Mana | Regeneración lenta, ligada a Spirit. |
| Mage | Mana | Regeneración lenta, ligada a Spirit. |

Reglas generales:
M1 y M2 no cuestan recurso. Las habilidades normales y el Special sí.
Rage: la ganancia al recibir daño es proporcional al porcentaje de vida perdido, con un tope por golpe. La ganancia al golpear tiene un tope por lanzamiento, para que los ataques multiobjetivo no generen Rage excesiva.
Energy: regeneración fija por segundo, sin depender de aciertos. Los valores exactos se definen en pruebas.
Mana: la regeneración en combate es baja, para que el consumo sea una decisión. Intellect puede ampliar la reserva y Spirit mejora la regeneración.
Spirit es un atributo separado: regenera vida fuera de combate y ayuda a regenerar Mana en las clases que lo usan.
Ultimate (propuesta pendiente): usa una barra aparte, Ultimate Charge, de 0 a 100. Se carga al infligir daño, curar o recibir daño, sin regeneración pasiva, con límites por lanzamiento. El Special cuesta 30 del recurso de la clase.
## 3. Atributos y algoritmos
Referencia: World of Warcraft Classic (Vanilla), no Retail.
Atributos primarios
Strength: Attack Power físico y daño de armas físicas.
Agility: crítico físico, armadura y evasión; su contribución depende de la clase.
Stamina: vida máxima.
Intellect: poder mágico y reserva de Mana.
Spirit: recuperación natural de vida y de Mana.
Estadísticas derivadas: Attack Power, Spell Power, Critical Strike, Armor, Defense, Dodge, Parry, Block (si el equipo o la clase lo permiten), Hit (con cuidado de no provocar fallos arbitrarios en PvP), Weapon Damage, Weapon Speed. Healing Power solo si finalmente se separa de Spell Power.
Fórmulas de referencia (placeholders, no balance final)
Attack Power físico: AP = AP_base + 2 × Strength + AP_gear
Daño físico: D = WeaponDamage + (AP / 14) × WeaponSpeed
Daño de habilidad física: D_skill = (WeaponDamage + (AP / 14) × WeaponSpeed) × M + B
Vida: HP = BaseHP + (Stamina × C_HP) + HP_gear
Reducción de daño físico: DR = Armor / (Armor + K); DamageReceived = IncomingDamage × (1 − DR)
Crítico: Crit = Crit_base + (Agility × C_crit) + Crit_gear
Daño mágico: D_magic = (SpellBaseDamage + SpellPower × C) × M
Curación: Healing = (BaseHealing + HealingPower × C_h) × M_h
M es el multiplicador de la habilidad y B el daño adicional fijo o escalado. Los coeficientes C, C_HP, C_crit, K y los multiplicadores se definen con el nivel máximo, la escala de estadísticas, las armas y el ritmo de combate.
Filosofía de PvP
La precisión depende de la puntería, el posicionamiento y el timing. Un ataque que visualmente conecta no debe fallar por una tirada invisible de Hit.
Dodge es principalmente movimiento o una acción contextual, no evasión automática por azar.
Parry y Block tienen condiciones o ventanas reconocibles.
Puede haber normalización parcial de estadísticas en PvP para que el equipo importe sin sustituir la habilidad del jugador.
PvE puede permitir una influencia más marcada de atributos y equipo.
## 4. Warrior
Rol: Bruiser / Frontliner. Arma: Longsword a dos manos. Recurso: Rage. Atributo principal: Strength. Secundarios: Stamina, Agility. Dificultad: Media. Alcance: cuerpo a cuerpo.
Identidad: presión, resistencia, interrupción y castigo. El Warrior domina los intercambios físicos. No tiene la movilidad del Rogue ni el alcance del Ranger, pero mantiene presión, resiste y castiga errores. Empieza cada combate sin Rage y la construye intercambiando golpes.
Ataques básicos (sin combo)
M1, Sword Slash: un corte horizontal rápido de ritmo estable. Genera una pequeña cantidad de Rage al acertar.
M2, Heavy Strike: golpe vertical lento y potente, con recuperación mayor. Sirve para castigar a enemigos comprometidos. Genera más Rage que M1.
Pasiva (nueva), Vengeful Fury: al recibir un golpe, el siguiente Heavy Strike del Warrior gana un pequeño aumento de daño durante una ventana breve. No se acumula y no se activa con daño periódico. Refuerza la identidad de castigo y reduce la dependencia de empezar los intercambios. Valores provisionales.
Skill Book: 15 habilidades normales
Cleaving Strike (Daño/AoE): corte horizontal amplio que daña a todos los enemigos alcanzados.
Crushing Blow (Burst/Castigo): golpe descendente muy pesado. Interrumpe habilidades canalizadas si conecta.
Piercing Thrust (Daño preciso): estocada rápida y lineal, con más alcance que M1.
Whirlwind (Daño/AoE): giro con la espada extendida que golpea alrededor. Tiene límite de impactos.
Parry (Defensa): desvía un ataque frontal en una ventana breve. Si acierta, permite un contraataque rápido. Si falla, deja al Warrior expuesto.
Iron Guard (Defensa/Mitigación): postura defensiva temporal que reduce el daño frontal pero también la velocidad de movimiento.
Retaliation (Contraataque): prepara una respuesta potente si el Warrior recibe un ataque durante la ventana. No evita necesariamente todo el daño.
Combat Roll (Movilidad/Evasión): rodar en una dirección con una ventana breve de evasión.
Heroic Leap (Movilidad/Iniciación): salto a una ubicación seleccionada con golpe al aterrizar. El punto de impacto se muestra antes.
Relentless Pursuit (Movilidad/Persecución): carga frontal con daño al impactar y ralentización breve. Es predecible una vez iniciada.
Ground Stomp (Control/AoE): golpea el suelo y ralentiza brevemente a los enemigos cercanos.
Earth Splitter (Control de zona): fisura frontal que daña y ralentiza a los enemigos alcanzados.
Sundering Strike (Debilitamiento): golpe que reduce temporalmente la armadura del objetivo. No se acumula consigo mismo.
Battle Cry (Mejora/Ofensiva): aumenta temporalmente el Attack Power del Warrior y de los aliados cercanos, y mejora la resistencia a interrupciones leves.
War Banner (Apoyo/Control de zona): planta un estandarte que reduce el daño recibido por aliados cercanos. Puede ser destruido y solo puede haber uno activo.
Special, Iron Counter (coste propuesto: 30 Rage): postura de contraataque. Si recibe un ataque frontal bloqueable durante la ventana, lo desvía y responde con un corte potente. Premia leer al adversario.
Ultimate, War God's Descent (Ultimate Charge 100): salta a una zona marcada y cae con un golpe devastador. Hace más daño en el centro que en el borde, interrumpe brevemente y tiene una preparación visible que permite esquivarlo.
## 5. Rogue
Rol: Assassin / Skirmisher. Arma: Dual Daggers. Recurso: Energy. Atributo principal: Agility. Secundarios: Strength, Stamina. Dificultad: Alta. Alcance: cuerpo a cuerpo.
Identidad: movilidad, precisión, engaño y burst. El Rogue entra, ejecuta una combinación de habilidades, aprovecha una oportunidad y se retira. Tiene poca resistencia directa y depende de la movilidad y el timing.
Ataques básicos (sin combo)
M1, Twin Fang: tajo rápido con una daga. Alterna visualmente la mano, pero cada golpe es independiente.
M2, Cross Cut: ataque rápido cruzando ambas dagas. Puede causar daño adicional moderado al golpear por la espalda o durante una ventana de vulnerabilidad.
Skill Book: 15 habilidades normales
Shadowstep (Movilidad): desplazamiento corto hacia una dirección o posición válida.
Backstab (Burst): ataque potenciado desde detrás del objetivo.
Blade Flurry (Daño/AoE): serie de cortes rápidos alrededor del Rogue.
Poisoned Blades (Debilitamiento): aplica veneno con acumulaciones limitadas.
Mark for Death (Preparación): marca a un objetivo para potenciar el siguiente ataque u habilidad ofensiva.
Smoke Bomb (Escape): nube que dificulta la visión y permite reposicionarse.
Vanish (Sigilo/Escape): desaparece brevemente y rompe el objetivo enemigo, sujeto a reglas de detección y daño recibido.
Evasive Roll (Evasión): esquiva rápida con ventana limitada de evasión.
Shadow Clone (Engaño): crea un señuelo que confunde ataques dirigidos.
Fan of Knives (Área): lanza dagas en abanico.
Crippling Strike (Control): corte que ralentiza al enemigo.
Ambush (Iniciación): desplazamiento corto seguido de un ataque sorpresa.
Hemorrhage (Daño progresivo): aplica sangrado durante un periodo.
Feint (Defensa): reduce el daño de un ataque próximo si se ejecuta correctamente.
Executioner's Cut (Ejecución): golpe adicional contra objetivos con poca vida, con límite de daño para evitar ejecuciones injustas.
Special, Perfect Evasion (coste propuesto: 30 Energy): evasión con ventana muy corta. Si evita un ataque, habilita una oportunidad de contraataque que potencia la siguiente habilidad ofensiva.
Ultimate, Death Sentence (Ultimate Charge 100): marca a un enemigo y ejecuta una secuencia de desplazamientos y cortes rápidos. Requiere mantener al objetivo en alcance, puede ser interrumpida y termina con un golpe de daño elevado.
## 6. Ranger
Rol: Ranged DPS / Marksman. Arma: Bow. Recurso: Energy (a confirmar). Atributo principal: Agility. Secundarios: Strength, Stamina. Dificultad: Media-alta. Alcance: largo.
Identidad: precisión, distancia, trampas y persecución. El Ranger controla la distancia, anticipa movimientos y castiga errores de posicionamiento. Su daño viene de proyectiles, precisión y herramientas físicas, no de magia.
Ataques básicos
M1, Quick Shot: disparo único de cadencia estable. No es un combo.
M2, Charged Shot: carga el arco y dispara una flecha más potente, de mayor alcance y penetración. La carga reduce temporalmente la movilidad.
Skill Book: 15 habilidades normales
Piercing Arrow (Daño lineal): flecha que atraviesa enemigos alineados.
Multishot (Daño/AoE): varias flechas en abanico.
Explosive Arrow (Área): flecha que explota al impactar.
Rapid Fire (Presión): secuencia de disparos rápidos.
Crippling Arrow (Control): flecha que ralentiza al objetivo.
Marked Target (Preparación): marca al enemigo y mejora los siguientes ataques contra él.
Backstep Shot (Movilidad): retrocede mientras dispara.
Evasive Leap (Evasión): salto hacia atrás o lateral.
Bear Trap (Trampa): coloca una trampa que inmoviliza brevemente.
Frost Trap (Control de zona): crea una zona que ralentiza.
Volley (Área): lluvia de flechas sobre una zona marcada.
Camouflage (Escape): oculta temporalmente al Ranger bajo condiciones específicas.
Wind Arrow (Daño/Empuje): flecha de impacto que desplaza ligeramente al objetivo.
Predator's Instinct (Mejora): aumenta temporalmente el crítico y la velocidad de disparo.
Hunter's Focus (Preparación): mejora el siguiente Charged Shot y reduce su tiempo de carga.
Special, Deadeye (coste propuesto: 30 Energy): el Ranger entra en concentración. Su siguiente disparo gana velocidad de proyectil, precisión mejorada y capacidad de atravesar objetivos. El jugador todavía debe apuntar bien.
Ultimate, Rain of Arrows (Ultimate Charge 100): lluvia de flechas sobre un área marcada. Cobertura amplia y múltiples impactos, pero el área se muestra antes y el Ranger puede ser interrumpido durante la preparación.
## 7. Cleric
Rol: Support / Battle Healer. Arma: Mace. Recurso: Mana. Atributo principal: Intellect. Secundarios: Stamina, Strength. Dificultad: Media-alta. Alcance: corto-medio.
Identidad: curación híbrida (confirmada), protección, apoyo y daño sagrado. El Cleric combina curaciones directas, escudos y regeneración limitada, sin ser un sanador tradicional de gran capacidad de curación. Puede luchar, defenderse y castigar enemigos mientras administra sus herramientas de apoyo. No es obligatorio en ningún equipo, aunque cambia la estrategia grupal.
Ataques básicos (sin combo)
M1, Consecrated Strike: golpe de maza simple, de ritmo estable.
M2, Holy Smite: golpe pesado que libera una descarga sagrada de corto alcance.
Skill Book: 15 habilidades normales
Holy Light (Curación): curación directa a un aliado o al propio Cleric.
Radiant Burst (Daño/AoE): explosión sagrada alrededor del Cleric.
Divine Shield (Defensa): escudo temporal sobre un aliado.
Healing Wave (Curación): proyectil curativo dirigido.
Purify (Limpieza): elimina determinados efectos negativos.
Consecration (Zona): área sagrada que daña a los enemigos.
Smite (Daño): proyectil sagrado de impacto directo.
Guardian Angel (Protección): reduce el daño recibido por un aliado durante un instante.
Sacred Ground (Curación/Zona): zona que cura gradualmente a los aliados.
Hammer of Justice (Control): golpe que interrumpe y ralentiza brevemente.
Redemption (Recuperación): recupera vida de un aliado tras recibir daño, con condiciones y límite.
Blessing of Might (Buff): aumenta el Attack Power de un aliado.
Blessing of Fortitude (Buff): aumenta temporalmente la vida máxima.
Divine Step (Movilidad): desplazamiento corto acompañado de energía sagrada.
Judgment (Debilitamiento): marca a un enemigo y aumenta el daño sagrado que recibe.
Special, Divine Intervention (coste propuesto: 30 Mana): barrera protectora alrededor del Cleric o un aliado. Absorbe una cantidad limitada de daño. Si se destruye, libera una pequeña onda que empuja a los enemigos cercanos. No concede inmunidad completa.
Ultimate, Divine Salvation (Ultimate Charge 100): invoca un área sagrada que cura de forma considerable a los aliados, elimina algunos efectos negativos y daña ligeramente a los enemigos. Tiene preparación y área visible. No restaura automáticamente toda la vida del equipo.
## 8. Mage
Rol: Ranged DPS / Controller. Arma: Staff. Recurso: Mana. Atributo principal: Intellect. Secundarios: Agility, Stamina. Dificultad: Alta. Alcance: largo.
Identidad: magia, burst, control y manipulación elemental. El Mage domina el campo de batalla con hechizos. Tiene alto potencial ofensivo y de control, pero poca resistencia si un enemigo se acerca. Sus hechizos deben obligar al rival a moverse y decidir.
Ataques básicos
M1, Arcane Bolt: proyectil mágico rápido de daño moderado.
M2, Charged Arcane Blast: acumula energía y dispara un proyectil más lento, potente y grande.
Skill Book: 15 habilidades normales
Fireball (Daño): proyectil de fuego explosivo.
Frost Nova (Control): congela brevemente a los enemigos cercanos.
Lightning Chain (Daño): rayo que rebota entre enemigos.
Arcane Missiles (Daño): serie de proyectiles dirigidos.
Flame Wave (Área): onda de fuego frontal.
Ice Lance (Daño preciso): proyectil de hielo rápido.
Meteor (Burst/Área): meteorito sobre una zona marcada.
Blink (Movilidad): teletransporte corto.
Ice Barrier (Defensa): escudo mágico temporal.
Frost Wall (Control de zona): levanta una pared de hielo.
Arcane Explosion (Área): explosión mágica alrededor del Mage.
Mana Drain (Debilitamiento): drena una cantidad limitada del recurso del objetivo (Mana, Energy o Rage) o reduce su generación, con tope para no anular el sistema de recursos de una clase.
Spell Echo (Mejora): repite una versión reducida del siguiente hechizo.
Polymorph (Control): transforma temporalmente a un enemigo e interrumpe su acción. Duración limitada y contrajuego, sobre todo en PvP.
Elemental Surge (Mejora): potencia el siguiente hechizo elemental según el elemento elegido.
Special, Arcane Overload (coste propuesto: 30 Mana): concentra energía arcana y potencia el siguiente hechizo (daño, alcance o tamaño según el hechizo). Reduce brevemente la movilidad durante la canalización y no se acumula con potenciadores equivalentes.
Ultimate, Cataclysm (Ultimate Charge 100): canaliza una explosión elemental sobre una zona seleccionada. Gran daño de área, preparación visible y posibilidad de interrupción. Los enemigos pueden escapar.
## 9. Comparación de identidades

| Clase | Daño físico | Daño mágico | Resistencia | Movilidad | Alcance | Burst | Control | Apoyo |
| Warrior | Alto | Bajo | Alta | Media | Corto | Medio-alto | Medio | Medio |
| Rogue | Alto | Bajo | Baja | Muy alta | Corto | Muy alto | Medio | Bajo |
| Ranger | Alto | Bajo | Media | Alta | Largo | Alto | Alto | Bajo |
| Cleric | Medio | Medio-alto | Media-alta | Media | Corto-medio | Medio | Alto | Muy alto |
| Mage | Bajo | Muy alto | Baja | Alta | Largo | Muy alto | Muy alto | Medio |

Son identidades relativas, no cifras definitivas de balance.
## 10. Escalado por clase
Warrior: Strength principal; Stamina secundaria.
Rogue: Agility principal; Strength secundaria.
Ranger: Agility principal; Strength secundaria.
Cleric: Intellect principal; Stamina secundaria.
Mage: Intellect principal; Agility secundaria.
Las habilidades físicas escalan con Weapon Damage y Attack Power. Las mágicas, con Spell Power. La vida escala con Stamina. Las curaciones escalan con Spell Power, con coeficientes propios, a menos que se decida separar Healing Power.
## 11. Principios de balance y diseño
Las cinco clases deben ser viables en PvE y PvP.
Ninguna clase debe ser obligatoria para formar un equipo.
Las habilidades deben tener anticipación, impacto, recuperación y contrajuego legibles.
Los controles fuertes deben tener límites, inmunidades temporales o rendimientos decrecientes.
Los ataques de área deben tener límites de impactos y de generación de recurso.
Las habilidades definitivas deben ser poderosas, anunciadas y esquivables.
Cada jugador arma su propio loadout con total libertad. El diseño no debe empujar hacia una combinación única óptima.
El equipo debe importar sin hacer irrelevante la habilidad mecánica.
Las clases evolucionadas pueden conservar, restringir o transformar habilidades de su clase base, y es donde aparecen los combos básicos.
El catálogo puede crecer con habilidades avanzadas y secretas.
## 12. Decisiones
Confirmadas
Curación: híbrida. Curaciones directas, escudos y regeneración limitada.
Recursos: propios por clase. Warrior con Rage, Rogue y Ranger con Energy, Cleric y Mage con Mana.
Ataques básicos: simples en las clases base. Los combos se reservan a evoluciones.
Sin builds predefinidas: solo las 15 habilidades por clase y la elección libre del jugador.
Pendientes
Recurso del Ranger: Energy es una asignación provisional.
Ultimate: barra Ultimate Charge aparte (propuesta) o coste en el recurso de la clase.
Cambio de habilidades: recomendación de cambiar libremente en ciudad y zonas seguras; no confirmada.
Spell Power y Healing Power: recomendación inicial de una sola estadística.
## 13. Alcance del contenido
Con 15 habilidades normales por clase hay 5 × 15 = 75 habilidades normales, 5 Specials y 5 Ultimates: 85 habilidades únicas, sin contar M1/M2, variantes ni habilidades secretas.
No hace falta implementar todo en la primera demo. Conviene desarrollar primero un subconjunto representativo de cada clase, validar el combate y ampliar después el Skill Book.
