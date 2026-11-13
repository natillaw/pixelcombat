# Sistema de misiones — arquitectura

Codigo en `game/quests/`, datos en `data/quests/`. Logica pura y determinista; la UI solo lee estado.

| Pieza | Responsabilidad |
|---|---|
| `QuestLibrary` | Carga y valida `definitions.json`, `reward_tables.json`, `secret_events.json`; busca por tipo/categoria/etiqueta; compatibilidad con un piso. |
| `QuestGenerator` | Definicion (plantilla) -> instancia (Dictionary): cantidades, texto, recompensa con semilla. Proteccion de repeticion y pesos por rareza. |
| `ObjectiveTracker` | `apply(objetivo, evento, sujeto, cantidad, ctx)`: kill, collect, interact, discover, reach, survive, condition. |
| `QuestManager` | Estados (locked/available/active/completed/failed/abandoned/claimed), limite de 3 secundarias, cadenas, ramas, reclamacion unica, guardado versionado. |
| `SecretEvents` | Condiciones all / any / sequence, piso, banderas, una vez por partida. |
| `RewardGenerator` | Puro: `generate(contexto, tabla, semilla)` -> paquete. No toca al jugador. |
| `RewardManager` | `deliver(player, paquete, flags)` todo o nada (comprueba mochila). |
| `SeedManager` | Semillas derivadas por hash de claves estables; sin RNG global. |

Definicion vs instancia: la definicion es JSON inmutable; la instancia guarda semilla, objetivos con progreso, recompensa ya generada y estado, de modo que recargar nunca regenera nada.

Integracion: `TowerState.quests` (se guarda con la torre), `GameSession` traduce eventos del mundo (muerte de enemigo, material, interaccion, piso, dano, pocion) a `QuestManager.on_event`; `ServicePanel` (gremio: Tablon / Misiones / Diario / Maestra) y `Hud` (rastreador) solo leen.
