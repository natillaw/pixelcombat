# Warrior — primer corte jugable

Documento de implementación de la clase Warrior de **PixelCombat**. Los números
son **provisionales**: sirven para validar el feel del combate, no para balance
final. La fuente de verdad del código es `combat/warrior_kit.gd`; este documento
explica qué está implementado y por qué.

Referencias de diseño: [`CLASES_V2.md`](CLASES_V2.md) (identidad y Skill Book) y
[`EVOLUCIONES_V1.md`](EVOLUCIONES_V1.md) (progresión futura).

## Identidad

- **Rol:** bruiser / frontliner.
- **Arma:** longsword a dos manos.
- **Recurso:** Rage (0–100). Empieza vacía, se llena al golpear y al recibir
  golpes, y decae fuera de combate.
- **Atributo principal:** Strength. Secundarios: Stamina, Agility.
- **Fantasía:** presión constante, resistencia e intercambios físicos. Castiga
  el compromiso enemigo con Heavy Strike y convierte el daño recibido en una
  ventana de contraataque con Vengeful Fury.
- **Sin combos, sin variantes, sin builds.** El Warrior tiene un set fijo de
  habilidades; el jugador elige cuándo usarlas, no cómo construirlas.

## Controles

| Entrada | Acción |
|---|---|
| WASD | Mover |
| Ratón | Apuntar |
| Clic izquierdo (mantener) | M1 · Sword Slash |
| Clic derecho | M2 · Heavy Strike |
| R | Reiniciar el entrenamiento |
| F3 | Overlay de debug (tick, FPS, red) |

Movimiento directo con aceleración; no hay click-to-move. La cámara sigue al
Warrior y el apuntado es independiente del movimiento.

## Implementado en este corte

| Pieza | Estado |
|---|---|
| M1 Sword Slash | Jugable |
| M2 Heavy Strike | Jugable |
| Pasiva Vengeful Fury | Jugable |
| Rage (generación, tope por swing, decaimiento) | Jugable |
| Muerte, reinicio y respawn del muñeco | Jugable |
| Muñeco de entrenamiento con telegráfico y ataque | Jugable |
| HUD (vida, Rage, cooldowns, pasiva, muerte) | Jugable |
| Special Iron Counter | Solo datos |
| Ultimate War God's Descent | Solo datos |
| Skill Book (15 habilidades) | Solo datos |
| Netcode | Dormido (base de ticks/input/snapshots) |

## Números actuales

### Stats base

| Stat | Valor |
|---|---|
| Strength | 20 |
| Stamina | 18 |
| Agility | 10 |
| Armor | 40 |
| Crit chance | 10 % |
| Daño de arma | 12–18 |
| Weapon speed | 2.6 |
| Vida máxima | 280 (`100 + Stamina × 10`) |

Fórmulas heredadas de `combat/stats.gd`:

- Attack Power = `Strength × 2 + bonus` → 40.
- Daño de arma = `roll(12–18) + Attack Power / 14 × weapon_speed`.
- Crítico = ×1.5.
- Reducción por armadura = `armor / (armor + 100)` → 28.6 % con 40.

### M1 · Sword Slash

| Campo | Valor |
|---|---|
| Windup / Active / Recovery | 0.12 / 0.12 / 0.18 s |
| Cooldown adicional | 0.05 s |
| Alcance | 78 px |
| Arco | 110° |
| Multiplicador | ×1.0 |
| Rage al acertar | +8 (máx. 16 por swing) |

Corte horizontal rápido y fiable. Se puede mantener pulsado para encadenar;
durante el ataque el movimiento se ralentiza pero no se bloquea.

### M2 · Heavy Strike

| Campo | Valor |
|---|---|
| Windup / Active / Recovery | 0.30 / 0.12 / 0.35 s |
| Cooldown adicional | 0.20 s |
| Alcance | 70 px |
| Arco | 80° |
| Multiplicador | ×2.1 |
| Rage al acertar | +14 (máx. 20 por swing) |

Golpe lento y comprometido. El Warrior queda prácticamente clavado durante el
windup y el active; el castigo es el precio de la ventana de daño.

### Pasiva · Vengeful Fury

- Se activa al recibir un **golpe directo** (el daño periódico no la activa).
- El siguiente **Heavy Strike** hace **+30 %** de daño.
- Ventana: **4 s** desde el golpe recibido.
- No se acumula. Se consume al iniciar el M2.
- Visual: aura naranja pulsante alrededor del Warrior mientras está activa.

### Rage

- Capacidad: 100.
- Ganancia al golpear: la del skill (M1 8, M2 14), con tope por swing para que
  un AoE futuro no llene la barra de golpe.
