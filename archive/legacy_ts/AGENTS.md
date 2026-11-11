# AGENTS.md — reglas comunes para cualquier agente (Claude, Gemini, otros)

El repositorio Git es la única fuente de verdad; la memoria del chat no lo es.

## Reglas duras del juego (nunca violarlas)
- Tiempo real **sin pausa ni cámara lenta** (D-014).
- Escuadrón de **5** héroes: el **Máster** (personaje del jugador, siempre en el hueco 1 y el único controlado) + 4 autónomos. Tab da la vista de grupo, G selecciona el escuadrón (D-017, D-080; 1-5 ya no cambia de héroe).
- Las órdenes directas **nunca** se rechazan al azar (D-016).
- **Muerte permanente** y memorial; sin resurrección (D-011). Única excepción: el Máster vuelve herido (D-080).
- Los héroes **nunca se re-generan** al cargar; se guarda el snapshot (D-004).
- Trust, Obedience y Composure son valores separados, con cambios deterministas (D-016).
- **No modificar los sprites de héroes de Caz** (`assets/sprites/**`) (D-023).
- Solo assets gratuitos con licencia registrada en `docs/ASSET_REGISTRY.md` (D-024).
- IP original; nombres prohibidos en `docs/specs/REFERENCE_INSPIRATION.md` (D-002).
- Script-first / "no-hands Godot": todo por script, comando o headless. Nunca pedir al dueño que use el editor (D-009, D-019).
- **Estabilizar antes de ampliar** (D-025): no añadir sistemas nuevos sin la tarea correspondiente en `docs/DEVELOPMENT_ROADMAP.md`.

## Autoridad cuando los documentos no coinciden
`docs/DECISIONS.md` > `docs/specs/*` > `docs/MASTER_PROJECT.md` > `docs/DEVELOPMENT_ROADMAP.md` > chat.
Para saber qué *existe*, manda el código ejecutado y probado; para saber qué *debe existir*, manda la spec. Un conflicto se reporta al dueño, no se resuelve en silencio.
Las ideas en estado **PENDIENTE** o **CANDIDATA** no se implementan: se pregunta. Las **SUSTITUIDAS** no se implementan nunca.
`docs/archive/` es historia: no se lee salvo petición expresa.

## Evidencia
- No afirmes que algo funciona sin ejecutarlo: indica el comando y la salida (o "NO VERIFICADO").
- Actualiza `docs/IMPLEMENTATION_STATUS.md` solo con lo verificado.
- Si cambias el formato de los datos del héroe o del guardado: sube `SAVE_VERSION`/`HeroGenerator.VERSION`, escribe la migración y su prueba.

## GDScript (lecciones aprendidas)
- Archivos nuevos: 4 espacios. En archivos existentes, respeta el estilo del archivo (hoy hay tabs en 9 de ellos).
- Tipa las variables. Nada de `var x := arr[0]` cuando `arr` es un Array sin tipo: escribe `var x: Tipo = arr[0]`.
- No asignes un literal de array tipado directamente a un campo tipado; usa `.append()` o construye antes el array tipado.
- `class_name` únicos. Los scripts nuevos necesitan `godot --headless --path . --import` antes de que los tests los vean.
- Los lambdas pueden cambiar miembros, pero no variables locales capturadas.
- Números de balance en datos (`HeroTables`, `SummonConfig`, `CombatRules`), nunca en la UI.

## Seguridad y Git
- Nunca escribas secretos (claves, tokens, `.env`) en ningún archivo.
- Pregunta antes de: borrar archivos, sobrescribir varios archivos a la vez, `git push`, `git reset`, merges a `main` o tocar algo fuera del repo.
- Una rama por tarea; commits pequeños que citen el ID (F-0xx, P-xx, D-xxx).
