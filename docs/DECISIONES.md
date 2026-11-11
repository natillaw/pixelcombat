# Bitácora de decisiones

Una entrada por decisión, con fecha. Las decisiones D1–D8 vienen del roadmap
(`docs/ROADMAP.md`, sección 3).

## 2026-11-10 — Arranque de PixelCombat

Base: commit `8a860a49` del proyecto Reflections (versión 2D de pixel art, ya
publicada en GitHub). Historial nuevo en `natillaw/pixelcombat`. Se descartó el
snapshot sin commitear del archivo `combat_2d_pixelart` porque mezclaba
archivos de momentos distintos y no compilaba.

- **D1 — Alcance:** primero un jugador, con la simulación preparada para
  servidor autoritativo. Online y PvP en las fases 8 y 9.
- **D2 — Nombre:** el proyecto se llama **PixelCombat**.
- **D3 — Pisos de pico:** los pisos 5 y 10 de **cada** tier de 10 pisos son
  pisos difíciles (mini-jefe y jefe, con misión dura opcional). *Supuesto del
  autor del roadmap; confirmar.*
- **D4 — Torre:** 10 tiers × 10 pisos. Cada tier cambia materiales, items, tema
  visual, enemigos y paleta.
- **D5 — Subclases:** 3 comunes por clase al inicio; después se abren las raras,
  únicas y legendarias por oleadas. La rareza no da más poder.
- **D6 — Clases base:** Warrior, Rogue, Mage y Archer. Cleric y Ranger quedan
  fuera de alcance; el soporte llega con subclases. Los docs de diseño
  antiguos (`CLASES_V2`, `EVOLUCIONES_V1`) hablan de cinco clases: se mantienen
  como referencia y se ajustan al llegar cada clase.
- **D7 — Licencias del LPC:** se prefieren capas con opción de solo atribución
  (ver `docs/ASSET_REGISTRY.md`).
- **D8 — PvP:** arenas instanciadas (1v1, 2v2, 3v3), como Battlerite.

- **D9 — Avance por la torre:** no se puede subir de piso sin haber completado
  el piso actual (condición de "completado" por definir: limpiar enemigos y/o
  objetivo del piso). Los pisos ya completados se pueden revisitar y respawnean
  enemigos.
- **D10 — Sin GPL:** el arte LPC solo usa piezas con opción de solo atribución
  (OGA-BY, CC-BY, CC0). Se eliminaron las 14 piezas que solo ofrecían SA/GPL.
  Para hachas dobles (Berserker) y arcos grandes hará falta otra fuente.

### Limpieza de la Fase 0
- Se eliminó `archive/legacy_ts/` (proyecto Tactical Summoners, 14 MB). Sigue
  disponible en el repo `natillaw/tactical-summoners`.
- Las rutas fijas a `C:\dev\combat` del README se sustituyeron por la variable
  de entorno `GODOT` y rutas relativas.
- `tools/run_tests.*` reintentan la importación una vez: en una importación en
  frío Godot 4.7.2 termina a veces con segfault (observado en Windows) y el
  segundo intento pasa.

## 2026-11-10 — Fase 1: combate