- Ganancia al recibir daño: `% de vida perdida`, acotado entre 1 y 15.
- Gracia sin combate: 5 s. Después decae a 6 Rage/s.
- El Special futuro costará 30; el HUD ya marca ese umbral en la barra.

### Movimiento

| Campo | Valor |
|---|---|
| Velocidad | 168 px/s |
| Aceleración | 1500 px/s² |
| Fricción | 2100 px/s² |
| Radio de colisión | 14 px |
| Buffer de input | 0.25 s |

El buffer permite pulsar M2 durante la recuperación de M1 sin perder la orden.

## Muñeco de entrenamiento

| Campo | Valor |
|---|---|
| Vida | 300 |
| Radio | 16 px |
| Alcance | 92 px |
| Arco | 70° |
| Daño | 22 |
| Telegráfico | 0.72 s |
| Recuperación | 0.35 s |
| Cooldown | 2.6 s |
| Respawn | 3 s |

El muñeco central ataca automáticamente; los otros dos son objetivos pasivos
para practicar el alcance y el ángulo. El telegráfico se dibuja como un cono
rojo que se intensifica hasta el impacto. Se puede destruir y vuelve a los 3 s.

## Arena

- Patio de piedra de **960 × 640**, muros de 40 px.
- Zona jugable: `Rect2(40, 40, 880, 560)`.
- Seis pilares con colisión (`radio 21`) y oclusión por y-sort.
- Cuatro antorchas con luz cálida procedural.
- Emblema de espada tenue en el centro.
- Todo el arte del escenario es procedural (sin tilesets externos): mantiene el
  primer corte autocontenido y deja la puerta abierta a un tileset definitivo.

## Skill Book (15 habilidades, solo datos)

Todas cuestan Rage (10–30) y tienen cooldown (4–18 s). Ninguna está implementada
todavía; `implemented = false` hasta su corte.

| # | Habilidad | Rol |
|---|---|---|
| 1 | Cleaving Strike | Daño / AoE |
| 2 | Crushing Blow | Burst / castigo |
| 3 | Piercing Thrust | Daño preciso |
| 4 | Whirlwind | Daño / AoE |
| 5 | Parry | Defensa |
| 6 | Iron Guard | Defensa / mitigación |
| 7 | Retaliation | Contraataque |
| 8 | Combat Roll | Movilidad / evasión |
| 9 | Heroic Leap | Movilidad / iniciación |
| 10 | Relentless Pursuit | Movilidad / persecución |
| 11 | Ground Stomp | Control / AoE |
| 12 | Earth Splitter | Control de zona |
| 13 | Sundering Strike | Debilitamiento |
| 14 | Battle Cry | Mejora / ofensiva |
| 15 | War Banner | Apoyo / Control de zona |

Special: **Iron Counter** (30 Rage, 12 s) — contraataque frontal.
Ultimate: **War God's Descent** (100 de carga, 60 s) — salto de área.

## Arquitectura de la implementación

```
main.gd                  input → InputMessage, registra CombatWorld en TickManager
└── CombatWorld (Tickable)   único paso de simulación por tick fijo
    ├── WarriorSim          ataques, Rage, pasiva, movimiento, muerte
    └── DummySim ×3         telegráfico, ataque, respawn
Arena (Node2D)           construye el mapa y spawnea actores; lee la sim
├── WarriorActor         LPC + VFX + SFX; nunca escribe la sim
└── DummyActor ×3        dibujo procedural, barra de vida, telegraph
GameHud (Control)        vida, Rage, cooldowns, pasiva, muerte
```

Regla dura: **la simulación solo cambia en `WarriorSim.step()`**. Los actores,
VFX, cámara y HUD son presentación y leen el estado o escuchan señales.

## Qué falta para cerrar el Warrior

1. **Special Iron Counter**: postura de contraataque con ventana, desvío y
   respuesta; coste 30 Rage y cooldown 12 s.
2. **Ultimate War God's Descent**: marcador de zona, salto, daño decreciente
   desde el centro, interrupción breve.
3. **Las 15 habilidades** del Skill Book, una por una, con su VFX y sonido.
4. **Enemigos reales** además del muñeco, con IA y ataques bloqueables.
5. **Balance**: validar daño, tiempos y Rage con enemigos de distintas
   resistencias; los números actuales son solo una base.
6. **Animaciones**: completar el set LPC (hurt, death dedicada, ataques por
   dirección) y pulir la transición idle/walk/attack.
7. **Audio**: más variedad de impactos y pasos; la música sigue sin añadirse
   hasta verificar licencia.
