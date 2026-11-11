# Auditoría de assets

## 1. Inventario (`assets/`, 20 830 archivos versionados en el repo en total)
| Ruta | Contenido | Tamaño | Usado por el código | Licencia (texto en repo) |
|---|---|---|---|---|
| `assets/sprites/` | **Tiny Pixel Fantasy – Character Generator (Caz)**: 10 capas, 211 PNG (576×384, 12×8 celdas de 48 px) + 1×1 vacíos | 3.2 MB | Sí: `SpriteComposer` (todas las combinaciones del generador existen, verificado) | **Solo un enlace a Google Doc** (`EULA_READ_ME.txt`). Texto no guardado. |
| `assets/pixel/tilesets/pixel-crawler/` | Floors/Wall tiles (Anokolisa) | 2 PNG | Sí: `MapTiles` | `Terms.txt` (crédito opcional, uso comercial, no revender) |
| `assets/pixel/enemies/pixel-crawler/` | 8 mobs × idle/run/death | 24 PNG | Sí: `EnemySprites` (5 tipos usados) | `Terms.txt` |
| `assets/packs/spritepilot-*` (8 packs) | Combate, criaturas, efectos, entorno, magia, pickups, UI, clima | ~2.7 MB | Intento de uso de 1 archivo con ruta errónea (F-012) | CC0 |
| `assets/packs/KILN_FX_Free_Sampler/` | 40 PNG de efectos | 352 KB | No | Uso en juegos; **prohibido redistribuir como pack** |
| `assets/packs/sprite_kitchen_combat_essentials_v0.1/` | 82 PNG + metadata | 1.5 MB | No | Uso en juegos; **prohibido subir/redistribuir como pack**; no entrenar IA |
| `assets/packs/voxel-dungeon-pack-full/` | 4 431 PNG (criaturas, entorno, fx, items, loot, props, UI) | 47 MB | No | CC0 |
| `assets/source_packs/` | **Copia aplanada** de todo `assets/packs/` | 52 MB | No | Igual |
| `assets/*.zip` (11) | Zips originales de los packs | ~13 MB | No | — |
| `assets/ASSET_REGISTRY.json`, `CREDITS.md` | Registro y créditos | — | Herramientas | Solo Pixel Crawler |
| `assets/_inbox/_done/.gitkeep` | Bandeja de importación | — | `Import-Asset.ps1` | — |

## 2. Problemas
- **A-1 (F-021) Duplicación masiva.** `assets/packs` y `assets/source_packs` contienen 10 093 archivos cada una con los mismos 4 439 contenidos PNG distintos (verificado por hash; difieren solo los `.import` por la ruta). Más los zips. ≈117 MB de contenido redundante; Godot importa ambas copias (tiempo de importación y `.godot/` duplicados).
- **A-2 (F-022) Registro de licencias incompleto.** `ASSET_REGISTRY.json`/`CREDITS.md` solo listan Pixel Crawler. Faltan Caz (el propio ASSET_MANIFEST exige acreditarlo con licencia), SpritePilot, KILN, Sprite Kitchen y Voxel Dungeon. `ASSET_MANIFEST.md` sigue diciendo "owner pack UNKNOWN".
- **A-3 Redistribución.** KILN y Sprite Kitchen prohíben compartir los efectos "on their own / as a standalone pack". Tener los zips y las carpetas sueltas en un repositorio Git es aceptable solo si el repo es privado; **no se pudo verificar la visibilidad del repo**. Riesgo si se hace público. La EULA de Caz no se pudo leer (enlace externo): pendiente de verificar si permite repos públicos y modificaciones.
- **A-4 (F-012) Ruta rota de VFX.** El único asset de pack referenciado no existe en la ruta usada.
- **A-5 Coherencia de estilo.** Voxel Dungeon (47 MB, la mayor parte del peso) son sprites renderizados desde voxels 3D; ART_DIRECTION pide evitar mezclar pixel art con renders 3D sin pasada de conversión. SpritePilot/KILN/Sprite Kitchen no se han probado junto a los héroes de 16 px de estilo Caz. Ninguno está aprobado según D-008 (prueba de una muestra antes de importar en masa) — **se importó en masa antes de la prueba de estilo**.
- **A-6 Referencias.** Todas las rutas usadas por el código existen salvo A-4. No hay referencias a `source_packs` desde código.
- **A-7 Imagen de referencia del HQ.** `infos/IMAGEN … HEADQUARTERS ….jpg` es una captura de un juego comercial de terceros. Válida como inspiración interna; no debe incluirse en builds ni imitarse su expresión (D-002).
- **A-8 Animaciones de héroes.** Se usan filas 0-3 (caminar/idle), 5-6 (lunge y caído) mediante `SpriteComposer.ANIMS`; hit/cast/muerte por tweens (D-020). No se ha verificado visualmente (headless). Los PNG originales de Caz no han sido modificados (sin cambios en Git desde el commit inicial).
- **A-9 Faltantes:** audio (T-028), fuente pixel (T-029), retratos (se usa un frame del sprite), iconos de skills.

## 3. Regla de preservación (confirmada)
Los sprites de héroes de Caz están intactos y se componen en memoria. Cualquier mejora futura debe: no editar `assets/sprites/**`; generar animaciones/efectos/retratos por código o en capas separadas; registrar todo asset nuevo gratuito con licencia en un único registro.

