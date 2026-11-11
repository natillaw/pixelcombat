# Arquitectura

Reflections separa **simulación determinista** y **presentación**. Esta página
describe el estado actual del código (corte Warrior) y las reglas que hay que
mantener al ampliarlo.

## Arranque

`project.godot` carga tres autoloads y arranca `game/main.tscn`:

| Autoload | Script | Papel |
|---|---|---|
| `InputSetup` | `game/input_setup.gd` | Registra el mapa de input en runtime |
| `TickManager` | `core/tick_manager.gd` | Reloj de simulación a 60 Hz fijo |
| `NetworkManager` | `net/network_manager.gd` | Base de red, dormida |

`game/main.gd` construye el mundo:

1. Crea `CombatWorld` (semilla 1337).
2. Crea `Arena`, que entrega límites y obstáculos al mundo y monta cámara,
   actores, antorchas y helpers de VFX/SFX.
3. Crea el `CanvasLayer` con `GameHud` y el overlay de debug.
4. Registra `CombatWorld` como el único `Tickable`.

En cada `_physics_process`, `main.gd` lee teclado y ratón, empaqueta un
`InputMessage` y lo entrega con `world.submit_input()`. El tick lo consume
`CombatWorld._on_tick()`.

## Flujo de un tick

```
TickManager (60 Hz)
└── CombatWorld._on_tick(tick_number, delta)
    ├── WarriorSim.step(tick, delta, input)
    │   ├── leer input
    │   ├── avanzar cooldowns / buffer
    │   ├── avanzar ataque (WINDUP → ACTIVE → RECOVERY → IDLE)
    │   ├── resolver impacto (arco + alcance + crítico + Rage)
    │   ├── mover con aceleración/fricción y colisión
    │   └── decaer Rage fuera de combate
    ├── DummySim.step(...) × N  (telegráfico → golpe → recuperación → respawn)
    └── tick_advanced(tick)
```

- El delta que llega a la simulación es **siempre** `1/60`, no el delta del
  motor.
- El orden es fijo: Warrior primero, luego los muñecos en orden de creación.
- El RNG vive en `CombatWorld` y se pasa a la simulación; nada usa `randf()`
  global dentro de un tick.
- `snapshot()` devuelve el estado serializable que usará la red.

## Módulos

| Ruta | Contenido | Capa |
|---|---|---|
| `core/tick_manager.gd` | Reloj, registro, pausa, orden determinista | Núcleo |
| `core/tickable.gd` | Interfaz `_on_tick` / `_on_register` / `_on_unregister` | Núcleo |
| `game/sim/combat_world.gd` | Único Tickable; bounds, obstáculos, dummies, snapshots | Simulación |
| `game/sim/warrior_sim.gd` | Ataques, Rage, pasiva, movimiento, muerte, reset | Simulación |
| `game/sim/dummy_sim.gd` | Telegráfico, ataque, vida, respawn | Simulación |
| `game/actors/warrior_actor.gd` | Sprite LPC, animación, VFX y SFX del Warrior | Presentación |
| `game/actors/dummy_actor.gd` | Dibujo procedural, cono de telegráfico, barra de vida | Presentación |
| `game/world/arena.gd` | Suelo, muros, pilares, antorchas, cámara, spawn, VFX/SFX | Presentación |
| `game/vfx/` | `SlashArc`, `ImpactBurst`, `DamageNumber` | Presentación |
| `game/ui/hud.gd` | Vida, Rage, cooldowns, pasiva, controles, muerte | Presentación |
| `game/art/` | `LpcComposer`, `LpcWardrobe`, `WarriorLook` | Presentación |
| `combat/warrior_kit.gd` | Números canónicos y Skill Book del Warrior | Datos |
| `combat/stats.gd` | Fórmulas de stats, daño de arma, crítico | Núcleo de combate |
| `combat/class_resource.gd` | Recurso de clase (Rage) | Núcleo de combate |
| `net/` | `InputMessage`, `Snapshot`, predicción, reconciliación, manager | Red (dormida) |

## Frontera simulación / presentación

| Permitido en simulación | Prohibido en simulación |
|---|---|
| Leer `InputMessage` | Leer `Input` directamente |
| Usar el RNG sembrado del mundo | `randf()`, `Time`, `Engine` |
| Emitir señales | Crear nodos, reproducir audio, dibujar |
| Mutar solo dentro de `step()` | Tocar el árbol de escena |

