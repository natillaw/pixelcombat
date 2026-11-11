> **SUSTITUIDO (2026-10-31)** por `docs/design/PROMPT_OVERHAUL_GRAFICO_LPC.md` (overhaul gráfico LPC). Se conserva por el detalle de héroes.

# PROMPT — Rework completo del frontend de héroes a LPC (Liberated Pixel Cup)

> Para Claude Code, en el repo `tactical-summoners`. Léelo entero antes de tocar nada.
> El dueño aprobó este cambio el 2026-10-31. Este prompt es la autorización para sustituir las decisiones de arte de héroes que se listan abajo. Todo lo que no esté aquí sigue rigiéndose por `AGENTS.md` y `docs/DECISIONS.md`.

---

## 0. Objetivo en una frase

Reemplazar el arte de los héroes (Tiny Pixel Fantasy de Caz, 48 px) por personajes **LPC por capas (64 px)** con todas sus animaciones. **Todos los héroes recién invocados salen con la misma ropa sencilla**. Las demás piezas de LPC (armaduras, cascos, capas, guantes, botas, armas, escudos) se catalogan y guardan para que más adelante las muestren los **ítems equipados**.

## 1. Contexto obligatorio (lee solo esto, en este orden)

1. `CLAUDE.md` y `AGENTS.md`: reglas duras, evidencia, Git.
2. `docs/DECISIONS.md`: busca D-004, D-020, D-021, D-023, D-024, D-039, D-055, D-060, D-070 y el "Master prompt H" (todo humano se hace con TPF).
3. `docs/specs/ITEMS_AND_LOOT.md` (§1 Equipo) y `docs/specs/ART_DIRECTION.md` (§ Cohesión D-055).
4. Código actual de héroes:
   - `scripts/core/sprite_composer.gd`: composición TPF, `ANIMS`, `pose_texture`, `build_frames`.
   - `scripts/core/hero_generator.gd`: `_make_appearance`, `VERSION = 3`.
   - `scripts/sandbox/hero_anim.gd`: animaciones hechas por código (ataque, cast, hit, muerte).
   - `scripts/data/item_defs.gd`: `SLOTS`, `ACTIVE_SLOTS`, `BASES`.
   - `scripts/data/bandit_art.gd`: bandidos con capas TPF (**no se tocan en este trabajo**, ver §9).
   - Usuarios de `SpriteComposer` (búscalos con grep): `hero_portrait.gd`, `hero_card.gd`, `summon_reveal.gd`, `hero_sheet.gd`, `hero_info_panel.gd`, `party_slot.gd`, `roster_screen.gd`, `sandbox_hero.gd`, `town_hero.gd` y cualquier otro.
5. `docs/ASSET_REGISTRY.md` y `assets/CREDITS.md`: formato de registro de licencias.

## 2. Decisiones que este trabajo sustituye (regístralas)

Crea una entrada nueva en `docs/DECISIONS.md` (siguiente número libre, por ejemplo D-07x, título "Héroes en LPC") que diga:

- **SUSTITUYE parcialmente D-023:** los héroes dejan de usar los sprites de Caz. Los PNG de Caz **no se borran** (los usan los bandidos y el Barón) y siguen sin modificarse.
- **SUSTITUYE la referencia de escala de D-055:** la nueva referencia es el alto opaco medido del héroe LPC (mídelo con `tools/measure_scale.gd`) y se anota el número.
- **Amplía D-021:** la armadura equipada **reemplaza** la capa LPC del slot (nunca se dibuja encima de la ropa inicial del mismo slot). El aspecto base guardado nunca cambia.
- **Nueva regla:** al invocar, todos los héroes llevan el **mismo atuendo inicial**. La variedad visual viene del cuerpo, el tono de piel, el pelo, los ojos y el vello facial, más el aura de rareza del retrato. La rareza **ya no** se expresa con sombreros ni armas.
- **Licencias:** solo piezas LPC con CC0, CC-BY, OGA-BY o CC-BY-SA (incluidas las duales CC-BY-SA/GPL). Las que solo sean GPL quedan fuera.

Marca también en `docs/specs/ITEMS_AND_LOOT.md` §1 que la lista de capas disponibles ahora es el catálogo LPC (§6).

## 3. Fuente de los assets

- Repo oficial: <https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator>
- Generador web (solo para mirar): <https://liberatedpixelcup.github.io/Universal-LPC-Spritesheet-Character-Generator/>

Reglas de importación:

