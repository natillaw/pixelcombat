# Simulador de combate headless (D-083)

Juega expediciones reales con el código del juego (reglas, ítems, IA de héroes y bandidos, `MasterBot`) sin dibujar nada, a paso fijo y tan rápido como dé la CPU. Sirve para balancear sin jugar.

## Uso

```
godot --headless --path . -s res://tools/sim/run_sim.gd -- --config tools/sim/configs/floor1_tactico_vs_loco.json
```

En Windows, igual con tu `godot.exe` (el de consola). Opciones después de `--`:

| Opción | Qué hace |
|---|---|
| `--config <archivo>` | la config (obligatoria) |
| `--runs <n>` | cambia el número de runs |
| `--workers <n>` | procesos de Godot en paralelo (por defecto: núcleos − 1, máx. 8) |
| `--out <carpeta>` | dónde escribir el informe |
| `--check-determinism` | lo corre dos veces (con distinto reparto de procesos) y comprueba que sale lo mismo |
| `--quiet` | menos texto |

El informe queda en `docs/reports/sim/<fecha>_<nombre>/`: `resumen.md`, `runs.csv` (una fila por run), `heroes.csv` (una fila por héroe y run) y `results.json` (todo, con la config).

## Configs (`tools/sim/configs/*.json`, admiten comentarios `//`)

```jsonc
{
  "name": "mi_prueba",
  "floors": "1-10",            // número, lista o rango
  "runs": 20, "seed": 1000,    // o "seeds": [1, 2, 3]
  "max_time": 1200,            // s de juego por run (después: TIMEOUT)
  "tick_hz": 30,               // paso fijo
  "workers": 4,
  "bot": {"style": "tactico",  // "tactico" | "loco"
          "retreat_hp": 0.3,   // el Máster se aparta con menos vida que esto (táctico)
          "retreat_standing": 1, // el táctico abandona si quedan ≤ N en pie (0 = nunca)
          "ping_every": -1,    // s entre pings de ataque (-1 = el del estilo)
          "use_commands": true, "use_skills": true, "revive": true, "gather": true,
          "aim_error_mult": 1.0, // error de puntería de los héroes autónomos
          "think_every": 0.25, "engage": 320,
          "knows_map": false,  // false = explora con niebla como un jugador nuevo; true = sabe el mapa
          "regroup_wait": 6,   // táctico: espera al grupo hasta N s antes de atraer a un grupo nuevo
          "camp": true, "camp_below": 0.55},  // D-090 táctico: acampa con la party por debajo de esa vida (o un mago sin maná)
  "party": [                   // el piso despliega los que admite (piso 1 = solo el Máster)
    {"master": true, "class": "warrior", "level": 3, "traits": ["stubborn"], "gear": "tier1"},
    {"class": "cleric", "level": 2, "rarity": "rare", "attrs": {"int": 14}, "skills": ["..."],
     "gear": {"preset": "kit_blanco", "items": [{"base": "amulet", "rarity": "uncommon", "ilvl": 2}]}}
  ],
  "party_seed": 1, "gear_seed": 1,   // mismos héroes y mismos ítems al azar en todos los runs
  "progress": "medio",         // D-084: nivel y tier de equipo por piso según cómo progresó el pueblo (progress_profiles.json: lento / medio / rapido)
  "gear_style": "mix",         // con progress: mix (tierN), def (tierN_def: armadura) o atk (tierN_atk: arma y joyas)
  "matrix": {"master": ["warrior", "mage"], "party": {"equilibrado": [...]}, "gear_style": ["mix", "def"], "bot": ["tactico", "loco"]},
                               // D-084: todas las combinaciones como variantes (ver configs/matriz_builds.json)
  "enemies": {"hp": 1.0, "damage": 1.0, "count": 1.0},
  "overrides": {"CombatRules.ARMOR_FLAT": 0.3, "TowerExpedition.FLOORS.2.threat": 60},
  "compare": [{"label": "tactico", "bot": {"style": "tactico"}}, {"label": "loco", "bot": {"style": "loco"}}],
  "sweep": {"param": "CombatRules.ARMOR_FLAT", "from": 0.1, "to": 0.4, "step": 0.05}
}
```

- **Clases**: warrior, rogue, archer (arquero; `ranger` y `explorador` se aceptan como alias), mage, cleric, commoner (también en español). **Rareza** = alias de estrellas (common 1 … legendary 5; P-09 sigue pendiente).
- **Gear**: un preset de `gear_presets.json` (`kit_blanco`, `sin_nada`, `tier1`, `tier2`, `tier3`), o una lista de ítems de `ItemDefs.BASES`. Las propiedades al azar las pone `ItemGen` con `gear_seed`; `"stats"` fija valores a mano y `"affixes": []` quita los afijos.
- **overrides / sweep**: cualquier constante como `Clase.CONSTANTE` (o una clave dentro de una tabla: `Clase.TABLA.clave`). Se aplica en tiempo de ejecución en una copia parcheada del script que se carga en cada proceso antes de compilar el juego; el repo no se toca. Un `sweep` también acepta rutas de la config (`bot.retreat_hp`, `enemies.hp`).
- Alertas: piso imposible (< 10 %), trivial (> 95 %) y **ventaja táctica corta**: el táctico debe sacar ≥ 30 puntos al loco con la misma build (`alerts.tactical_gap`).
- Si un ítem, clase, rasgo, skill, preset, piso o constante no existe, el simulador para con `SIM ERROR: …` antes de jugar.

## Cómo funciona

- `run_sim.gd` (entrada) → `sim_main.gd` (valida, reparte runs en trabajos, lanza procesos `--child`, junta y escribe el informe con `sim_report.gd`).
- Cada proceso hijo (`sim_runner.gd`) monta una cuenta nueva por run (`sim_party.gd`), crea un `SandboxScreen` real del piso y lo avanza con `tick(1/tick_hz)`; el `MasterBot` maneja solo al Máster con pings, Comandos y skills, como un jugador. Objetivo de la misión: `MasterBot.mission_goal` (el mismo que usa `playthrough_bot`).
- `SimMode.on` apaga sprites, efectos, números flotantes, arte del mapa, dibujo de la niebla, HUD y pantalla de resultados. La niebla sigue limitando lo que ven los héroes.
- Reproducible: la semilla del run entra en el mapa del piso (cuenta nueva), en el `_rng` de la expedición, en los dados de cada héroe y de cada criatura (antes dependían del id de instancia) y en el lado del altar del Barón (antes `randf()`).
