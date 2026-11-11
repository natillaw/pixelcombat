#!/usr/bin/env python3
"""Idea inventory + no-loss check for the 2026-10-30 doc consolidation.
Each entry: (idea, source file, text that must appear in the source, destination file, text that must appear in the destination).
Writes audit/IDEA_INVENTORY.md and exits 1 if any idea has no destination match.
Run from the repo root:  python audit/check_idea_inventory.py"""
import sys, pathlib
R = pathlib.Path(__file__).resolve().parent.parent
A = "docs/archive/infos/docs/ai-context/"
S = "docs/archive/infos/"
I = [
 # --- decisions
 ("D-001 free-first", A+"DECISIONS.md", "D-001", "docs/DECISIONS.md", "D-001"),
 ("D-002 IP original", A+"DECISIONS.md", "D-002", "docs/DECISIONS.md", "D-002"),
 ("D-003 procedural worlds deferred (now under review)", A+"DECISIONS.md", "D-003", "docs/DECISIONS.md", "D-003"),
 ("D-004 persistent identity / snapshot", A+"DECISIONS.md", "D-004", "docs/DECISIONS.md", "D-004"),
 ("D-005 local before backend", A+"DECISIONS.md", "D-005", "docs/DECISIONS.md", "D-005"),
 ("D-006 async multiplayer first", A+"DECISIONS.md", "D-006", "docs/DECISIONS.md", "D-006"),
 ("D-007 2D pixel art", A+"DECISIONS.md", "D-007", "docs/DECISIONS.md", "D-007"),
 ("D-008 art test before bulk", A+"DECISIONS.md", "D-008", "docs/DECISIONS.md", "D-008"),
 ("D-009 script-first", A+"DECISIONS.md", "D-009", "docs/DECISIONS.md", "D-009"),
 ("D-010 turn-based superseded", A+"DECISIONS.md", "D-010", "docs/DECISIONS.md", "D-010"),
 ("D-011 permanent death", A+"DECISIONS.md", "D-011", "docs/DECISIONS.md", "D-011"),
 ("D-012 FUE/AGI/VIT/INT/TEM + formulas", A+"DECISIONS.md", "PS = 40 + 10×VIT", "docs/DECISIONS.md", "PV = 40 + 10×VIT"),
 ("D-012 stress is not a 6th attribute", A+"DECISIONS.md", "Stress is a separate", "docs/DECISIONS.md", "estrés"),
 ("D-013 character identity first", A+"DECISIONS.md", "D-013", "docs/DECISIONS.md", "D-013"),
 ("D-014 hybrid RTS no pause", A+"DECISIONS.md", "D-014", "docs/DECISIONS.md", "D-014"),
 ("D-015 keys 1-5 / Tab / G, empty slot feedback", A+"DECISIONS.md", "Empty/dead slots", "docs/DECISIONS.md", "Ranura vacía o muerta"),
 ("D-016 Trust/Obedience/Composure", A+"DECISIONS.md", "D-016", "docs/DECISIONS.md", "D-016"),
 ("D-017 five-hero squad", A+"DECISIONS.md", "D-017", "docs/DECISIONS.md", "D-017"),
 ("D-018 synthesis/sacrifice/promotion", A+"DECISIONS.md", "D-018", "docs/DECISIONS.md", "D-018"),
 ("D-018 memory unlock MAYBE", A+"DECISIONS.md", "Memory unlock on promotion", "docs/DECISIONS.md", "P-11"),
 ("D-019 no-hands Godot", A+"DECISIONS.md", "D-019", "docs/DECISIONS.md", "D-019"),
 ("D-020 missing animations in code (sheet facts)", A+"DECISIONS.md", "4-frame side melee lunge", "docs/DECISIONS.md", "lunge lateral de 4 frames"),
 ("D-021 equipment layers, base look no stats", A+"DECISIONS.md", "D-021", "docs/DECISIONS.md", "D-021"),
 ("D-021 default underclothes open", A+"DECISIONS.md", "default underclothes", "docs/DECISIONS.md", "P-14"),
 ("D-022 skill library 4+1, lv 1-70, >=30 per class", A+"DECISIONS.md", "4 actives + 1 ultimate", "docs/DECISIONS.md", "4 activas + 1 definitiva"),
 ("D-022 5 vs 7 stars conflict", A+"DECISIONS.md", "7 stars and 70 levels", "docs/DECISIONS.md", "D-029 — 7 estrellas y 70 niveles"),
 ("Boss design principle", A+"DECISIONS.md", "Boss design", "docs/DECISIONS.md", "Jefes con mecánicas"),
 # --- design gaps
 *[(f"DESIGN_GAPS item {n}", A+"DESIGN_GAPS.md", f"{n}. ", "docs/DECISIONS.md", f"G-{n:02d}") for n in list(range(1,19))+list(range(21,26))],
 ("DESIGN_GAPS 24 memory unlock", A+"DESIGN_GAPS.md", "24. **MAYBE:**", "docs/DECISIONS.md", "G-24 = P-11"),
 ("DESIGN_GAPS 26 promotion material sources", A+"DESIGN_GAPS.md", "26.", "docs/DECISIONS.md", "G-26"),
 ("Deferred: base simulation, offline, backend, multiplayer", A+"DESIGN_GAPS.md", "offline progress", "docs/DECISIONS.md", "Progreso offline"),
 ("Equipment sheet facts (Held_Item 2..6, Top/Bottom/Hat)", A+"DESIGN_GAPS.md", "Held_Item/2..6", "docs/specs/ITEMS_AND_LOOT.md", "Held_Item/2..6"),
 ("First prototype acceptance criteria", A+"DESIGN_GAPS.md", "Acceptance criteria for the first prototype", "docs/MASTER_PROJECT.md", "Primer alcance jugable"),
 # --- bible
 ("High concept", A+"PROJECT_BIBLE.md", "High concept", "docs/MASTER_PROJECT.md", "Concepto"),
 ("8 pillars", A+"PROJECT_BIBLE.md", "Inspect existing code and preserve work", "docs/MASTER_PROJECT.md", "Inspeccionar y preservar"),
 ("Core loop", A+"PROJECT_BIBLE.md", "Core loop", "docs/MASTER_PROJECT.md", "Bucle principal"),
 ("Procedural generation 7 rules", A+"PROJECT_BIBLE.md", "Persist the generated result", "docs/MASTER_PROJECT.md", "Persistir el resultado generado"),
 ("Theme families (8)", A+"PROJECT_BIBLE.md", "Crystal/glass desert", "docs/specs/TOWER_AND_WORLD.md", "Crystal/glass desert"),
 ("Base/economy scope incl. crafting, research, storage", A+"PROJECT_BIBLE.md", "training, crafting, research", "docs/specs/HQ_AND_ECONOMY.md", "investigación, almacén"),
 ("Offline progress rules", A+"PROJECT_BIBLE.md", "Offline progress", "docs/DECISIONS.md", "timestamp"),
 ("AI dialogue optional, template fallback", A+"PROJECT_BIBLE.md", "AI dialogue", "docs/DECISIONS.md", "Diálogo con LLM opcional"),
 ("Technical rules", A+"PROJECT_BIBLE.md", "Separate data, simulation", "docs/MASTER_PROJECT.md", "Separar datos, simulación"),
 ("Out of scope initially", A+"PROJECT_BIBLE.md", "Out of scope initially", "docs/DECISIONS.md", "Fuera de alcance inicial"),
 ("Definition of done", A+"PROJECT_BIBLE.md", "Definition of done", "docs/MASTER_PROJECT.md", "Definición de \"hecho\""),
 ("Script-first workflow rule", A+"PROJECT_BIBLE.md", "Mandatory development workflow", "AGENTS.md", "Script-first"),
 # --- roadmap / tasks
 ("Priority if behind schedule", A+"ROADMAP.md", "Priority if behind schedule", "docs/DEVELOPMENT_ROADMAP.md", "Prioridades si hay retraso"),
 ("Phase 3B hero growth", A+"ROADMAP.md", "Phase 3B", "docs/DEVELOPMENT_ROADMAP.md", "Síntesis / sacrificio / promoción"),
 ("Phase 4 personality & memory", A+"ROADMAP.md", "Phase 4", "docs/DEVELOPMENT_ROADMAP.md", "Personalidad de 8 dimensiones"),
 ("T-026 UI art", A+"TASK_BOARD.md", "T-026", "docs/DEVELOPMENT_ROADMAP.md", "T-026"),
 ("T-027 effects", A+"TASK_BOARD.md", "T-027", "docs/DEVELOPMENT_ROADMAP.md", "T-027"),
 ("T-028 audio", A+"TASK_BOARD.md", "T-028", "docs/DEVELOPMENT_ROADMAP.md", "T-028"),
 ("T-029 pixel font", A+"TASK_BOARD.md", "T-029", "docs/DEVELOPMENT_ROADMAP.md", "T-029"),
 ("T-030 equipment layers", A+"TASK_BOARD.md", "T-030", "docs/specs/ITEMS_AND_LOOT.md", "T-030"),
 ("T-031 skill engine", A+"TASK_BOARD.md", "T-031", "docs/DEVELOPMENT_ROADMAP.md", "T-031"),
 ("T-032 skill VFX + icons", A+"TASK_BOARD.md", "T-032", "docs/DEVELOPMENT_ROADMAP.md", "T-032"),
 ("T-014..T-020 Phase 3B tasks", A+"TASK_BOARD.md", "T-016", "docs/DEVELOPMENT_ROADMAP.md", "T-014…T-020"),
 # --- handoff / session summary ideas
 ("Advanced classes Berserker/Assassin/Sniper/Templar/Sorcerer", A+"HANDOFF_LOG.md", "Berserker", "docs/DECISIONS.md", "Berserker"),
 ("Commoner class + past-life professions", A+"HANDOFF_LOG.md", "Commoner class", "docs/DECISIONS.md", "Commoner"),
 ("20 canonical occupations", A+"HANDOFF_LOG.md", "20 canonical occupations", "docs/specs/HQ_AND_ECONOMY.md", "artista"),
 ("Personality chatter on floor entry", A+"HANDOFF_LOG.md", "Quest Chatter", "docs/DECISIONS.md", "chatter"),
 ("Rescue with agony timer", S+"SESSION_SUMMARY.md", "agony timer", "docs/DECISIONS.md", "temporizador de agonía"),
 ("Secret skills & discovery chains", S+"SESSION_SUMMARY.md", "Secret Skills", "docs/specs/TOWER_AND_WORLD.md", "discover_secret"),
 ("Enemy roles frontliner/ranged/support", S+"SESSION_SUMMARY.md", "frontliners, ranged, support", "docs/DEVELOPMENT_ROADMAP.md", "soporte"),
 ("Multi-floor regional progression", S+"SESSION_SUMMARY.md", "multi-floor regional progression", "docs/specs/TOWER_AND_WORLD.md", "Torre de 100 pisos"),
 # --- reference systems
 *[(f"REFERENCE_SYSTEMS #{n}", "docs/specs/REFERENCE_INSPIRATION.md", f"| {n} |", "docs/DECISIONS.md", f"#{n}") for n in (6,7,8,9,10,11,12,13,16,17,18)],
 # --- assets
 ("Researched packs (Caz base, 0x72, Tiny Creatures, Kenney)", A+"ASSET_MANIFEST.md", "0x72", "docs/ASSET_REGISTRY.md", "0x72"),
 ("Skill VFX/icon candidates", A+"ASSET_MANIFEST.md", "StarsteelGaming", "docs/ASSET_REGISTRY.md", "StarsteelGaming"),
 ("UI asset needs v1.5", A+"ASSET_MANIFEST.md", "UI additions for v1.5", "docs/ASSET_REGISTRY.md", "Assets de UI previstos"),
 ("Caz 16x16-style scale note", A+"ASSET_MANIFEST.md", "16x16-style", "docs/ASSET_REGISTRY.md", "~16 px"),
 ("Per-asset record fields", A+"ASSET_MANIFEST.md", "For every imported asset record", "docs/ASSET_REGISTRY.md", "Para cada asset se registra"),
 # --- agent rules
 ("Authority order", S+"AGENTS.md", "Authority when documents disagree", "AGENTS.md", "Autoridad cuando los documentos"),
 ("Never claim without running", S+"AGENTS.md", "Never claim something is implemented", "AGENTS.md", "No afirmes que algo funciona"),
 ("No secrets", S+"AGENTS.md", "Never write secrets", "AGENTS.md", "Nunca escribas secretos"),
 ("Spec vs code conflict rule", A+"AGENT_SYNC.md", "code that was run and tested wins", "AGENTS.md", "manda el código ejecutado"),
 ("GDScript lessons", "GEMINI.md", "GEMINI.md", "AGENTS.md", "lambdas"),
 ("Token economy: one task per session", A+"RULES_LITE.md", "Token economy", "CLAUDE.md", "No cargues todos los documentos"),
 # --- reference images
 ("HQ must look in-game, not a menu", "docs/specs/reference/hq_ingame_reference_THIRD_PARTY.jpg", None, "docs/specs/HQ_AND_ECONOMY.md", "in-game y no como un simple menú"),
 ("Procedural map reference (biomes, bridges, doors)", "docs/specs/reference/procedural_map_reference.jpg", None, "docs/specs/TOWER_AND_WORLD.md", "procedural_map_reference.jpg"),
]
def read(p):
    f = R / p
    return f.read_text(encoding="utf-8") if f.exists() and f.suffix in (".md", ".txt") else ("" if not f.exists() else None)
