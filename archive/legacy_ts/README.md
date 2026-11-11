# Tactical Summoners

RPG táctico en pixel art 2D (Godot 4, GDScript). Se invocan héroes únicos y persistentes (personalidad, historia, relaciones, muerte permanente), se forma un escuadrón de 5 y se le dirige en tiempo real, sin pausa, mediante control RTS híbrido.

**Estado:** prototipo en fase de reparación. Qué funciona de verdad: `docs/IMPLEMENTATION_STATUS.md`. Fallos conocidos: `audit/`.

## Abrir y jugar
1. Godot 4.7 (según `project.godot`) → Project Manager → Import → `project.godot`.
2. La primera apertura importa los sprites. Pulsa F5.
3. Partida guardada automáticamente en `user://save.json`. El menú tiene botones de depuración (gemas, piedras, libros, borrar partida).

Controles del sandbox: clic izquierdo para seleccionar o arrastrar una caja, clic derecho para mover, 1-5 para enfocar a un héroe, Tab para la vista de grupo, G para seleccionar el escuadrón, Q para la habilidad y S para parar. Los héroes muertos no vuelven.

## Pruebas
`powershell -ExecutionPolicy Bypass -File tools\Run-Tests.ps1` (12 suites; escribe `tools\last_test_run.txt`).

## Documentación
- Agentes: `CLAUDE.md`, `GEMINI.md`, `AGENTS.md`.
- Proyecto: `docs/MASTER_PROJECT.md` (visión), `docs/DECISIONS.md` (decisiones), `docs/DEVELOPMENT_ROADMAP.md` (plan), `docs/ARCHITECTURE.md` (código), `docs/specs/` (detalle por sistema).
- Historia: `docs/archive/` (no vigente).

## Assets
Los héroes usan **Tiny Pixel Fantasy – Character Generator by Caz** (`assets/sprites/`; leer su EULA, enlazada en `EULA_READ_ME.txt`, antes de compartir o vender). El resto de packs y sus licencias están en `docs/ASSET_REGISTRY.md`.
