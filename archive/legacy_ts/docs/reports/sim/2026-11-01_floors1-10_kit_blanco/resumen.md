# Simulación: floors1-10_kit_blanco

Generado por `tools/sim/run_sim.gd` (D-083). 200 runs, 2 variantes, paso fijo 30 Hz, máximo 1200 s de juego por run.

## Alertas

- **Piso 1 trivial** (tactico): 100 % de victorias (> 95 %)
- **Piso 2 trivial** (tactico): 100 % de victorias (> 95 %)
- **Piso 5 imposible** (tactico): 0 % de victorias (< 10 %)
- **Piso 7 imposible** (tactico): 0 % de victorias (< 10 %)
- **Piso 8 imposible** (tactico): 0 % de victorias (< 10 %)
- **Piso 9 trivial** (tactico): 100 % de victorias (> 95 %)
- **Piso 10 imposible** (tactico): 0 % de victorias (< 10 %)
- **Piso 1 trivial** (loco): 100 % de victorias (> 95 %)
- **Piso 2 trivial** (loco): 100 % de victorias (> 95 %)
- **Piso 3 trivial** (loco): 100 % de victorias (> 95 %)
- **Piso 5 imposible** (loco): 0 % de victorias (< 10 %)
- **Piso 6 imposible** (loco): 0 % de victorias (< 10 %)
- **Piso 7 imposible** (loco): 0 % de victorias (< 10 %)
- **Piso 9 trivial** (loco): 100 % de victorias (> 95 %)
- **Piso 10 imposible** (loco): 0 % de victorias (< 10 %)
- **Loco ≥ táctico** en el piso 1: loco 100 % vs tactico 100 %
- **Loco ≥ táctico** en el piso 2: loco 100 % vs tactico 100 %
- **Loco ≥ táctico** en el piso 3: loco 100 % vs tactico 90 %
- **Loco ≥ táctico** en el piso 4: loco 90 % vs tactico 60 %
- **Loco ≥ táctico** en el piso 8: loco 30 % vs tactico 0 %
- **Loco ≥ táctico** en el piso 9: loco 100 % vs tactico 100 %

## Resultados por variante y piso

| Variante | Piso | Misión | Party | Runs | Victoria | Duración (s) | Derribos | Muertes | Enemigos muertos | Motivos de derrota |
|---|---|---|---|---|---|---|---|---|---|---|
| tactico | 1 | combat | 1 | 10 | **100 %** | 349 ± 26 | 0.0 ± 0.0 | 0.0 ± 0.0 | 19.7 ± 1.1 | — |
| tactico | 2 | exploration | 2 | 10 | **100 %** | 230 ± 29 | 0.0 ± 0.0 | 0.0 ± 0.0 | 10.6 ± 3.4 | — |
| tactico | 3 | defense | 3 | 10 | **90 %** | 177 ± 52 | 0.6 ± 1.1 | 0.2 ± 0.63 | 10.2 ± 3.3 | master_lost 1 |
| tactico | 4 | escape | 2 | 10 | **60 %** | 383 ± 432 | 0.4 ± 0.5 | 0.4 ± 0.52 | 7.6 ± 3.2 | master_lost 2, timeout 2 |
| tactico | 5 | boss | 5 | 10 | **0 %** | 151 ± 71 | 4.6 ± 0.7 | 4.0 ± 0.0 | 6.5 ± 3.6 | master_lost 8, retreat 2 |
| tactico | 6 | rescue | 3 | 10 | **10 %** | 173 ± 115 | 2.9 ± 1.4 | 1.8 ± 0.63 | 4.5 ± 3.3 | master_lost 9 |
| tactico | 7 | sabotage | 4 | 10 | **0 %** | 123 ± 67 | 3.1 ± 0.6 | 2.9 ± 0.32 | 5.9 ± 4.7 | master_lost 7, retreat 3 |
| tactico | 8 | combat | 1 | 10 | **0 %** | 405 ± 424 | 0.1 ± 0.3 | 0.0 ± 0.0 | 4.3 ± 2.8 | master_lost 8, timeout 2 |
| tactico | 9 | survival | 5 | 10 | **100 %** | 75 ± 0 | 0.0 ± 0.0 | 0.0 ± 0.0 | 0.0 ± 0.0 | — |
| tactico | 10 | boss | 5 | 10 | **0 %** | 138 ± 37 | 4.6 ± 0.7 | 3.6 ± 1.27 | 4.5 ± 1.8 | master_lost 9, retreat 1 |
| loco | 1 | combat | 1 | 10 | **100 %** | 342 ± 24 | 0.0 ± 0.0 | 0.0 ± 0.0 | 19.7 ± 1.1 | — |
| loco | 2 | exploration | 2 | 10 | **100 %** | 220 ± 30 | 0.0 ± 0.0 | 0.0 ± 0.0 | 10.5 ± 3.2 | — |
| loco | 3 | defense | 3 | 10 | **100 %** | 162 ± 4 | 0.4 ± 0.7 | 0.0 ± 0.0 | 9.6 ± 2.0 | — |
| loco | 4 | escape | 2 | 10 | **90 %** | 163 ± 72 | 0.4 ± 0.5 | 0.3 ± 0.48 | 6.9 ± 3.3 | master_lost 1 |
| loco | 5 | boss | 5 | 10 | **0 %** | 166 ± 32 | 4.9 ± 1.2 | 4.0 ± 0.0 | 9.2 ± 2.8 | master_lost 10 |
| loco | 6 | rescue | 3 | 10 | **0 %** | 247 ± 101 | 2.3 ± 0.7 | 1.9 ± 0.32 | 8.2 ± 2.3 | master_lost 9, time_limit 1 |
| loco | 7 | sabotage | 4 | 10 | **0 %** | 306 ± 346 | 3.3 ± 0.7 | 3.0 ± 0.0 | 7.6 ± 9.9 | master_lost 9, timeout 1 |
| loco | 8 | combat | 1 | 10 | **30 %** | 214 ± 95 | 0.1 ± 0.3 | 0.0 ± 0.0 | 6.4 ± 3.4 | master_lost 7 |
| loco | 9 | survival | 5 | 10 | **100 %** | 75 ± 0 | 0.0 ± 0.0 | 0.0 ± 0.0 | 0.0 ± 0.0 | — |
| loco | 10 | boss | 5 | 10 | **0 %** | 154 ± 41 | 5.4 ± 1.7 | 4.0 ± 0.0 | 5.2 ± 2.4 | master_lost 10 |

