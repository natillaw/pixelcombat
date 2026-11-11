# Inventario de `Downloads\new assets` (10 nov 2026)

Auditoría de licencias de los packs que el dueño tiene en
`C:\Users\natha\Downloads\new assets`. Regla del proyecto (D10): solo se usa
lo que ofrece **licencia de solo atribución o CC0**. Nada de GPL ni de
share-alike obligatorio.

Se leyó el `LICENSE`, `CREDITS` o `README` de cada zip. Un pack sin archivo de
licencia **no se usa** hasta verificar su fuente, aunque el nombre diga CC0.

## Verificados: se pueden usar

| Pack | Licencia (según el propio zip) | Uso previsto |
|---|---|---|
| `spritepilot-creatures-pack.zip` | CC0 1.0 | **Importado** en `assets/pixel/enemies/spritepilot_creatures/`: murciélago, slime, fantasma, abeja, pez, pájaro, araña, escarabajo. Primeros enemigos de los pisos 1–10 |
| `DENZI_CC0.zip` y `DENZI_CC0_individual_organized_tiles_sprites.zip` | CC0 | Monstruos 32×48, tiles de mazmorra, iconos de habilidad y de magia, cascos, demonios. Pendiente de importar por pieza |
| `lpc-more-weapons.zip` | OGA-BY 3.0+ | Armas LPC extra (látigo, bastones, cristales, honda, armas oversize). Candidatas para Mage/Archer |
| `lpc-baobab.zip` | OGA-BY 3.0+ | Árboles para exteriores |
| `lpc-blacksmith.zip` | OGA-BY 3.0, CC-BY 3.0+ | Herrería de la ciudad hub |
| `lpc-tailor.zip` | CC-BY 3.0+ (también GPL: se elige CC-BY) | Sastrería de la ciudad hub |
| `lpc-sawmill.zip` | CC-BY 4.0 | Aserradero / carpintería |
| `lpc-jungle-v2.zip` | CC-BY 4.0 | Tiles de jungla (tier temático) |
| `painterly-spell-icons-3.zip`, `-4.zip` | CC-BY 3.0 (también GPL y SA: se elige CC-BY 3.0) | Iconos de habilidades. Atribución a J. W. Bjerk (eleazzaar) |

## Verificar antes de usar

| Pack | Problema |
|---|---|
| `painterly-spell-icons-1.zip`, `-2.zip` | Mismo autor que 3 y 4, pero sin README: confirmar que ofrecen CC-BY 3.0 |
| `lpc-desert-ruins.zip`, `lpc-jungle-ruins.zip` | La licencia principal es OGA-BY 3.0+, pero los créditos de terreno que incluyen listan piezas solo CC-BY-SA/GPL: revisar tile por tile |
| `weapons.zip` | Autor Tuomo Untinen; el `credits.txt` no deja clara la licencia |
| `para_CC0_particlefx-1.zip` | El nombre dice CC0 pero no trae archivo de licencia: confirmar la fuente |
| `Universal-LPC-Spritesheet-Character-Generator-master.zip` | Código GPL-3.0 (no se distribuye). El arte es mixto: usar solo piezas con opción de solo atribución en su `CREDITS.csv`. Esta versión puede ofrecer piezas nuevas con OGA-BY que el índice actual no tenía |
| Packs LPC de 2024–2025 (`lpc-2024-*`, `lpc-2025-*`, `hairstyles-*`, `furry-ears-tails-*`, `lpc-helmets`, `foremansfairywings_*`, `lpc-*-tilesets`) | Mezcla de licencias por archivo; la `credits.txt` de algunos dice "OGA-BY 3.0 aplica a todo", pero hay que comprobarlo pack a pack antes de importar |

## No usar (sin licencia verificable)

`496_RPG_icons`, `RPGIconsExtra_by_Ails`, `Everything`, `Grue`, `Pix`, `Pix2`,
`Reptile`, `goblin`, `items`, `potions`, `Water_Effect`, `lizard headwear`,
`font_Pix3M_ccby` (el nombre dice CC-BY pero no hay archivo), y los PNG sueltos
de la raíz (`golem-*.png`, `werewolf-*.png`, `taur_walk.png`, etc.). Si algún
día se encuentra su fuente y su licencia, se mueven a la tabla de arriba.

## No usar (licencia incompatible)

- `lpc-fruit-trees.zip`: CC-BY-SA 3.0 / GPL 3.0.
- `lpc-jungle.zip` (v1): solo CC-BY-SA 3.0. Usar `lpc-jungle-v2`.

## Cómo importar un pack nuevo

1. Copiar a `assets/...` **con** su archivo de licencia o créditos.
2. Añadirlo a `docs/ASSET_REGISTRY.md` con licencia y autor.
3. Si es LPC, pasar por `tests/test_asset_licenses.gd`.
4. No editar los PNG originales.
