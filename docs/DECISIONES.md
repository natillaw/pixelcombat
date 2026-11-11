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