## Por clase (media por run)

| Variante | Piso | Clase | Daño | Curación | Daño recibido | Muertes enemigas | Derribos | Muere |
|---|---|---|---|---|---|---|---|---|
| tactico | 1 | warrior (Máster) | 1869 ± 117 | 0 ± 0 | 22 ± 30 | 19.7 ± 1.1 | 0.0 ± 0.0 | 0 % |
| tactico | 2 | cleric | 771 ± 309 | 260 ± 173 | 280 ± 173 | 6.4 ± 3.0 | 0.0 ± 0.0 | 0 % |
| tactico | 2 | warrior (Máster) | 663 ± 172 | 0 ± 0 | 7 ± 10 | 4.2 ± 1.7 | 0.0 ± 0.0 | 0 % |
| tactico | 3 | cleric | 290 ± 103 | 280 ± 120 | 303 ± 119 | 4.2 ± 2.4 | 0.2 ± 0.42 | 10 % |
| tactico | 3 | ranger | 300 ± 118 | 0 ± 0 | 78 ± 47 | 2.4 ± 1.3 | 0.3 ± 0.68 | 10 % |
| tactico | 3 | warrior (Máster) | 252 ± 436 | 0 ± 0 | 50 ± 76 | 3.6 ± 4.6 | 0.1 ± 0.32 | 0 % |
| tactico | 4 | cleric | 447 ± 243 | 225 ± 150 | 306 ± 127 | 3.3 ± 2.4 | 0.4 ± 0.52 | 40 % |
| tactico | 4 | warrior (Máster) | 578 ± 209 | 0 ± 0 | 69 ± 70 | 4.3 ± 1.8 | 0.0 ± 0.0 | 0 % |
| tactico | 5 | cleric | 52 ± 38 | 120 ± 122 | 238 ± 86 | 0.7 ± 0.9 | 1.0 ± 0.0 | 100 % |
| tactico | 5 | mage | 192 ± 137 | 0 ± 0 | 276 ± 159 | 1.8 ± 1.4 | 1.2 ± 0.42 | 100 % |
| tactico | 5 | ranger | 163 ± 95 | 0 ± 0 | 235 ± 101 | 1.0 ± 1.2 | 1.2 ± 0.42 | 100 % |
| tactico | 5 | rogue | 269 ± 152 | 0 ± 0 | 254 ± 139 | 2.2 ± 1.6 | 1.2 ± 0.42 | 100 % |
| tactico | 5 | warrior (Máster) | 194 ± 102 | 0 ± 0 | 270 ± 121 | 0.8 ± 0.9 | 0.0 ± 0.0 | 0 % |
| tactico | 6 | cleric | 213 ± 149 | 0 ± 0 | 168 ± 38 | 1.9 ± 1.0 | 1.4 ± 0.52 | 90 % |
| tactico | 6 | ranger | 251 ± 150 | 0 ± 0 | 144 ± 71 | 0.7 ± 0.8 | 1.5 ± 1.08 | 90 % |
| tactico | 6 | warrior (Máster) | 278 ± 228 | 0 ± 0 | 182 ± 27 | 1.9 ± 1.9 | 0.0 ± 0.0 | 0 % |
| tactico | 7 | cleric | 132 ± 132 | 106 ± 139 | 204 ± 53 | 1.0 ± 1.2 | 0.9 ± 0.32 | 100 % |
| tactico | 7 | mage | 352 ± 302 | 0 ± 0 | 136 ± 53 | 2.2 ± 2.1 | 1.0 ± 0.0 | 100 % |
| tactico | 7 | ranger | 229 ± 152 | 0 ± 0 | 141 ± 75 | 1.4 ± 1.4 | 0.9 ± 0.32 | 90 % |
| tactico | 7 | warrior (Máster) | 254 ± 196 | 0 ± 0 | 174 ± 56 | 1.3 ± 1.2 | 0.3 ± 0.48 | 0 % |
| tactico | 8 | warrior (Máster) | 837 ± 401 | 0 ± 0 | 173 ± 29 | 4.3 ± 2.8 | 0.1 ± 0.32 | 0 % |
| tactico | 9 | cleric | 0 ± 0 | 0 ± 0 | 0 ± 0 | 0.0 ± 0.0 | 0.0 ± 0.0 | 0 % |
| tactico | 9 | mage | 0 ± 0 | 0 ± 0 | 0 ± 0 | 0.0 ± 0.0 | 0.0 ± 0.0 | 0 % |
| tactico | 9 | ranger | 0 ± 0 | 0 ± 0 | 0 ± 0 | 0.0 ± 0.0 | 0.0 ± 0.0 | 0 % |
| tactico | 9 | rogue | 0 ± 0 | 0 ± 0 | 0 ± 0 | 0.0 ± 0.0 | 0.0 ± 0.0 | 0 % |
| tactico | 9 | warrior (Máster) | 0 ± 0 | 0 ± 0 | 0 ± 0 | 0.0 ± 0.0 | 0.0 ± 0.0 | 0 % |
| tactico | 10 | cleric | 34 ± 27 | 174 ± 139 | 323 ± 145 | 0.3 ± 0.5 | 1.2 ± 0.42 | 90 % |
| tactico | 10 | mage | 202 ± 127 | 0 ± 0 | 202 ± 112 | 1.5 ± 1.4 | 1.0 ± 0.0 | 90 % |
| tactico | 10 | ranger | 122 ± 63 | 0 ± 0 | 236 ± 129 | 0.4 ± 0.5 | 1.1 ± 0.57 | 90 % |
| tactico | 10 | rogue | 234 ± 94 | 0 ± 0 | 273 ± 98 | 1.5 ± 1.1 | 1.1 ± 0.32 | 90 % |
| tactico | 10 | warrior (Máster) | 185 ± 91 | 0 ± 0 | 212 ± 98 | 0.8 ± 0.8 | 0.2 ± 0.42 | 0 % |
| loco | 1 | warrior (Máster) | 1881 ± 131 | 0 ± 0 | 31 ± 48 | 19.7 ± 1.1 | 0.0 ± 0.0 | 0 % |
| loco | 2 | cleric | 796 ± 296 | 299 ± 167 | 332 ± 178 | 7.0 ± 2.6 | 0.0 ± 0.0 | 0 % |
| loco | 2 | warrior (Máster) | 646 ± 175 | 0 ± 0 | 2 ± 4 | 3.5 ± 1.9 | 0.0 ± 0.0 | 0 % |
| loco | 3 | cleric | 312 ± 140 | 347 ± 168 | 333 ± 185 | 4.1 ± 2.4 | 0.2 ± 0.42 | 0 % |
| loco | 3 | ranger | 330 ± 70 | 0 ± 0 | 99 ± 54 | 3.0 ± 1.2 | 0.2 ± 0.42 | 0 % |
| loco | 3 | warrior (Máster) | 139 ± 53 | 0 ± 0 | 21 ± 26 | 2.5 ± 1.5 | 0.0 ± 0.0 | 0 % |
| loco | 4 | cleric | 345 ± 189 | 144 ± 107 | 220 ± 89 | 2.5 ± 1.7 | 0.4 ± 0.52 | 30 % |
| loco | 4 | warrior (Máster) | 617 ± 398 | 0 ± 0 | 47 ± 70 | 4.4 ± 3.6 | 0.0 ± 0.0 | 0 % |
| loco | 5 | cleric | 78 ± 76 | 249 ± 169 | 312 ± 103 | 0.6 ± 0.7 | 0.9 ± 0.32 | 100 % |
| loco | 5 | mage | 289 ± 243 | 0 ± 0 | 241 ± 102 | 2.5 ± 2.6 | 1.0 ± 0.47 | 100 % |
| loco | 5 | ranger | 163 ± 75 | 0 ± 0 | 254 ± 128 | 1.6 ± 1.1 | 1.1 ± 0.57 | 100 % |
| loco | 5 | rogue | 301 ± 136 | 0 ± 0 | 316 ± 187 | 2.3 ± 1.5 | 1.5 ± 0.71 | 100 % |
| loco | 5 | warrior (Máster) | 477 ± 236 | 0 ± 0 | 272 ± 93 | 2.2 ± 1.5 | 0.4 ± 0.52 | 0 % |
| loco | 6 | cleric | 213 ± 150 | 0 ± 0 | 148 ± 52 | 1.7 ± 1.5 | 0.9 ± 0.32 | 90 % |
| loco | 6 | ranger | 203 ± 116 | 0 ± 0 | 132 ± 42 | 0.6 ± 1.1 | 1.3 ± 0.68 | 100 % |
| loco | 6 | warrior (Máster) | 895 ± 428 | 0 ± 0 | 173 ± 64 | 5.9 ± 2.2 | 0.1 ± 0.32 | 0 % |
| loco | 7 | cleric | 201 ± 247 | 173 ± 223 | 269 ± 144 | 0.3 ± 0.5 | 1.0 ± 0.0 | 100 % |
| loco | 7 | mage | 368 ± 516 | 0 ± 0 | 152 ± 99 | 2.2 ± 2.4 | 1.2 ± 0.63 | 100 % |
| loco | 7 | ranger | 269 ± 351 | 0 ± 0 | 152 ± 37 | 1.6 ± 2.9 | 1.0 ± 0.0 | 100 % |
| loco | 7 | warrior (Máster) | 2374 ± 3619 | 0 ± 0 | 167 ± 60 | 3.5 ± 5.8 | 0.1 ± 0.32 | 0 % |
| loco | 8 | warrior (Máster) | 1129 ± 519 | 0 ± 0 | 179 ± 41 | 6.4 ± 3.4 | 0.1 ± 0.32 | 0 % |
| loco | 9 | cleric | 0 ± 0 | 0 ± 0 | 0 ± 0 | 0.0 ± 0.0 | 0.0 ± 0.0 | 0 % |
| loco | 9 | mage | 0 ± 0 | 0 ± 0 | 0 ± 0 | 0.0 ± 0.0 | 0.0 ± 0.0 | 0 % |
| loco | 9 | ranger | 0 ± 0 | 0 ± 0 | 0 ± 0 | 0.0 ± 0.0 | 0.0 ± 0.0 | 0 % |
| loco | 9 | rogue | 0 ± 0 | 0 ± 0 | 0 ± 0 | 0.0 ± 0.0 | 0.0 ± 0.0 | 0 % |
| loco | 9 | warrior (Máster) | 0 ± 0 | 0 ± 0 | 0 ± 0 | 0.0 ± 0.0 | 0.0 ± 0.0 | 0 % |
| loco | 10 | cleric | 133 ± 92 | 200 ± 152 | 309 ± 141 | 0.5 ± 0.7 | 1.0 ± 0.0 | 100 % |
| loco | 10 | mage | 192 ± 138 | 0 ± 0 | 161 ± 58 | 1.4 ± 1.4 | 1.3 ± 0.48 | 100 % |
| loco | 10 | ranger | 120 ± 89 | 0 ± 0 | 206 ± 82 | 0.9 ± 1.1 | 1.3 ± 0.68 | 100 % |
| loco | 10 | rogue | 154 ± 97 | 0 ± 0 | 213 ± 122 | 0.1 ± 0.3 | 1.4 ± 0.7 | 100 % |
| loco | 10 | warrior (Máster) | 363 ± 151 | 0 ± 0 | 231 ± 47 | 2.3 ± 1.6 | 0.4 ± 0.52 | 0 % |

