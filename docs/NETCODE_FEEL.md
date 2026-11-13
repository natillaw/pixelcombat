# El feel con latencia (13 nov 2026)

Pensado para cuando se active la capa de red (Fase 9) y el PvP. Hoy el juego es de un solo jugador; esto es lo que ya
esta resuelto y lo que hay que decidir al conectar.

## Como probarlo hoy
Ajustes > "Accesibilidad y musica" > **Latencia simulada** (0-300 ms, de 20 en 20). Retrasa el input N ticks
(`net/input_delay.gd`, 60 ticks/s: 100 ms = 6 ticks) antes de dar al `CombatWorld`; el HUD avisa en rojo. No cambia la
simulacion, solo cuando llega cada comando, asi que sirve para sentir lo que notara el jugador con ping.

## Ya resuelto
- **El reloj de la simulacion no se toca en red.** El hit-stop y la camara lenta usan `Engine.time_scale` en un solo
  jugador; en red o PvP (`Arena.time_dilation_allowed()`) el hit-stop pasa a ser un congelado solo visual de los sprites
  y la camara lenta se omite.
- **Sacudidas, zoom, retroceso visual y flashes** son presentacion pura: no afectan a ningun resultado.
- El input ya viaja como `InputMessage` por tick (`move_dir`, `aim_dir`, `actions`); la orientacion del personaje al
  caminar es solo visual (la sim usa `aim_dir`).

## Decisiones para la capa de red (recomendadas, sin implementar)
1. **Inicio de ataque inmediato, impacto confirmado.** La animacion de windup y el telegraph de tu propio golpe empiezan
   al pulsar (prediccion local, inofensiva); los numeros de dano, impactos y el congelado de sprites salen cuando el
   servidor confirma el golpe. Si el servidor lo rechaza, el golpe se queda en "fallo" sin efectos.
2. **Esquiva y parry por ventana, no por fotograma.** Hoy las invulnerabilidades duran 0,10 s (arquero), 0,12 s (mago),
   0,18 s (guerrero) y 0,20 s (pícaro). Con 100 ms de latencia la del arquero y la del mago casi desaparecen. Antes de
   abrir PvP online: subir cada ventana al menos a 0,15-0,18 s o compensar la latencia en el servidor (retroceder
   `ping/2` al evaluar la esquiva de un jugador, con tope de 100 ms).
3. **Hit-stop solo visual y corto** (<= 60 ms) o ninguno en PvP competitivo; ya viene gobernado por el ajuste
   "Pausa de impacto".
4. **Empujones y estados (aturdir, ralentizar)** los decide el servidor y llegan por snapshot; el cliente no los
   adelanta (evita el "rubber band" al ser empujado).
5. **Objetivo de latencia:** jugable hasta ~100 ms, aceptable hasta 150 ms, degradado por encima. Probar cada cambio
   de combate con 0, 60, 100 y 160 ms en el simulador.

## Pendiente de medir con personas
Como se siente el movimiento (la prediccion y la reconciliacion de `net/` existen y tienen tests, pero no se ha
jugado con ping real), el lag de las esquivas de arquero y mago, y si hace falta suavizar la posicion de los rivales.
