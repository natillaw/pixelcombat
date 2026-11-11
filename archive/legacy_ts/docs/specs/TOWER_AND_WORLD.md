# Torre, mundo, misiones y eventos — banco de ideas y spec parcial

**Estado:** torre de 100 pisos (D-027) y generación procedural (D-026) **CONFIRMADAS**; el resto está **PENDIENTE** (ver `docs/DECISIONS.md`). Este archivo recoge las ideas para que no se pierdan; **no son requisitos** hasta que se confirmen. Los principios de misión y de jefe ya CONFIRMADOS están en `CONTROL_AND_MISSIONS.md` §9-10.

## 1. Torre (D-027 confirmada; progreso P-02b)
- Meta indicada por el dueño (2026-10-30): **Torre de 100 pisos**, con los **10 primeros como alcance inicial**.
- Lo que existe en el código (`scripts/core/tower_expedition.gd`, tema "Stone Crypt & Ancient Depths"):

| Piso | Nombre | Dificultad | Misión | Tamaño (celdas) | Enemigos |
|---|---|---|---|---|---|
| 1 | Outer Threshold | Easy | combat | 80×80 | 4 |
| 2 | Guarded Hall | Easy | combat | 90×90 | 6 |
| 3 | Forgotten Corridors | Normal | retrieval | 100×100 | 8 |
| 4 | Patrolled Vaults | Normal | combat | 110×110 | 10 |
| 5 | Ancient Crypt | Normal | rescue | 120×120 | 12 |
| 6 | Catacomb Labyrinth | Hard | exploration | 130×130 | 14 |
| 7 | Corrupted Depths | Hard | combat | 140×140 | 16 |
| 8 | Deep Ritual Chamber | Hard | survival | 150×150 | 18 |
| 9 | Guardian Sanctuary | Very Hard | defense | 160×160 | 20 |
| 10 | Lord of the Depths | Very Hard | boss | 140×140 | 10 |

- Idea de referencia (CANDIDATA/DIFERIDA): cada 10 pisos se desbloquean mazmorras, instalaciones y un nuevo tope de nivel; pisos ocultos que se desbloquean con subquests.
- Preguntas abiertas: progreso por piso, si se pueden repetir pisos, recompensas por piso, y si el tamaño de 80-160 celdas es razonable (el rendimiento lo cuestiona: F-014).

## 2. Generación procedural (D-026 confirmada)
- Antes: D-003 (diferida; mapa fijo). Ahora: el dueño pide generación procedural (2026-10-30) y existe `ProceduralMap` (salas con reintentos, pasillos, bucles, celdas de enemigos y tesoros, validación de alcance).
- Referencia visual: `reference/procedural_map_reference.jpg`. Salas rectangulares y orgánicas, pasillos, puertas, ríos de agua profunda con puentes, praderas, lava, cristal mágico, antorchas, enemigos y objetos repartidos.
- Reglas obligatorias (MASTER_PROJECT §5): semilla + versión del generador, validar la navegación y **persistir el snapshot**.

## 3. Biomas (P-03)
Familias temáticas de trabajo: Ashen/cursed kingdom · Verdant/overgrown wilds · Arcane/fractured reality · Umbral/abyssal depths · Storm/sky-isles · Forge/clockwork empire · Tidal/drowned civilization · Crystal/glass desert. Elementos de terreno vistos en la referencia: agua profunda, hierba, lava, cristal mágico, puentes de madera.

## 4. Misiones (tipos)
Confirmados como principio (D-014): explorar, investigar, rescatar/escoltar, recuperar y extraer, defender, sobrevivir, evitar/distraer, mecanismos de jefe, y decidir entre extraer o seguir. Tipos que ya están en la tabla de pisos: combat, retrieval, rescue, exploration, survival, defense, boss.

## 5. Eventos (P-18)
- Objetivos que cambian a mitad de misión (explorar → exterminar → escapar), mediante una máquina de estados con cambios guionizados.
- Opinión del héroe ante objetivos opcionales (pista transparente; nunca cancela órdenes).

## 6. Secretos (P-15)
Existe `HeroData.discover_secret(id, pista)`: idempotente (sin recompensas duplicadas), crea un recuerdo y un evento (+5 Trust, +2 Obedience) y no se hereda al morir (el memorial lo conserva). Falta definir de dónde salen los secretos y qué otorgan.

## 7. Expediciones (P-17)
Pilar del Bible: base, economía, equipo y expediciones se refuerzan entre sí. Sin definir: ¿son las misiones de la torre o envíos de héroes sin control directo?

## 8. Jefes (P-25)
Principios confirmados: fases, ataques de área telegrafiados, ventanas de vulnerabilidad, objetos de arena, adds con propósito, presión del objetivo y decisión de extraer. Idea candidata: jefe inmune hasta activar un mecanismo o altar del campo.

## 9. Rescate de caídos (P-13)
Idea registrada (sin implementar): un héroe incapacitado puede ser rescatado antes de que expire un temporizador de agonía; si no, muerte permanente. Hay que encajarlo con D-011.