## Recursos e ítems (media por run)

| Variante | Piso | Recogido en el piso | Guardado al volver | Recompensa del piso | Ítems de recompensa | Consumibles usados | Bot (pings / comandos / skills / revividos) |
|---|---|---|---|---|---|---|---|
| tactico | 1 | essence 0.6 | essence 0.6 | books 0.0, essence 1.0, food 0.0, gems 75.0, left_behind 0.0, materials 0.0, starsteel 1.0, stones 1.0 | 2.2 ± 0.4 | 0.0 ± 0.0 | 80.7 / 0.0 / 12.2 / 0.0 |
| tactico | 2 | essence 0.4 | essence 0.4 | books 1.0, essence 1.0, food 0.0, gems 90.0, left_behind 0.0, materials 0.0, starsteel 2.0, stones 1.0 | 3.0 ± 0.0 | 0.0 ± 0.0 | 45.9 / 1.0 / 5.6 / 0.0 |
| tactico | 3 | essence 0.1 | essence 0.1 | books 0.0, essence 1.8, food 0.0, gems 94.5, left_behind 0.0, materials 0.0, starsteel 1.8, stones 0.9 | 3.1 ± 1.2 | 0.0 ± 0.0 | 27.8 / 1.9 / 1.6 / 0.1 |
| tactico | 4 | essence 0.4, mat_enchanted_cloth 0.1 | essence 0.2 | books 0.6, essence 1.2, food 0.0, gems 72.0, left_behind 0.0, materials 0.0, starsteel 1.8, stones 1.2 | 2.0 ± 1.8 | 0.0 ± 0.0 | 91.2 / 0.4 / 4.2 / 0.0 |
| tactico | 5 | essence 0.3, mat_enchanted_cloth 0.7 | essence 0.1 | — | 0.0 ± 0.0 | 0.0 ± 0.0 | 28.9 / 1.0 / 1.5 / 0.6 |
| tactico | 6 | mat_enchanted_cloth 0.6, mat_iron_ore 0.6 | mat_enchanted_cloth 0.1, mat_iron_ore 0.1 | books 0.1, essence 0.3, food 0.0, gems 15.0, left_behind 0.0, materials 0.0, starsteel 0.4, stones 0.2 | 0.5 ± 1.6 | 0.0 ± 0.0 | 76.5 / 1.2 / 2.1 / 1.1 |
| tactico | 7 | mat_iron_ore 0.3, mat_resonant_crystal 0.7 | mat_iron_ore 0.1, mat_resonant_crystal 0.2 | — | 0.0 ± 0.0 | 0.0 ± 0.0 | 22.4 / 0.7 / 1.8 / 0.0 |
| tactico | 8 | mat_moon_flower 0.7, mat_resonant_crystal 0.1 | — | — | 0.0 ± 0.0 | 0.0 ± 0.0 | 534.7 / 0.0 / 6.1 / 0.0 |
| tactico | 9 | — | — | books 0.0, essence 4.0, food 0.0, gems 195.0, left_behind 0.0, materials 0.0, starsteel 5.0, stones 3.0 | 5.4 ± 0.5 | 0.0 ± 0.0 | 0.0 / 0.0 / 0.0 / 0.0 |
| tactico | 10 | mat_rune_plate 0.1 | — | — | 0.0 ± 0.0 | 0.0 ± 0.0 | 25.7 / 0.7 / 1.8 / 0.7 |
| loco | 1 | essence 0.6 | essence 0.6 | books 0.0, essence 1.0, food 0.0, gems 75.0, left_behind 0.0, materials 0.0, starsteel 1.0, stones 1.0 | 2.2 ± 0.4 | 0.0 ± 0.0 | 149.9 / 0.0 / 12.3 / 0.0 |
| loco | 2 | essence 0.4 | essence 0.4 | books 1.0, essence 1.0, food 0.0, gems 90.0, left_behind 0.0, materials 0.0, starsteel 2.0, stones 1.0 | 3.0 ± 0.0 | 0.0 ± 0.0 | 67.6 / 1.4 / 6.0 / 0.0 |
| loco | 3 | essence 0.2 | essence 0.2 | books 0.0, essence 2.0, food 0.0, gems 105.0, left_behind 0.0, materials 0.0, starsteel 2.0, stones 1.0 | 3.4 ± 0.5 | 0.0 ± 0.0 | 22.4 / 2.1 / 0.6 / 0.0 |
| loco | 4 | essence 0.3, mat_enchanted_cloth 0.1 | essence 0.3, mat_enchanted_cloth 0.1 | books 0.9, essence 1.8, food 0.0, gems 108.0, left_behind 0.0, materials 0.0, starsteel 2.7, stones 1.8 | 3.0 ± 1.2 | 0.0 ± 0.0 | 62.3 / 0.7 / 4.7 / 0.0 |
| loco | 5 | essence 0.5, mat_enchanted_cloth 0.9 | — | — | 0.0 ± 0.0 | 0.0 ± 0.0 | 55.9 / 1.8 / 3.3 / 0.0 |
| loco | 6 | mat_enchanted_cloth 0.8, mat_iron_ore 1.2 | mat_enchanted_cloth 0.2, mat_iron_ore 0.3 | — | 0.0 ± 0.0 | 0.0 ± 0.0 | 90.5 / 1.6 / 6.3 / 0.0 |
| loco | 7 | mat_iron_ore 0.4, mat_resonant_crystal 0.9 | — | — | 0.0 ± 0.0 | 0.0 ± 0.0 | 206.5 / 1.4 / 13.8 / 0.0 |
| loco | 8 | mat_moon_flower 0.7, mat_resonant_crystal 0.3 | mat_moon_flower 0.3, mat_resonant_crystal 0.2 | books 0.3, essence 0.9, food 0.0, gems 54.0, left_behind 0.0, materials 0.0, starsteel 1.5, stones 0.9 | 1.3 ± 2.1 | 0.0 ± 0.0 | 112.6 / 0.0 / 8.5 / 0.0 |
| loco | 9 | — | — | books 0.0, essence 4.0, food 0.0, gems 195.0, left_behind 0.0, materials 0.0, starsteel 5.0, stones 3.0 | 5.4 ± 0.5 | 0.0 ± 0.0 | 0.0 / 0.0 / 0.0 / 0.0 |
| loco | 10 | mat_rune_plate 0.1 | — | — | 0.0 ± 0.0 | 0.0 ± 0.0 | 51.2 / 1.7 / 4.1 / 0.0 |

