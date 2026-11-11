# Formato LPC (Universal LPC Spritesheet Character Generator)

Fuente: https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator, clonado con `--depth 1` en `../_vendor/lpc` el 2026-10-31. Commit `86160e7507d6841259cff624a51a63c1d4847ee3` (2026-10-28). Repo público, no del dueño. Su `AGENTS.md`/`CLAUDE.md` son del proyecto ajeno y no se siguen.

## Estructura

- `sheet_definitions/<categoría>/**.json`: una definición por pieza (768 archivos): `name`, `priority`, `layer_N` con `zPos` y una ruta por tipo de cuerpo, `animations` (lista), `credits` (`file`, `authors`, `licenses`, `urls`), `match_body_color`, `custom_animation` para frames sobredimensionados.
- `spritesheets/<ruta>/<cuerpo>/<animación>.png`: **un PNG por animación**, frames de **64×64 px**, una fila por dirección.
- `CREDITS.csv`: `filename, notes, authors, licenses, urls` por archivo.
- `palette_definitions/` + `PALETTE_RECOLOR_GUIDE.md`: muchas prendas vienen en un color base (gris o blanco) y el generador las **recolorea por paleta**. El importador tiene que hacer lo mismo (ver la captura de escala: la ropa sale blanca).

## Animaciones (medido en `spritesheets/body/bodies/male/`)

Filas en orden **arriba (N), izquierda (O), abajo (S), derecha (E)**, salvo las de una fila.

| Animación | Tamaño | Frames | Filas |
|---|---|---|---|
| idle | 128×256 | 2 | 4 |
| combat_idle | 128×256 | 2 | 4 |
| walk | 576×256 | 9 | 4 |
| run | 512×256 | 8 | 4 |
| slash | 384×256 | 6 | 4 |
| halfslash | 384×256 | 6 | 4 |
| backslash | 832×256 | 13 | 4 |
| thrust | 512×256 | 8 | 4 |
| shoot | 832×256 | 13 | 4 |
| spellcast | 448×256 | 7 | 4 |
| hurt | 384×64 | 6 | 1 |
| jump | 320×256 | 5 | 4 |
| sit | 192×256 | 3 | 4 |
| emote | 192×256 | 3 | 4 |
| climb | 384×64 | 6 | 1 |

Mapa al juego (4 direcciones): idle→`idle`, combat_idle→`combat_idle`, walk→`walk`, run→`run`, attack_slash→`slash`, attack_thrust→`thrust`, attack_shoot→`shoot`, cast→`spellcast`, hurt→`hurt` (una fila; se usa en las 4 direcciones), death→`hurt` (los últimos frames: LPC no trae muerte aparte).

## Tipos de cuerpo

Definidos en `layer_1` de cada pieza: `male`, `muscular`, `female`, `pregnant`, `teen`, `child`. **Se usan solo los adultos `male`, `muscular` y `female`** (filtro del prompt).

## Frames sobredimensionados

Algunas armas declaran `custom_animation`: `thrust_oversize` (20 piezas), `slash_oversize` (18), `walk_128` (18), `slash_128` (8), `slash_reverse_oversize` (5), herramientas (`tool_axe`, `tool_whip`). Son frames mayores de 64 px centrados en el personaje: el compositor los dibuja con su propio desplazamiento.

## zPos

Cada `layer_N.zPos` fija el orden de dibujo (cuerpo 10; cabeza, pelo, ropa y armas por encima según su definición). El compositor ordena las capas por `zPos`, no por slot.

## Cabezas, orejas y razas

Las razas se arman con una **cabeza** de `head/heads/<familia>/` sobre el cuerpo humano, más orejas, colas o alas opcionales. Todas las de abajo pasan el filtro de licencia (CC0, CC-BY, OGA-BY o CC-BY-SA; las duales con GPL valen). Las variantes `child` quedan fuera.

