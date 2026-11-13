# PNJ persistentes (los ocho de Albor + Cornelius)

Simulacion ABSTRACTA y barata: cada PNJ tiene una linea por **etapa de historia** (0 inicio, 1 tras el piso 5,
2 tras el piso 9, 3 tras vencer a Garrick) en `data/lore.json` > `npcs`. No hay IA en tiempo real.

| PNJ | Papel | Personalidad | Pasado / secreto | Meta | Reaccion al avance |
|---|---|---|---|---|---|
| Brann | Herrero | Tosco y honrado | Forjo para la Vigia; reconoce el acero granate | Que su fragua sirva a los vivos | Etapa 2: "el acero granate es de la Vigia" |
| Mira | Alquimista | Curiosa, algo imprudente | Huele los relicarios; la tinta es de los Siete | Entender la tinta | Etapa 3: miedo y ganas de olerlos |
| Tomas | Carpintero | Calmado | Hizo los postes de la Vigia | Que el bosque vuelva a ser seguro | Etapa 2: el Cuervo usa su madera |
| Lena | Sastre | Reservada | Conoce el tinte granate de las insignias | Guardar su secreto | Etapa 2: revela de donde viene el tinte |
| Ottis | Tabernero | Hablador | Su nombre esta en el libro de la Vigia y no lo recuerda | Saber quien fue | Etapa 3: invita la casa |
| Dara | Gremio | Firme y breve | Sirvio en la Vigia | Cerrar el pasado | Etapa 2: "dile a Garrick que lo recuerdo" |
| Orla | Mercader | Astuta | Rechazo un relicario del Cuervo | No comerciar con lo que habla | Etapa 3: vende sin miedo |
| Tessin | Banquero | Meticuloso | Guarda una cuenta a nombre de una nina | Decidir que hacer con ella | Etapa 3: la cuenta de Garrick |
| Cornelius | Elite errante | Digno y cansado | Desertor de la Vigia/Cuervo; guarda el relicario de su hija | Que nadie tache su nombre | Solo aparece una vez (ver `10_BOSSES`) |

Rutinas: los PNJ de servicio estan en su puesto; los paseantes de la avenida son ambiente sin dialogo.
