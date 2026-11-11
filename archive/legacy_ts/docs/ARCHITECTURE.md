# Arquitectura técnica

Describe el código **tal como está** (commit `509218b`). Los problemas conocidos están en `audit/CODE_AUDIT.md`; la arquitectura objetivo, en `docs/DEVELOPMENT_ROADMAP.md` (bloque C).

## Arranque
`project.godot` → `scenes/main.tscn` (un `Control`) → `scripts/main.gd`. Este crea el fondo, la barra de monedas y cambia de pantalla con `show_screen(nombre)`. Toda la UI se construye por código (D-019); no hay escenas de UI.

## Módulos
| Carpeta | Contenido | Rol |
|---|---|---|
| `scripts/autoload/game.gd` (`Game`) | Monedas, roster (`heroes: id → HeroData`), party de 5, memorial, HQ, edificios, mapas de torre, guardado/carga/migración | Estado global y fachada. Única fuente de verdad del progreso. Emite `changed` |
| `scripts/core/` | `HeroData` (modelo + XP/stats + social + serialización), `HeroGenerator` (semilla → héroe), `Gacha` (rareza + pity), `SpriteComposer` (apila capas de Caz), `ProceduralMap` (salas + pasillos + A*), `TowerExpedition` (tabla de pisos 1-10) | Lógica sin nodos (salvo `ProceduralMap`, que lee `Game.PARTY_SIZE`) |
| `scripts/data/` | `HeroTables` (clases, rasgos, pasivas, profesiones, trasfondos, nombres, reglas por estrella), `SummonConfig` (banners validados) | Datos estáticos. **Añadir contenido aquí, no en la UI** |
| `scripts/sandbox/` | `SandboxScreen` (misión + simulación + input + cámara + HUD), `SandboxHero`, `SandboxEnemy`, `SandboxMap` (mapa fijo), `SandboxMapView`, `MapTiles`, `CombatRules`, `SkillTables`, `HeroAnim`, `CombatVFX`, `EnemySprites`, `HeroChatter`, `SandboxRelic`, `HQWorld` | Juego en tiempo real |
| `scripts/ui/` | Pantallas (`MainMenu`, `SummonScreen`, `RosterScreen`, `PartyScreen`, `HQScreen`, `MemorialScreen`) + widgets + `UIKit` (tema/estilos) | Presentación; llama a métodos de `Game` y escucha `changed` |
| `tests/` | 6 `--script` (SceneTree) + 6 escenas `smoke_*` | Ver `tools/Run-Tests.ps1` |
| `tools/` | `Run-Tests.ps1`, `Import-Asset.ps1` (registro de assets), `prepare_crawler.py`, `contact_sheet.py`, `scan_packs.py`, `unpack_assets.py` | Herramientas |

## Flujo de datos
UI → `Game.<acción>()` → modifica el estado → `_commit()` → `save_game()` (si `autosave`) → `changed.emit()` → las pantallas se reconstruyen.
Misión: `SandboxScreen` crea `SandboxHero` a partir de `HeroData` del party (o un escuadrón de prueba si el party no está completo) → `tick()` en `_physics_process` → muerte → `Game.record_death()` → éxito → `Game.grant()`.

## Persistencia
- Archivo: `user://save.json`. `SAVE_VERSION = 5`.
- Escritura atómica: `.tmp` → verificar JSON → copia `.bak` → renombrar. Carga con respaldo `.bak`.
- Migraciones en `Game._migrate` (v1→v5). Héroes guardados como snapshot completo (`HeroData.to_dict`). Semillas en hexadecimal (64 bits).
- Pisos de torre: semilla + tamaño (+ `grid_rows` que no se usan al cargar) — pendiente de cambiar a snapshot (F-014).
- **Regla:** cualquier campo nuevo → subir `SAVE_VERSION`, migración y prueba.

## Sprites de héroes
`SpriteComposer` mezcla en memoria las capas PNG de `assets/sprites/<Capa>/<estilo>_<color>.png` (hoja 576×384, frames de 48 px) según `HeroData.appearance`. Los PNG originales no se tocan (D-023). Animaciones: `SpriteComposer.ANIMS` + tweens en `HeroAnim`.

## Convenciones
- GDScript tipado. Cuidado con los Variant: `var x: Tipo = arr[0]`, no `:=` desde un Array sin tipo.
- `class_name` únicos; los scripts nuevos necesitan `--import` antes de que los tests los vean.
- Indentación: hoy es mixta (tabs en 9 archivos). Para archivos nuevos se usan 4 espacios y en los existentes se respeta el estilo del archivo; la normalización es una tarea aparte (F-024).
- Los lambdas pueden modificar miembros, pero no locales capturadas.
- Números de balance en `CombatRules`, `SummonConfig`, `HeroTables`; nunca en la UI.

## Puntos de acoplamiento conocidos
`Game` es un "god object"; `SandboxMap` y `ProceduralMap` duplican la API sin interfaz común; `hq_facilities` vs `town_buildings`; `events` vs `memories`. Ver `audit/CODE_AUDIT.md` §3-4.
