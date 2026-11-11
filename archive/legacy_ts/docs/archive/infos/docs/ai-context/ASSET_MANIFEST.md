# Asset Manifest and License Register

Status values: Candidate / Downloaded / Import-tested / Approved / Rejected. A site being free does not mean every item on it has the same license; check the exact pack page and retain its license file.

| Candidate source | Use | License check | Status |
|---|---|---|---|
| [Kenney](https://kenney.nl/assets) | UI, icons and prototype assets; inspect 2D/pixel-art suitability per pack | Verify exact pack page | Candidate |
| [OpenGameArt](https://opengameart.org/) | Pixel-art sprites, tilesets, icons, sound and music | Per-file license varies; retain attribution terms | Candidate |
| [itch.io game assets](https://itch.io/game-assets) | Pixel-art characters, enemies, tilesets, UI and effects | Check each pack license and redistribution terms | Candidate |
| [Godot Asset Library](https://godotengine.org/asset-library/asset) | Plugins/tools | License and maintenance vary by plugin | Candidate |
| [OpenGameArt](https://opengameart.org/) | Optional audio, sprites, music | Per-file license varies | Candidate |
| [Freesound](https://freesound.org/) | Sound effects | Per-recording license varies | Candidate |

For every imported asset record: filename/path, source URL, creator, exact license, license URL, download date/version, modifications, attribution, commercial-use permission and import-test status.

Suggested folders: `assets/_inbox/`, `assets/_approved/`, `assets/_rejected/`, `assets/pixel/characters/`, `assets/pixel/enemies/`, `assets/pixel/tilesets/`, `assets/pixel/ui/`, `assets/pixel/effects/`.

This is a researched shortlist only. No listed assets are claimed to have been downloaded or tested. Do not redistribute raw packs as standalone asset libraries.


## UI additions for v1.5 (placeholder assets)
- Hero portrait/frame for five numbered slots (1–5).
- Skill icon slots with cooldown overlay, resource cost and target/range indicator.
- Command icons: move, attack, attack-move, hold, regroup/follow, interact, scout, retreat/extract.
- Camera state icons: group view, focused hero, off-screen ally indicator.
- Social-state icons/markers for Trust, Obedience, Composure, bond and rivalry; must be understandable without color alone.
- Order/path feedback: destination marker, target marker, invalid-order reason, interaction progress and extraction zone.

## Owner-supplied hero pixel-art pack (reported 2026-10-28)
| Item | Value |
|---|---|
| Pack name / source URL | UNKNOWN - owner to record |
| License and attribution rules | UNKNOWN - owner to record; keep the license file in the repo |
| Sprite and tile size | UNKNOWN - decide after an in-engine test |
| Number of designs | "many" (owner); count not recorded |
| Status | Owned; not yet import-tested |
Next: record name and license, then map designs to generator part IDs and palettes (task T-021).

## Researched 2026-10-28 (all Candidate: not downloaded, not import-tested)
IMPORTANT: the hero pack (Tiny Pixel Fantasy Character Generator, by Caz) is a **16x16-style** pack. The 48 px is only the sheet cell; the figure is about 16 px wide. Match tiles/enemies at **16x16** and draw the map at native scale with camera zoom (T-025), not 48 px tiles.

| Pack | Use | Source | License (as stated by the author) | Status |
|---|---|---|---|---|
| Tiny Pixel Fantasy - Base Pack (Caz) | Tiles (town, woodland, cave, castle, ship) + 8 character sheets; same artist/style as the heroes | https://cazwolf.itch.io/tiny-pixel-fantasy1 (page links a full Terms of Use/EULA) | Author states free assets are CC BY 4.0 and free for commercial use; credit Caz + link the license. Read the linked EULA before shipping. One tile per PNG (no tilesheet): script must pack them. | Candidate |
| 16x16 DungeonTileset II (0x72) | Dungeon tiles + animated monsters + weapons | https://0x72.itch.io/dungeontileset-ii | CC0 (author: use for whatever you like) | Candidate |
| Tiny Creatures (Clint Bellanger, for Kenney Tiny Dungeon) | 100+ monsters, 16x16, few animations | https://clintbellanger.itch.io/tiny-creatures | CC0 | Candidate |
| Tiny Dungeon (Kenney) | 16x16 dungeon tiles + chibi characters | https://opengameart.org/content/tiny-dungeon | CC0 | Candidate |

Style note: Kenney/Clint sprites use thick outlines and may clash with Caz's style; test side by side before approving. Credits file (CREDITS.md) must list Caz + CC BY 4.0 link once any Caz asset ships.

## Skill VFX and icon candidates (researched 2026-10-28, not downloaded)
Licenses marked CC0 were read on the page; every other pack must have its license page read before import.
| Use | Pack | Source | License |
|---|---|---|---|
| Mage: fire/ice/lightning effects | Spell Effects by StarsteelGaming | https://opengameart.org/content/spell-effects-by-starsteelgaming | CC0 |
| Mage/Archer: projectiles, explosions, ice lance (16x16) | Pixel Art Spells by DevWizard | https://opengameart.org/content/pixel-art-spells | CC0 |
| Thief: rogue effects | Pixel Art VFX - Rogue (FREE version) | listed in https://itch.io/c/7139964/attackeffect | check page |
| Warrior/Spearman/Archer: slashes, hit impacts | VFX collections and slash packs | https://itch.io/c/7139964/attackeffect | check page |
| Mage elemental effects | NYKNCK effect set (Ice Shard, Fireball, Wind, Explosion) | https://itch.io/c/5647574/spells-effects | check page |
| Skill icons | 250 Magical Pixel-art Icons Free Pack; Unique Free 8-bit Spell Icons 16x16 (55 icons); 48 Free Swordsman Skills Icons | https://itch.io/c/5647574/spells-effects and https://itch.io/c/1960015/spell-effects | check page |
Note: many effects are 32x32; the heroes are about 16 px wide, so scale effects to fit.
