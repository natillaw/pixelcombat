# Narrative - changelog

## 2026-11-12 - Mitologia aprobada: Opcion B, "La Herida que Recuerda"
Decision del dueno ("b"). Es canon desde ahora. Cambios de canon respecto a lo que ya estaba en el juego:

1. La Aguja Negra **reaparecio** hace trescientos anos (la herida se reabrio); los Siete la levantaron mucho
   antes. Sustituye a "cayo del cielo" en la intro.
2. El Cuervo sigue siendo, en publico, una banda de saqueadores; su verdad profunda (nacio de la Vigia de Albor
   y vende relicarios, recuerdos hechos objeto) se revela por pistas a lo largo del tier 1.
3. El "Primer Silencio" solo se nombra desde el tier 2; en el tier 1 es "el olvido" (rumor y pistas).
4. Las bestias siguen sin lore: son la fauna que el bosque conserva sin entender.

No se elimina nada del canon anterior: Albor, los Despiertos, el Gremio, los ocho PNJ, Garrick, Rask, Veyra y
Cornelius se mantienen; se les anade pasado y motivacion (ver 07_NPCS y 10_BOSSES).

## 2026-11-12 - Fase 13: repaso de contradicciones y cierre del tier 1
Repaso de lore (pisos 1-10, `data/lore.json`, `Narrative/`) tras aprobar la Opcion B:

- **Nombres**: todo el contenido visible esta en espanol (Maton, Espadachin, Arquero, Hechicero, Degollador y
  Escudero del Cuervo; Rask el Tajador, Veyra la Hechicera, Garrick Mano Negra, Cornelius el Desertor, Portaestandarte
  del Cuervo). Las bestias tienen nombre y plural propios y siguen sin lore. `tests/test_narrative.gd` comprueba que
  el nombre de cada jefe coincide con su hablante en el lore y que no quedan marcadores rotos.
- **Intro**: la frase antigua ("cayo del cielo") queda marcada como previa al cambio en `00_NARRATIVE_OVERVIEW.md` y
  anotada en `docs/DECISIONES.md`.
- **Primer Silencio**: solo desde el tier 2; en el tier 1 se usa "el olvido".
- **Cuervo**: bandidos = enemigos reales del tier 1; bestias = fauna que solo da materiales.
- **Misiones**: el marco de misiones (cadena del libro mayor, secreta de la Vigia, principal del Cuervo) usa las mismas
  banderas de historia que `TowerState.flags`; no introduce canon nuevo.
- **Nivel maximo**: el rediseno del guerrero fijo el nivel maximo en 10; la meta antigua "nivel 14-18 al llegar a
  Garrick" queda obsoleta y no aparece en el lore.

Sin contradicciones abiertas en el tier 1. Pendiente fuera de alcance: tier 2 en adelante.
