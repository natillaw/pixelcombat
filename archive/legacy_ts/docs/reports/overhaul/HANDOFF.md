# Handoff del overhaul LPC

**Fase actual: 6 hecha (UI B, packs, interiores); 7 a medias.** Ver "Siguiente" al final.

Hecho:
- Fase 0: `.gdignore` y `.gitignore` para `assets/nuevos assets/` (sacados del índice), prompt viejo marcado SUSTITUIDO, inventario `USO_ASSETS_ANTES.md`, fixture de 200 semillas (`tests/test_hero_fixture.gd`), línea base `BASELINE.md` (25 suites en verde).
- Fase 1: LPC clonado en `../_vendor/lpc` (commit `86160e7`), `docs/specs/LPC_FORMAT.md` (formato, animaciones, razas, rejillas de packs), `escala.png` (`tools/overhaul_scale_shot.gd`), `ui_ab.png` (`tools/overhaul_ui_ab.gd`).

Puertas abiertas (no seguir sin respuesta):
1. Escala D-B: ¿rejilla lógica de 32 px con todo el arte a ×1 (los tiles de 16 px se colocan 2×2 por celda), o tiles de 16 px escalados ×2 como dice el prompt? Ver `escala.png`.
2. Estilo de UI: A (Dragon Regalia, actual) o B (CraftPix basic UI). Ver `ui_ab.png`.
3. Pesos humano/elfo (propuesta 80/20).

Siguiente paso exacto: con las respuestas, registrar D-072..D-078 (D-A..D-G) en `DECISIONS.md` y empezar la fase 2 (`tools/import_lpc.py` con recoloreo por paletas → `assets/pixel/lpc/`).

Fase 2 (hecha): `tools/lpc_manifest.json` + `tools/import_lpc.py` (recoloreo por paletas con numpy/Pillow) → `assets/pixel/lpc/`; `scripts/core/lpc_composer.gd` (`visual_layers`, `compose_anim`, `build_frames_for`, `pose_texture_for`, caché); `scripts/data/lpc_wardrobe.gd` (`STARTER_OUTFIT`, `STARTER_WEAPON_BY_CLASS`, `random_look`); `tests/smoke_lpc.gd` (ALL PASSED) y `tira_heroe.png`.
Pendiente técnico: armas con frames sobredimensionados (slash_128, thrust_oversize) no se importan aún; las animaciones que falten en un arma usan su hoja de walk.

Siguiente paso exacto (fase 3): `HeroGenerator.VERSION = 4` con `appearance_lpc` desde `hero_seed ^ 0x4C5043` y la raza por pesos de `SummonConfig`; migración de guardado (v13) que guarda `appearance_legacy`; cambiar a `LpcComposer` todos los llamadores de `SpriteComposer` (retrato, tarjeta, reveal, ficha, panel, party, roster, pueblo y sandbox con `HeroAnim` en 4 direcciones).

Fase 3 (hecha): generador v4 (`HeroGenerator.lpc_look`), `HeroData.look`, guardado v13 con migración (roster y memorial), `SpriteComposer` delega en `LpcComposer` (`uses_lpc`, `feet_offset`, `face_region`, `build_frames_legacy` con los nombres viejos de animación). Capturas en `docs/reports/overhaul/fase3/`.
Pendiente: `HeroAnim` en 4 direcciones reales (hoy los alias usan izquierda/derecha para atacar y caer), el ataque por arma (`ItemDefs.BASES[*].attack_anim`), la tarjeta del pueblo y del título se ven con LPC pero sin revisar en detalle.

Fase 4 (hecha): piezas bandidas importadas (pañuelo, capucha, capa, cuero, placas, cascos, parche, hacha, maza, bastones, mandoble), `scripts/data/lpc_factions.gd`, `BanditArt` reescrito sobre LPC (misma interfaz, 4 caras por tipo), test de facción en `smoke_bandits`.
Pendiente: armas con frames sobredimensionados (el bastón de cristal y el mandoble solo tienen walk/hurt a 64 px); las animaciones de enemigo usan la fila derecha y `hurt` como muerte.

Fase 5 (hecha): `tools/lpc_catalog.py` → `assets/pixel/lpc/wardrobe_catalog.json` (408 piezas con slot, material, variantes, animaciones, licencia, autores) y hojas `docs/reports/overhaul/vestuario/<slot>.png`; `tools/lpc_races_sheet.py` → `razas.png` (23 cabezas); `scripts/data/lpc_races.gd` (10 arquetipos, sin stats ni pisos); `scripts/data/item_visuals.gd` (base → pieza LPC, color de metal por nivel de ítem: cobre, hierro, acero, plata, oro); el equipo se ve en el héroe (`SpriteComposer` pasa `ItemVisuals.equipment_layers`). Test en `smoke_lpc`.
Pendiente: escudos, anillos, amuletos y trinkets solo con ícono; armas sobredimensionadas.

