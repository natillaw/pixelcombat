# PROMPT MAESTRO — Overhaul gráfico completo: LPC para todos los personajes + nuevos assets para el mundo, la UI y los íconos

> Para Claude Code, en el repo `tactical-summoners`. **Sustituye** a `docs/design/PROMPT_LPC_HEROES.md`; márcalo como SUSTITUIDO al empezar.
> El dueño aprobó este overhaul el 2026-10-31. Este prompt es la autorización para sustituir las decisiones de arte que se listan en §2. Todo lo demás sigue rigiéndose por `AGENTS.md` y `docs/DECISIONS.md`.
> Es un trabajo grande: hazlo **por fases**. Al final de cada fase el juego tiene que arrancar, pasar las suites y tener capturas. Las **puertas** (🚪) son paradas obligatorias para que el dueño apruebe antes de seguir.

---

## 0. Objetivo

1. **Todos los personajes humanoides salen de LPC** (Liberated Pixel Cup, capas de 64 px):
   - Héroes: humanos y elfos.
   - Bandidos: humanos con atuendo propio que los distingue perfectamente.
   - Razas enemigas: orcos, no muertos y todas las demás que tenga LPC.
2. **Los héroes recién invocados llevan todos la misma ropa sencilla.** Las demás piezas de LPC se catalogan para que las muestren los ítems equipados.
3. **Rehacer el mundo, los props, los íconos, los fondos y la UI** con los packs de `assets/nuevos assets/`, más los que ya están en el repo, con una escala y un estilo coherentes con LPC.
4. Añadir una **capa de pulido visual**: luces, viento, sombras, partículas y unificación de paleta.

## 1. Contexto obligatorio (lee solo esto)

1. `CLAUDE.md` y `AGENTS.md`.
2. `docs/DECISIONS.md`: D-004, D-007, D-008, D-011, D-020, D-021, D-023, D-024, D-039, D-055, D-057, D-058, D-060, D-070 y el "Master prompt H".
3. `docs/specs/ART_DIRECTION.md`, `docs/specs/ITEMS_AND_LOOT.md` §1 y `docs/ASSET_REGISTRY.md`.
4. Código de arte actual:
   - Personajes: `scripts/core/sprite_composer.gd`, `scripts/core/hero_generator.gd`, `scripts/sandbox/hero_anim.gd`, `scripts/data/bandit_art.gd`, `scripts/sandbox/enemy_sprites.gd`, `scripts/data/enemy_defs.gd`.
   - Mundo: `scripts/sandbox/caz_art.gd`, `bosque_art.gd`, `forest_art.gd`, `map_tiles.gd`, `proc_art.gd`, `scripts/core/procedural_map.gd`.
   - Efectos e íconos: `scripts/sandbox/combat_vfx.gd`, `scripts/data/item_icons.gd`, `skill_icons.gd`, `art_palette.gd`, `asset_catalog.gd`.
   - UI: `scripts/ui/ui_kit.gd` y todos los `scripts/ui/*.gd` que dibujan héroes o íconos.
5. `docs/design/PROMPT_LPC_HEROES.md`: tiene el detalle de los héroes; este prompt lo resume y lo amplía.
6. Ejecuta `tools\Run-Tests.ps1` y guarda la **línea base**. No rompas suites; si una ya fallaba, anótalo.
7. Haz un **inventario de uso** antes de cambiar nada: con grep, lista qué script usa qué asset (`AssetCatalog.*`, rutas `res://assets/...`). Guárdalo en `docs/reports/overhaul/USO_ASSETS_ANTES.md`. Sirve para saber qué se reemplaza y qué queda huérfano.

## 2. Decisiones nuevas (regístralas como D-07x en `docs/DECISIONS.md`)

- **D-A: Personajes en LPC.**
  - Sustituye D-023 para héroes y el "Master prompt H" (ya no todo humano es TPF).
  - Sustituye D-070 en cuanto al arte del Barón.
  - Los PNG de Caz **no se borran ni se modifican**. Quedan sin uso y se anotan como obsoletos en el registro.
