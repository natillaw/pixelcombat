# Unificación de UI y arte — informe (2026-10-31)

Rama: `feat/ui-and-art-unification` (repositorio local v10). Decisiones: D-060, D-061, D-062, D-063.
Respuestas del dueño aplicadas: base 640×360 (2a); usar Raven, Enemy_Animations_Set, 2D Pixel Dungeon y m6x11 porque el dueño tiene sus licencias (3a); Q ataque + W/E/R (3 habilidades); 8 ranuras de equipo con futuro a 11; síntesis y sacrificio implementados; tope de 5★; Esc abre un menú **sin pausar** el juego.

## Packs
| Pack | Uso | Licencia |
|---|---|---|
| Kit propio (`assets/ui/ts_kit`) | Paneles 9-slice, retratos, estrellas, marcos de rareza, invocación (círculo, rayo, carta), portal | Propio |
| Dragon Regalia UI | Botones de 4 estados, pestañas, ranuras de equipo, cerrar | El dueño tiene la licencia |
| KURAI skill icons, Caz MV icons, Raven 32 px | Iconos de habilidades, objetos y recursos | El dueño tiene la licencia |
| Ninja Adventure (criaturas, jefes, FX, sfx) | Criaturas normalizadas con `art_cohesion --creatures` | CC0 |
| Enemy_Animations_Set | Esqueletos | El dueño tiene la licencia |
| 2D Pixel Dungeon | Importado para el futuro bioma mazmorra (aún sin usar) | El dueño tiene la licencia |
| xDeviruchi (música), Kenney UI audio | Música por pantalla con crossfade, sonidos de UI | Ver `assets/CREDITS.md` |
| m5x7 / m6x11 | Fuentes pixel 16/32 px | El dueño tiene la licencia |
| **Cute_Fantasy, items.zip** | **No usados** (no comercial / sin licencia clara) | — |

Todo está registrado en `docs/ASSET_REGISTRY.md` y `assets/CREDITS.md`. Las rutas salen de una sola tabla: `scripts/data/asset_catalog.gd`.

## Qué cambió por fase
- **A — Importación:** `tools/import_packs.py` (selección, LICENSE.txt por carpeta, WAV→OGG, registro y créditos), `ArtPalette` (colores oficiales, 6 rarezas) y `AssetCatalog`.
- **B — Criaturas:** tiras derecha/idle/run/attack/hurt/death normalizadas hacia la tinta de los héroes de Caz (#190657), saturación ×0,85 y tope de valor. Ataque, daño y muerte generados cuando el pack no los trae. Jefe nuevo **Grove Warlord** en el piso 5.
- **C1 — Base visual:** 640×360 con escala entera (ventana 1280×720 por defecto), fuentes pixel sin suavizado y tema construido por código (paneles del kit, botones Dragon Regalia).
- **C3 — Expedición:** HUD con grupo (retratos, vida, recurso, estados), habilidades Q/W/E/R con iconos, coste y enfriamiento, órdenes, minimapa con niebla y clic para mirar, y barra de jefe. Esc abre el menú sin pausa: opciones de volumen, temblor, tamaño de ventana y pantalla completa, controles y créditos.
- **C4 — Pantallas:**
  - Título con portal animado y héroes.
  - Pueblo con barra de recursos e iconos de acceso rápido.
  - Inventario global con comparación ▲▼, equipar o reciclar, y recetas.
  - Revelación de la invocación por rareza; se puede saltar y termina en un resumen.
  - Ficha del héroe con pestañas: resumen, habilidades, 8 ranuras de equipo, progresión (ascensión, síntesis, sacrificio), profesión y relaciones.
  - Resultados con desplazamiento y MVP.
- **Backend:**
  - D-060: 8 ranuras activas; manos, ring2 y especial bloqueadas.
  - D-061: síntesis, que da bonus permanentes a un héroe al consumir otros, con muerte registrada en el memorial como "sacrificed". Sacrificio, que convierte un héroe en recursos. Los dos piden confirmación y guardan antes.

## Capturas (antes → después)
Carpeta `docs/reports/ui_art/`:
- Antes: `before_village.png`, `before_summons.png`, `before_floor1.png`, `before_results.png`.
- Después:
  - `after_01_title.png`
  - `after_02_reveal.png`
  - `after_04_town.png`
  - `after_05_roster_summary.png`
  - `after_06_sheet_tab3.png`
  - `after_07_inventory.png`
  - `after_08_hud_driven.png`
  - `after_09_esc_menu.png`
  - `after_12_results.png`
  - `after_cohesion_lineup.png`

## Pruebas ejecutadas
`powershell -ExecutionPolicy Bypass -File tools\Run-Tests.ps1` con Godot 4.7.2 (2026-10-31 06:38), salida en `tools/last_test_run.txt`:
```
core, summons v2, ui smoke, sandbox, memorial v3, combat, mission, animation, art, simulation,
deep systems, procedural, combat core, orders, skills, vfx, hq, items, town, boot, tower,
expedition, slice, ui full: PASS (24/24)
```
Tras reducir las escalas de las criaturas grandes se repitió `smoke_vfx`: ALL PASSED.

## Sin verificar
- No se ha jugado a mano de principio a fin.
- No se han medido los FPS reales en el iGPU Ryzen.
- No se han escuchado la música ni los sonidos.
- No se ha visto en movimiento la sensación de la interpolación de física.
- **Diferencia de densidad de píxel conocida:** las criaturas Ninja de 16 px escaladas ×2/×3 tienen píxeles más gruesos que los héroes de Caz a ×1. No tiene arreglo sin arte nuevo; las escalas se bajaron todo lo posible.

## Pendiente del prompt (no hecho)
- Flechas para aliados fuera de pantalla.
- Anillos de selección y retícula del kit en el mundo.
- Sprites del kit para la zona de extracción y el portal dentro de la misión.
- Desaturar los VFX.
- Bioma mazmorra con 2D Pixel Dungeon.
- Arrastrar y soltar en la pantalla de grupo.
- Filtros y búsqueda en el roster.
- Fundidos entre escenas.
- Música de combate que sube al detectar enemigos.
