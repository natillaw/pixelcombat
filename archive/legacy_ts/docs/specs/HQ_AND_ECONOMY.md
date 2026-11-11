# Headquarters, profesiones, construcción, producción, economía y crafting — banco de ideas

**Estado:** todo está **PENDIENTE** salvo lo indicado. Ideas conservadas, no requisitos.

## 1. HQ in-game (P-04)
- Indicación del dueño: el HQ debe verse **in-game y no como un simple menú**. Referencia: `reference/hq_ingame_reference_THIRD_PARTY.jpg` (solo inspiración: es de un juego de terceros, D-002).
- Elementos observados en la referencia: una sala interior con zonas etiquetadas (tablón de encargos, tienda de objetos mágicos, mostrador de aventuras, taberna, avisos del gremio, mapa), héroes que pasean con bocadillos de diálogo y PNJ en sus puestos.
- Existe: `HQScreen` (menú de asignación) y `HQWorld` (mapa explorable; no compila, F-001).

## 2. Profesiones de vida pasada (P-05)
Cada héroe nace con una (`HeroTables.PROFESSIONS`). Todas tienen bonus previsto y "acción improvisada":
granjero (provisiones; Pitchfork Thrust) · chef (comidas con buff; Frying Pan Bash) · herrero (fabricar y reparar equipo; Hammer Strike) · leñador (madera; Axe Chop) · minero (mineral y cristal; Pickaxe Swing) · constructor/carpintero (mejoras de edificios; Hammer Bonk) · médico/boticario (curar heridos, medicina; Bottle Throw) · mercader (comercio y precios; Walking Stick Strike) · guardia (defensa del asentamiento; Spear Thrust) · cazador (carne, pieles, materiales; Basic Bow Shot) · sastre/peletero (ropa y armadura ligera; Scissors Slash) · ingeniero (trampas y defensas; Wrench Strike) · explorador (inteligencia de exploración; Dagger Stab) · erudito (investigación y saber sobre enemigos; Book Bash) · alquimista (reactivos y elixires; Weak Potion Throw) · sacerdote (moral y recuperación espiritual; Staff Strike) · pescador (pesca; Fishing Rod Whack) · mozo de cuadra (monturas; Pitchfork Jab) · cantero (piedra y fortificaciones; Chisel Strike) · artista (moral; Instrument Bash).
**Hoy no tienen efecto en el juego** (F-009).

## 3. Instalaciones y construcción (P-22)
- Instalaciones de trabajo en el código: cocina (comida), taller (materiales), enfermería (medicina), sala común (socializar y entrenar), cada una con nivel (sin uso).
- Edificios del pueblo en el código: ayuntamiento, dormitorio 1 y dormitorio 2 (+5 de capacidad de roster cada uno, sobre una base de 5), herrería, cocina, enfermería; `upgrade_building` cuesta materiales (sin UI).
- Ideas de referencia (CANDIDATAS): estación de promoción con niveles, casa de conversión, archivo de reliquias de los caídos (encaja con memorial y legado).
- Hay que unificarlos en un solo modelo (F-009).

## 4. Producción (P-23)
Hoy cada trabajador produce por turno de HQ: cocina +5 comida, taller +4 materiales, enfermería +3 medicina; los compañeros de una misma instalación ganan +1 de relación y cada trabajo crea un recuerdo. Intención (aún no implementada): bonificar según la profesión.

## 5. Economía y recursos (P-21)
- Existen: gemas (invocar; recompensa de misión), piedras de promoción, libros de entrenamiento (100 XP cada uno), comida, materiales y medicina.
- Requisito del Bible: registrar fuentes, sumideros y topes de cada recurso.
- Candidata: una sola moneda abstracta con nombre original (inspiración: el recurso oculto de la obra de referencia; no usar su nombre).
- Progreso offline: DIFERIDO (con timestamp, tope e idempotente).

## 6. Crafting (P-20)
El Bible lo incluye en Base/economía (entrenamiento, crafting, investigación, almacén, producción, tablón de expediciones, desbloqueos de edificios). Sin spec: recetas, estaciones y relación con las profesiones (herrero, sastre, alquimista, chef…).
