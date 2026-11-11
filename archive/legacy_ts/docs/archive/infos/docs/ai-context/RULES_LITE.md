# Rules (lite) — binding, 1 min read
Repo (Git) is the source of truth, not chat memory. Authority: DECISIONS > specs > BIBLE > ROADMAP > chat.
- Game: Tactical Summoners, Godot 4, 2D pixel art, hybrid RTS, real time, NO pause/time-slow.
- 5-hero squad (final). Keys 1-5 focus hero, Tab group, G squad. Permanent death, no resurrection.
- Direct orders are never randomly refused. Heroes never re-roll on load. Procedural worlds deferred (fixed map).
- Trust, Obedience, Composure are separate persistent fields; changes are deterministic.
- Script-first: generators, @tool EditorScripts, CLI. Give exact paths + minimal run steps. Manual editor steps only if unavoidable.
- NO-HANDS GODOT (D-019): the owner will NOT edit Godot manually. The AI does everything via scripts: .gd/.tscn/.tres generation, @tool EditorScripts, headless Godot CLI, PowerShell (.ps1, Windows) for files, git, imports and tooling. This includes character animations (SpriteFrames/AnimationPlayer built by script from sprite sheets). Never answer with "open the editor and click..."; give a script + one command to run + expected output. Owner only runs commands and reports results.
- Inspect real code before editing; do not rewrite what exists. Never claim "implemented/tested" unless you ran it.
- Never write secrets. Do not contradict DECISIONS.md; propose a new D-xxx instead.
- Token economy: work ONE task per session; ask for only the files you need; do not re-read docs already given; keep replies short.
