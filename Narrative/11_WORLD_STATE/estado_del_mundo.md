# Estado del mundo y consecuencias (tier 1)

Banderas narrativas persistentes: `TowerState.flags` (se guardan en la partida, `to_dict` / `from_dict`).

| Bandera | La pone | Efecto visible |
|---|---|---|
| `rask_defeated` | Matar a Rask | (gancho) cambia lo que cuentan los PNJ en futuras ampliaciones |
| `veyra_defeated` | Matar a Veyra | idem |
| `cornelius_defeated` | Matar a Cornelius | no vuelve a aparecer (ya existia `elite_defeated`) |
| `garrick_defeated` | Matar a Garrick | PNJ en etapa 3, rumores nuevos en la taberna, cierre del tier |

**Etapa de historia** (`TowerState.story_stage`): 0 al empezar, 1 tras completar el piso 5, 2 tras el piso 9, 3 tras
vencer a Garrick. Decide la linea de cada PNJ (`Lore.npc_line(station, stage)`).
**Rumores**: lista base + `rumors_after[bandera]` (`Lore.rumor(index, flags)`).
Ampliaciones previstas (no hechas): reputacion numerica con el Gremio y cambios del tablon segun banderas.
