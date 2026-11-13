# Hoja de ruta narrativa

Hecho (2026-11-12): mitologia B aprobada (Fase 1), mitologia e historia (Fase 2), estructura de 100 pisos y
detalle de los pisos 1-10 (Fase 3), facciones y PNJ ligeros (Fase 4), jefes (Fase 6), banderas y estado del mundo
(Fase 7), datos y validadores (Fase 8 parcial), lore en el juego: titulos y frases de piso, dialogos de jefes,
PNJ por etapa, cierre del tier 1, rumores (Fase 9).

Pendiente del tier 1:
1. **Fase 5**: plantillas de mision con sabor del Cuervo (robar el cargamento, destruir el estandarte, interrogar al
   capitan) apoyadas en los tipos existentes, y mision principal tematica por piso 1-10; encuadrar con el marco de
   `docs/quests/`.
2. **Fases 10-12**: animaciones (muerte/parpadeo de enemigos LPC), efectos por ataque y estado, crafting completo por
   clase, libro de skills como botin de elite/jefe, iconos de consumibles, legibilidad de interfaz y balance con el bot.
3. **Fase 13**: validacion de punta a punta con `CampaignLab`.

Base futura (sin implementar): 9 regiones restantes (`03_TOWER_STRUCTURE.md`), el precio de guardar, quien firma los
relicarios, los Siete Pueblos.

## Fase 5 hecha (misiones con sabor del Cuervo)
Plantillas nuevas en `data/missions.json`: **Robar el cargamento** (cargamento = relicario, se lleva al altar de entrega),
**Destruir el estandarte** (portaestandartes inmoviles `crow_standard` que llaman refuerzos) e **Interrogar al capitan**
(caceria de un bandido elite). Las plantillas existentes tienen variantes con sabor (`flavors`) y los pisos 1-9 tienen mision
principal fija de historia (`story`): 1 Despejar la linde, 2 Quitarles las hachas, 3 Destruir el estandarte, 4 Prisioneros
del Cuervo, 5 Interrogar al capitan (+ Rask y Veyra), 6 Robar el cargamento, 7 Mojones de la Vigia, 8 El asedio del Cuervo,
9 Marcas del Cuervo; el 10 es la prueba de Garrick. Validado en `tests/test_narrative.gd`.

## Fases 10 y 11 hechas (tecnico)
- **10**: caida de los enemigos LPC al morir (giran sobre su ultima pose y se desvanecen), efecto al aplicarse cada estado nuevo (sangrado, silencio, escudo, empuje, comida) con duracion corta para que no se queden pegados, aviso "!" al despertar un campamento, efecto e icono por movilidad en el HUD, proyectiles con sprites del pack.
- **11**: cada ranura tiene al menos 2 recetas por clase y el set de tier 1 mas barato cabe en lo recolectable en los pisos 1-10 (test que lo mide); tomo de habilidad como segunda fuente de skills de mundo (Rask y Veyra 30 %, Cornelius 60 %, Garrick siempre); iconos de consumibles (CraftPix) e indicador de comida activa en el HUD; **cada item es su propio icono** (su pieza LPC recortada, `ItemIcons`) en mochila (rejilla), ficha de personaje, mercader y banco.