## Quién mata a los héroes (total)

- tactico, piso 3: Bandido Arquero 1, Bandido Degollador 1
- tactico, piso 4: Bandido Bruto 1, Bandido Degollador 1, Bandido Maton 2
- tactico, piso 5: Bandido Bruto 3, Bandido Degollador 2, Bandit Captain 4, left behind 31
- tactico, piso 6: Bandido Arquero 2, Bandido Bruto 1, Bandido Chaman 1, Bandido Mago 1, left behind 13
- tactico, piso 7: Bandido Bruto 1, Bandido Degollador 5, Bandido Mago 1, Bandido Maton 4, left behind 18
- tactico, piso 10: Bandido Bruto 1, Bandido Mago 1, The Crimson Baron 10, left behind 24
- loco, piso 4: Bandido Arquero 1, Bandido Degollador 2
- loco, piso 5: Bandido Bruto 5, left behind 35
- loco, piso 6: Bandido Bruto 7, Bandido Mago 4, left behind 8
- loco, piso 7: Bandido Arquero 1, Bandido Bruto 6, Bandido Degollador 1, Bandido Mago 1, Bandido Maton 4, left behind 17
- loco, piso 10: Bandido Bruto 5, Bandido Degollador 1, The Crimson Baron 2, left behind 32

## Velocidad

- Tiempo de juego simulado: 42523 s en 2818.7 s reales de CPU por proceso → **×15.1** tiempo real por proceso.
- Con 2 procesos en paralelo: 1461.4 s de reloj en total → **×29.1** tiempo real.

Archivos: `runs.csv` (una fila por run), `heroes.csv` (una fila por héroe y run), `results.json` (todo, con la config).
