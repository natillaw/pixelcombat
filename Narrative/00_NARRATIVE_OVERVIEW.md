# Narrativa de PixelCombat - vision general

Estado: **Fase 0 completada, Fase 1 pendiente de aprobacion del dueno.** Hasta que se apruebe una mitologia
no hay canon nuevo; todo lo marcado PROPUESTA puede cambiar. Lo marcado CANON ya esta en el juego.

## Canon existente (CANON, en `data/lore.json` y en el codigo)
- Albor (ciudad hub) al pie de la Torre de las Cien Puertas (la "Aguja Negra"). Los Despiertos: al morir
  vuelven a Albor sin heridas ni recuerdos de su vida anterior y se eligen nombre.
- PNJ: Brann (herrero), Mira (alquimista), Tomas (carpintero), Lena (sastre), Ottis (tabernero), Dara (Gremio),
  Orla (mercader), Tessin (banquero).
- El Cuervo (granate): banda de saqueadores del Bosque, jefe Garrick Mano Negra; tenientes Rask el Tajador
  y Veyra la Hechicera (pisos 5); elite errante Cornelius el Desertor (50 % de aparecer una vez en un
  piso 5-10). Las bestias son animales sin lore que solo dan materiales.
- Frase de la intro ANTES del cambio de canon (sustituida por la mitologia B): "hace trescientos anos el cielo se resquebrajo y cayo una aguja de piedra negra". Ahora la Aguja *resurge* (ver CHANGELOG).

## Lo que el generador de pisos garantiza (base para escribir texto de piso)
Fuente: `tower_generator.gd`, `map_gen.gd`, `mission_gen.gd`, `terrain_renderer.gd`, `data/biomes.json`,
`data/tower.json`. **Los pisos son procedurales y los 10 pisos del tier 1 comparten un solo bioma (bosque).**
Por tanto el texto de un piso solo puede apoyarse en esto:

- **Bioma**: `forest` en todo el tier 1 (hierba verde, arboles como muros, flores, matas, setas, rocas,
  estanques de agua, tinte frio-azulado, vineta). Nada de rios caudalosos, montanas ni minas.
- **Estilo de mapa** (sorteo ponderado): campo abierto (4), mixto (3), cuevas (1). Tamano 64-72 x 48-56 casillas
  (pisos 1-3) y 84-96 x 64-76 (resto); entrada en una esquina y salida lejos; pasillos de al menos 3 casillas.
- **Campamentos** de 2-4 enemigos (pool del tier: bandidos ~79 %, bestias ~21 %), nidos de bestias
  (mision "Plaga") con crias, vetas ricas de mineral/hierba/madera, altares, jaulas de prisioneros,
  balizas de exploracion, baliza de resistencia, reliquia + altar de entrega, sellos del jefe.
- **Misiones de piso**: principal (+ opcional a veces): limpieza, caceria de elites, exterminio de un tipo,
  recoleccion, rituales (altares), reconocimiento (balizas), rescate, plaga (nidos), resistencia, reliquia.
  Pisos x5: doble mision, 2 minijefes (Rask y Veyra) y limite de tiempo opcional. Piso 10: Garrick con
  prueba (sellos, oleadas o escoltas elite).
- **Elite errante** (Cornelius): opcional, un piso entre 5 y 10, una sola vez por partida.
- Nada mas: no hay puentes, edificios en los pisos, mazmorras interiores ni cambios de bioma dentro del tier.

Consecuencia de diseno: la **variedad de cada piso es narrativa** (papel, tono, que bandidos y bestias aparecen,
que pista se encuentra), no geografica.
