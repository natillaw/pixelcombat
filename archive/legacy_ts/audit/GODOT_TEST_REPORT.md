# Informe de Godot y pruebas

## 1. Disponibilidad
- `godot`/`godot4` no están en el contenedor.
- Intenté descargar `Godot_v4.7.1-stable_linux.x86_64` a la carpeta temporal de la sesión (fuera del repo) y ejecutar una copia del proyecto; la acción fue **denegada por el sistema de permisos**. No insistí.
- **No se ha ejecutado ninguna prueba ni importación.** Nada de este informe afirma que el juego funcione.
- No hay evidencia de ejecución en el repo: `tools/last_test_run.txt` está en `.gitignore`; las afirmaciones "ALL PASS" de `SESSION_SUMMARY.md` y `HANDOFF_LOG.md` no adjuntan salida.

## 2. Suites registradas (`tools/Run-Tests.ps1`, 12)
Criterio de PASS del runner: exit 0 + marcador + sin "FAIL  " + sin "SCRIPT ERROR". Resultado previsto por **trazado estático** del código actual:

| Suite | Archivo | Previsión | Motivo |
|---|---|---|---|
| core | `test_core.gd` | Sin fallo detectado | — |
| summons v2 | `test_summons.gd` | Sin fallo detectado | §11 es tautológica (F-008) |
| ui smoke | `smoke_ui.tscn` | Sin fallo detectado* | *Si F-001 rompe la resolución de clases globales, podría fallar |
| sandbox | `smoke_sandbox.tscn` | **FALLA** | El primer héroe que llega a `GOAL_CELL` recoge el relicario → misión SUCCESS → `tick()` deja de simular; "order only affects the selected hero" no puede cumplirse (F-003) |
| memorial v3 | `test_memorial.gd` | Sin fallo detectado | — |
| combat | `smoke_combat.tscn` | **FALLA** | `SandboxScreen.ENEMY_CELLS` no existe → error de compilación (F-004) |
| mission | `smoke_mission.tscn` | **FALLA** | Línea 48: recoger el relicario completa la misión y entrega la recompensa; fallan "another hero can recover the dropped relic" (l.61), "panel shows … [RELIC]" (l.67) y "placeholder reward granted once" (l.74) (F-003) |
| animation | `smoke_anim.tscn` | Sin fallo detectado | Solo comprueba nombres/locks, no aspecto visual |
| art | `smoke_art.tscn` | Sin fallo detectado | Depende de que los PNG de Pixel Crawler estén importados |
| simulation | `test_simulation.gd` | Sin fallo detectado | Comprueba producción del HQ pero no el efecto de profesiones |
| deep systems | `test_deep_systems.gd` | **FALLA** | `g.memorial[0]["id"]` → clave inexistente (F-005) |
| procedural | `test_procedural.gd` | No verificable | `ProceduralMap` lee `Game.PARTY_SIZE`; en modo `--script` la disponibilidad del autoload debe comprobarse. Comprobaciones débiles (`>= 0`) |

## 3. Qué verifican realmente las pruebas (un PASS no prueba la funcionalidad)
- **Modo Torre:** ninguna prueba crea `SandboxScreen` con piso > 0 → F-002 invisible para la batería.
- **HQ explorable:** ninguna prueba instancia `HQWorld` → F-001 invisible (salvo como error global).
- **Escena principal:** ninguna prueba carga `scenes/main.tscn`.
- **Determinismo del generador entre versiones:** la prueba se reduce a la constante de versión.
- **Persistencia de pisos:** "persistent across re-runs" usa la misma instancia de `Game`; no guarda/carga.
- **Profesiones:** ninguna prueba verifica que afecten a nada.
- **Visual:** headless no renderiza; animaciones y tiles nunca se han validado visualmente por un agente.

## 4. Pruebas faltantes recomendadas
1. Arranque de `main.tscn` sin errores de script (smoke de boot).
2. `SandboxScreen.new(1..10)` con `ProceduralMap`: 5 héroes, enemigos, ruta spawn→objetivo, 600 ticks sin errores.
3. Misión: el relicario NO está en la salida; recoger ≠ completar.
4. `HQWorld` instanciable.
5. Promoción de un héroe `class.none` a 3★ (regresión F-007).
6. Hero "golden": semilla fija → `to_dict()` exacto guardado en un fixture (detecta F-008).
7. Carga de un guardado v4 y v5 reales (fixtures JSON).
8. Capacidad de roster con mensaje correcto.

## 5. Comandos para ejecutar en Windows (PowerShell)
```powershell
# 0) Versión real del motor
& "C:\ruta\Godot_v4.x-stable_win64_console.exe" --version
# 1) Importación (registra class_name; muestra errores de compilación)
& "C:\ruta\Godot_v4.x-stable_win64_console.exe" --headless --path . --import 2>&1 | Tee-Object import_log.txt
# 2) Batería completa (escribe tools\last_test_run.txt)
powershell -ExecutionPolicy Bypass -File tools\Run-Tests.ps1 -Godot "C:\ruta\Godot_v4.x-stable_win64_console.exe"
# 3) Arranque de la escena principal durante 5 s (detecta F-001)
& "C:\ruta\Godot_v4.x-stable_win64_console.exe" --headless --path . --quit-after 300 2>&1 | Tee-Object boot_log.txt
# 4) Comprobación de scripts sin ejecutar (Godot 4.x)
& "C:\ruta\Godot_v4.x-stable_win64_console.exe" --headless --path . --check-only --script res://scripts/sandbox/hq_world.gd
```
Usar el ejecutable `_console.exe` para que la salida llegue a la terminal. Devolver `tools\last_test_run.txt`, `import_log.txt` y `boot_log.txt`.

## 6. Clasificación de errores (cuando se ejecute)
- **Proyecto:** F-001…F-005, F-007 (esperados).
- **Motor/versión:** posibles avisos si el binario no es 4.7 (`config/features`), formato `unique_id` en `main.tscn` (≥ 4.6).
- **Entorno:** headless sin renderizador (no valida visuales); rutas `user://` distintas en Windows.
