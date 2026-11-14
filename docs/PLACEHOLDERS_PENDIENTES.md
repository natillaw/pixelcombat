# Graficos hechos en codigo (placeholders por sustituir con pixel art)

Regla del dueño (13 nov 2026): nada de formas geometricas dibujadas por el agente si hay pixel art en el repo. Donde no lo habia, se dejo un placeholder en codigo y esta anotado aqui. Cuando lleguen los assets locales del dueño, cada fila dice que archivo pide y donde se cambia. Las licencias se anotan en `docs/ASSET_REGISTRY.md` y `assets/ASSET_REGISTRY.json` al incorporarlos.

## Placeholders (dibujados con `draw_*`, a sustituir)
| Que | Donde | Que asset hace falta |
|---|---|---|
| Estandarte purpura con emblema dorado (avenida y puerta de la Torre) | `game/world/city_prop.gd` `_draw_banner` (kind `banner`) | Estandarte vertical de ~16x40 px, animado o 2 fotogramas, tonos purpura/oro |
| Brasero de piedra con llama animada (puerta de la Torre) | `city_prop.gd` `_draw_brazier` (kind `brazier`) | Brasero o antorcha de pie con llama de 3-4 fotogramas |
| Puesto de mercado con toldo a rayas (2 variantes) | `city_prop.gd` `_draw_stall` (kind `stall`) | Puesto de mercado ~80x60 px, toldo rojo/blanco y azul/blanco |
| Farola con lampara | `city_prop.gd` `_draw_lamppost` (kind `lamppost`) | Farola ~16x40 px (apagada/encendida) |
| Estatua de guardian | `city_prop.gd` `_draw_statue` (kind `statue`) | Estatua de piedra ~24x50 px |
| Anillo de losas de la plaza | `city_prop.gd` `_draw_plaza_ring` (kind `plaza_ring`) | Suelo de plaza circular o losas de piedra clara para pintar sobre el adoquin |
| Cristal flotante de la fuente | `game/world/arena.gd` clase `Fountain` | Cristal ~24x44 px con brillo (2-4 fotogramas) |
| Globo de dialogo "..." sobre los residentes | `game/actors/npc_actor.gd` `_draw_bubble` | Icono de globo de dialogo ~20x14 px |
| Fuente: agua y chorros (ya existian, los dejo tal cual) | `arena.gd` `Fountain` | Fuente de piedra completa animada |
| Fachadas procedurales de edificios sin sprite (ya existian) | `arena.gd` `Building` | Sprites de edificios |

## REWORK DE ASSETS (pendiente, el dueño trae assets mejores desde su equipo local)
Estos usan pixel art que ya estaba en el repo, pero el dueño los considera **viejos** (13 nov 2026): hay que sustituirlos por assets mejores. El codigo ya los dibuja por recorte de hoja, asi que el cambio es poner el sprite nuevo y ajustar la constante de recorte. Incluye tambien la tabla de placeholders de arriba y los edificios de `assets/pixel/village/` si se quiere un estilo unico.

| Que | Hoja actual | Donde se cambia |
|---|---|---|
| Bancos (tronco caido) | `assets/tiles/bosque/bosque_props.png` | `city_prop.gd` `REGION_LOG`, kind `bench` |
| Maceteros (arbusto de bayas) | `bosque_props.png` | `REGION_BERRY_BUSH`, kind `planter` |
| Parterres de flores | `bosque_props.png` | `REGION_FLOWERS`, kind `flowerbed` |
| Carreta de mercader | `assets/props/campamento/props_campamento.png` | `REGION_WAGON`, kind `wagon` |
| Hoguera de descanso | `assets/props/campamento/prop_fogata_anim.png` | `arena.gd` constante `CAMPFIRE`, caso `campfire` de `InteractableActor` |
| Barriles y cajas de la ciudad | `assets/pixel/village/` | `terrain_renderer.gd` `_spawn_decor` |

## Hoy usan pixel art del repo (ver el rework de arriba)
| Que | Hoja | Recorte |
|---|---|---|
| Bancos de la plaza = tronco caido | `assets/tiles/bosque/bosque_props.png` | `tronco_caido` (`bosque_tileset.json`) |
| Maceteros = arbusto de bayas | `bosque_props.png` | `arbusto_bayas` |
| Parterres de flores | `bosque_props.png` | `flores_blancas/moradas/rosas/amarillas` |
| Carreta de mercader | `assets/props/campamento/props_campamento.png` | carreta (104,2,32,22) |
| Hoguera de descanso animada (pisos 2-10) | `assets/props/campamento/prop_fogata_anim.png` | 4 fotogramas de 16x18 |
| Barriles y cajas | `assets/pixel/village/` | `barrel.png`, `crate.png` |
| Residentes | LPC (`assets/pixel/lpc/`) | placas, yelmo barbuta, capucha, capa, cota, cuero |

## Otras cosas construidas en esta ronda (registro)
- Tutorial por pistas (`data/tutorial.json`, `game/ui/tutorial_hints.gd`, panel en `hud.gd`): usa `UiStyle.draw_panel`, sin arte propio.
- Hogueras de descanso, residentes, props de ciudad: ver `DECISIONES.md` ("Ciudad con vida...").
- Curva de XP y bot sin mapa: ver `DECISIONES.md` ("Ritmo de niveles y bot sin mapa").