| Permitido en presentación | Prohibido en presentación |
|---|---|
| Leer campos de la sim | Escribir posición, vida, Rage, estado |
| Escuchar señales | Iniciar ataques o aplicar daño |
| `_process`, tweens, dibujo, audio | Usar `_physics_process` para lógica |

Los actores son la prueba de esta frontera: `WarriorActor` lee
`sim.position`, `sim.velocity`, `sim.state`, y reacciona a
`attack_started` / `attack_hit` / `damage_taken`. Si el sprite se mueve, la
autoridad sigue siendo `WarriorSim`.

## Colisión y arena

- Arena lógica: `Rect2(40, 40, 880, 560)`.
- `CombatWorld.resolve_position(pos, radius)`:
  1. Clampa a los límites con el radio del actor.
  2. Empuja fuera de los obstáculos (pilares, `radio 21`).
  3. Empuja fuera de los muñecos vivos.
- La presentación no resuelve colisión: solo dibuja el resultado.

## Ataques

`WarriorSim` usa una máquina de estados simple:

```
IDLE ──input──▶ WINDUP ──tiempo──▶ ACTIVE ──tiempo──▶ RECOVERY ──tiempo──▶ IDLE
```

- `ACTIVE` resuelve el impacto **una vez** contra todos los objetivos vivos.
- El impacto comprueba distancia (`range + target.radius`) y ángulo
  (`arc / 2`) respecto a `attack_aim`.
- El daño sale de `stats.roll_weapon_damage(rng) × skill.damage_mult`, con
  crítico ×1.5.
- El Rage se gana por golpe conectado, con un tope por swing (`rage_cap`).
- El buffer de 0.25 s permite encolar M2 durante la recuperación de M1.

## Rage

`ClassResource` encapsula el valor y el máximo. `WarriorSim` decide cuándo
generar y cuándo decaer:

- Al golpear: `rage_gain` del skill, limitado por `rage_cap` por swing.
- Al recibir daño: % de vida perdida, acotado 1–15.
- Fuera de combate: 5 s de gracia y luego −6/s.

## Muerte y reset

- `take_damage()` clampea la vida a 0, marca `alive = false`, cancela el ataque
  y emite `died`.
- `R` llama a `CombatWorld.reset()`: revive al Warrior en el centro, vacía Rage,
  devuelve los muñecos a su spawn y los revive.
- El HUD muestra la pantalla de muerte; el actor hace una caída con tween.

## Netcode (dormido)

La base existe para no reescribir la simulación después:

- `InputMessage`: tick, peer, `move_dir`, `aim_dir`, acciones.
- `Snapshot`: estado serializable por tick.
- `net/prediction.gd` y `net/reconciliation.gd`: predicción y corrección.
- `NetworkManager`: autoload sin conexión activa.

Nada de esto se usa todavía en el bucle del juego. La regla es que **cualquier
estado que la red necesite debe estar en `snapshot()`** y que la simulación debe
poder avanzar en headless sin árbol de escena.

## Tests

| Suite | Qué cubre |
|---|---|
| `core/tests/test_tick.gd` | 60 Hz, delta fijo, registro, pausa, overlay |
| `net/tests/test_net.gd` | Mensajes y snapshots de red |
| `net/tests/test_reconciliation.gd` | Predicción y reconciliación |
| `combat/tests/test_stats.gd` | Fórmulas de stats |
| `combat/tests/test_skill.gd` | Skill / SkillRunner |
| `combat/tests/test_effect_pipeline.gd` | Pipeline de efectos |
| `combat/tests/test_hit_authority.gd` | Autoridad de impactos |
| `combat/tests/test_rogue.gd` | Núcleo de combate heredado (Rogue) |
| `combat/tests/test_warrior.gd` | Datos del Warrior y contrato de stats |
| `tests/test_warrior_sim.gd` | Simulación: M1/M2, Rage, pasiva, muerte, red |
| `tests/test_warrior_data.gd` | Contrato contra los documentos de diseño |

Ejecuta todo con `tools/run_tests.ps1` (o `.sh` en Linux). Las suites son
scripts `SceneTree` sin ventana y salen con código 0/1.

## Decisiones abiertas

- **Rogue** sigue en `combat/` con su suite porque comparte el núcleo de combate;
  se archivará cuando el núcleo se recorte a lo que usa el Warrior.
- El arte del escenario es procedural. Un tileset definitivo puede sustituirlo
  sin tocar la simulación, porque la arena lógica solo depende de `bounds` y
  `obstacles`.
- La música no se ha añadido: falta verificar la licencia del pack.
