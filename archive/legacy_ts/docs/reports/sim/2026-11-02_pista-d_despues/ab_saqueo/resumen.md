# Simulación: pista-d_ab_loot

Generado por `tools/sim/run_sim.gd` (D-083). 20 runs, 2 variantes, paso fijo 30 Hz, máximo 1200 s de juego por run.

## Alertas

- **Piso 3 imposible** (tactico_saquea): 0 % de victorias (< 10 %)
- **Piso 9 imposible** (tactico_saquea): 0 % de victorias (< 10 %)

## Resultados por variante y piso

| Variante | Piso | Misión | Party | Runs | Victoria | Duración (s) | Derribos | Muertes | Enemigos muertos | Motivos de derrota |
|---|---|---|---|---|---|---|---|---|---|---|
| tactico_saquea | 3 | defense | 3 | 5 | **0 %** | 264 ± 82 | 2.4 ± 0.5 | 2.0 ± 0.0 | 21.6 ± 10.0 | master_lost 5 |
| tactico_saquea | 9 | survival | 5 | 5 | **0 %** | 124 ± 20 | 5.4 ± 0.5 | 4.0 ± 0.0 | 2.6 ± 1.7 | master_lost 5 |
| tactico_sin_saquear | 3 | defense | 3 | 5 | **40 %** | 202 ± 61 | 1.4 ± 1.3 | 1.2 ± 1.1 | 17.0 ± 8.6 | master_lost 3 |
| tactico_sin_saquear | 9 | survival | 5 | 5 | **20 %** | 164 ± 82 | 5.2 ± 0.8 | 3.2 ± 1.79 | 4.6 ± 4.2 | master_lost 4 |

## Por clase (media por run)

| Variante | Piso | Clase | Daño | Curación | Daño recibido | Muertes enemigas | Derribos | Muere |
|---|---|---|---|---|---|---|---|---|
| tactico_saquea | 3 | cleric | 574 ± 271 | 577 ± 266 | 580 ± 220 | 7.6 ± 3.2 | 1.2 ± 0.45 | 100 % |
| tactico_saquea | 3 | ranger | 617 ± 253 | 0 ± 0 | 225 ± 59 | 6.2 ± 3.0 | 1.0 ± 0.0 | 100 % |
| tactico_saquea | 3 | warrior (Máster) | 686 ± 664 | 0 ± 0 | 226 ± 52 | 7.8 ± 6.9 | 0.2 ± 0.45 | 0 % |
| tactico_saquea | 9 | cleric | 38 ± 53 | 182 ± 77 | 297 ± 22 | 0.0 ± 0.0 | 1.4 ± 0.55 | 100 % |
| tactico_saquea | 9 | mage | 121 ± 88 | 0 ± 0 | 166 ± 73 | 0.6 ± 0.9 | 1.0 ± 0.0 | 100 % |
| tactico_saquea | 9 | ranger | 88 ± 23 | 0 ± 0 | 258 ± 67 | 0.8 ± 0.8 | 1.4 ± 0.55 | 100 % |
| tactico_saquea | 9 | rogue | 79 ± 36 | 0 ± 0 | 171 ± 91 | 1.2 ± 0.4 | 1.2 ± 0.45 | 100 % |
| tactico_saquea | 9 | warrior (Máster) | 27 ± 31 | 0 ± 0 | 281 ± 68 | 0.0 ± 0.0 | 0.4 ± 0.55 | 0 % |
| tactico_sin_saquear | 3 | cleric | 583 ± 326 | 580 ± 374 | 557 ± 299 | 7.6 ± 3.4 | 0.6 ± 0.55 | 60 % |
| tactico_sin_saquear | 3 | ranger | 612 ± 236 | 0 ± 0 | 189 ± 90 | 6.8 ± 4.0 | 0.6 ± 0.55 | 60 % |
| tactico_sin_saquear | 3 | warrior (Máster) | 244 ± 200 | 0 ± 0 | 124 ± 82 | 2.6 ± 3.6 | 0.2 ± 0.45 | 0 % |
| tactico_sin_saquear | 9 | cleric | 58 ± 68 | 233 ± 175 | 263 ± 70 | 0.2 ± 0.4 | 1.4 ± 0.55 | 80 % |
| tactico_sin_saquear | 9 | mage | 262 ± 267 | 0 ± 0 | 128 ± 75 | 1.0 ± 1.2 | 0.8 ± 0.45 | 80 % |
| tactico_sin_saquear | 9 | ranger | 124 ± 82 | 0 ± 0 | 280 ± 79 | 0.4 ± 0.5 | 1.8 ± 0.84 | 80 % |
| tactico_sin_saquear | 9 | rogue | 135 ± 100 | 0 ± 0 | 153 ± 121 | 2.6 ± 2.2 | 1.0 ± 0.71 | 80 % |
| tactico_sin_saquear | 9 | warrior (Máster) | 61 ± 67 | 0 ± 0 | 239 ± 112 | 0.4 ± 0.9 | 0.2 ± 0.45 | 0 % |

