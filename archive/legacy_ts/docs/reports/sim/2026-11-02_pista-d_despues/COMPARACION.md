# Pista D: antes / después (pisos 1-10, kit blanco, táctico vs loco)

Antes: `../2026-11-02_pista-d_antes/` (4 runs por piso y estilo, commit base 2985d83d). Después: este informe
(5 runs, commit 132d629f + reporte). Godot 4.7.2, misma config `floors1-10_kit_blanco.json`. Muestras pequeñas:
±25 pts es ruido posible. No se ha tocado ningún valor.

| Piso | Misión | Táctico antes | Táctico después | Loco antes | Loco después |
|---|---|---|---|---|---|
| 1 | combat | 100 % | 100 % | 0 % | 20 % |
| 2 | exploration | 100 % | 100 % | 100 % | 100 % |
| 3 | defense | 75 % | **0 %** | 100 % | 60 % |
| 4 | escape | 0 % | 0 % | 0 % | 0 % |
| 5 | boss | 0 % | 0 % | 0 % | 0 % |
| 6 | rescue | 0 % | 0 % | 0 % | 0 % |
| 7 | sabotage | 0 % | 0 % | 0 % | 0 % |
| 8 | combat | 0 % | 0 % | 0 % | 0 % |
| 9 | survival | 25 % | **0 %** | 0 % | 0 % |
| 10 | boss | 0 % | 0 % | 0 % | 0 % |

## Alertas que cambian
- Piso 3 (táctico) pasa a **< 10 %** (75 → 0) y el loco le saca 60 pts (antes 25).
- Piso 9 (táctico) pasa a **< 10 %** (25 → 0).
- Piso 2 sigue con loco = táctico (100/100), como antes.

## Causa (A/B en `ab_saqueo/`, pisos 3 y 9, táctico, 5 runs)
Con `kit_blanco` no hay equipo nuevo ni comidas: lo que cambia es que el `MasterBot` ahora va a saquear los
cuerpos (hasta 220 px, mantiene F) también en defensa y supervivencia, y lo derriban.

| Piso | Táctico que saquea | Táctico sin saquear (`bot.loot: false`) |
|---|---|---|
| 3 defense | 0 % | 40 % |
| 9 survival | 0 % | 20 % |

Es comportamiento del bot (y una tentación para el jugador), no números del juego. Propuesta sin aplicar: que el
bot solo saquee sin enemigos a la vista y no en misiones de defensa/supervivencia hasta que acaben.

## Botín (media por run, después)
Pocos ítems por piso (0,2-3 en cuerpos; ~30 % basura); a casa llegan sobre todo en los pisos ganados (1-3);
el avaricioso no aparece (la party de esta config no lo tiene).

## Arreglo del saqueo de la IA (`saqueo_seguro/`, pisos 3 y 9, táctico vs loco, 2 runs)
Regla nueva (sin tocar valores del juego): el `MasterBot` y los héroes autónomos solo saquean sin criaturas
vivas a ≤ 320 px (`LootDefs.LOOT_SAFE_RADIUS`) y sin estar peleando ni lanzando; en defensa y supervivencia
(`LootDefs.HOLD_MISSIONS`) nunca dejan su sitio: solo lo que tienen a los pies en una pausa, y el barrido del
final recoge el resto. El jugador sigue saqueando cuando quiera.

| Piso | Táctico antes | Táctico con saqueo libre | Táctico sin saquear (A/B) | **Táctico con saqueo seguro** | Loco con saqueo seguro |
|---|---|---|---|---|---|
| 3 defense | 75 % (4) | 0 % (5) | 40 % (5) | **0 % (2)** | 0 % (2) |
| 9 survival | 25 % (4) | 0 % (5) | 20 % (5) | **50 % (2)** | 0 % (2) |

(entre paréntesis, runs). El piso 9 vuelve a su nivel (y el táctico vuelve a sacarle ventaja al loco). El piso 3
sigue en 0 % en estos 2 runs: con 2 runs no se distingue de un ~40 % (0 de 2 sale ~1 de cada 3 veces); el bot ya
no se aleja a saquear (1 saqueo por run, a sus pies). Para confirmarlo harían falta ≥ 10 runs del piso 3.
