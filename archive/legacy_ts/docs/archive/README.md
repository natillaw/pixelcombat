# Archivo histórico — NO es instrucción vigente

Documentos retirados el 2026-10-30 (Fase 2 de consolidación). Se conservan en su ruta original bajo `docs/archive/` como historia y procedencia. **Ningún agente debe leerlos salvo petición expresa.** Todo su contenido vigente o pendiente se trasladó a:
`docs/DECISIONS.md` · `docs/MASTER_PROJECT.md` · `docs/IMPLEMENTATION_STATUS.md` · `docs/DEVELOPMENT_ROADMAP.md` · `docs/ASSET_REGISTRY.md` · `docs/specs/` · `AGENTS.md`.
La trazabilidad idea por idea está en `audit/IDEA_INVENTORY.md`.

| Archivo | Por qué se retiró |
|---|---|
| `infos/docs/ai-context/DECISIONS.md`, `PROJECT_BIBLE.md`, `DESIGN_GAPS.md`, `ROADMAP.md`, `TASK_BOARD.md`, `ASSET_MANIFEST.md` | Fusionados en los documentos nuevos (originales conservados aquí) |
| `infos/docs/ai-context/CURRENT_STATE.md`, `IMPLEMENTATION_STATUS.md` | Contradictorios y desactualizados; sustituidos por `docs/IMPLEMENTATION_STATUS.md` con evidencia |
| `infos/SESSION_SUMMARY.md` | **NO VERIFICADO**: afirma suites PASS y funciones que no existen (F-006, F-037). Sus ideas se registraron como PENDIENTES |
| `infos/docs/ai-context/HANDOFF_LOG.md`, `CHANGELOG.md` | Historial de sesiones |
| `infos/AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, `docs/ai-context/AGENT_SYNC.md`, `RULES_LITE.md` | Sustituidos por `AGENTS.md`/`CLAUDE.md`/`GEMINI.md` de la raíz |
| `infos/CONTEXT_BUNDLE.md`, `CONTEXT_LITE.md` | Generados automáticamente, desactualizados |
| `infos/README.md`, `SESSION_HANDOFF_PROMPT.md` | Del "starter pack" previo a Git |
| `infos/tools/sync/ts_sync.py` | Protocolo de claims/STATE_HASH retirado (P-28). Busca `docs/ai-context` y ya no funcionará desde aquí |
| `infos/tools/audit/Audit-GodotProject.ps1` | Nunca ejecutado; sustituido por `audit/` |
| `Apply-DropD.ps1`, `tools/Update-Project.ps1`, `tools/manifest.json` | Instaladores de "drops" ZIP previos a Git |
| `.gemini/commands/ts/skill.toml` | Dependía del generador de skills inexistente |