- **D-B: Escala del mundo.**
  - LPC está pensado para tiles de 32 px. La rejilla base del mundo pasa a **32 px**.
  - Los personajes LPC se dibujan a escala 1 (frame de 64 px).
  - Los packs de CraftPix se usan a escala 1 si su rejilla es de 32 px.
  - Los packs de 16 px se reemplazan, o se escalan ×2 **de forma entera** solo si no hay reemplazo.
  - Nunca escalado no entero.
  - Sustituye la referencia de escala de D-055 por el alto medido del humano LPC.
  - 🚪 Se confirma con capturas en la Fase 1.
- **D-C: Atuendo inicial único.** Todos los héroes invocados llevan el mismo `STARTER_OUTFIT`. La variedad está en raza, cuerpo, piel, pelo, ojos y vello facial. La rareza **no** añade sombreros ni armas: se expresa con el aura del retrato y los efectos de invocación.
- **D-D: Equipo visible.** Amplía D-021: el ítem equipado **reemplaza** la capa LPC de su slot. El aspecto base guardado nunca cambia.
- **D-E: Bandidos.** Son humanos LPC con un atuendo bandido fijo por tipo y un **color de facción único** (ver §6). Ningún héroe puede salir con ese color en la ropa inicial.
- **D-F: Razas.**
  - Héroes: humano y elfo (pesos en datos, en `SummonConfig`).
  - Enemigos: todas las razas no humanas de LPC que pasen los filtros (§3).
  - Las razas enemigas no cambian el roster decidido de los pisos 1–10 (solo bandidos y algún animal). Quedan en el catálogo para pisos futuros.
- **D-G: Licencias.**
  - LPC: solo CC0, CC-BY, OGA-BY o CC-BY-SA (incluidas las duales con GPL). Las que solo sean GPL quedan fuera.
  - Packs nuevos: según §4.

Actualiza también `docs/specs/ART_DIRECTION.md` (nueva sección "Overhaul LPC") y `ITEMS_AND_LOOT.md` §1.

## 3. LPC: fuente e importación

- Repo oficial: <https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator>. Clónalo **fuera del proyecto** (`../_vendor/lpc`) y anota el hash del commit.
- `assets/nuevos assets/CharGen_v0.9.3.zip` es la app de escritorio de pflat (exe + `.pak`). **No se importa:** sirve como herramienta de vista previa para el dueño. La fuente de assets es el repo de GitHub.
- **No adivines la estructura.** Inspecciona `README`, `sheet_definitions/`, `spritesheets/` y `CREDITS.csv`, y escribe `docs/specs/LPC_FORMAT.md` con:
  - Tamaño de frame y orden de filas y animaciones.
  - Frames por animación.
  - `zPos`.
  - Tipos de cuerpo.
  - Armas con frames sobredimensionados.
  - Cómo se combinan cabezas, orejas y cuerpos por raza.
- Importador reproducible (`tools/import_lpc.gd` o `.py`) hacia `assets/pixel/lpc/`, que copie **solo lo usado**, más `CREDITS.csv` filtrado y un registro en `docs/ASSET_REGISTRY.md` y `assets/CREDITS.md`.
- Filtros:
  - Licencia según D-G.
  - Cuerpos **adultos** solamente (fuera `child`, `teen`, `pregnant`).
  - La pieza tiene al menos walk, slash o thrust, spellcast, shoot y hurt.
- **Razas:** enumera desde `sheet_definitions` todas las cabezas y cuerpos no humanos (orco, esqueleto, zombi, goblin, lobo, lagarto, minotauro, etc., **los que existan de verdad**) y las orejas de elfo. Escribe la tabla en `LPC_FORMAT.md` con su licencia y las animaciones disponibles. No inventes razas.
- Animaciones (mapa en datos, en 4 direcciones): idle, combat_idle, walk, run, attack_slash, attack_thrust, attack_shoot, cast, hurt, death.
  - Si falta idle o run, se resuelve igual que en `PROMPT_LPC_HEROES.md` §4, y se cae al equivalente **para todas las capas a la vez**.
  - `HeroAnim` se conserva (tweens, dash, roll, pánico, flash) y pasa a 4 direcciones reales.
  - Qué ataque usa cada arma va en `ItemDefs.BASES[*].attack_anim`.

## 4. Packs nuevos: triaje y licencias (`assets/nuevos assets/`)

