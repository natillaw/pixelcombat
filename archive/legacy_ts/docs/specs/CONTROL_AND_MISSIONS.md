> **Estado (2026-10-30):** Spec CONFIRMADA (D-014, D-015). Movida intacta desde `CONTROL_AND_REALTIME_MISSIONS.md`. Gran parte NO está implementada: ver `docs/IMPLEMENTATION_STATUS.md`. Las referencias a "procedural world deferred" / "fixed map" están sustituidas por D-026 (pisos procedurales).

# Control, Camera & Real-Time Missions — Tactical Summoners

**Version:** 1.5 design baseline, 2026-10-28  
**Status:** Approved specification; not yet implemented or playtested.

## 1. Core control fantasy
The player is a field commander of autonomous, individually generated heroes. Heroes navigate, select reasonable basic-attack targets and perform routine attacks themselves. The player creates advantage by positioning the squad, choosing priorities, using active skills, issuing interactions and deciding when to extract. The game runs continuously in real time; there is no tactical pause or time-slow.

## 2. Camera modes and number keys 1–5
The default camera shows the squad and nearby map. The five number keys are dedicated hero focus shortcuts:

- Press **1, 2, 3, 4 or 5**: select the corresponding deployed hero and smoothly move the camera to follow that hero. The selected hero's portrait, status, skills and command panel become active.
- The camera keeps following the focused hero until another hero key or the group-view shortcut is pressed. This is a camera focus, not direct movement control; the other heroes continue their AI and current orders in real time.
- Press the same hero number again: recenter the camera on that hero (do not toggle into a pause or special control mode).
- Press **Tab**: return to squad/group view, framing the living deployed heroes and nearby threats. Selection remains on the last focused hero unless the player chooses a group command.
- Press **G**: select all living deployed heroes for a group order; camera returns to group view.
- If a numbered slot is empty or its hero is dead/unavailable, show a short UI message and do not silently focus another hero.
- If a focused hero moves far ahead (for example, an Explorer scouting), the camera may follow them and leave allies off-screen. Show small squad-edge indicators for off-screen allies and a quick return-to-group shortcut (Tab). Do not teleport heroes or change their orders when switching camera.
- Camera focus must never pause the simulation. Enemies continue to move, attacks resolve and objectives progress.

This resolves the intended combination: group view is the default tactical overview, while keys 1–5 let the player inspect and direct one hero at a time.

## 3. Proposed keyboard/mouse bindings
Initial bindings for keyboard and mouse, all remappable later. Do not assume final controller/mobile support until platform is confirmed.

| Input | Action |
|---|---|
| Left-click hero / portrait | Select and focus that hero |
| **1–5** | Select deployed squad slot and follow that hero with the camera |
| **Tab** | Return camera to group view |
| **G** | Select all living deployed heroes and show group view |
| Drag selection box | Multi-select heroes in visible area |
| Right-click ground | Move selected hero/selected group to location |
| Right-click enemy | Attack/mark that target for selected unit(s) |
| Right-click usable object | Interact if context is valid |
| **A** then click target/ground | Attack-move to a point or target (proposed; validate usability) |
| **H** | Hold/defend current position |
| **F** | Follow/regroup toward rally point or squad leader |
| **R** | Retreat toward active extraction point (if the mission enables it) |
| **E** or contextual button | Interact with nearby objective (proposed; avoid conflict with skill hotkeys) |
| **Q / W / E / R** | Active skills 1–4 for selected hero, only if UI and binding plan avoids conflicts; if R is retreat, use Q/W/E plus clickable skill buttons in prototype |
| Mouse wheel | Zoom camera |
| Middle-mouse drag or edge-pan | Pan camera; choose one in the first usability test |
| Escape | Close non-modal panel/clear targeting; never pauses the simulation |

**Binding note:** avoid assigning the same key to retreat and a skill. For the first keyboard prototype, use Q/W/E for up to three skills and clickable skill buttons; keep retreat on a clearly labelled UI button until bindings are playtested. The ability bar must show actual bindings.

## 4. Hero command panel (opens/updates when a hero is focused)
The hero panel is contextual and should remain readable during live combat. It contains:
1. **Identity:** name, portrait, class/role, rarity if used, level and unique ID in the detailed roster view.
2. **Vitals:** health, current resource, key conditions/status effects, injury indicator and downed/dead state.
3. **Active skills:** icon, short name, cooldown, resource cost, range and valid-target hint. Disabled skills explain why.
4. **Command controls:** Move, Attack/Target, Hold, Follow/Regroup, Interact, Retreat/Extract. Show current order state.
5. **Behavior summary:** 1–3 concise trait tags (e.g. Scout, Protective, Cautious) plus a small Trust / Obedience / Composure indicator. Full detail is in the inspect panel, not the always-on HUD.
6. **Feedback:** current order, target, path failure, skill invalidity, fear/composure event and brief combat log entries.

Selecting/focusing a hero does not stop or slow the world. UI panels must not cover the hero's immediate danger area or hide boss telegraphs.

## 5. Order model and priorities
Each hero has one primary order state:
- **Auto:** pathfind around obstacles, avoid known hazards and attack a reasonable nearby threat.
- **Move:** travel to the destination; after arrival return to Auto unless the player chose Hold.
- **Attack target:** prioritize a designated enemy. If it dies or becomes unreachable, show feedback and return to Auto or follow a documented fallback rule.
- **Attack-move:** advance toward a location while engaging reasonable threats along the route.
- **Hold/defend:** stay near a location, engage threats inside the defense radius and do not chase far away.
- **Follow/regroup:** maintain a useful distance from a leader or rally point without sprite stacking.
- **Interact:** approach and complete a contextual action with visible progress and clear interruption rules.
- **Retreat/extract:** prioritize the extraction route and avoid optional fights unless attacked or mission rules require otherwise.
- **Scout:** optional explicit order for heroes with scouting capability; move to a location, reveal/report relevant information and return or hold as configured.

