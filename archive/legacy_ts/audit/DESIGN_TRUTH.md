# Fuente de verdad del diseño (reconstrucción)

**Regla aplicada:** `DECISIONS.md` > specs > Bible > Roadmap (orden de autoridad del propio proyecto, `infos/AGENTS.md`). Donde una decisión escrita choca con evidencia posterior (código del 10-29, prompt del usuario del 10-30), se marca **PENDIENTE DE CONFIRMACIÓN** en lugar de elegir. No se inventa ninguna decisión nueva.

**Fuentes abreviadas:** `DEC` = DECISIONS.md · `CTRL` = CONTROL_AND_REALTIME_MISSIONS.md · `SUM` = SUMMONS_AND_HERO_GENERATION.md · `CMB` = COMBAT_AND_STATS.md · `BIB` = PROJECT_BIBLE.md · `GAPS` = DESIGN_GAPS.md · `PM` = prompt maestro de auditoría del usuario (2026-10-30) · `IMG-HQ`/`IMG-MAP` = imágenes de referencia en `infos/`.

**Estados:** I = implementado · ID = implementado pero defectuoso · P = parcial · N = no implementado · D = solo diseñado · NV = no verificable.

## 1. Decisiones firmes (sin contradicción)
1. Juego original, sin copiar expresión de *Pick Me Up* (D-002); free-first, sin APIs de pago como dependencia (D-001).
2. 2D pixel art (D-007). Héroes de **Tiny Pixel Fantasy – Character Generator (Caz)**, no se redibujan ni sustituyen; animaciones faltantes se hacen en código (D-020; PM §6).
3. RTS híbrido en tiempo real **sin pausa ni cámara lenta** (D-014).
4. Escuadrón de **5** héroes; roster de prueba ≥ 6 (D-017).
5. Teclas 1-5 enfocan héroe, Tab vista de grupo, G selecciona escuadrón (D-015).
6. Órdenes directas nunca se rechazan al azar (D-014, D-016).
7. Trust, Obedience, Composure separados; cambios deterministas (D-016).
8. Muerte permanente + memorial; sin resurrección en el prototipo (D-011).
9. Identidad persistente, sin re-roll al cargar; guardar snapshot, no solo semilla (D-004).
10. Flujo script-first / "no-hands Godot" (D-009, D-019).

## 2. Por sistema

