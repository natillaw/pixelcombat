# Simulación: pista-d_saqueo_seguro

Generado por `tools/sim/run_sim.gd` (D-083). 8 runs, 2 variantes, paso fijo 30 Hz, máximo 1200 s de juego por run.

## Alertas

- **Piso 3 imposible** (tactico): 0 % de victorias (< 10 %)
- **Piso 3 imposible** (loco): 0 % de victorias (< 10 %)
- **Piso 9 imposible** (loco): 0 % de victorias (< 10 %)

## Resultados por variante y piso

| Variante | Piso | Misión | Party | Runs | Victoria | Duración (s) | Derribos | Muertes | Enemigos muertos | Motivos de derrota |
|---|---|---|---|---|---|---|---|---|---|---|
| tactico | 3 | defense | 3 | 2 | **0 %** | 226 ± 34 | 2.0 ± 0.0 | 2.0 ± 0.0 | 17.0 ± 5.7 | master_lost 2 |
| tactico | 9 | survival | 5 | 2 | **50 %** | 240 ± 84 | 4.5 ± 0.7 | 2.0 ± 2.83 | 9.0 ± 1.4 | master_lost 1 |
| loco | 3 | defense | 3 | 2 | **0 %** | 165 ± 34 | 2.0 ± 0.0 | 2.0 ± 0.0 | 15.5 ± 3.5 | master_lost 2 |
| loco | 9 | survival | 5 | 2 | **0 %** | 148 ± 24 | 5.5 ± 2.1 | 4.0 ± 0.0 | 6.5 ± 3.5 | master_lost 2 |

## Por clase (media por run)

| Variante | Piso | Clase | Daño | Curación | Daño recibido | Muertes enemigas | Derribos | Muere |
|---|---|---|---|---|---|---|---|---|
| tactico | 3 | cleric | 525 ± 151 | 559 ± 299 | 580 ± 306 | 9.5 ± 0.7 | 1.0 ± 0.0 | 100 % |
| tactico | 3 | ranger | 649 ± 123 | 0 ± 0 | 239 ± 16 | 5.0 ± 2.8 | 1.0 ± 0.0 | 100 % |
| tactico | 3 | warrior (Máster) | 225 ± 182 | 0 ± 0 | 175 ± 4 | 2.5 ± 2.1 | 0.0 ± 0.0 | 0 % |
| tactico | 9 | cleric | 111 ± 71 | 434 ± 308 | 142 ± 2 | 1.5 ± 0.7 | 0.5 ± 0.71 | 50 % |
| tactico | 9 | mage | 543 ± 80 | 0 ± 0 | 125 ± 47 | 1.5 ± 0.7 | 0.5 ± 0.71 | 50 % |
| tactico | 9 | ranger | 233 ± 45 | 0 ± 0 | 416 ± 105 | 1.0 ± 0.0 | 3.0 ± 1.41 | 50 % |
| tactico | 9 | rogue | 229 ± 10 | 0 ± 0 | 130 ± 122 | 5.0 ± 0.0 | 0.5 ± 0.71 | 50 % |
| tactico | 9 | warrior (Máster) | 111 ± 20 | 0 ± 0 | 174 ± 112 | 0.0 ± 0.0 | 0.0 ± 0.0 | 0 % |
| loco | 3 | cleric | 378 ± 209 | 498 ± 187 | 505 ± 73 | 6.0 ± 4.2 | 1.0 ± 0.0 | 100 % |
| loco | 3 | ranger | 557 ± 94 | 0 ± 0 | 174 ± 33 | 6.5 ± 0.7 | 1.0 ± 0.0 | 100 % |
| loco | 3 | warrior (Máster) | 308 ± 29 | 0 ± 0 | 250 ± 93 | 3.0 ± 0.0 | 0.0 ± 0.0 | 0 % |
| loco | 9 | cleric | 84 ± 89 | 261 ± 267 | 225 ± 91 | 1.0 ± 1.4 | 1.0 ± 0.0 | 100 % |
| loco | 9 | mage | 387 ± 75 | 0 ± 0 | 219 ± 31 | 2.0 ± 0.0 | 0.5 ± 0.71 | 100 % |
| loco | 9 | ranger | 112 ± 16 | 0 ± 0 | 317 ± 199 | 1.5 ± 0.7 | 2.0 ± 1.41 | 100 % |
| loco | 9 | rogue | 167 ± 151 | 0 ± 0 | 177 ± 23 | 1.5 ± 0.7 | 1.0 ± 0.0 | 100 % |
| loco | 9 | warrior (Máster) | 118 ± 11 | 0 ± 0 | 223 ± 71 | 0.5 ± 0.7 | 1.0 ± 0.0 | 0 % |

## Recursos e ítems (media por run)

| Variante | Piso | Recogido en el piso | Guardado al volver | Recompensa del piso | Ítems de recompensa | Consumibles usados | Bot (pings / comandos / skills / revividos) |
|---|---|---|---|---|---|---|---|
| tactico | 3 | essence 1.0 | — | — | 0.0 ± 0.0 | 0.0 ± 0.0 | 27.0 / 2.5 / 1.5 / 0.0 |
| tactico | 9 | mat_rune_plate 0.5 | mat_rune_plate 0.5 | books 0.0, essence 2.0, food 0.0, gems 97.5, left_behind 0.0, materials 0.0, starsteel 2.5, stones 1.5 | 2.5 ± 3.5 | 0.0 ± 0.0 | 25.0 / 2.5 / 0.5 / 2.5 |
| loco | 3 | — | — | — | 0.0 ± 0.0 | 0.0 ± 0.0 | 32.0 / 2.5 / 2.5 / 0.0 |
| loco | 9 | mat_rune_plate 1.5 | — | — | 0.0 ± 0.0 | 0.0 ± 0.0 | 19.0 / 1.5 / 1.0 / 0.0 |

## Botín de los cuerpos (pista D, media por run)

| Variante | Piso | Cuerpos con botín | Ítems en cuerpos | Basura | Saqueados | A casa | Perdidos | Retenidos (avaricioso) | Saqueos del bot |
|---|---|---|---|---|---|---|---|---|---|
| tactico | 3 | 2.0 | 1.0 | 0.0 | 0.0 | 0.0 | 1.0 | 0.00 | 1.0 |
| tactico | 9 | 2.5 | 1.0 | 0.5 | 0.0 | 0.0 | 1.0 | 0.00 | 0.5 |
| loco | 3 | 1.0 | 1.0 | 0.0 | 0.0 | 0.0 | 1.0 | 0.00 | 0.0 |
| loco | 9 | 2.5 | 1.0 | 0.5 | 1.0 | 0.0 | 1.0 | 0.00 | 1.5 |

## Quién mata a los héroes (total)

- tactico, piso 3: left behind 4
- tactico, piso 9: left behind 4
- loco, piso 3: left behind 4
- loco, piso 9: left behind 8

## Velocidad

- Tiempo de juego simulado: 1559 s en 256.3 s reales de CPU por proceso → **×6.1** tiempo real por proceso.
- Con 6 procesos en paralelo: 56.3 s de reloj en total → **×27.7** tiempo real.

Archivos: `runs.csv` (una fila por run), `heroes.csv` (una fila por héroe y run), `results.json` (todo, con la config).