Order priorities:
1. Explicit current player order.
2. Immediate avoidance of a clearly telegraphed lethal hazard, if that reaction is enabled.
3. A committed interaction/escort/defense action whose interruption rules were shown to the player.
4. Autonomous target selection and personality preferences.

New direct orders replace the previous compatible order. Do not build a complex hidden queue in the first prototype. Orders need visible destination/target markers and a reason when invalid (blocked path, out of range, target gone, cooldown, dead hero).

## 6. Autonomous behavior and individual personality
Baseline AI should be competent and predictable:
- navigate around obstacles and avoid known hazards;
- use basic attacks when no conflicting direct order exists;
- not chase targets indefinitely or abandon the active mission;
- respect direct movement, target, hold, follow and extraction orders;
- use only basic attacks autonomously in the first slice; active skills are player-triggered.

Traits alter preferences, not core input reliability. Example: an **Explorer/Scout** has greater perception, reveals points of interest sooner, gains more from investigating and may volunteer to scout when in Auto. If assigned to move ahead, the player can focus camera with key 1 (if that hero occupies slot 1), inspect the scout's skills and order them to investigate, attack, hold, regroup or extract. Other heroes continue acting under their own orders while the camera is focused on the scout.

Do not make heroes randomly refuse basic orders. Trust, obedience and composure can influence how quickly or cautiously an order is executed in special, clearly signaled circumstances, but no invisible coin-flip may cancel a routine command. See `SUMMONS_AND_HERO_GENERATION.md`.

## 7. Trust, obedience, composure and bonds in live play
- **Trust (long-term):** belief that the commander and company will protect them and treat them fairly. Influences willingness to volunteer, dialogue, recovery and relationship events.
- **Obedience (discipline):** trained reliability in carrying out orders under pressure. Primarily influences hesitation/formation discipline in extreme, telegraphed conditions—not routine order success.
- **Composure (mission state):** short-term steadiness affected by fear, injuries, isolation, allies falling and boss events. Can temporarily influence aim, reactions or skill precision if communicated.
- **Bond/rivalry (relationship):** pairwise relationship between heroes. Can trigger coordinated benefits, protective actions, conflict or post-mission scenes after validation.
- These are separate dimensions. Do not collapse them into one “morale” number. MVP stores the values and displays them but should only implement simple, deterministic effects after the base controls work.
- Any hesitation, panic or special reaction must show a clear reason and recovery path. A player command remains authoritative in ordinary situations.

## 8. Camera, HUD and no-pause readability
- Default: group framing with soft follow to group center. Hero key: camera smoothly follows that hero. Tab: group framing.
- Camera changes never affect game time, orders, pathfinding, target selection or mission progress.
- Off-screen ally indicators and danger-edge indicators are required when focusing a scout away from the squad.
- HUD layers: portraits/slot numbers, health/resource, selected hero, skill bar, order buttons, objective tracker, extraction status, enemy telegraphs, interaction prompts, Trust/Obedience/Composure mini-state and event log.
- Do not rely on color alone for selection, status or danger.
- Use camera bounds/zoom so sprites, range indicators and telegraphs remain legible.
- Commands should take one or two inputs; skills should not require a long menu sequence.
- No tactical pause, time-slow, or pause-on-skill-selection.

## 9. Mission design: exploration and combat share one map
Mission objectives may include:
- scout routes and discover points of interest;
- investigate evidence or activate mechanisms;
- rescue or escort someone;
- recover an item and extract;
- defend a location while a timer/process completes;
- survive a threat wave;
- bypass, distract or evade enemies;
- expose a boss weak point or interact with arena mechanisms;
- decide whether to extract with current rewards or continue deeper.

At least one early mission must be completable without killing every enemy. Enemies can guard routes, react to noise, interrupt objectives or chase for a bounded time. Avoid unfair omniscience.

## 10. Boss design
Use phase changes, telegraphed area attacks, vulnerable windows, arena objects, adds with a purpose, objective pressure and meaningful extraction decisions. Boss health is one tuning variable, not the whole mechanic. Every major attack must have readable warning and counterplay.

## 11. First playable vertical slice
Start with one fixed map and five heroes (D-017):
1. Roster shows at least six generated heroes; choose five for deployment.
2. Enter a top-down real-time mission with a non-combat objective and at least one enemy.
3. Press 1–5 to focus/select a hero and reveal that hero's command/skill interface.
4. Press Tab to restore group camera; verify other heroes continue acting.
5. Move, target, attack-move, hold, follow, interact and retreat/extract.
6. Activate one unique skill per deployed hero.
7. Use an Explorer to reveal/investigate a point while the rest of the team remains under AI or explicit orders.
8. Complete objective and extract while an optional enemy remains alive.
9. Save mission outcome, relationship changes and memorial/death state; reload and verify persistence.

## 12. Acceptance criteria
- Keys 1–5 select and camera-follow the correct deployed hero and update the contextual panel without pausing time.
- Tab returns to group view; G selects the group.
- Other heroes keep acting while the camera focuses one hero.
- Hero UI shows skills, cooldown/resource, current order, core status and compact social-state indicators.
- Direct orders have visible feedback and do not fail silently.
- Autonomous navigation/attacks work without constant clicking; heroes do not stack on one pixel.
- Explorer/scout can move ahead, reveal an objective and return/re-group.
- At least one mission can be completed without killing every enemy.
- Permanent death and hero relationships survive save/load.
- These are requirements, not claims of implementation; all remain unverified until tested in Godot.