1. Clona el repo **fuera del proyecto** (por ejemplo `../_vendor/lpc`) y fija el commit. Anota el hash en `docs/ASSET_REGISTRY.md`.
2. **No adivines la estructura.** Antes de escribir código, inspecciona `README`, `sheet_definitions/` (JSON por pieza: capas, `zPos`, variantes, tipos de cuerpo, animaciones soportadas), `spritesheets/` y `CREDITS.csv`. Escribe lo que encuentres en `docs/specs/LPC_FORMAT.md`: tamaño de frame, orden de filas y animaciones, frames por animación, armas con frames sobredimensionados y cómo se resuelve el `zPos`. Todo el código posterior se basa en ese documento.
3. Copia al proyecto **solo lo necesario**, con un script reproducible: `tools/import_lpc.gd` (headless) o `tools/import_lpc.py`. Destino: `assets/pixel/lpc/` con la misma estructura de carpetas del repo para las piezas elegidas. Copia `CREDITS.csv` filtrado a esas piezas.
4. Filtros del importador:
   - Licencia en la lista blanca de §2.
   - Tipos de cuerpo **adultos**: `male`, `female` y, si existe, `muscular`. Se excluyen `child`, `teen` y `pregnant`.
   - Cabezas y cuerpos **humanos** para héroes. Las cabezas no humanas (orco, esqueleto, lobo, etc.) se catalogan con la etiqueta `creature`, pero no se importan aún.
   - La pieza debe tener al menos las animaciones base: walk, slash o thrust, spellcast, shoot, hurt.
5. Todo lo importado se registra en `docs/ASSET_REGISTRY.md` (fuente, commit, licencias) y `assets/CREDITS.md` (autores, generado desde `CREDITS.csv`).
6. Después: `godot --headless --path . --import`.

## 4. Animaciones: mapa de estados del juego

Construye la tabla en datos (`scripts/data/lpc_anims.gd` o dentro del composer) a partir de `docs/specs/LPC_FORMAT.md`. Estados mínimos, en 4 direcciones:

| Estado del juego | Animación LPC | Notas |
|---|---|---|
| idle | idle (si la pieza la tiene) o el frame 0 de walk | Si falta en alguna capa, cae al frame 0 de walk **para todas las capas a la vez** (nunca mezclar) |
| combat_idle | combat idle si existe; si no, idle | |
| walk | walk | |
| run | run si existe; si no, walk con fps × 1.5 | |
| attack_slash | slash | Espadas, hachas, mazas |
| attack_thrust | thrust | Lanzas, dagas, estocadas |
| attack_shoot | shoot | Arcos |
| cast | spellcast | Skills y canalizar el altar |
| hurt | hurt | |
| death | hurt (secuencia completa, termina en el suelo) | Mantener `HeroAnim.spawn_death` (D-011) |

- **Fallback por pieza:** si una capa equipada no tiene una animación, esa capa usa la animación equivalente de la ropa inicial del mismo slot. Si tampoco existe, se oculta solo en esa animación, se registra un aviso y lo cubre el test (§10).
- **`HeroAnim` se conserva:** los tweens de anticipación, golpe, retroceso, flash, pánico, dash y roll se siguen aplicando encima. Solo cambian los nombres de animación que llama (`attack_<dir>`, `cast_<dir>`, etc.). Ahora hay 4 direcciones reales: elimina la lógica de `side_of` que reusaba izquierda/derecha para arriba/abajo, salvo donde haga falta.
- Qué ataque usa cada arma va en datos: `ItemDefs.BASES[*].attack_anim` (`slash` / `thrust` / `shoot` / `cast`), con un valor por defecto por clase.

## 5. Atuendo inicial único ("ropa normalita")

Constante de datos, no de UI: `scripts/data/lpc_wardrobe.gd → STARTER_OUTFIT`.

- Camisa o túnica simple de manga larga en tono neutro (lino, beige o blanco roto), pantalón sencillo marrón, zapatos o botas de cuero básicos y, si existe, un cinturón simple.
- **Sin** casco, sombrero, capa, guantes ni armadura.
- Tiene que existir para **todos los tipos de cuerpo** importados y tener **todas** las animaciones de §4. Si una pieza no cumple, elige otra que sí. Documenta la elección (ids exactos) en la entrada de DECISIONS.
- **Arma visible:** si el héroe no tiene arma equipada, se dibuja un arma básica de su clase **solo visual** (daga para rogue, espada corta para warrior/commoner, bastón de madera para mage/cleric, arco simple para ranger), definida en `STARTER_WEAPON_BY_CLASS`. **No da stats** (D-021). Cuando exista el sistema de ítems, el arma equipada la reemplaza.

## 6. Catálogo de vestuario (todas las demás piezas, para ítems)