Fase 6 (hecha): `tools/import_packs.py` (50+ packs, licencias en `ASSET_REGISTRY.json`), tema UI B (madera, pergamino, botones verdes; `UIKit.piece`), paleta de UI en madera.
Edificios entrables (pedido del dueño): `tools/bake_tmx.py` hornea los mapas Tiled de los packs (taller con forja, capilla, guild hall 2 pisos, casa, templo, mazmorra) a `assets/pixel/interiors/`, más edificios sueltos `bld_*` para el pueblo. `BuildingInterior` (click en un edificio construido): la sala a ×2 frente a los héroes, los héroes asignados en sus puestos, arrastrar para mirar; sin trabajadores el panel avisa y no se produce nada. `InteriorDefs` mapea edificio → interior y exterior.
Pueblo (fase 7, parcial): suelo con el tileset de bosque del dueño (caminos de tierra orgánicos, clusters, anillo de árboles); edificios de los packs a ×1.

## Siguiente (en orden)
1. **Escala del mundo ×2 frente a los personajes (revisión de D-072):** pueblo, pisos y Wilds. Pasar de imagen horneada a `TileMapLayer` (tiles de 16 px en un nodo a escala 2) y doblar las celdas lógicas o el tamaño del mapa; ajustar en datos radios, alcances, velocidades y percepción para que el balance en celdas no cambie (test de distancias). Los edificios `bld_*` a ×2 → parcelas del pueblo más grandes (`TownTables` plot ×2) y mapa del pueblo más grande.
2. **Profesiones estilo WoW** (pedido del dueño): ventana de recetas por edificio/profesión: lista por categorías a la izquierda con color de dificultad (naranja/amarillo/verde/gris según nivel del artesano), detalle a la derecha con materiales tengo/necesito, cantidad y botón Crear; requiere trabajador asignado.
3. **Biblioteca de ítems (D-077):** tiers por material, slot trinket, rarezas con único, afijos buenos y malos, drops temáticos por enemigo vs línea del herrero, joyero, sets del herrero, únicos por misión secreta, consumibles, requisitos de nivel y clase, íconos emparejados (packs de íconos ya importados en `assets/pixel/packs/icons_*`, `willibab`, `rpg_icons`).
4. Pisos y Wilds con mezcla de packs (árboles, rocas, arbustos, objetos de CraftPix junto al tileset del dueño).
5. Fase 8 (pulido: luces, viento, copas translúcidas, partículas, viñeta, opciones de calidad) y fase 9 (borrar lo huérfano: aprobado por el dueño salvo los PNG de Caz; créditos; informe).

## Pase de beta (2026-11-01)
Hecho y probado (30 suites ALL PASSED, ningún error de script en 8 partidas completas del bot):
- Bugs del juego encontrados por el bot de partida completa y corregidos: las oleadas de defensa nunca salían (piso 3 se ganaba sin pelear); un escuadrón del tamaño del piso se trataba como "de prueba" (pisos de 1 héroe no guardaban nada); el dash con el cursor sobre el héroe no hacía nada.
- Red de seguridad: si quedan menos de 5 héroes, cada mañana llega un recluta 1★ (permadeath se mantiene, la cuenta nunca se bloquea).
- Balance: tutorial más suave (amenaza 14), piso 3 con oleadas que crecen despacio (tope 6), Wilds tier 1 ×1,4 de daño, XP de las Wilds ×0,7.
- Mundo: árboles, arbustos y rocas de CraftPix mezclados en los pisos; pueblo y personajes a ×2; animaciones de ataque, guardia y caída en 4 direcciones.
- Pulido: luces de fogatas y altar, hojas y luciérnagas, viñeta; opción "Efectos visuales" (apagado/bajo/alto).
- Español por defecto (`StringsEs`, botón Español/English en Opciones); textos compuestos traducidos por trozos.
- Limpieza: capas TPF de bandidos borradas.
- Herrería solo para herreros, con aprendices y aptitud oculta por oficio (D-078, guardado v15): `AptitudeDefs` (tiers, multiplicadores, eventos, todo en datos), `TownSim._apprentices`, nota "talento ???" en el panel del pueblo.
- El dash, si choca de frente con un muro, se desliza en diagonal (antes no hacía nada; test de Space a veces fallaba en Wilds aleatorias).

Pendiente para la beta:
- **Economía del pueblo → progresión:** en la partida del bot, el pueblo no llega a producir equipo (madera y grano se agotan, la herrería se construye tarde o nunca, el herrero novato sube despacio), así que el piso 5 es un muro con héroes nivel 1-2 sin gear. Hay que afinar la economía para que un jugador que usa el pueblo llegue equipado al piso 5 (área de la sesión de ítems/crafteo), y mejorar la IA de pueblo del bot.
- Pisos 5-10 sin verificar en partida completa (se verificaron por separado en la matriz).
- Armas LPC sobredimensionadas (tajos grandes), textos con números que no pasan por UIKit (algunos tooltips) sin traducir.
- Partida de prueba humana.
