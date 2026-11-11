> **Estado (2026-10-30):** Spec CONFIRMADA (D-007, D-008, D-020, D-023). Movida intacta. La mención a "turn/target telegraphs" es un resto del diseño por turnos sustituido (D-010).

# Art Direction — Tactical Summoners

**Status:** Direction selected for the first prototype: **2D pixel art**. Exact resolution, tile size and palette remain to be validated in-engine.

## Visual target
Original dark-fantasy pixel art with readable silhouettes, limited palette ramps, restrained lighting effects and clear animation timing. Prioritize gameplay readability over detail. Characters, enemies, UI icons, status effects and turn/target telegraphs must remain distinguishable at the actual game window size. Do not imitate the exact character designs, interface, icons, or visual identity of any reference work.

## First art test
Create or source with compatible licenses:
- One allied hero sprite with idle, attack, hit and death states (placeholder frames are acceptable).
- One enemy sprite with idle, attack wind-up, hit and death states.
- One small battle background or tileset sample.
- Selection rings, target highlights, range indicators and enemy telegraph icons (no rank/position markers; combat is real-time).
- A readable hero panel showing HP, resource, status effects, skills and compact Trust/Obedience/Composure markers.
- One portrait/card treatment for a hero's personality and background.

Validate sprite scale, contrast, animation readability, UI legibility, file sizes and licenses before scaling production.

## Pixel-art production rules
- Pick a working internal resolution and integer scaling only after a quick in-engine test.
- Keep palette ramps and outlines consistent across heroes, enemies, effects and environment.
- Use transparent PNG sprites/sprite sheets; document frame size, frame order, pivot/origin and animation names.
- Avoid subpixel movement where it causes shimmer; test camera and UI scaling on intended display sizes.
- Use visual telegraphs that remain clear without relying on color alone.
- Prefer modular palettes, equipment overlays and portrait variants to unique art for every procedural hero.
- Procedural variation may choose from approved sprites, palettes, equipment layers and portrait details; do not randomly splice incompatible pixels.

## Character identity through art
A generated hero's visual presentation should reflect their class, origin, equipment and a few persistent distinguishing details. The first prototype does not need a fully procedural sprite generator: curated sprite parts plus data-driven combinations are enough. Record chosen part IDs so a hero's appearance does not reroll on reload.

## World generation
Procedural world generation is deferred/undecided. For the prototype use a fixed, hand-authored battle background or small dungeon sequence. Pixel-art tile/chunk generation may be explored only after the core combat and hero loop is validated.

## Asset sourcing
Use placeholders first where practical. For each imported asset, record source, creator, exact license, attribution requirements, modification and approval status in `docs/ai-context/ASSET_MANIFEST.md`. A free download is not automatically public domain or commercially reusable.

## Avoid
- Mixing pixel art with 3D renders or smooth vector art without a deliberate conversion pass.
- Excessive detail that disappears at native display size.
- Unreadable combat effects, telegraphs or status icons.
- Random sprite combinations that cause visual mismatch.
- Copied characters, logos, UI, maps or distinctive visual expression from reference IP.


## Real-time readability requirements (added 2026-10-28)
- Pixel-art sprites must remain distinguishable at the default group-camera zoom; hero silhouettes and team selection need more than color alone.
- Telegraphs, selection outlines, target highlights, interaction points and extraction zones must remain readable against busy terrain.
- Avoid high-frequency animation or excessive screen shake that hides orders and enemy tells.
- Plan small, clear animation states for idle, move, attack wind-up, attack, hit, skill cast, stagger/downed and extraction.
- Use distinct silhouettes/weapon effects for enemy roles; boss attacks need clear safe/unsafe areas.


## Hero-focus camera and social UI readability (v1.5)
- Number keys 1–5 focus a hero while the world continues; make the focused hero unmistakable with portrait/frame/name, not color alone.
- When a hero is focused away from the group, off-screen ally edge indicators should be simple and low-noise.
- Reserve HUD space for selected hero vitals, active skills/cooldowns, order state and compact Trust/Obedience/Composure signals.
- Trust/Obedience/Composure should use icons, labels or tooltips as well as meters; do not communicate meaning through color alone.


## Cohesión con los héroes (D-055, 2026-10-31)
Los héroes del generador de personajes de Caz son la referencia y **no se modifican** (D-023). Para que un NPC, monstruo o criatura nueva encaje:
- **Contorno exterior oscuro**, cercano al de los héroes (luminosidad ≈0,12, morado muy oscuro #2a1657), conservando como mucho un 25 % del tono propio. Medido con `tools/art_cohesion.gd`.
- **Escala**: medir el alto opaco frente al héroe (31 px) con `tools/measure_scale.gd` y asignar la clase de tamaño (`CombatRules.CREATURE_SIZE`): pequeño < 0,8, estándar 0,8–1,5, grande 1,5–2,5, enorme > 2,5.
- **Pies abajo del frame**, mirando a la derecha, con tiras de frames cuadrados (como los packs actuales).
- **Saturación y contraste moderados**: sin colores puros ni brillo mayor que el de los héroes; el pixel art no se escala de forma no entera en el arte fuente.
- **No destructivo**: los ajustes se aplican a **copias** en `assets/processed/` generadas por script; los PNG originales y sus licencias no cambian (`docs/ASSET_REGISTRY.md`).
- Flujo para un asset nuevo: registrar la licencia → `tools/art_cohesion.gd` (auditoría) → `-- --write` → `godot --headless --path . --import` → revisar la captura `tests/capture_feel.tscn`.
