> **Estado (2026-10-30):** Referencia (no requisitos). Movida intacta desde `REFERENCE_SYSTEMS.md`. Estados actualizados en `docs/DECISIONS.md` §3-4. Las reglas de nombres prohibidos siguen VIGENTES (D-002).

# Reference Systems (v1.7)

Inspiration notes only. Tactical Summoners is an original game (D-002). Mechanics are ideas; names, characters, dialogue, plot and distinctive terms of the reference work are **not** used.

## Sources and reliability
- Reference work: *Pick Me Up, Infinite Gacha* (web novel by Hermod; manhwa by U-Ne Cho and Wasakbasak; KakaoPage original, Tapas English). Reported as ongoing; one source says Tapas closes 2027-03-31 (verify).
- Fan wiki (hero tiers and rules): https://infinite-gacha.fandom.com (pages could not be fetched whole; search excerpts only).
- Fan spoiler summary through roughly floor 35: https://www.novelupdatesforum.com/threads/pick-me-up-infinite-gacha.168425/ (fan-written, partial, may contain errors).
- Ignore SEO sites describing a mobile game with an "Infinite Cycle" mechanic; they do not describe the work.
- An unofficial fan game project (Moebius Order) exists; it has no rights to the work. Do not copy it.

## Status legend
APPROVED = in the roadmap. MAYBE = owner undecided. CANDIDATE = worth considering, not approved. DEFERRED = later. NO = do not use.

## Mechanics matrix
| # | Reference behavior (paraphrased) | Our adaptation | Status | Where |
|---|---|---|---|---|
| 1 | Hero tiers from low to very high; the lowest are expendable and weak | Promotion tiers with data-driven unlocks; rarity stays separate from power | APPROVED | D-018, Phase 3B |
| 2 | Synthesis consumes a hero to boost another; most of the value is lost | Lossy, irreversible, confirmed, transactional | APPROVED | D-018 |
| 3 | A hero can be consumed to create materials | Sacrifice (hero to materials) | APPROVED (interpretation to confirm) | D-018 |
| 4 | Promotion needs materials and unlocks more | Tier up unlocks skill slot, class option, level cap, potential | APPROVED | D-018 |
| 5 | Promotion reveals more of the hero's past | Memory unlock on promotion | MAYBE | DESIGN_GAPS 24 |
| 6 | Classes appear from a higher tier at birth; some classes are gacha-only | Class availability by tier; one rare class gated to summons | CANDIDATE | - |
| 7 | Daily dungeons give promotion materials | Fixed mission reward first; recurring source later | DEFERRED | gap 26 |
| 8 | Facilities: promotion station with levels, conversion house, archive for the fallen's relics | Memorial already approved; facility upgrades later | CANDIDATE | Phase 7 |
| 9 | Mission objective can change mid-mission (explore, then exterminate, then escape) | Objective state machine with scripted switches | CANDIDATE | Control spec 9 |
| 10 | Optional subquests show each hero's opinion; the commander accepts or refuses | Transparent hero-intent hint on optional objectives; never cancels direct orders | CANDIDATE | Trust/Obedience |
| 11 | Hero "favorability" decides how responsive heroes are; gifts raise it | Trust already exists; gifts are optional later | CANDIDATE | - |
| 12 | Bosses are immune until a field mechanism is activated; altars shift the fight | Matches boss principles; use as one template | CANDIDATE | Control spec 10 |
| 13 | Replay stones let the owner watch past missions | Mission replay or event recap | DEFERRED | - |
| 14 | Five-person parties; several parties can be summoned into one mission | Our squad is five (D-017); multi-party is not planned | NO (for now) | D-017 |
| 15 | Every 10 floors unlocks dungeons, facilities and a level cap | Tower campaign pacing | DEFERRED | Deferred |
| 16 | Invasions between players; protection before a level; death costs permanent stats | Async multiplayer only, later | DEFERRED | D-006 |
| 17 | A hidden resource ("interference") pays for summons, missions and facilities | Single abstract currency with an original name | CANDIDATE | economy |
| 18 | Hidden or bonus stages unlocked by subquests | Optional stages | DEFERRED | - |

## Naming rules
Do not use: Loki, Niflheim, Iselle, Islat Han, Anytng, "waiting room", "Interference Force", "Hero Protection System", "Hall of Magic", "replay stone", or any character or place names. Pick original terms and keep them in a glossary file when chosen.

## Design takeaways
1. Loss must be informed. Show the cost before the player commits.
2. Low-tier heroes still need identity (personality, history). That keeps sacrifice meaningful.
3. Player authority stays absolute for direct orders. Hero opinions are information, not refusals.
4. Objectives that change during a mission create pressure without extra enemies.