rows, bad = [], 0
for idea, src, skey, dst, dkey in I:
    s = read(src)
    if s is None:
        sloc, sok = src, (R / src).exists()
    else:
        line = next((i + 1 for i, l in enumerate(s.splitlines()) if skey in l), None)
        sloc, sok = (f"{src}:{line}" if line else f"{src} (NOT FOUND)"), line is not None
    d = read(dst) or ""
    dok = dkey in d
    bad += (not dok) + (not sok)
    rows.append(f"| {idea} | `{sloc}` | `{dst}` | {'OK' if (dok and sok) else 'MISSING'} |")
out = ["# Inventario de ideas — trazabilidad de la consolidación (2026-10-30)", "",
       "Generado por `python audit/check_idea_inventory.py`. Cada idea de los documentos archivados apunta a su destino vigente.",
       "Las specs movidas intactas (`docs/specs/*`) conservan el 100 % de su contenido y no se listan línea a línea.", "",
       f"**Ideas comprobadas:** {len(I)} · **Sin destino o sin origen:** {bad}", "",
       "| Idea | Origen | Destino | Estado |", "|---|---|---|---|", *rows]
(R / "audit/IDEA_INVENTORY.md").write_text("\n".join(out) + "\n", encoding="utf-8")
print(f"{len(I)} ideas, {bad} missing")
sys.exit(1 if bad else 0)