## Recursos e ítems (media por run)

| Variante | Piso | Recogido en el piso | Guardado al volver | Recompensa del piso | Ítems de recompensa | Consumibles usados | Bot (pings / comandos / skills / revividos) |
|---|---|---|---|---|---|---|---|
| tactico_saquea | 3 | essence 0.4 | — | — | 0.0 ± 0.0 | 0.0 ± 0.0 | 40.8 / 2.4 / 4.6 / 0.2 |
| tactico_saquea | 9 | mat_rune_plate 0.4 | — | — | 0.0 ± 0.0 | 0.0 ± 0.0 | 13.4 / 1.0 / 0.4 / 1.0 |
| tactico_sin_saquear | 3 | essence 0.4 | — | books 0.0, essence 0.8, food 0.0, gems 42.0, left_behind 0.0, materials 0.0, starsteel 0.8, stones 0.4 | 1.2 ± 1.6 | 0.0 ± 0.0 | 23.2 / 2.4 / 1.8 / 0.0 |
| tactico_sin_saquear | 9 | mat_rune_plate 0.4 | mat_rune_plate 0.4 | books 0.0, essence 0.8, food 0.0, gems 39.0, left_behind 0.0, materials 0.0, starsteel 1.0, stones 0.6 | 1.0 ± 2.2 | 0.0 ± 0.0 | 16.4 / 1.6 / 0.6 / 1.8 |

## Botín de los cuerpos (pista D, media por run)

| Variante | Piso | Cuerpos con botín | Ítems en cuerpos | Basura | Saqueados | A casa | Perdidos | Retenidos (avaricioso) | Saqueos del bot |
|---|---|---|---|---|---|---|---|---|---|
| tactico_saquea | 3 | 1.8 | 1.4 | 0.2 | 1.4 | 0.0 | 1.4 | 0.00 | 3.0 |
| tactico_saquea | 9 | 1.0 | 0.4 | 0.4 | 0.2 | 0.0 | 0.4 | 0.00 | 0.8 |
| tactico_sin_saquear | 3 | 2.2 | 1.8 | 0.4 | 1.0 | 1.0 | 0.8 | 0.00 | 0.0 |
| tactico_sin_saquear | 9 | 1.4 | 0.6 | 0.4 | 0.2 | 0.2 | 0.4 | 0.00 | 0.0 |

## Quién mata a los héroes (total)

- tactico_saquea, piso 3: Grunt 8, left behind 2
- tactico_saquea, piso 9: left behind 20
- tactico_sin_saquear, piso 3: Grunt 1, left behind 5
- tactico_sin_saquear, piso 9: left behind 16

## Velocidad

- Tiempo de juego simulado: 3775 s en 1062.5 s reales de CPU por proceso → **×3.6** tiempo real por proceso.
- Con 6 procesos en paralelo: 207.4 s de reloj en total → **×18.2** tiempo real.

Archivos: `runs.csv` (una fila por run), `heroes.csv` (una fila por héroe y run), `results.json` (todo, con la config).