Archivo de datos generado por el importador: `assets/pixel/lpc/wardrobe_catalog.json`, cargado por `scripts/data/lpc_wardrobe.gd`.

Cada entrada:

```json
{
  "visual_id": "chest_plate_steel",
  "slot": "chest",
  "lpc_item": "<id/ruta en sheet_definitions>",
  "variants": ["steel", "gold", "bronze"],
  "material": "plate",
  "weight": "heavy",
  "body_types": ["male", "female"],
  "anims": ["walk", "slash", "thrust", "spellcast", "shoot", "hurt", "idle"],
  "z": 0,
  "license": "CC-BY-SA 3.0 / GPL 3.0",
  "authors": ["..."],
  "tags": ["armor"]
}
```

- **Mapeo de slots** a `ItemDefs.SLOTS`: `head` (cascos, capuchas, sombreros), `chest` (torso, armaduras, túnicas), `hands` (guantes, brazales), `legs`, `feet`, `main_hand` (armas), `off_hand` (escudos). Lo que no encaje (capas, cinturones, hombreras, collares) va a slots visuales extra: `back`, `belt`, `shoulders`, `neck`. Esos son **solo visuales** por ahora, no se añaden a `ItemDefs.SLOTS` sin preguntar.
- Clasifica `material` (`cloth`, `leather`, `chain`, `plate`, `other`) y `weight` (`light`, `medium`, `heavy`) a partir del nombre de la pieza. Si no es obvio, pon `unknown`; no inventes.
- **No asignes stats ni crees ítems nuevos:** el loot, los afijos y los sets están PENDIENTES (P-19). Solo añade un campo opcional `visual_id` a los bases existentes de `ItemDefs.BASES` (helm → un casco del catálogo, mail → malla, robe → túnica, etc.) y repórtalo al dueño para que lo apruebe.
- Genera una **hoja de muestras** por slot (`docs/reports/lpc_wardrobe/<slot>.png`): cada pieza puesta sobre un héroe base, con su `visual_id` debajo. El dueño elegirá de ahí.

## 7. Composer nuevo (misma API)

Crea `scripts/core/lpc_composer.gd` (`class_name LpcComposer`) con la **misma interfaz pública** que `SpriteComposer`, para que los llamadores cambien lo mínimo:

- `FRAME` (64), `compose_frame(appearance, anim, dir, frame)`, `pose_texture(hero, anim := "idle")`, `build_frames(hero) -> SpriteFrames`, `clear_cache()`.
- **`visual_layers(hero, equipment := {}) -> Array`**: resuelve qué capas se dibujan:
  1. Partes del cuerpo del aspecto guardado.
  2. `STARTER_OUTFIT`.
  3. Cada slot con ítem equipado y `visual_id` **reemplaza** la capa inicial de ese slot (D-021).
  4. Orden final por `zPos` de LPC.
- Armas con frames sobredimensionados: respeta el tamaño y el offset que diga `LPC_FORMAT.md`. El arma no se recorta.
- **Caché:** una textura compuesta por (héroe, hash del equipo visible). Se invalida al cambiar el equipo. En la UI usa solo texturas de un frame; en combate, `SpriteFrames` sobre una hoja compuesta. Mide la memoria con 5 héroes en combate y 50 en el roster, y anótala.
- `SpriteComposer` (TPF) **se queda** para los bandidos y el Barón. Los héroes dejan de llamarlo.

## 8. Generador y guardado (D-004: los héroes nunca se re-generan)

- `HeroGenerator.VERSION = 4`. El aspecto nuevo se guarda en `h.appearance` con formato LPC, por ejemplo `{"format": "lpc", "body_type": ..., "skin": ..., "head": ..., "eyes": ..., "hair": ..., "hair_color": ..., "beard": ...}`.
- **Determinismo sin romper semillas viejas:** la tirada del aspecto LPC usa un RNG **propio** con semilla `hero_seed ^ 0x4C5043` (por ejemplo). **No consume** tiradas del RNG principal: nombre, clase, rasgos, pasivas y Trust de cada semilla siguen idénticos. Elimina las tiradas de TPF de `_make_appearance` sin alterar el orden de las demás llamadas. Si eso cambia el resultado de alguna tirada posterior, **haz que siga consumiéndolas y descarta el valor**, y pruébalo.
- Rareza: `style_rolls` puede seguir sesgando los peinados (más estilos para más estrellas). No añadas sombreros ni armas por rareza.
- **Migración de partidas guardadas:** sube `SAVE_VERSION`. Para cada héroe con aspecto TPF:
  - Genera su aspecto LPC con la misma función determinista a partir de `hero_seed`.
  - Conserva el viejo en `appearance_legacy` (no se borra).
  - Escribe la migración y su test.