## 4. Recomendaciones (no aplicadas)
1. Conservar **una** copia (`assets/packs/<pack>/`) y mover zips fuera del proyecto o a Git LFS / almacenamiento externo; añadir `.gdignore` a carpetas no usadas para que Godot no las importe.
2. Registrar todos los packs en `ASSET_REGISTRY.json` y regenerar `CREDITS.md`; guardar el texto de la EULA de Caz (PDF/TXT) junto a los sprites.
3. Hacer la prueba de estilo D-008 (1 enemigo, 1 efecto, 1 tile por pack) antes de usar SpritePilot/Voxel/KILN/Kitchen.
4. Confirmar visibilidad del repo antes de cualquier publicación.

## 5. Inventario actualizado (2026-11-02, pista C)
Conteo real de `assets/` (sin `.import`/`.uid`), por carpeta:

| Ruta | PNG | Audio (ogg/wav/mp3) | Otros | Tamaño |
|---|---|---|---|---|
| `assets/_inbox/` | 154 | 0 | 19 | 1.6 MB |
| `assets/audio/music/` | 0 | 7 | 1 | 11.6 MB |
| `assets/audio/sfx/` | 0 | 54 | 1 | 4.9 MB |
| `assets/audio/ui/` | 0 | 100 | 1 | 0.9 MB |
| `assets/fonts/` | 0 | 0 | 3 | 0.0 MB |
| `assets/fx/bandidos/` | 5 | 0 | 0 | 0.0 MB |
| `assets/packs/KILN_FX_Free_Sampler/` | 40 | 0 | 2 | 0.1 MB |
| `assets/packs/sprite_kitchen_combat_essentials_v0.1/` | 82 | 0 | 20 | 0.7 MB |
| `assets/packs/spritepilot-combat-pack/` | 27 | 0 | 12 | 0.1 MB |
| `assets/packs/spritepilot-creatures-pack/` | 24 | 0 | 11 | 0.1 MB |
| `assets/packs/spritepilot-effects-pack/` | 21 | 0 | 10 | 0.1 MB |
| `assets/packs/spritepilot-environment-pack/` | 27 | 0 | 12 | 0.2 MB |
| `assets/packs/spritepilot-magic-pack/` | 27 | 0 | 12 | 0.1 MB |
| `assets/packs/spritepilot-pickups-pack/` | 30 | 0 | 13 | 0.1 MB |
| `assets/packs/spritepilot-ui-pack/` | 27 | 0 | 12 | 0.1 MB |
| `assets/packs/spritepilot-weather-pack/` | 27 | 0 | 12 | 0.1 MB |
| `assets/packs/voxel-dungeon-pack-full/` | 4431 | 0 | 451 | 14.0 MB |
| `assets/pixel/bosses/` | 21 | 0 | 1 | 0.0 MB |
| `assets/pixel/caz-base/` | 311 | 0 | 1 | 0.7 MB |
| `assets/pixel/enemies/` | 98 | 0 | 3 | 0.2 MB |
| `assets/pixel/fx/` | 64 | 0 | 1 | 0.1 MB |
| `assets/pixel/icons/` | 6 | 0 | 3 | 2.8 MB |
| `assets/pixel/interiors/` | 15 | 0 | 15 | 0.5 MB |
| `assets/pixel/lpc/` | 3580 | 0 | 8 | 12.6 MB |
| `assets/pixel/packs/` | 5359 | 0 | 0 | 27.8 MB |
| `assets/pixel/tilesets/` | 62 | 0 | 2 | 0.1 MB |
| `assets/pixel/ui/` | 132 | 0 | 3 | 0.6 MB |
| `assets/processed/creatures/` | 80 | 0 | 0 | 0.1 MB |
| `assets/processed/outline/` | 85 | 0 | 0 | 0.4 MB |
| `assets/props/campamento/` | 2 | 0 | 1 | 0.0 MB |
| `assets/sprites/Body/` | 5 | 0 | 0 | 0.1 MB |
| `assets/sprites/Bottom/` | 26 | 0 | 0 | 0.2 MB |
| `assets/sprites/Eyes/` | 4 | 0 | 0 | 0.0 MB |
| `assets/sprites/Facial_Hair/` | 20 | 0 | 0 | 0.1 MB |
| `assets/sprites/Front_Hair/` | 30 | 0 | 0 | 0.2 MB |
| `assets/sprites/Hat/` | 25 | 0 | 0 | 0.2 MB |
| `assets/sprites/Held_Item/` | 6 | 0 | 0 | 0.1 MB |
| `assets/sprites/Rear_Hair/` | 40 | 0 | 0 | 0.3 MB |
| `assets/sprites/Top/` | 55 | 0 | 0 | 0.7 MB |
| `assets/tiles/bosque/` | 2 | 0 | 1 | 0.0 MB |
| **Total** | **14950** | **161** | **631** | **82 MB** |

**Qué usa la pista C (D-110..D-117) y qué falta:**
- Impactos: el catálogo `CombatVFX.FX` (SpritePilot, KILN, Sprite Kitchen, Voxel Dungeon) sigue igual; el juice nuevo son partículas de 2 px generadas por código (sin arte nuevo).
- Party frames: retratos compuestos (`SpriteComposer.face_region`), marco y barras dibujados por código con `ArtPalette`. **Pendiente de arte:** marcos de party frame del kit UI (hoy rectángulos con borde).
- Mundo vivo: sombras de nubes y pájaros dibujados por código (pájaro de 3-5 px). **Pendiente de arte:** sprite de pájaro animado (hay `farm_animals`/`hunt_animals`, sin pájaros pequeños de 2 frames).
- Recolección: arte existente (`crystals`, `forest_objects`, `bushes`, `rocks2`, troncos de BosqueArt); pips de cargas y astillas por código.
- Shader: `assets/shaders/wind_sway.gdshader` (nuevo, propio). Perfiles: `assets/juice/*.tres` (generados).