Primero, `assets/nuevos assets/` tiene que ignorarse en Godot y en git: añade un `.gdignore` y la carpeta a `.gitignore`. **No se suben zips crudos.** Al repo solo entra lo usado, procesado por script en `assets/pixel/...` o `assets/processed/...`.

| Grupo | Archivos | Licencia | Veredicto |
|---|---|---|---|
| Duplicados | Todos los `* (1).zip` | — | **Ignorar** (son copias idénticas; compruébalo por hash) |
| CraftPix (unos 60 zips `craftpix-*`) | Ver la tabla de uso de abajo | Lee el `License.txt` de **cada** zip y regístralo. Lo habitual en freebies: uso comercial sí, redistribuir el pack no | Usar según el plan de abajo |
| Willibab armor icons | `CHESTS.png`, `HELMS.png`, `SHIELDS.png` | Gratis comercial ([página](https://willibab.itch.io/willibabs-simple-32x32-armor-icons)) | **Usar**: íconos de cascos, pechos y escudos (875 variantes de color) |
| Sin licencia en el archivo | `RPG Icons.zip` (Icon1..N), `Armor[16x16].zip` (`Free.png`), `32x32_PixelWeapons_Free.png` | Desconocida | **No usar** hasta encontrar el autor y la licencia. Pregunta al dueño de dónde salieron |
| Ciencia ficción | `craftpix-881716-free-pixel-art-sci-fi-icons-pack` | — | **Descartar** (no encaja con el mundo) |
| CharGen | `CharGen_v0.9.3.zip` | — | No importar (ver §3) |

**Plan de uso de CraftPix** (verifica cada uno abriendo su contenido y midiendo la rejilla):

- **Bosque (pisos 1–10):**
  - Árboles: `free-tree-pixel-art-asset-pack`, `free-top-down-trees-pixel-art`.
  - Arbustos: `free-top-down-bushes`.
  - Objetos: `free-forest-objects-top-down`.
  - Rocas: `free-rocks`, `free-rocks-and-stones`, `free-rocky-area-objects`.
  - Caminos: `free-path-and-road-top-down-tileset`.
  - Puentes: `free-bridges-top-down`.
  - Plantas: `free-pixel-art-plants-for-farm`.
- **Campamento bandido:** objetos del bosque y de mazmorra, más lo que ya hay en `assets/props/campamento/`.
- **Pueblo / base:**
  - Edificios: `free-fantasy-medieval-village-buildings`, `free-village-pixel-tileset-for-top-down-defense`.
  - Locaciones: `free-top-down-pixel-art-guild-hall` (edificio de invocación o cuartel), `main-characters-home`, `free-glassblowers-workshop` (profesiones), `free-chapel`.
- **Mazmorras y pisos futuros:**
  - Mazmorras: `free-2d-top-down-pixel-dungeon`, `free-pixel-art-dungeon-objects`, `free-pixel-dungeon-props-and-objects`.
  - Cuevas: `free-top-down-pixel-art-cave-objects`, `top-down-crystals`.
  - Ruinas y templos: `free-top-down-ruins`, `free-ruined-temple`.
  - No muertos: `free-undead-tileset`, `free-cursed-land-tileset`.
  - Agua: `free-top-down-seabed-objects`.
- **Criaturas no humanoides** (los humanoides vienen de LPC):
  - `free-slime-mobs`, `free-predator-plant-mobs`, `free-top-down-hunt-animals`, `free-top-down-animals-farm`.
  - `free-top-down-orc-game-character` y `free-vampire-4-direction` **solo si** no hay un equivalente LPC mejor. Si se usan, normalízalos con `tools/art_cohesion.gd` y su clase de tamaño.
- **Íconos de ítems:**
  - Botín: `free-rpg-loot-icons`, `free-40-loot-icons`, `free-goblin-loot-icons`, `free-undead-loot-icons`.
  - Armas: `32x32-pixel-art-weapons`, `free-bow-and-crossbow-icons`.
  - Equipo: `free-clothing-32x32-icons`, `free-shield-and-amulet-icons`, `free-belt-rpg-icons`.
  - Materiales: `free-minerals-icons`, `free-pixel-art-icons-for-mine-location`, `free-paint-pixel-art-icon-pack`.
  - Más los de Willibab.
- **Íconos de habilidad:** `free-swordsman-skills-pixel-art-icons`, `free-paladin-pixel-art-skill-icons`, junto con kurai (ya en uso).
- **Íconos de UI:** `free-basic-pixel-art-fantasy-icons-16x16-for-ui`.
- **Fondos** (título, invocación, carga, resultados; parallax):
  - `free-summer-pixel-art-backgrounds`, `free-sky-with-clouds`, `ocean-and-clouds`, `free-nature-backgrounds`.
  - `free-pixel-art-fantasy-2d-battlegrounds` (vista lateral: **solo para pantallas de menú**, nunca en el mapa top-down).
- **Efectos:** `free-animated-magic-book` (pantalla de invocación y conjuros), más SpritePilot y KILN (ya en uso).
- **Temporada:** `free-halloween-icons` → catálogo de eventos; no se usa aún.
- **UI:** `free-basic-pixel-art-ui-for-rpg` **compite** con Dragon Regalia (en uso). 🚪 Haz una captura de la misma pantalla con cada uno y que el dueño elija **uno solo**. No se mezclan dos estilos de UI.

Para cada pack: licencia → `assets/ASSET_REGISTRY.json` (con `tools/Import-Asset.ps1`, ampliándolo si hace falta) → `CREDITS.md` → `docs/ASSET_REGISTRY.md`. La pantalla de **Créditos** del juego se genera desde el registro y debe incluir a todos los autores de LPC.

## 5. Héroes (resumen de `PROMPT_LPC_HEROES.md`, que sigue valiendo en el detalle)

- **`STARTER_OUTFIT`** (en `scripts/data/lpc_wardrobe.gd`):
  - Camisa o túnica de manga larga en tono neutro, pantalón marrón sencillo, botas o zapatos de cuero básicos y un cinturón simple si existe.
  - Sin casco, capa, guantes ni armadura.
  - Tiene que existir para **todos** los cuerpos y razas de héroe, con todas las animaciones.
  - No puede usar el color de facción bandido.
- **Arma visual por clase** (`STARTER_WEAPON_BY_CLASS`), solo visual y sin stats: daga, espada corta, bastón, arco. La reemplaza el arma equipada.
- **Raza:** humano o elfo con pesos en `SummonConfig` (propuesta: 80/20). Los elfos llevan orejas de elfo LPC y, si existen, rasgos propios (tonos de piel o pelo). 🚪 Confirmar los pesos.
- **Generador v4** (`HeroGenerator.VERSION = 4`):
  - Aspecto LPC con RNG propio (`hero_seed ^ 0x4C5043`), **sin** cambiar el nombre, la clase, los rasgos, las pasivas ni el Trust de semillas viejas.
  - Fixture con 200 semillas **antes** de tocar nada.
- **Migración** (sube `SAVE_VERSION`): los héroes TPF pasan a LPC de forma determinista y conservan `appearance_legacy`. Incluye a los del memorial.
- **`LpcComposer`** con la misma API pública que `SpriteComposer` (`FRAME`, `pose_texture`, `build_frames`, `clear_cache`), más `visual_layers(actor, equipment)` y caché por (actor, hash del equipo).
  - Se cambian a él todos los llamadores de héroes: retrato, tarjeta, reveal de invocación, ficha, panel, party, roster, pueblo y sandbox.

## 6. Bandidos y Barón

- `scripts/data/lpc_factions.gd → BANDIT`:
  - Un **color de facción** (propuesta: rojo carmesí apagado en pañuelos, capuchas o fajas, más cuero oscuro).
  - Un atuendo LPC fijo **por tipo** de bandido de `EnemyDefs.BANDITS`. Ejemplo:
    - Explorador: capucha, cuero ligero y daga.
    - Bruto: torso descubierto o cuero pesado, y hacha.
    - Arquero: capucha y arco.
    - Mago bandido: túnica oscura con faja carmesí y bastón.
  - Variedad solo en cuerpo, piel, pelo y barba. El atuendo y el color no varían dentro de un tipo.
- **Barón Carmesí** (jefe del piso 10):
  - LPC con la armadura más imponente del catálogo, capa y arma grande, en el color de facción con detalles dorados.
  - Tiene que ser **más grande y temible** que un bandido. Opciones:
    1. Hoja LPC ×2 de forma entera, como hoy (D-070).
    2. Escala 1 con aura y FX.
  - 🚪 Captura de las dos opciones; decide el dueño.
- Sustituye `BanditArt` (TPF) por la versión LPC con la misma interfaz que usa `EnemySprites`. El preset JSON viejo se conserva sin uso.
- Test: **ningún** héroe (en 1000 semillas) usa el color de facción en su ropa inicial, y todo bandido sí lo usa.

## 7. Razas enemigas (catálogo para pisos futuros)

- `scripts/data/lpc_races.gd`: por cada raza LPC disponible (§3), un arquetipo visual base con cabeza y cuerpo, más 2 o 3 atuendos (guerrero, arquero, chamán o lanzador).
- **No** se añaden a los pisos 1–10 ni se crean stats nuevos: van al catálogo y a una hoja de muestras (`docs/reports/overhaul/razas.png`) para que el dueño diseñe con ellas. Lo que cambie el balance o el roster es PENDIENTE: pregunta.

## 8. Catálogo de vestuario (para ítems)

- `assets/pixel/lpc/wardrobe_catalog.json`, generado por el importador y cargado por `lpc_wardrobe.gd`.
- Por pieza: `visual_id`, `slot`, `lpc_item`, `variants`, `material` (cloth, leather, chain, plate, other, unknown), `weight`, `body_types`, `races`, `anims`, `z`, `license`, `authors` y `tags`.
- Slots: `head`, `chest`, `hands`, `legs`, `feet`, `main_hand`, `off_hand`, más los visuales extra `back`, `belt`, `shoulders` y `neck`. Los extra **no** se añaden a `ItemDefs.SLOTS` sin preguntar.
- **Íconos ↔ visuales:** propone el emparejamiento de cada `visual_id` con un ícono de los packs (Willibab, CraftPix) por material y color, en `scripts/data/item_visuals.gd`. Ejemplo: casco de placas de acero en LPC con el casco gris de Willibab.
- Solo añade un `visual_id` opcional a los bases existentes de `ItemDefs.BASES`. **No** crees ítems, afijos ni stats (P-19 PENDIENTE).
- Hojas de muestras por slot en `docs/reports/overhaul/vestuario/<slot>.png`.

## 9. Mundo y escala (Fase 1 con puerta)

1. Mide la rejilla real de cada pack de entorno de CraftPix y anótala en `docs/specs/LPC_FORMAT.md` → "Rejillas de packs".
2. 🚪 **Captura de escala** antes de convertir nada. En la misma imagen:
   - Héroe LPC, bandido LPC y una criatura de CraftPix.
   - Un árbol, una roca y un edificio de CraftPix.
   - Un tile de camino.
   - La rejilla de 32 px.
   - Las alternativas.

   El dueño aprueba D-B o pide un ajuste.
3. Con la escala aprobada:
   - Rejilla base a 32 px en `procedural_map.gd`, `map_tiles.gd`, `nav_map.gd`, `fog_map.gd` y las vistas.
   - Ajusta colisiones, radios, alcances y velocidades **en los datos** (`CombatRules`, `EnemyDefs`), en proporción, para que el **balance no cambie**: las distancias en celdas siguen iguales.
   - Cámara y zoom con escalado entero.
4. **Tilesets:** genera por script los `TileSet` de bosque, pueblo y mazmorra desde los packs, con autotiling o terrenos para caminos y bordes. Reemplaza `CazArt`, `BosqueArt`, `ForestArt` y `MapTiles` (deja los viejos como fallback hasta que todo pase y luego elimínalos **preguntando**).
5. **Densidad de decoración:** el mapa no debe tener tiles de pasto vacíos. Dispersión por ruido con capas de suelo, detalle, props y copas por encima.

## 10. Capa de pulido visual (Fase final)

- `CanvasModulate` de ambiente por bioma y hora, y `PointLight2D` en fogatas, antorchas, hechizos, cristales y altar, con parpadeo.
- Shader de **viento** en pasto, arbustos y copas.
- **Copas** de árbol por encima de los personajes, que se vuelven semitransparentes cuando hay un héroe debajo.
- **Sombras** de contacto automáticas bajo personajes y props.
- Partículas por bioma: luciérnagas, hojas que caen, niebla con ruido, ceniza en el campamento.
- **Contorno** uniforme opcional para personajes, por shader, para separarlos del fondo.
- **Unificación de paleta**: shader o post-proceso que acerca los packs a una paleta común, aplicado a copias procesadas o en runtime, nunca a los originales.
- Viñeta y corrección de color suaves.
- Todo configurable en Opciones (calidad baja, media o alta) y sin tocar la legibilidad de telegraphs ni órdenes (ART_DIRECTION).

## 11. Fases y puertas

| Fase | Contenido | Puerta 🚪 |
|---|---|---|
| 0 | Línea base de tests, inventario de uso, fixture de semillas, `.gdignore` y `.gitignore` | — |
| 1 | LPC clonado, `LPC_FORMAT.md`, rejillas de packs, **captura de escala** y **captura UI A/B** | Escala (D-B), estilo de UI, pesos humano/elfo |
| 2 | Importador LPC, licencias, `LpcComposer`, `STARTER_OUTFIT`, armas iniciales, tira de animaciones | — |
| 3 | Generador v4, migración y todas las pantallas de héroe en LPC | — |
| 4 | Bandidos y Barón en LPC | Tamaño del Barón |
| 5 | Catálogo de vestuario, `item_visuals`, razas, hojas de muestras | Emparejamientos de `visual_id` con los bases |
| 6 | Triaje y registro de licencias de los packs; íconos, fondos y efectos nuevos | Packs sin licencia |
| 7 | Rejilla de 32 px, tilesets, mapas del bosque, pueblo y mazmorra, densidad | — |
| 8 | Capa de pulido visual | — |
| 9 | Limpieza (eliminar lo huérfano solo con permiso), créditos, documentación, informe | Borrados |

## 12. Pruebas (sin salida citada no hay PASS)

1. Las suites de siempre siguen pasando (compáralo con la línea base).
2. **Determinismo** del aspecto LPC en 1000 semillas, y **semillas viejas** intactas en 200 (fixture).
3. **Atuendo inicial** idéntico en 100 héroes y variedad en cuerpo, pelo, ojos y barba.
4. **Facción:** ningún héroe con color bandido; todos los bandidos con él.
5. **Catálogo:** archivos existentes, licencia válida, animaciones declaradas. Lista de avisos para piezas incompletas.
6. **Reemplazo por slot:** equipar y quitar cascos y pechos cambia y restaura capas.
7. **Migración** de una partida con la versión anterior (fixture).
8. **Balance intacto tras la rejilla de 32 px:** distancias de ataque, aggro y movimiento en celdas iguales a la línea base, y una simulación corta del piso 1 con resultados en el mismo rango.
9. **Smoke** de todas las escenas sin errores ni avisos de assets faltantes.
10. **Rendimiento:** FPS y memoria con 5 héroes, 10 bandidos y el mapa del bosque completo con pulido en "alta". Anota los números.

Capturas en `docs/reports/overhaul/`:

- Antes y después de título, invocación y reveal, pueblo, roster, ficha, inventario, bosque, campamento, combate, Barón y resultados.
- Tiras de animación de héroe, bandido y Barón.
- Escala, UI A/B, razas y vestuario.

## 13. Entrega

- Rama `feat/overhaul-lpc`. Commits pequeños que citen D-A a D-G y la fase. No hagas push a `main` ni merge.
- Actualiza `docs/IMPLEMENTATION_STATUS.md` (solo lo verificado), `docs/VERSIONS.md` (una entrada por fase con lo que hay que probar), `docs/ASSET_REGISTRY.md`, `assets/CREDITS.md`, `ART_DIRECTION.md`, `LPC_FORMAT.md` e `ITEMS_AND_LOOT.md`.
- Informe en `docs/reports/overhaul/OVERHAUL_REPORT.md`:
  - Qué cambió y comandos con su salida.
  - Qué quedó NO VERIFICADO.
  - Ids del `STARTER_OUTFIT`, de los atuendos bandidos y del Barón.
  - Razas disponibles y piezas del catálogo por slot y material.
  - Packs usados, descartados y pendientes de licencia.
  - Rendimiento medido.
  - Lista de **preguntas abiertas** para el dueño.
- Si la sesión se acaba a mitad, deja `docs/reports/overhaul/HANDOFF.md` con la fase actual, lo hecho, lo pendiente y el siguiente paso exacto.
