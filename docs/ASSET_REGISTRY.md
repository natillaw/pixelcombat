# Registro de assets y licencias

Vista humana de los assets de **PixelCombat**. Los datos completos por pack
siguen en `assets/ASSET_REGISTRY.json` y `assets/CREDITS.md`; los créditos
archivo por archivo del LPC están en `assets/pixel/lpc/CREDITS.csv`.

## Reglas

1. **Solo se usa un asset con licencia leída y registrada aquí antes de
   incorporarlo al juego.**
2. Que un pack sea gratuito no lo hace de dominio público: hay que leer la
   licencia del pack concreto.
3. Los PNG originales del LPC no se editan. `LpcComposer` compone capas en
   memoria y cachea el resultado.
4. Los packs crudos de `new assets/` no forman parte del juego: están ignorados
   por git y por Godot (`.gdignore`). No se referencian desde el código.
5. No se redistribuyen packs crudos como biblioteca independiente.
6. Antes de publicar el repositorio, revisar las licencias marcadas
   **REVISAR**.

## En uso — corte Warrior

| Asset | Ruta | Uso | Licencia | Estado |
|---|---|---|---|---|
| **Universal LPC Spritesheet Character Generator** | `assets/pixel/lpc/` | Cuerpo, cabeza, pelo, barba y equipo del Warrior vía `LpcComposer` / `LpcWardrobe` | CC0 / CC-BY / OGA-BY / CC-BY-SA según archivo (ver `CREDITS.csv`) | En uso |
| Fuente **m5x7** (Daniel Linssen) | `assets/fonts/m5x7.ttf` | HUD y números de daño | CC0 | En uso |
| **PixelRPGCursors Lite** (Indigolay) | `assets/pixel/cursors/` | Espada cruzada al pasar sobre enemigos y base del puntero (el Default se dibujó a juego, el pack Lite no trae flecha); el reloj de arena sin usar aun | Gratis uso comercial y modificable; no se puede revender ni redistribuir los archivos sueltos (README.pdf) | En uso - REVISAR antes de publicar el repo |
| **Ninja Adventure Asset Pack** (pixel-boy & AAA) | `assets/audio/sfx/ninja/` | Tajos, impactos, alerta del muñeco, muerte | CC0 1.0 | En uso |

### Capas LPC del Warrior

Definidas en `game/art/warrior_look.gd`:

| Capa | Pieza | Variante |
|---|---|---|
| Cuerpo | `body` (male) | skin `light` |
| Cabeza | `head_human_male` | — |
| Pelo | `hair_buzzcut` | `dark_brown` |
| Barba | `beard_trimmed` | — |
| Pecho | `armour_plate` | `steel` |
| Piernas | `legs_plate` | `steel` |
| Manos | `gloves` | `steel` |
| Pies | `boots_basic` | `leather` |
| Cabeza | `helmet_barbuta` | `steel` |
| Arma | `weapon_longsword` | `default` |

Los frames son de 64×64; las filas son arriba, izquierda, abajo, derecha.

### SFX usados

| Archivo | Uso |
|---|---|
| `Whoosh_Slash/Slash2.wav` | M1 |
| `Whoosh_Slash/Sword2.wav` | M2 |
| `Whoosh_Slash/Whoosh.wav` | fallo del muñeco |
| `Hit_Impact/Hit2.wav` | impacto de M1 |
| `Hit_Impact/Impact3.wav` | impacto de M2 |
| `Hit_Impact/Impact.wav` | daño recibido |
| `Hit_Impact/Impact5.wav` | muerte |
| `Hit_Impact/Impact2.wav` | golpe del muñeco |
| `Alert/Alert2.wav` | telegráfico del muñeco |

## Inventario de `new assets`

Veredicto de licencia pack por pack en
[`INVENTARIO_NEW_ASSETS.md`](INVENTARIO_NEW_ASSETS.md).