## Enemigos nuevos con sprite provisional (13 nov 2026, roadmap 1.2)
Mientras no lleguen los assets locales del dueño, los 5 enemigos nuevos reutilizan sprites del repo (tintados o recompuestos). Al llegar los assets propios, solo hay que cambiar el bloque `sprite` del enemigo en el JSON (`data/enemies/tier1.json` o `bandits.json`); no hace falta tocar codigo.

| Enemigo | Sprite provisional | Que asset hace falta |
|---|---|---|
| Cuervo carroñero (`carrion_crow`) | `spritepilot_creatures/32px/bird` tintado gris-violeta | Cuervo/ave negra animada (vuelo 4-8 fotogramas, picado, muerte), ~32 px |
| Limo ácido (`acid_slime`) | `spritepilot_creatures/32px/slime` tintado verde | Limo verde con burbujas, idle/ataque/muerte, ~32 px |
| Bruto del Cuervo (`bandit_brute`) | LPC recompuesto (camiseta sin mangas, maza), escala 1.2 | Sprite de bandido corpulento (hombros anchos, mazo grande) en estilo LPC o equivalente |
| Zapador del Cuervo (`bandit_sapper`) | LPC recompuesto (capucha, daga) | Bandido con mochila de bombas/pólvora y abrojos |
| Chamán del Cuervo (`bandit_shaman`) | LPC recompuesto (capucha, capa, baculo) | Chamana con plumas/huesos y bastón, animacion de conjuro |
| Efectos: charco de veneno, abrojos/fuego, escudo de apoyo | `game/world/zone_actor.gd` (paquete de efectos del repo) | FX propios: nube de veneno, abrojos en el suelo, burbuja de escudo sobre aliados |
| Sonidos de los enemigos nuevos (graznido, chapoteo, bomba, conjuro) | ninguno (sin audio especifico) | SFX por enemigo en `assets/audio/sfx/` |

## Interfaz y herramientas (pendiente de assets o decisiones del dueño)
| Que | Estado | Que hace falta |
|---|---|---|
| Hoja de personaje (tecla C) | Aun con el pergamino CraftPix, desentona | Marco/ranuras de equipo en el estilo Dragon Regalia o un panel nuevo |
| Iconos de recursos, estados sociales y estrellas | Disponibles en `assets/pixel/ui/ts_kit/icons`, sin usar en pantalla | Solo integrarlos (no necesitan asset nuevo) |
| Nombres de habilidades en ingles | Sin traducir | Decision del dueño (traducir todo o conservar nombres propios) |
| Contador de FPS (F3) | Texto simple | Opcional: fuente/estilo propio |

## Torre viva (14 nov 2026): objetos nuevos con arte provisional
| Que | Estado actual | Que asset hace falta |
|---|---|---|
| Fango y pinchos del suelo | Dibujados en codigo (`zone_actor.gd` `_draw_procedural`) | Sprites de charco de barro y de trampa de pinchos (con 2-3 fotogramas) |
| Charco venenoso / fuego de aceite | Efectos del paquete de FX del repo (poison-cloud, ground-flames) | FX propios si se quiere un estilo unico |
| Barriles (explosivo y de aceite) | `assets/pixel/village/barrel.png` tintado | Barril con marcas de pólvora (rojo/negro) y barril de aceite (con goteo); animacion de rotura/explosion |
| Cofres de madera, hierro y dorado | Dibujados en codigo (`arena.gd` `InteractableActor`) | 3 cofres ~24x20 px, cerrado/abierto |
| Camara sellada | Cofre dorado grande dibujado en codigo | Puerta o relicario sellado con cerradura |
| Llave oxidada | Dibujada en codigo | Icono/sprite de llave ~12x16 px con brillo |
| Notas de lore | Icono `ts_kit/icons/res_skill_book.png` | Pergamino o diario en el suelo ~16x16 px |
| Pedestal de eventos | Dibujado en codigo (pedestal con llama) | Altar o pedestal pequeno con llama, 2 variantes (bueno/arriesgado) |
| Etiqueta de afijo de elite | Texto sobre el enemigo | Icono por afijo (rayo, escudo, bomba, gota) |
| Oscuridad del piso | Shader de viñeta | Luces suaves alrededor de fogatas/antorchas (sprites de brillo) |
| Sonidos: explosion, cofre, llave, pergamino, pinchos, fango | Ninguno | SFX correspondientes en `assets/audio/sfx/` |

## Campamentos y comportamientos (14 nov 2026)
| Que | Estado actual | Que asset hace falta |
|---|---|---|
| Tiendas, fogata, cajas, barriles, sacos, camastros, armero, estandarte, atalaya de los campamentos | `assets/props/campamento/props_campamento.png` y `prop_fogata_anim.png` (pack del dueño) | Mas variantes (tienda grande de mando, empalizada, mesa de mapas, cocina, granja/huerto, corral) |
| Produccion de los campamentos (granja, forja, almacen de comida) | No existe aun | Sprites de huerto, forja con yunque, almacen de grano, mesa de cocina |
| Enemigos durmiendo | Sprite normal de pie + texto "z z" | Pose o animacion de dormido (tumbado en el camastro) y de patrulla (marcha lenta) |
| Alerta del campamento | Sin efecto visual | Icono "!" y/o cuerno/campana al dar la alarma |