| Definición | Nombre | Cuerpos | Licencias |
|---|---|---|---|
| `head/heads/beast/heads_boarman.json` | Boarman | male,muscular,female,pregnant,teen | CC-BY 3.0; GPL 2.0 |
| `head/heads/beast/heads_minotaur.json` | Minotaur | male,muscular,female,pregnant,teen | CC-BY-SA 3.0; GPL 3.0 |
| `head/heads/beast/heads_minotaur_female.json` | Minotaur female | male,muscular,female,pregnant,teen | CC-BY-SA 3.0; GPL 3.0 |
| `head/heads/beast/heads_wartotaur.json` | Wartotaur | male,muscular,female,pregnant,teen | CC-BY 3.0; OGA-BY 3.0 |
| `head/heads/beast/heads_wolf_female.json` | Wolf female | male,muscular,female,pregnant,teen | CC-BY-SA 3.0; GPL 3.0 |
| `head/heads/beast/heads_wolf_male.json` | Wolf male | male,muscular,female,pregnant,teen | CC-BY-SA 3.0; GPL 3.0 |
| `head/heads/fantasy/heads_goblin.json` | Goblin | male,muscular,female,pregnant,teen | CC-BY 4.0; GPL 2.0; GPL 3.0; OGA-BY 3.0 |
| `head/heads/fantasy/heads_orc_female.json` | Orc female | male,muscular,female,pregnant,teen | CC-BY-SA 3.0; GPL 3.0; OGA-BY 3.0 |
| `head/heads/fantasy/heads_orc_male.json` | Orc male | male,muscular,female,pregnant,teen | CC-BY-SA 3.0; GPL 3.0; OGA-BY 3.0 |
| `head/heads/fantasy/heads_troll.json` | Troll | male,muscular,female,pregnant,teen | CC-BY 3.0 |
| `head/heads/farm/heads_mouse.json` | Mouse | male,muscular,female,pregnant,teen | CC-BY 3.0; CC-BY-SA 3.0; OGA-BY 3.0 |
| `head/heads/farm/heads_pig.json` | Pig | male,muscular,female,pregnant,teen | CC-BY 3.0; GPL 3.0 |
| `head/heads/farm/heads_rabbit.json` | Rabbit | male,muscular,female,pregnant,teen | CC-BY 3.0; CC-BY-SA 3.0; OGA-BY 3.0 |
| `head/heads/farm/heads_rat.json` | Rat | male,muscular,female,pregnant,teen | CC-BY 3.0; CC-BY-SA 3.0; OGA-BY 3.0 |
| `head/heads/farm/heads_sheep.json` | Sheep | male,muscular,female,pregnant,teen | CC-BY 3.0; GPL 3.0 |
| `head/heads/human/heads_human_elderly_small.json` | Human Elderly Small | male,muscular,female,pregnant,teen | CC-BY; OGA-BY 3.0 |
| `head/heads/human/heads_human_female.json` | Human Female | male,muscular,female,pregnant,teen | CC-BY-SA 3.0; GPL 3.0; OGA-BY 3.0 |
| `head/heads/human/heads_human_female_elderly.json` | Human Female Elderly | male,muscular,female,pregnant,teen | CC-BY 3.0; OGA-BY 3.0 |
| `head/heads/human/heads_human_female_small.json` | Human Female Small | male,muscular,female,pregnant,teen | CC-BY; OGA-BY 3.0 |
| `head/heads/human/heads_human_male.json` | Human Male | male,muscular,female,pregnant,teen | CC-BY-SA 3.0; GPL 3.0; OGA-BY 3.0 |
| `head/heads/human/heads_human_male_elderly.json` | Human Male Elderly | male,muscular,female,pregnant,teen | CC-BY 3.0; OGA-BY 3.0 |
| `head/heads/human/heads_human_male_gaunt.json` | Human Male Gaunt | male,muscular,female,pregnant,teen | CC-BY-SA 3.0; GPL 3.0; OGA-BY 3.0 |
| `head/heads/human/heads_human_male_plump.json` | Human Male Plump | male,muscular,female,pregnant,teen | CC-BY-SA 3.0; GPL 3.0 |
| `head/heads/human/heads_human_male_small.json` | Human Male Small | male,muscular,female,pregnant,teen | CC-BY; OGA-BY 3.0 |
| `head/heads/reptile/heads_alien.json` | Alien | male,muscular,female,pregnant,teen | CC-BY-SA 3.0; GPL 3.0; OGA-BY 3.0 |
| `head/heads/reptile/heads_lizard_female.json` | Lizard female | male,muscular,female,pregnant,teen | CC-BY-SA 3.0; GPL 3.0; OGA-BY 3.0 |
| `head/heads/reptile/heads_lizard_male.json` | Lizard male | male,muscular,female,pregnant,teen | CC-BY-SA 3.0; GPL 3.0; OGA-BY 3.0 |
| `head/heads/undead/heads_frankenstein.json` | Frankenstein | male,muscular,female,pregnant,teen | CC-BY-SA 3.0; GPL 3.0; OGA-BY 3.0 |
| `head/heads/undead/heads_jack.json` | Jack O Lantern | male,muscular,female,pregnant,teen | CC-BY-SA 3.0; GPL 3.0 |
| `head/heads/undead/heads_skeleton.json` | Skeleton | male,muscular,female,pregnant,teen | CC-BY-SA 3.0; GPL 3.0; OGA-BY 3.0 |
| `head/heads/undead/heads_vampire.json` | Vampire | male,muscular,female,pregnant,teen | CC-BY-SA 3.0; GPL 3.0; OGA-BY 3.0 |
| `head/heads/undead/heads_zombie.json` | Zombie | male,muscular,female,pregnant,teen | CC-BY-SA 3.0; GPL 3.0 |
| `head/ears/head_ears_big.json` | Big ears | male,muscular,female,teen,pregnant,child | CC-BY-SA 3.0; GPL 3.0 |
| `head/ears/head_ears_down.json` | Downward Elven Ears | male,muscular,female,teen,pregnant,child | CC-BY 3.0+; GPL 3.0; OGA-BY 3.0+ |
| `head/ears/head_ears_dragon.json` | Dragon Ears | male,muscular,female,teen,pregnant,child | CC-BY 3.0+; GPL 3.0; OGA-BY 3.0+ |
| `head/ears/head_ears_elven.json` | Elven ears | male,muscular,female,teen,pregnant,child | CC-BY-SA 3.0; GPL 3.0 |
| `head/ears/head_ears_hang.json` | Hanging Elven Ears | male,muscular,female,teen,pregnant,child | CC-BY 3.0+; GPL 3.0; OGA-BY 3.0+ |
| `head/ears/head_ears_long.json` | Long ears | male,muscular,female,teen,pregnant,child | CC-BY-SA 3.0; GPL 3.0; OGA-BY 3.0 |
| `head/ears/head_ears_medium.json` | Medium Elven Ears | male,muscular,female,teen,pregnant,child | CC-BY 3.0+; GPL 3.0; OGA-BY 3.0+ |
| `body/lizard/tail_lizard.json` | Lizard tail | male,muscular,female,pregnant,teen,child | CC-BY-SA 3.0; GPL 3.0; OGA-BY 3.0 |
| `body/lizard/wings_lizard.json` | Lizard Wings | male,muscular,female,pregnant,teen | CC-BY-SA 3.0; GPL 3.0; OGA-BY 3.0 |
| `body/lizard/wings_lizard_bat.json` | Batlike Lizard Wings | male,muscular,female,pregnant,teen | OGA-BY 3.0 |

