# Region 1 - Bosque del Cuervo (pisos 1-10)  [DECISION APROBADA, implementada en data/lore.json]

Todos los pisos comparten **un solo bioma (bosque)** y se generan proceduralmente; por eso cada ficha es un
**papel narrativo** (que descubre o enfrenta el jugador, que bandidos aparecen, que tono), no geografia. Solo se
cita lo que el generador garantiza (campamentos, nidos, altares, jaulas, balizas, reliquias, sellos, vetas).
Fuente de verdad de los textos: `data/lore.json` > `floors`. Validado por `tests/test_narrative.gd`.

| Piso | Nombre | Tono | Papel | Frase de entrada | Pista / rumor del mundo | Bandidos | Bestias |
|---|---|---|---|---|---|---|---|
| 1 | La Linde | calma | Primeros pasos | Donde el bosque aun recuerda tu nombre. | Un trapo granate atado a una rama: alguien marca el camino. | espadachin | limo, murcielago, arana |
| 2 | Sendero de los Lenadores | inquietud | Se descubre que hay gente | Hachas sin dueno y huellas que no son de bestia. | Un hacha con el nombre raspado: nombres tachados. | maton, degollador | limo, avispa |
| 3 | El Primer Campamento | tension | Primer campamento serio | Humo, brasas y una bandera granate. | Cuentas: "relicarios entregados, catorce". | maton, espadachin, arquero | arana, murcielago |
| 4 | Emboscadas | peligro | Arqueros y degolladores; prisioneros | Aqui nadie te ataca de frente. | Un prisionero: buscan "cosas que huelen a recuerdo". | arquero, degollador, espadachin | avispa, limo |
| 5 | El Puesto Avanzado | hito | Rask y Veyra | Dos tenientes, una sola consigna: que nadie pase. | Rask quema relicarios, Veyra los lee; tinta granate en los dedos. | maton, hechicero, escudero | escarabajo, arana |
| 6 | Rutas de Contrabando | recelo | Carga y reliquias que recuperar | Lo que sale del bosque no siempre sale entero. | Cajas con lacre granate que susurran. | escudero, hechicero, degollador | murcielago, fuego fatuo |
| 7 | La Vigia Perdida | melancolia | Rastros de la Vigia de Albor | Insignias de una guardia que ya no existe. | Insignia de cuervo: "anotar a quien despierta". | espadachin, arquero, hechicero | fuego fatuo, limo |
| 8 | Territorio del Cuervo | opresion | Campamentos densos | Aqui el bosque tiene dueno. | Regla en un tronco: "tacha el nombre, guarda la cosa". | escudero, hechicero, maton, arquero | escarabajo, avispa |
| 9 | La Antesala | calma tensa | Calma antes de Garrick; el Desertor | El bosque se calla antes de Garrick. | Relicario con nombre de nina: "no dejes que me lo quiten". | degollador, escudero, espadachin, hechicero | arana, fuego fatuo |
| 10 | El Campamento de Garrick | confrontacion | Garrick y la revelacion | Un hombre que no olvida nada te espera. | "La Torre no te quita los recuerdos, te los guarda. Y yo vendo lo que guarda." | todos | - |

## Como se ve cada elemento del generador en la narrativa
- **Campamento** = puesto del Cuervo; **nido** = guarida de bestias (sin lore); **altar** = mojon de la Vigia
  (piso 7) o altar de tinta (resto); **jaula** = prisionero del Cuervo; **baliza** = marca de la Vigia;
  **reliquia** = *relicario* (objeto que guarda un recuerdo ajeno); **sellos del jefe** = lacre granate.
- **Elite errante**: Cornelius el Desertor (piso 5-10, 50 %); ver `10_BOSSES`.

## Conexion con el hilo general
Pisos 1-4: la banda existe y marca nombres. 5-6: el Cuervo comercia con recuerdos (relicarios). 7: nacio de la
Vigia. 8-9: su codigo y sus victimas. 10: Garrick revela que la Torre guarda, y que el Cuervo vende lo que guarda.
