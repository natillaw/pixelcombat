# PixelCombat

Action RPG 2D de pixel art. Combate de acción con el ratón estilo **Drakantos**
y skillshots con telegraph estilo **Battlerite**, una torre de 100 pisos
procedurales, recolección, crafting, items con rarezas y una ciudad hub al pie
de la torre. PvP planificado: las clases se diseñan para ser balanceables.

Cuatro clases base: **Warrior, Rogue, Mage y Archer**, cada una con muchas
subclases (comunes, raras, únicas y legendarias).

Estado actual: el **Warrior** es jugable en un patio de entrenamiento (M1, M2,
Rage, pasiva, muñeco, HUD). El resto está en el [roadmap](docs/ROADMAP.md).

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
| Clic izquierdo | M1 · Sword Slash: ataque básico con 3 cargas que se recuperan solas (mantener para encadenar) |
| Clic derecho | M2 · Heavy Strike: especial; mantén el botón tras el golpe inicial para potenciarlo (+60 % daño, +25 % alcance a 0,6 s) |
| Espacio | Esquiva (i-frames, cancela windup/recovery, cooldown 1,1 s) |
| 1-5 | Skills S1-S5. Se **desbloquean por nivel**: nivel 2 Piercing Thrust (15 Rage), nivel 4 Cleaving Strike (20 Rage). Empiezas con solo M1, M2 y esquiva; la XP sale de matar enemigos |
| Q | Special Iron Counter (nivel 6, 30 Rage): postura frontal que bloquea el primer golpe y contraataca |
| F | Ultimate War God's Descent (nivel 8; necesita la barra al 100 %, que sube al conectar golpes) |
| Tab | Panel de loadout: equipa las skills desbloqueadas (pausa el juego) |
| F5 / F6 | Depuración: subir un nivel / volver al nivel 1 |
| R | Reiniciar entrenamiento |
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

Una suite suelta:

```powershell
& $env:GODOT --headless --path . --script tests/test_warrior_sim.gd
```

## Estructura

| Ruta | Contenido |
|---|---|
| `game/` | Escena principal, arena, actores, VFX, HUD y simulación del corte actual |
| `game/sim/` | Simulación determinista (`CombatWorld` → `WarriorSim`, `EnemySim`, `DummySim`) |
| `combat/` | Núcleo de combate reutilizable: stats, skills, efectos, kits de clase |
| `core/` | Tick fijo (`TickManager`, `Tickable`) |
| `net/` | Capa de red dormida: `InputMessage`, snapshots, predicción |
| `ui/` | Overlay de debug |
| `data/` | Contenido dirigido por datos: `skills/` y `enemies/` hoy; items, recetas y pisos después |
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
