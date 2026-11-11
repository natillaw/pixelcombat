# Uso de assets antes del overhaul (2026-10-31)

Generado con grep sobre `scripts/`, `tests/` y `tools/`: qué script usa qué constante de `AssetCatalog` o qué ruta `res://assets/...`. Sirve para saber qué se reemplaza y qué queda huérfano.

| Referencia | Ruta | Usado en |
|---|---|---|
| `AssetCatalog.ASSETS_ROOT` | `` | `scripts/sandbox/enemy_sprites.gd` |
| `AssetCatalog.CAZ_CHARACTERS` | `res://assets/pixel/caz-base/Characters/` | `scripts/sandbox/caz_art.gd` |
| `AssetCatalog.CAZ_TILES` | `res://assets/pixel/caz-base/Tiles/` | `scripts/sandbox/caz_art.gd` |
| `AssetCatalog.CREATURES` | `` | `scripts/sandbox/enemy_sprites.gd`, `tests/capture_cohesion.gd`, `tests/smoke_ui_full.gd`, `tools/art_cohesion.gd` |
| `AssetCatalog.FONT_BODY` | `res://assets/fonts/m5x7.ttf` | `scripts/ui/ui_kit.gd` |
| `AssetCatalog.FONT_TITLE` | `res://assets/fonts/m6x11.ttf` | `scripts/ui/ui_kit.gd` |
| `AssetCatalog.HERO_LAYERS` | `res://assets/sprites/` | `scripts/core/sprite_composer.gd` |
| `AssetCatalog.ITEM_ICONS` | `res://assets/pixel/icons/caz_mv/MV Icons Complete Sheet Free - ALL.png` | `scripts/data/item_icons.gd` |
| `AssetCatalog.KIT` | `res://assets/pixel/ui/ts_kit/` | `scripts/ui/expedition_hud.gd`, `scripts/ui/summon_reveal.gd` |
| `AssetCatalog.MUSIC` | `res://assets/audio/music/xdeviruchi/` | `scripts/autoload/ui_sfx.gd` |
| `AssetCatalog.PACKS` | `res://assets/packs/` | `scripts/sandbox/combat_vfx.gd` |
| `AssetCatalog.PIXEL_CRAWLER_ENEMIES` | `res://assets/pixel/enemies/pixel-crawler/` | `scripts/sandbox/enemy_sprites.gd` |
| `AssetCatalog.PIXEL_CRAWLER_TILES` | `res://assets/pixel/tilesets/pixel-crawler/` | `scripts/sandbox/forest_art.gd`, `scripts/sandbox/map_tiles.gd`, `scripts/sandbox/town_view.gd` |
| `AssetCatalog.PROCESSED_CREATURES` | `res://assets/processed/creatures/` | `scripts/sandbox/enemy_sprites.gd`, `tools/art_cohesion.gd` |
| `AssetCatalog.PROCESSED_OUTLINE` | `res://assets/processed/outline/` | `scripts/sandbox/enemy_sprites.gd` |
| `AssetCatalog.SKILL_ICONS` | `res://assets/pixel/icons/kurai_skills/SKILL ICONS.png` | `scripts/data/item_icons.gd`, `scripts/data/skill_icons.gd`, `scripts/ui/expedition_hud.gd` |
| `AssetCatalog.SLOT_FRAMES` | `` | `scripts/data/item_icons.gd` |
| `AssetCatalog.UI` | `` | `scripts/ui/expedition_hud.gd`, `scripts/ui/ui_kit.gd` |
| `AssetCatalog.UI_SFX` | `res://assets/audio/ui/kenney/` | `scripts/autoload/ui_sfx.gd` |
| `AssetCatalog.VOXEL_CREATURES` | `res://assets/packs/voxel-dungeon-pack-full/creatures/sheets/` | `scripts/sandbox/enemy_sprites.gd` |
| `AssetCatalog.VOXEL_PROPS` | `res://assets/packs/voxel-dungeon-pack-full/props/frames/` | `scripts/sandbox/town_view.gd` |
| `res://assets/CREDITS.md` | `res://assets/CREDITS.md` | `scripts/ui/game_menu.gd` |
| `res://assets/audio/music/xdeviruchi/` | `res://assets/audio/music/xdeviruchi/` | `scripts/data/asset_catalog.gd` |
| `res://assets/audio/sfx/ninja/` | `res://assets/audio/sfx/ninja/` | `scripts/data/asset_catalog.gd` |
| `res://assets/audio/ui/kenney/` | `res://assets/audio/ui/kenney/` | `scripts/data/asset_catalog.gd` |
| `res://assets/fonts/m5x7.ttf` | `res://assets/fonts/m5x7.ttf` | `scripts/data/asset_catalog.gd` |
| `res://assets/fonts/m6x11.ttf` | `res://assets/fonts/m6x11.ttf` | `scripts/data/asset_catalog.gd` |
| `res://assets/fx/bandidos/fx_escudo_altar.png` | `res://assets/fx/bandidos/fx_escudo_altar.png` | `scripts/sandbox/sandbox_screen.gd` |
| `res://assets/packs/` | `res://assets/packs/` | `scripts/data/asset_catalog.gd` |
| `res://assets/packs/voxel-dungeon-pack-full/creatures/sheets/` | `res://assets/packs/voxel-dungeon-pack-full/creatures/sheets/` | `scripts/data/asset_catalog.gd` |
| `res://assets/packs/voxel-dungeon-pack-full/props/frames/` | `res://assets/packs/voxel-dungeon-pack-full/props/frames/` | `scripts/data/asset_catalog.gd` |
| `res://assets/pixel/bosses/ninja/` | `res://assets/pixel/bosses/ninja/` | `scripts/data/asset_catalog.gd` |
| `res://assets/pixel/caz-base/Characters/` | `res://assets/pixel/caz-base/Characters/` | `scripts/data/asset_catalog.gd` |
| `res://assets/pixel/caz-base/Tiles/` | `res://assets/pixel/caz-base/Tiles/` | `scripts/data/asset_catalog.gd` |
| `res://assets/pixel/enemies/enemy_animations_set/` | `res://assets/pixel/enemies/enemy_animations_set/` | `scripts/data/asset_catalog.gd` |
| `res://assets/pixel/enemies/ninja/` | `res://assets/pixel/enemies/ninja/` | `scripts/data/asset_catalog.gd` |
| `res://assets/pixel/enemies/pixel-crawler/` | `res://assets/pixel/enemies/pixel-crawler/` | `scripts/data/asset_catalog.gd` |
| `res://assets/pixel/fx/ninja/` | `res://assets/pixel/fx/ninja/` | `scripts/data/asset_catalog.gd` |
| `res://assets/pixel/icons/caz_mv/MV` | `res://assets/pixel/icons/caz_mv/MV` | `scripts/data/asset_catalog.gd` |
| `res://assets/pixel/icons/kurai_skills/Gold` | `res://assets/pixel/icons/kurai_skills/Gold` | `scripts/data/asset_catalog.gd` |
| `res://assets/pixel/icons/kurai_skills/SKILL` | `res://assets/pixel/icons/kurai_skills/SKILL` | `scripts/data/asset_catalog.gd` |
| `res://assets/pixel/icons/raven/32x32.png` | `res://assets/pixel/icons/raven/32x32.png` | `scripts/data/asset_catalog.gd` |
| `res://assets/pixel/tilesets/pixel-crawler/` | `res://assets/pixel/tilesets/pixel-crawler/` | `scripts/data/asset_catalog.gd` |
| `res://assets/pixel/tilesets/pixel_dungeon/` | `res://assets/pixel/tilesets/pixel_dungeon/` | `scripts/data/asset_catalog.gd` |
| `res://assets/pixel/tpf_bandidos/` | `res://assets/pixel/tpf_bandidos/` | `scripts/data/bandit_art.gd` |
| `res://assets/pixel/ui/dragon_regalia/` | `res://assets/pixel/ui/dragon_regalia/` | `scripts/data/asset_catalog.gd` |
| `res://assets/pixel/ui/ts_kit/` | `res://assets/pixel/ui/ts_kit/` | `scripts/data/asset_catalog.gd` |
| `res://assets/processed/` | `res://assets/processed/` | `scripts/data/asset_catalog.gd` |
| `res://assets/processed/creatures/` | `res://assets/processed/creatures/` | `scripts/data/asset_catalog.gd` |
| `res://assets/processed/outline/` | `res://assets/processed/outline/` | `scripts/data/asset_catalog.gd`, `tools/art_cohesion.gd` |
| `res://assets/props/campamento/bandidos.json` | `res://assets/props/campamento/bandidos.json` | `scripts/sandbox/bosque_art.gd` |
| `res://assets/props/campamento/prop_fogata_anim.png` | `res://assets/props/campamento/prop_fogata_anim.png` | `scripts/sandbox/bosque_art.gd` |
| `res://assets/props/campamento/props_campamento.png` | `res://assets/props/campamento/props_campamento.png` | `scripts/sandbox/bosque_art.gd` |
| `res://assets/sprites/` | `res://assets/sprites/` | `scripts/data/asset_catalog.gd` |
| `res://assets/tiles/bosque/bosque_props.png` | `res://assets/tiles/bosque/bosque_props.png` | `scripts/sandbox/bosque_art.gd` |
| `res://assets/tiles/bosque/bosque_tiles.png` | `res://assets/tiles/bosque/bosque_tiles.png` | `scripts/sandbox/bosque_art.gd` |
| `res://assets/tiles/bosque/bosque_tileset.json` | `res://assets/tiles/bosque/bosque_tileset.json` | `scripts/sandbox/bosque_art.gd` |

## Carpetas de `assets/` sin referencia directa (candidatas a huérfanas)

- `assets/_inbox/_done`
- `assets/_inbox/pisos_1_10`
- `assets/_inbox/ts_generated_kit`