| Asset | Ruta | Uso | Licencia | Estado |
|---|---|---|---|---|
| **SpritePilot Creatures Pack** | `assets/pixel/enemies/spritepilot_creatures/` | Enemigos del tier 1: Slime, Bat, Spider, Beetle, Wisp (fantasma), Hornet (abeja) y el jefe Brood Beetle (el Beetle ampliado y tintado); pez y pájaro sin usar | CC0 1.0 | **En uso** (`data/enemies/tier1.json`) |

## Disponible para futuros cortes

| Pack | Ruta | Uso previsto | Licencia | Nota |
|---|---|---|---|---|
| SpritePilot (combat, magic, effects, environment) | `assets/pixel/` | VFX de habilidades | CC0 | Sin integrar |
| KILN FX Free Sampler | `assets/pixel/fx/` | Tajos, chispas, explosiones | Uso en juegos sí; no redistribuir como pack | Sin integrar |
| Enemy Animations Set | `assets/pixel/enemies/enemy_animations_set/` | Enemigos reales | Licencia del dueño (D-063) | Sin integrar |
| Pixel Crawler (Anokolisa) | `assets/pixel/tilesets/`, `assets/pixel/enemies/pixel-crawler/` | Tiles y mobs | Términos del autor: uso comercial, no revender | Sin integrar |
| Iconos de habilidad (Kurai, Caz, Raven) | `assets/pixel/icons/` | UI del Skill Book | Mixta (CC0 / CC BY 4.0 / términos del autor) | Revisar por icono |
| Kenney Interface Sounds | `assets/audio/ui/` | Clics y UI | CC0 1.0 | Sin integrar |
| XDeviruchi music | `assets/audio/music/` | Música | CC BY-SA 4.0 | **No integrada**: verificar antes de usar |
| Tileset y props de bosque | `assets/tiles/bosque/`, `assets/props/` | Mapas futuros | Hecho por el dueño / CraftPix | Sin integrar |

## Fuera del juego

| Ruta | Qué es |
|---|---|
| `new assets/` | Packs crudos descargados (~588 MB). Ignorados por git y Godot. |


## Atribución mínima

Si se publica una build, incluir:

- Universal LPC Spritesheet Character Generator y los autores listados en
  `assets/pixel/lpc/CREDITS.csv` (varía por capa).
- Daniel Linssen por m5x7 (CC0, atribución no obligatoria pero apreciada).
- pixel-boy & AAA por Ninja Adventure (CC0).
- Cualquier pack adicional que se integre, según su licencia.

## Pendientes de licencia

- **Música**: no se ha añadido al juego. `assets/audio/music/` tiene pistas
  CC BY-SA 4.0, pero falta confirmar que el pack completo lo sea y decidir la
  atribución antes de reproducirla.
- **Iconos**: la colección mezcla CC0, CC BY 4.0 y términos del autor; revisar
  caso por caso antes de usarlos en el Skill Book.
- **Packs marcados REVISAR** en `assets/ASSET_REGISTRY.json` (RPG icons, pixel
  weapons, armor16): uso autorizado por el dueño como excepción, pero sin
  licencia clara. No usar en builds públicas hasta resolverlo.

## Licencias del LPC (auditoría, 10 nov 2026)

Cada archivo del LPC lista una o varias licencias **alternativas** en
`assets/pixel/lpc/CREDITS.csv` (columna `licenses`); se puede elegir una.
Sobre las 342 filas del CSV:

- **281** ofrecen una opción de solo atribución (OGA-BY 3.0, CC-BY 3.0/4.0 o
  CC0). Elegimos esa opción: basta con acreditar a los autores.
- **61** solo ofrecían CC-BY-SA y/o GPL. **Se eliminaron del repo (10 nov 2026)**:
  `ears_elven`, `hair_long`, `hair_bedhead`, `hair_messy1`, `hair_parted`,
  `hair_pixie`, `helmet_horned`, `eyepatch`, `weapon_waraxe`,
  `weapon_bow_recurve`, `weapon_bow_great`, `shield_kite`, `backpack_pack` y
  `backpack_satchel`. Sus filas ya no están en `CREDITS.csv`.

Reglas:

1. Al elegir piezas nuevas del LPC, **preferir las que tienen opción de solo
   atribución**.
