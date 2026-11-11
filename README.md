# Reflections

Action RPG top-down con clases de identidad fija: sin gacha, sin builds y sin
variantes. Cada clase tiene un set cerrado de habilidades y se domina
aprendiendo cuándo usarlas.

El proyecto está en desarrollo. El primer corte jugable es el **Warrior** en un
patio de entrenamiento: M1, M2, Rage, la pasiva Vengeful Fury, un muñeco de
entrenamiento y HUD completo.

## Requisitos

- **Godot 4.7.2** (el proyecto también declara compatibilidad 4.7).
- Windows para el flujo de desarrollo actual; Linux funciona para CI y tests
  headless.

Ruta local de referencia en este equipo:

```
C:\Users\natha\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe
```

## Ejecutar

Directo, sin editor:

```powershell
& 'C:\Users\natha\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe' --path 'C:\dev\combat'
```

O abre el editor y pulsa **F5**:

```powershell
& 'C:\Users\natha\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe' --editor --path 'C:\dev\combat'
```

Si es la primera ejecución tras un cambio grande de assets:

```powershell
& 'C:\Users\natha\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'C:\dev\combat' --import
```

## Controles

| Entrada | Acción |
|---|---|
| WASD | Mover |
| Ratón | Apuntar |
| Clic izquierdo | M1 · Sword Slash (mantener para encadenar) |
| Clic derecho | M2 · Heavy Strike |
| R | Reiniciar entrenamiento |
| F3 | Overlay de debug |

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
& 'C:\Users\natha\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'C:\dev\combat' --script tests/test_warrior_sim.gd
```

## Estructura

| Ruta | Contenido |
|---|---|
| `game/` | Juego del primer corte: `main`, arena, actores, VFX, HUD, simulación |
| `game/sim/` | Simulación determinista (`CombatWorld` → `WarriorSim`, `DummySim`) |
| `combat/` | Núcleo de combate reutilizable: stats, skills, efectos, `WarriorKit` |
| `core/` | Tick fijo (`TickManager`, `Tickable`) |
| `net/` | Base de red dormida: `InputMessage`, snapshots, predicción |
| `ui/` | Overlay de debug |
| `assets/` | Arte LPC, fuentes, SFX y packs usados por el juego |
| `docs/` | Diseño y arquitectura |
| `archive/legacy_ts/` | Código y contenido del proyecto anterior, fuera de uso |
| `new assets/` | Packs crudos descargados; ignorados por git y por Godot |

Las suites viven en `core/tests/`, `net/tests/`, `combat/tests/` y `tests/`.

## Documentación

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — cómo está montado y qué
  reglas no se rompen.
- [`docs/design/CLASES_V2.md`](docs/design/CLASES_V2.md) — diseño de las cinco
  clases.
- [`docs/design/WARRIOR.md`](docs/design/WARRIOR.md) — el corte actual, números
  y qué falta.
- [`docs/design/EVOLUCIONES_V1.md`](docs/design/EVOLUCIONES_V1.md) — progresión
  futura.
- [`docs/ASSET_REGISTRY.md`](docs/ASSET_REGISTRY.md) — assets y licencias.
- [`AGENTS.md`](AGENTS.md) — convenciones para contribuir.

## Licencias

El código es del proyecto. Los assets de terceros conservan sus licencias; los
créditos por archivo están en `assets/pixel/lpc/CREDITS.csv` y en los
`LICENSE.txt` de cada pack. No se redistribuyen los packs crudos de
`new assets/`.
