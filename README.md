# PixelCombat

Action RPG 2D de pixel art. Combate de acción con el ratón estilo **Drakantos**
y skillshots con telegraph estilo **Battlerite**, una torre de 100 pisos
procedurales, recolección, crafting, items con rarezas y una ciudad hub al pie
de la torre. PvP planificado: las clases se diseñan para ser balanceables.

Cuatro clases base: **Warrior, Rogue, Mage y Archer**, cada una con muchas
subclases (comunes, raras, únicas y legendarias).

Estado actual: las **cuatro clases son jugables** en un patio de entrenamiento con
muñecos y enemigos con telegraph. Cada una tiene M1, M2, sus skills, Special y
Ultimate, su recurso propio (Rage, Energy o Mana), su nivel y su loadout. Se
cambia de clase en el panel Tab o con F7. El resto está en el
[roadmap](docs/ROADMAP.md).

## Requisitos

- **Godot 4.7.2**.
- Windows para el desarrollo diario; Linux funciona para CI y tests headless.
- Variable de entorno `GODOT` apuntando al ejecutable (usa la versión
  `_console` para los comandos de terminal).

## Ejecutar

Abre el proyecto en el editor y pulsa **F5**, o desde terminal:

```powershell
& $env:GODOT --path .
```

La primera vez, o tras cambiar muchos assets, importa:

```powershell
& $env:GODOT --headless --path . --import
```

## Controles (corte actual)

| Entrada | Acción |
|---|---|
| WASD | Mover |
| Ratón | Apuntar |
| Clic izquierdo | M1: ataque básico con cargas que se recuperan solas (mantener para encadenar) |
| Clic derecho | M2: ataque especial; mantén el botón para cargarlo (más daño y alcance) |
| Espacio | Esquiva (i-frames, cancela windup/recovery, cooldown 1,1 s) |
| 1-5 | Skills S1-S5. Se **desbloquean por nivel** (niveles 2, 4 y 10 las de cada clase). Empiezas con solo M1, M2 y esquiva; la XP sale de matar enemigos |
| Q | Special (nivel 6, cuesta 30): Iron Counter, Perfect Evasion, Arcane Overload o Deadeye |
| F | Ultimate (nivel 8; necesita la barra al 100 %, que sube al conectar golpes) |
| Tab | Panel de loadout: pestañas de clase y skills desbloqueadas (pausa el juego) |
| F7 | Depuración: pasar a la siguiente clase |
| F5 / F6 | Depuración: subir un nivel / volver al nivel 1 |
| E | Interactuar: puertas de la ciudad, entrada de la torre, salidas de piso |
| , / . | En la ciudad, elegir el piso de la torre (hasta el más alto desbloqueado) |
| Clic izquierdo sobre un item del suelo o un nodo | Recoger / recolectar (hay que estar cerca; el clic no ataca). Recolectar tarda ~1,5 s y se cancela si te mueves, atacas, esquivas o te golpean |
| E en una puerta de la ciudad | Herreria, Alquimia, Carpinteria y Sastreria abren su taller (la Taberna aun no): flechas cambian receta y tier, Intro fabrica |
| (HUD) | Arriba a la derecha: minimapa del piso (salida en cian, objetivos en dorado, jefes y elites en rojo) |
| I | Inventario: clic equipa, clic derecho vende (solo en zona segura) |
| R | Reiniciar el escenario actual (enemigos vivos y vida completa) |
| F3 | Overlay de debug |
| Esc | Salir |


## Tests

Todas las suites headless:

```powershell
pwsh -File tools/run_tests.ps1
```

En Linux / CI:

```bash
GODOT=/ruta/a/godot bash tools/run_tests.sh
```

Laboratorio de balance (bots deterministas; escribe `tests/out/balance_matrix.csv`):

```powershell
& $env:GODOT --headless --path . --script tools/balance/run_balance.gd
& $env:GODOT --headless --path . --script tools/balance/run_balance.gd -- 30   # otro nivel
```

Una suite suelta:

```powershell
& $env:GODOT --headless --path . --script tests/test_warrior_sim.gd
```

## Estructura

| Ruta | Contenido |
|---|---|
| `game/` | Escena principal, arena, actores, VFX, HUD y simulación del corte actual |
| `game/sim/` | Simulación determinista (`CombatWorld` → `PlayerSim`, `EnemySim`, `ProjectileSim`, `DummySim`) |
| `combat/` | Núcleo de combate reutilizable: stats, skills, efectos, kits de clase |
| `core/` | Tick fijo (`TickManager`, `Tickable`) |
| `net/` | Capa de red dormida: `InputMessage`, snapshots, predicción |
| `ui/` | Overlay de debug |
| `data/` | Contenido dirigido por datos: `classes/`, `skills/`, `enemies/` y `progression.json` hoy; items, recetas y pisos después |
| `assets/` | Arte LPC, fuentes, SFX y packs usados por el juego |
| `docs/` | Roadmap, decisiones, arquitectura y diseño |

Las suites viven en `core/tests/`, `net/tests/`, `combat/tests/` y `tests/`.

## Documentación

- [`docs/ROADMAP.md`](docs/ROADMAP.md): fases del proyecto.
- [`docs/DECISIONES.md`](docs/DECISIONES.md): bitácora de decisiones.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md): cómo está montado y qué reglas
  no se rompen.
- [`docs/design/CLASES_V2.md`](docs/design/CLASES_V2.md) y
  [`docs/design/EVOLUCIONES_V1.md`](docs/design/EVOLUCIONES_V1.md): clases y
  subclases (el diseño original tenía cinco clases; ver DECISIONES D6).
- [`docs/design/WARRIOR.md`](docs/design/WARRIOR.md): el corte actual.
- [`docs/ASSET_REGISTRY.md`](docs/ASSET_REGISTRY.md): assets y licencias.
- [`AGENTS.md`](AGENTS.md): convenciones para contribuir.

## Licencias

El código es del proyecto. Los assets de terceros conservan sus licencias;
los créditos por archivo están en `assets/pixel/lpc/CREDITS.csv` y en
[`docs/ASSET_REGISTRY.md`](docs/ASSET_REGISTRY.md), que además explica cómo se
eligen las licencias del LPC.