- Héroes del memorial: también se migran, para que su retrato se vea.

## 9. Fuera de alcance (no lo hagas; repórtalo)

- **Bandidos y Barón:** siguen con TPF (Master prompt H, D-070). En el informe final incluye una captura de héroes LPC junto a bandidos TPF, y propón al dueño dos opciones: (a) pasar los bandidos a LPC usando el catálogo con ropa de un solo color, o (b) dejarlos así. No lo implementes.
- **Escala del mundo:** los personajes LPC miden bastante más que los TPF y que las celdas actuales (tiles de 16 px, celda de 48 px). **No cambies tiles, celdas, colisiones ni cámara.** Primero entrega capturas (§10) con tres opciones y espera la decisión del dueño:
  1. Mundo igual y personajes LPC a escala 1.
  2. Escalar el mundo ×2 de forma entera (tiles a 32 px, celda a 96 px) y ajustar la cámara.
  3. Mundo igual y cámara alejada.
  Nunca escales pixel art de forma no entera.
- Sistema de loot, afijos o sets (P-19), slots nuevos con stats, plugins nuevos.

## 10. Pruebas y evidencia (sin esto no hay PASS)

Tests nuevos, usando la infraestructura de tests del repo:

1. **Determinismo:** misma semilla y estrellas dan el mismo aspecto LPC en 1000 semillas.
2. **Semillas viejas intactas:** para 200 semillas, nombre, clase, rasgos, pasivas y Trust son iguales antes y después del cambio. Guarda un fixture JSON con los valores actuales **antes** de tocar el generador.
3. **Atuendo inicial:** 100 héroes invocados tienen exactamente las mismas capas de ropa (`STARTER_OUTFIT`) y difieren en cuerpo, pelo, ojos o barba.
4. **Catálogo:** cada `visual_id` apunta a archivos existentes, tiene licencia en la lista blanca y declara sus animaciones. Las piezas sin las animaciones base se listan como aviso.
5. **Reemplazo por slot:** equipar `chest_*` quita la camisa inicial; equipar `head_*` añade el casco; quitar el ítem restaura la ropa inicial.
6. **Migración:** una partida guardada con la versión anterior (fixture) carga, todos los héroes tienen `format: "lpc"` y su `appearance_legacy` intacto.
7. **Smoke de escenas:** invocación y reveal, roster, ficha de héroe, party, pueblo y sandbox cargan sin errores ni avisos de capas faltantes.

Capturas en `docs/reports/lpc_heroes/`:

- Antes y después del reveal de invocación, roster, ficha, pueblo y combate en el sandbox.
- Las 4 direcciones × todas las animaciones de §4 de un héroe (GIF o tira PNG).
- Tres comparaciones de escala (§9), con héroe LPC, bandido TPF y tiles actuales.
- Hojas de muestras del catálogo (§6).

## 11. Entrega

- Rama `feat/lpc-heroes`. Commits pequeños que citen la nueva D-xxx. No hagas push a `main` ni merge.
- Actualiza `docs/IMPLEMENTATION_STATUS.md` (solo con lo verificado), `docs/VERSIONS.md`, `docs/ASSET_REGISTRY.md`, `assets/CREDITS.md`, `docs/specs/ART_DIRECTION.md` (nueva referencia de escala) y `docs/specs/LPC_FORMAT.md`.
- Informe final en `docs/reports/LPC_HEROES_REPORT.md`:
  - Qué cambió, comandos ejecutados con su salida y qué quedó NO VERIFICADO.
  - Ids del `STARTER_OUTFIT` y de las armas iniciales.
  - Número de piezas del catálogo por slot y material.
  - Memoria medida.
  - **Preguntas abiertas para el dueño:** escala del mundo (§9), bandidos (§9), los `visual_id` propuestos para los bases de `ItemDefs` (§6) y razas no humanas (¿se permiten orejas de elfo u otros rasgos en héroes?).

## 12. Orden de trabajo sugerido

1. Fixture de semillas viejas (test 2) **antes** de cambiar nada.
2. Clonar LPC y escribir `docs/specs/LPC_FORMAT.md`.
3. Importador con filtros, más registro de licencias.
4. `lpc_wardrobe.gd`: `STARTER_OUTFIT`, armas iniciales y catálogo.
5. `LpcComposer`, más la tira de animaciones de prueba.
6. Generador v4 y migración.
7. Cambiar los llamadores de héroes a `LpcComposer`, y ajustar `HeroAnim` a 4 direcciones.
8. Tests, capturas, documentación e informe.
9. Parar y esperar al dueño en las preguntas abiertas.