| Sistema | Decisión vigente | Evidencia documental | Evidencia en código | Estado | Contradicciones | Dependencias | Riesgos |
|---|---|---|---|---|---|---|---|
| Gameplay (bucle) | Refugio → escuadrón → misión en piso de torre → resultados → refugio | BIB "Core loop" | `main.gd` menú → sandbox → resultado → menú | P | Sin selección de piso | Misiones, Torre | Bucle cerrado solo en piso 0 |
| Combate | Tiempo real, rango/cadencia/telegrafías, sin rangos ni turnos | D-014, CMB | `combat_rules.gd`, `sandbox_hero.gd`, `sandbox_enemy.gd` | P | Pasivas con texto de turnos (C-13) | Atributos, skills | Fórmulas provisionales (D-012) |
| Control RTS híbrido | Mover/atacar/attack-move/mantener/seguir/interactuar/retirada; cámara 1-5/Tab/G | CTRL §2-5 | Solo mover, stop, skill (Q); cámara y selección | P | — | UI de órdenes | Spec mucho mayor que lo construido |
| Autonomía de héroes | Navegación y ataque básico autónomo; skills solo por el jugador | CTRL §6 | `combat_tick` elige enemigo más cercano | I (NV) | — | Combate | Sin evitación de peligros |
| Personalidades | 8 dimensiones 0-100 + arquetipo + 1-3 rasgos | SUM §6 | 16 rasgos con modificadores de stats y Trust/Obedience; sin dimensiones | P | — | Generador | — |
| Historia individual | Ganchos de trasfondo, metas, miedos | SUM §5 | 12 trasfondos de texto fijo | P | — | Generador | Poca variedad |
| Relaciones | Vínculos/rivalidades por pares | D-016, SUM §7 | `HeroData.relationships`, actualizado por HQ y muerte | P | Estado "unfamiliar" inalcanzable | Eventos | — |
| Confianza y obediencia | Valores visibles, sin rechazo de órdenes | D-016 | Campos + ledger; solo `ally_fell` −2 en juego | P | — | Eventos de misión | — |
| Memoria | Registro estructurado de eventos | SUM §8 | `memories` (cap 50) + `events` (cap 100) | P | Dos registros paralelos | — | Duplicación |
| Profesiones | **PENDIENTE**: vida pasada con bonus de base | HANDOFF 00:15/00:26 (Gemini); PM | `HeroTables.PROFESSIONS` (20); se muestra en roster/HQ | P (sin efecto) | GAPS 20 las difiere; no hay decisión | HQ, economía | Docs afirman efecto inexistente |
| Clases y promociones | Promoción por tiers con desbloqueos (D-018); clases base + avanzadas | D-018, HANDOFF 23:41 | 6 clases base; `PROMOTION_CLASS_POOL` vacío; promoción = +1★ | ID (F-007) | C-03, C-04, C-05 | Skills, equipo | Crash en promoción |
| Invocación | Banners data-driven, odds visibles, pity, log con semilla | SUM §2-3, §10 | `summon_config.gd`, `gacha.gd`, `Game.pull` | I (NV) | Reproducibilidad rota (F-008) | Generador | — |
| Rarezas | Etiqueta de presupuesto, no personalidad | SUM §4 | 1-5★ con capas visuales/rasgos | I | C-06 nombres | — | — |
| Muerte y legado | Muerte permanente, memorial, "legado" | D-011, PM | `record_death`, `MemorialScreen`; secretos no heredados (test) | P | "Legado" no definido en docs | Persistencia | — |
| Expediciones | **PENDIENTE** | BIB pilar 4; PM | Solo `TowerExpedition` (tabla) | D | — | Torre, economía | Término sin spec |
| Torre de 100 pisos | **PENDIENTE DE CONFIRMACIÓN** | PM; REFERENCE #15 "deferred" | Ninguna | N | C-01 | Generación procedural | Sin decisión escrita |
| Primeros 10 pisos (alcance inicial) | **PENDIENTE DE CONFIRMACIÓN** | PM; "Mega Prompt" (no en repo) | `TowerExpedition.FLOORS` 1-10 (nombre, tipo, tamaño, nº enemigos) | P / ID (F-002) | C-01 | Mapa, misiones | Inalcanzable desde la UI |
| Generación procedural | **PENDIENTE DE CONFIRMACIÓN** (D-003 dice diferida) | D-003 vs PM, IMG-MAP | `ProceduralMap` salas+pasillos, validación de alcance | ID | C-01 | Interfaz de mapa | Mapas guardados como semilla (F-014) |
| Biomas | **PENDIENTE** | BIB "theme families" (etiquetas), IMG-MAP (agua, hierba, lava, magia), PM | Ninguno ("Stone Crypt" único tema) | N | — | Tiles, generación | — |
| Misiones | Objetivos variados: investigar, rescatar, defender, sobrevivir, recuperar, extraer | D-014, CTRL §9 | Solo "Recover the relic"; tipos en tabla sin lógica | ID (F-003, F-020) | — | Mapa, IA | — |
| Eventos | **PENDIENTE** (eventos de misión que cambian objetivos: CANDIDATE) | REFERENCE #9, PM | Ninguno | N | — | Misiones | — |
| Secretos | **PENDIENTE** | PM; SESSION_SUMMARY | `discover_secret` solo llamado desde tests | P (no integrado) | — | Misiones | — |
| Jefes | Fases, telegrafías, mecánicas de arena, no solo HP | D-014, CTRL §10 | Piso 10 etiquetado "boss"; sin jefe | N | — | Combate | — |
| Recompensas | Placeholder de misión; materiales de promoción | D-018, T-020 | +100 gemas, +1 piedra en éxito | P | — | Economía | — |
| Inventario | Persistir equipo/inventario | BIB alcance prototipo | Ninguno | N | — | Equipo | — |
| Equipo | Capas que reemplazan la base; stats solo de items | D-021 | Ninguno (capa `held` es cosmética) | N | — | Sprites, datos | — |
| Loot / Afijos / Sets | **PENDIENTE** | PM únicamente | Ninguno | N | — | Equipo | Sin spec |
| Crafting | **PENDIENTE** (BIB lo lista; GAPS 20 lo difiere) | BIB, PM | Ninguno | N | C-02 | Economía, profesiones | — |
| Economía / Recursos | Fuentes, sumideros y topes rastreados | BIB | gemas, piedras, libros, comida/materiales/medicina | P | Dos economías desconectadas | HQ | Sin sumideros para comida/medicina |
| Headquarters | **PENDIENTE**: IMG-HQ exige un HQ "in-game y no un simple menú" | IMG-HQ, PM, BIB "refuge" | `HQScreen` (menú) + `HQWorld` (no compila, F-001) | ID | — | Tiles, sprites | — |
| Construcción / Instalaciones | **PENDIENTE** | PM, REFERENCE #8 | `town_buildings` + `upgrade_building` sin UI; `hq_facilities` niveles sin uso | P (paralelo) | — | HQ | Sistemas duplicados |
| Producción | **PENDIENTE** | PM | Cantidades fijas por trabajador | P | C-12 | Profesiones | — |
| Animaciones | En código a partir de la hoja de Caz (D-020) | D-020 | `hero_anim.gd`, `SpriteComposer.ANIMS` | I (NV visual) | — | Sprites | No verificadas visualmente |
| VFX | Efectos de packs gratuitos | ASSET_MANIFEST, T-027 | `CombatVFX` (ruta rota), arcos dibujados | ID (F-012) | — | Assets | — |
| UI | Panel contextual con vitals, skills, órdenes, T/O/C | CTRL §4 | Panel de texto; botones Skill/Stop | P | — | — | — |
| Guardado | Atómico, versionado, migraciones | D-004, SUM §5 | `game.gd` v5 + `.bak` | I (NV) | Torre guardada como semilla | — | — |
| Rendimiento | No especificado | — | Mapas de hasta 160×160 celdas | NV | — | — | Textura 7680² (F-014) |
| Progresión | XP por libros, nivel, promoción por estrellas | código | `train`, `promote` | P | C-05 | — | — |
| Audio | Efectos + 1-2 pistas (T-028) | TASK_BOARD | Ninguno | N | — | — | — |

## 3. Decisiones que el usuario debe confirmar (no se han inventado)
1. ¿Generación procedural de pisos/biomas pasa a ser requisito actual (anula D-003/D-014 en ese punto)?
2. ¿Torre de 100 pisos como meta, con 10 pisos como primer alcance?
3. ¿HQ explorable (vista in-game, IMG-HQ) sustituye al menú?
4. Conjunto de clases definitivo (C-03) y clases avanzadas (C-04).
5. 5★/80 niveles vs 7★/70 niveles (C-05) y nombres de rareza (C-06).
6. Profesiones: efecto real en producción/crafting.
7. Alcance y especificación de inventario, loot, afijos, sets, crafting, expediciones, eventos, secretos y "legado".
8. ¿Se mantiene el protocolo multiagente (claims, STATE_HASH) o se simplifica?