- **Encarar al cursor (hecho):** el personaje siempre mira al cursor, también al moverse (strafe). El sprite de 4 direcciones usa histéresis del 15 % para no parpadear en diagonales.
- **Enemigos y telegraph (decisión de diseño):** las fuentes públicas de Drakantos no documentan telegraphs ni ventanas de esquiva. Lo único confirmado: jefes de varias fases y enemigos con mecánicas combinables. Por tanto el telegraph viene de Battlerite (zona o cono visible antes del golpe, escalado por peligro) y de Drakantos tomamos los **jefes por fases** y la **combinación de mecánicas simples** entre tipos de enemigo.
- **Esquiva (hecho):** 104 px en 0,25 s, invulnerable los primeros 0,18 s, cooldown 1,1 s, sin recurso. Hacia el movimiento; quieto, retrocede (opuesto al cursor). Cancela WINDUP y RECOVERY, nunca ACTIVE (se buferiza 0,15 s). Los DoT ignoran los i-frames. Los cooldowns de un ataque cancelado se conservan. Los datos viven en `WarriorKit.DODGE`; es acción común, así que las otras clases heredarán la misma estructura.
- **Skills por datos (hecho):** las skills ejecutables viven en `data/skills/*.json` y las carga `SkillCatalog`, que valida el esquema (test en CI). `WarriorKit.M1/M2` ahora salen del catálogo. La simulación es genérica por slot: `M1`, `M2` y `S1`-`S5` (teclas 1-5). Formas `cone`, `line`, `circle`; `max_targets` toma los más cercanos; coste de Rage al lanzar (sin Rage no se lanza y se emite `skill_denied`); el cooldown de los básicos cuenta desde el final del ataque y el de las demás skills desde el lanzamiento. Las skills S se lanzan al pulsar (mantener no repite), M2 sigue repitiendo al mantener. Se implementaron Cleaving Strike (cono 200°, 20 Rage, 6 s) y Piercing Thrust (línea, máx. 2 objetivos, 15 Rage, 5 s) como prueba del pipeline; el equipado de slots (panel de loadout) llega después.
- **Contrato de tests cambiado a propósito:** `test_warrior.gd` y `test_warrior_data.gd` exigían que ninguna skill del Skill Book fuera jugable (corte M1/M2). Ahora exigen que `implemented` coincida con `IMPLEMENTED_SKILLS`, para que nada se marque jugable sin estar en el catálogo.
- **Ultimate (hecho):** barra de Ultimate Charge 0-100 que sube **solo al conectar golpes** (referencia Drakantos); recibir daño no la carga. Cada skill declara `ult_gain` por objetivo golpeado y `ult_cap` por lanzamiento (M1 3/6, M2 6/8, Cleaving 4/12, Piercing 5/10), así que un barrido contra muchos enemigos no la llena de golpe. La ultimate no se carga a sí misma. War God's Descent gasta toda la barra al lanzarse (`charge: 100`) y **no tiene cooldown aparte** (el de 60 s del diseño provisional se eliminó: lo sustituye la carga). Mecánica: salta 150 px hacia el cursor durante 0,70 s de windup, con la zona marcada en el suelo (telegraph rojo que se rellena, anillo interior de la zona central), y golpea un círculo de 78 px: daño x4, x1,5 más en los 32 px centrales, 15 Rage. Ni la esquiva ni nada la cancela una vez lanzada (`uncancelable`), porque ya gastó la barra. El punto de aterrizaje se ajusta a los límites de la arena. Campos nuevos del esquema: `ult_gain`, `ult_cap`, `charge`, `anchor` (`self` | `aim_leap`), `leap_distance`, `center_radius`, `center_mult`, `telegraph`, `uncancelable`. Números provisionales; falta medir cuánto tarda en cargarse en combate real.
- **M1 y M2 estilo Drakantos (hecho):** según el anuncio de la beta cerrada en Steam y la wiki, en Drakantos el clic izquierdo es el ataque básico y el derecho el ataque **especial, que se puede mantener para potenciarlo**; los básicos se pueden usar sin esperar el cooldown pero "funcionan como una resistencia" (los cuerpo a cuerpo tienen cargas), y el personaje mira al cursor al atacar. Las fuentes no dan cifras, así que los números son nuestros y provisionales. **M1** (Sword Slash) usa una reserva de 3 cargas que se recarga de forma continua (1 por 0,9 s): ráfaga de 3 golpes y luego ritmo sostenido de ~1 golpe/s; sin cargas no hay golpe y no se avisa. **M2** (Heavy Strike) se lanza al pulsar (ya no repite al mantener) y, si se mantiene el botón al acabar el windup (0,3 s), se carga hasta 0,6 s: hasta +60 % de daño y +25 % de alcance, proporcional a lo mantenido; al llegar al máximo se lanza sola; soltar antes lo lanza con lo que lleve; la esquiva lo cancela y reinicia la carga. Cooldown de M2: 3 s desde que termina. Un toque rápido da el daño base de siempre. Esquema nuevo: `charges {max, recharge}` y `hold {max, damage_bonus, range_bonus}`. Efecto de balance: el DPS sostenido de M1 baja a la mitad (de ~2,1 a ~1 golpes/s); se medirá en el laboratorio de balance.
- **Enemigos con telegraph (hecho):** los enemigos se definen en `data/enemies/*.json` y los carga `EnemyCatalog` (que valida el esquema, incluido que cada ataque tenga `windup` > 0 y que los sprites existan). `EnemySim` sigue IDLE → CHASE → TELEGRAPH → ACTIVE → RECOVER. **Reglas de telegraph:** (1) la zona (cono, línea o círculo) se dibuja completa desde el primer instante y se rellena durante el `windup`; (2) la dirección queda fijada al empezar, así que salirse de la zona esquiva el golpe aunque el enemigo siga mirando; (3) el daño se resuelve **una sola vez**, al empezar ACTIVE, contra la zona marcada, de modo que una esquiva con i-frames bien sincronizada también lo evita; (4) la zona dibujada es exactamente la que usa la simulación (círculos sin deformar), y (5) ningún ataque baja de 0,45 s de telegraph (lo comprueba un test). Cada ataque tiene su cooldown desde que cae y un peso para elegirlo entre los listos con el RNG propio del enemigo (derivado de la semilla del mundo), por lo que el combate es determinista. Tier 1: **Slime** (cono lento, 0,75 s), **Bat** (línea con embestida de 120 px, 0,55 s), **Spider** (círculo de 58 px a 0,9 s o salto en cono estrecho a 0,5 s) y **Beetle** (cono enorme a 1,0 s, 240 de vida y armadura 40). Reaparecen a los 8-10 s (dato `respawn_seconds`; en la torre lo gestionará el sistema de pisos). Los enemigos del arenero acampan lejos del centro hasta que el jugador entra en su rango de aggro. Arte: SpritePilot Creatures (CC0). Pendiente: ataques a distancia (proyectiles), estados, grupos y jefes por fases (Drakantos: 3-4 fases).
- **Corrección:** el telegraph de la ultimate del jugador se dibujaba como una elipse aplastada pero golpea un círculo real; ahora se dibuja sin deformar.
