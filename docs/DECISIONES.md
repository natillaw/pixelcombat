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

### Limpieza de la Fase 0
- Se eliminó `archive/legacy_ts/` (proyecto Tactical Summoners, 14 MB). Sigue
  disponible en el repo `natillaw/tactical-summoners`.
- Las rutas fijas a `C:\dev\combat` del README se sustituyeron por la variable
  de entorno `GODOT` y rutas relativas.
- `tools/run_tests.*` reintentan la importación una vez: en una importación en
  frío Godot 4.7.2 termina a veces con segfault (observado en Windows) y el
  segundo intento pasa.