**Razas enemigas disponibles (adultas):** orco, goblin, troll, esqueleto, zombi, vampiro, Frankenstein, calabaza (Jack), lobo, minotauro, wartotauro, jabalí (boarman), lagarto, alien, ratón, cerdo, conejo, rata y oveja. **Elfo:** humano + orejas élficas (`head_ears_elven`, `_medium`, `_hang`, `_down`).

## Rejillas de packs (CraftPix y otros, medido el 2026-10-31)

Medido leyendo la cabecera de cada PNG dentro del zip (`docs/reports/overhaul/packs_raw.json`). "Rejilla" = la que cuadra con todos los tilesets del pack. Los packs de objetos sueltos no tienen rejilla: se listan sus tamaños más comunes.

| Pack | PNG | Rejilla | Tamaños más comunes | License.txt |
|---|---|---|---|---|
| Armor[16x16] | 1 | — | 128x96 | **no** |
| CharGen_v0.9.3 | 0 | — |  | **no** |
| RPG Icons | 400 | — | 32x32 | **no** |
| free-rpg-loot-icons-pixel-art | 96 | — | 32x32 | sí |
| free-pixel-art-sci-fi-icons-pack | 20 | — | 128x128 | sí |
| top-down-crystals-pixel-art | 165 | — | 64x64, 32x32 | sí |
| free-clothing-32x32-pixel-icons | 41 | — | 32x32, 1840x1148 | sí |
| free-top-down-bushes-pixel-art | 165 | — | 32x32, 16x16 | sí |
| free-ruined-temple-top-down-location-pixel-art | 163 | 16 | 384x128, 192x128 | sí |
| free-tree-pixel-art-asset-pack | 71 | — | 41x48, 178x206 | sí |
| free-2d-top-down-pixel-dungeon-asset-pack | 23 | 16 | 128x512, 176x288 | sí |
| free-top-down-pixel-art-guild-hall-asset-pack | 101 | 16 | 448x208, 384x128 | sí |
| free-pixel-art-plants-for-farm | 3 | — | 1840x2445, 288x224 | sí |
| free-vampire-4-direction-pixel-character-sprite-pack | 195 | 16 | 256x256, 704x256 | sí |
| free-pixel-art-dungeon-objects-asset-pack | 15 | 16 | 1840x2445, 1008x128 | sí |
| free-paint-pixel-art-icon-pack | 96 | — | 32x32 | sí |
| free-basic-pixel-art-ui-for-rpg | 20 | 16 | 1840x2445, 384x208 | sí |
| free-summer-pixel-art-backgrounds | 41 | — | 576x324, 2304x1296 | sí |
| free-top-down-pixel-art-cave-objects | 103 | — | 64x64, 128x128 | sí |
| free-predator-plant-mobs-pixel-art-pack | 189 | 16 | 448x256, 320x256 | sí |
| free-top-down-animals-farm-pixel-art-sprites | 49 | 16 | 192x256, 32x32 | sí |
| free-top-down-orc-game-character-pixel-art | 336 | 16 | 512x256, 384x256 | sí |
| free-top-down-trees-pixel-art | 165 | — | 64x64, 128x128 | sí |
| free-chapel-pixel-art-top-down-asset-pack | 240 | 16 | 96x96, 96x64 | sí |
| free-swordsman-skills-pixel-art-icons | 48 | — | 32x32 | sí |
| free-village-pixel-tileset-for-top-down-defense | 187 | 32 | 32x32, 23x21 | sí |
| free-forest-objects-top-down-pixel-art | 82 | — | 128x128, 64x64 | sí |
| 32x32-pixel-art-weapons-free-collection | 71 | — | 32x32, 1840x2445 | sí |
| free-sky-with-clouds-background-pixel-art-set | 38 | — | 576x324, 1840x2445 | sí |
| free-path-and-road-top-down-pixel-tileset | 17 | 16 | 240x416, 240x480 | sí |
| free-rocky-area-objects-pixel-art | 83 | — | 128x128, 64x64 | sí |
| main-characters-home-free-top-down-pixel-art-asset | 22 | 16 | 336x288, 432x1024 | **no** |
| free-pixel-dungeon-props-and-objects-asset-pack | 21 | 16 | 576x48, 160x640 | sí |
| free-bridges-top-down-pixel-art-asset-pack | 15 | 16 | 688x192, 1840x2445 | sí |
| free-rocks-pixel-art-asset-pack | 41 | — | 119x157, 85x123 | sí |
| free-minerals-pixel-art-icons | 96 | — | 32x32 | sí |
| free-glassblowers-workshop-top-down-pixel-art-asset | 46 | 16 | 384x32, 384x480 | sí |
| free-top-down-seabed-objects-pixel-art | 242 | — | 64x64, 128x128 | sí |
| free-undead-tileset-top-down-pixel-art | 262 | 16 | 32x32, 64x64 | sí |
| free-pixel-art-icons-for-mine-location | 80 | — | 32x32 | sí |
| ocean-and-clouds-free-pixel-art-backgrounds | 41 | — | 576x324, 2304x1296 | sí |
| free-halloween-icons-pixel-art | 48 | — | 32x32 | sí |
| free-pixel-art-fantasy-2d-battlegrounds | 69 | — | 1920x1080, 1840x2445 | sí |
| free-slime-mobs-pixel-art-top-down-sprite-pack | 159 | 16 | 512x256, 640x256 | sí |
| free-top-down-hunt-animals-pixel-sprite-pack | 114 | 16 | 192x128, 128x128 | sí |
| free-animated-magic-book-pixel-art-asset-pack | 76 | 16 | 16x16, 32x32 | sí |
| free-fantasy-medieval-village-buildings-asset-pack | 16 | — | 440x580, 320x400 | sí |
| free-nature-backgrounds-pixel-art | 48 | — | 576x324, 2304x1296 | sí |
| free-goblin-loot-icons-32x32-pixel-art | 101 | — | 32x32, 1840x2445 | sí |
| free-belt-rpg-pixel-art-icons | 96 | — | 32x32 | sí |
| free-shield-and-amulet-rpg-icons | 96 | — | 32x32 | sí |
| free-paladin-pixel-art-skill-icons | 49 | — | 32x32, 1840x2445 | sí |
| free-top-down-ruins-pixel-art | 165 | — | 32x32, 48x48 | sí |
| free-cursed-land-top-down-pixel-art-tileset | 144 | 16 | 64x64, 32x32 | sí |
| free-40-loot-icons-pixel-art | 80 | — | 32x32 | sí |
| free-rocks-and-stones-top-down-pixel-art | 165 | — | 64x64, 32x32 | sí |
| free-undead-loot-pixel-art-icons | 101 | — | 32x32, 1840x2445 | sí |
| free-basic-pixel-art-fantasy-icons-16x16-for-ui | 259 | — | 16x16, 32x32 | sí |
| free-bow-and-crossbow-pixel-art-icons | 156 | — | 32x32 | sí |

**Lectura:** los tilesets de entorno de CraftPix son de **16 px** (caminos, mazmorra, guild hall, capilla, puentes, no muertos, tierras malditas, templo en ruinas). Solo `village-pixel-tileset-for-top-down-defense` es de 32 px. Árboles, rocas, arbustos y objetos son sprites sueltos de 32, 64 y 128 px.