2. `wardrobe_catalog.json` marca con `license_safe: false` (67 de 408 piezas del
   generador) las que no ofrecen solo atribución: **no importarlas**.
   `tests/test_asset_licenses.gd` falla si el índice vuelve a incluir una.
3. Antes de publicar, generar la pantalla de créditos a partir de
   `CREDITS.csv` (tarea pendiente, Fase 10).

## Terreno de los pisos (en uso)

| Asset | Ruta | Uso | Licencia | Estado |
|---|---|---|---|---|
| **4-Season Terrain (LPC)** — Lanea Zimmerman (Sharm), Eliza Wyatt (DeathsDarling), Hyptosis | `assets/pixel/lpc_terrain/` | Suelo (hierba/tierra), agua, cliffs, arboles, rocas, flores, setas y hierba alta de los pisos, via `TerrainRenderer` y `data/biomes.json` | **OGA-BY 3.0** (atribucion; ver `assets/pixel/lpc_terrain/CREDITS.txt`) | En uso |

Otros packs auditados el 2026-11-11 (Descargas/new assets) y su veredicto:

| Pack | Licencia | Veredicto |
|---|---|---|
| Tiny Top-Down Village — 58 Buildings (Pixel-Deck) | Uso comercial OK, modificar OK, atribucion opcional; no revender ni redistribuir el pack completo sin cambios | **Usable** (solo las piezas que se usen se copian al repo; REVISAR antes de publicar) |
| Free Pixel RPG Starter Kit (Ishihara Asset Forge): bosque 16 px, aldea 16 px, UI, FX | Uso comercial OK, sin credito, editable; no revender ni usar como datos de entrenamiento de IA | Usable (muestra reducida: hierba/tierra, 4 props, aldea basica) |
| Pixel Spell Magic FX / Magic Spells VFX Lite / PVFX Foundry / Pixel VFX Essentials | Por leer en cada LICENSE | Pendiente de integrar en las skills |
| Dark World Free Asset Pack | **Sin licencia incluida** | No usar |
| tiny-dungeon-monsters, tileset.png, ForgoneFantasy basics, animated torch | Sin licencia incluida | No usar hasta verificar la fuente |

| Antorcha animada (GIF de 9 fotogramas, 48x48) | `assets/pixel/fx/torch_sheet.png` (convertida del GIF de Descargas/new assets) | Antorchas de ciudad y cliffs | **Sin licencia incluida**: la subio el dueno del proyecto; REVISAR la fuente antes de publicar | En uso |

## Efectos, iconos y torre (en uso, 2026-11-11)

| Asset | Ruta | Uso | Licencia | Estado |
|---|---|---|---|---|
| **PVFX Foundry 1.0** (101 efectos, tier "lit") | `assets/pixel/fx/vfx/*__*.png` | Golpes, ataques cuerpo a cuerpo, magia, estados, explosiones; `data/fx.json` | CC0 1.0 (hojas y manifiestos) | En uso |
| **Pixel Spell & Combat FX** (muestra del starter kit, 22 efectos) | `assets/pixel/fx/vfx/kit_*.png` | Subir de nivel, recoger, escudo, circulos, orbes... | Uso comercial OK, sin credito; no revender ni usar para entrenar IA | En uso |
| Iconos de habilidad (Swordsman y Paladin de CraftPix, Dark Fantasy Combat Skills de M-Xing, Spell Icons Vol.1, Aeromancer) | `assets/pixel/icons/skills/` (64x64) | HUD y panel de habilidades | Licencias gratuitas comerciales de cada autor; **REVISAR Spell Icons y Aeromancer antes de publicar** | En uso |
| Antorcha animada (GIF) | `assets/pixel/fx/torch_sheet.png` | Antorchas | Sin licencia incluida; REVISAR | En uso |

| **Free Basic Pixel Art UI for RPG** (CraftPix) | `assets/pixel/ui/craftpix/` | Paneles (nueve parches), botones y marco del retrato de toda la interfaz via `UiStyle` | Licencia gratuita de CraftPix (uso comercial, no redistribuir el pack); REVISAR antes de publicar | En uso |
