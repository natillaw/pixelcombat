# Informe — Expediciones reales, control directo, autonomía, fog of war y pueblo vivo

Fecha: 2026-10-31 · Godot **4.6.2** (el proyecto declara 4.7) · Sin repositorio Git: no hay commit ni ZIP.
Decisiones del dueño registradas para este trabajo: **D-051** (obediencia mínima), **D-052** (esquiva por tirada), **D-053** (enfocar = controlar), **D-054** (daño del proyectil al impactar), **D-055** (cohesión visual mediante copias), **D-056** (alcance autorizado).

## 1. Estado inicial (auditado, no supuesto)

| Problema reportado | Causa encontrada en el código |
|---|---|
| Mapas pequeños, todo en 2 min | Piso 1 = 44×40 celdas (~30 s de punta a punta). Presupuesto de **4 enemigos**, colocados de 1 en 1 o de 2 en 2 en las salas **más cercanas a la entrada** (`ProceduralMap._try_generate`). |
| Un héroe limpia todo | Todos los enemigos con las mismas stats (60 PV, 12 ATK), sin grupos ni roles. |
| Esquiva perfecta | `_try_dodge`: salía **siempre** del círculo telegrafiado si quedaban ≥0,15 s. Además, los arqueros hacían *kiting* (`_kite`) en pleno wind-up, otra esquiva gratuita. |
| Información gratis con zoom | No existía el fog of war; la vista M mostraba el mapa entero. |
| Héroes ausentes del pueblo | El código del pueblo **funciona** (8 héroes aparecen, caminan y hacen actividades distintas, verificado). Causas reales: (1) una partida nueva tiene **0 héroes** y el pueblo sale vacío sin explicación; (2) quien duerme o trabaja dentro de un edificio se oculta sin ninguna señal, así que de noche el pueblo parece vacío. La hipótesis de que el escuadrón se quedaba en "deployed" era **falsa**: `after_expedition` ya los devuelve a "idle". |
| Persistencia de pisos | Solo se guardaba la semilla y el piso se regeneraba al cargar (F-014): cualquier cambio en el generador habría alterado los pisos guardados. |

## 2. Mapas

- `TowerExpedition.FLOORS`: piso 1 de 92×80 hasta piso 9 de 124×106; el piso 10 (jefe) mide 90×80. Presupuesto de enemigos de 16 a 38, con criaturas de roles mezclados.
- **Generador v2** (`ProceduralMap.GEN_VERSION = 2`): el número de salas crece con el área (14–40). Las salas forman una cadena desde la entrada hasta el objetivo y se dividen en zonas por su posición en la cadena:
  - **Entrada:** sin enemigos.
  - **Exploración:** grupos de 2–3 y patrullas.
  - **Peligro:** grupos de 3–4, emboscadas, guardianes con tesoro y patrullas.
  - **Objetivo:** guardado; en el piso 10, el jefe espera aquí.
  - Algunas salas tranquilas tienen pequeños tesoros. Hay rutas alternativas por corredores extra.
- **Persistencia (D-004/D-026):** los pisos v2 se guardan como snapshot completo (`to_snapshot` / `from_snapshot`: celdas, encuentros, zonas, objetivos). Los pisos guardados antes se siguen construyendo con el generador 1 a partir de su semilla, así que **no cambian**. Guardado **v9 → v10** con migración y prueba.
- **Consecuencia:** una cuenta que ya tenga pisos generados los conserva pequeños, porque D-026 prohíbe regenerarlos. Solo los pisos nuevos son grandes. Si quieres pisos v2 en tu cuenta actual, la decisión es tuya (partida nueva o una regla de "regenerar pisos no visitados").

## 3. Duración (medida con `tools/measure_expedition.gd`, 3 semillas por piso, héroe a 88 px/s)

| Piso | Celdas | Encuentros / criaturas | Hasta el 1.er encuentro | Directo al objetivo | Recorrer todas las salas |
|---|---|---|---|---|---|
| 1 | 92×80 | 6–7 / 16 | 18–26 s | 62–67 s | **7,0–8,8 min** |
| 5 | 108×92 | 12–13 / 28 | 20–24 s | 69–79 s | **11,8–13,1 min** |
| 10 | 90×80 | 5–6 / 14 | 18–21 s | 59–64 s | 6,6–7,1 min |

Solo cuenta caminar. A eso se suman combates (con grupos, alertas y curanderos), repliegues y el desconocimiento del camino por la niebla. Las misiones "combat" exigen encontrar a todos. **No verificado:** la duración real de una partida jugada a mano; la estimación de 10–30 min se basa en estas cifras, no en una sesión cronometrada.

## 4. Dificultad sin inflar la vida

- `scripts/data/enemy_defs.gd`: stats y **rol** por criatura.
  - **Enjambre:** rata, murciélago (28/22 PV, rápidos).
  - **Cuerpo a cuerpo:** slimes, goblin.
  - **Bruto:** orc_brute, gólem (320 PV).
  - **Guardia:** hobgoblin (correa de 160 px alrededor de su puesto).
  - **A distancia:** araña y seta morada (golpean a 150 px con proyectil y se apartan); aplican veneno.
  - **Soporte:** setas roja/azul (curan un 20 % al aliado más herido cada 5 s y se quedan detrás).
  - Además: +8 % de vida y daño por piso.
- **Encuentros:** herir o ver a uno alerta a todo su grupo (que entonces percibe a ×1,6). Hay emboscadas ocultas hasta que un héroe pasa a 90 px, patrullas que caminan entre salas y guardianes que vuelven a su puesto.
- **Composición:** cada grupo empieza con un combatiente de primera línea y lleva como mucho un curandero. La decisión de a quién atacar primero (por ejemplo, al curandero) es real.
- **Métrica real** (`smoke_expedition`): un héroe de nivel 1, solo, contra slime + 2 ratas del piso 1 **gana, pero con 56/130 PV**. Antes no recibía daño.

## 5. IA: fin de la esquiva perfecta (D-052)

- Una tirada **por golpe** (no por tick) contra `CombatRules.auto_dodge_chance(AGI, nivel) = 0,0015 × AGI × (nivel − 1)`, con tope del 30 %. **A nivel 1 es 0.** Solo se reacciona si quedan ≥0,25 s de wind-up.
- El *kiting* ya no ocurre durante el wind-up del enemigo y tiene un enfriamiento de 2,5 s.
- Las pruebas lo confirman: nivel 1 nunca esquiva; un veterano con AGI 99 esquivó 13 de 60 golpes, y un fallo no se reintenta.
- D-037 sigue vigente: no hay fallo aleatorio de golpes; lo que se tira es si el héroe reacciona.
- **D-054:** el daño de flechas, orbes y proyectiles de habilidad (incluidos los de enemigos) se aplica al **llegar**. Si el objetivo murió mientras el proyectil volaba, no hace nada. El daño pendiente avanza con el reloj de la simulación, así que es determinista.

## 6. Control directo tipo campeón (D-053)

- **Tomar el control:** 1–5 (Shift+1–5 para los héroes 6–10 en raids) o un clic sobre un héroe. La cámara le sigue con un poco de anticipación.
- **Autoridad:** `SandboxHero.controller = "player" | "ai"` (más `order` para las órdenes). Con control del jugador, la autonomía **no** esquiva, no hace kiting y no persigue fuera de su alcance. En reposo solo ataca lo que tiene a tiro, como un campeón de MOBA.
- **Movimiento:** clic derecho para mover o atacar; mantenerlo pulsado hace que el héroe siga al cursor (repetición cada 0,12 s).
- **Habilidades:** *quick cast con indicador*. Al mantener Q/W/E/R se ven el alcance real y el área en el cursor (`SkillAimView`); al soltar se lanza:
  - las de área, al suelo (limitadas al alcance);
  - las dirigidas, al enemigo visible más cercano al cursor.
  - Son **las mismas habilidades y reglas** que usa la IA; solo cambia quién decide.
- **Identidad por clase:** el arquero controlado usa su alcance de 190 px, su proyectil y su línea de visión, igual que el autónomo.
- **Cambio de héroe:** no reinicia cooldowns ni estados (probado). Tab devuelve a todos a la autonomía.
- **Obediencia (D-051):** con Obediencia < 25 no se le puede tomar el control ni darle órdenes; aparece "ignores you (Obedience N)". Es determinista.

## 7. Autonomía con personalidad

- `HeroTables.AGGRESSION` (rasgos) da un temperamento de −3 a 3:
  - **Correa respecto al héroe controlado:** de 90 a 330 px.
  - **Radio de persecución:** 260 ± 30 px por punto.
  - **Umbral de repliegue:** 35 % de vida ± 8 % por punto. Por debajo, se repliega hacia el héroe controlado o el centro del grupo y lo dice ("falling back").
- **Exploradores** (ranger, rogue o rasgo Curious): sin enemigos a la vista y con más del 60 % de vida, se asoman a la niebla cercana (como mucho 10 celdas y siempre dentro de su correa). No se adentran solos en el mapa.
- Los que no controlas acompañan al héroe controlado en vez de quedarse quietos (probado).
- **Pendiente (honesto):** no hay memorias, relaciones ni diálogo que influyan en el combate (P-24). Trust y Composure aún no afectan a la autonomía.

## 8. Fog of war

- **Datos** (`FogMap`): un byte por celda, sin nodos, con tres estados: nunca visto / explorado / visible. La visión se calcula desde los héroes con radio (6 celdas; los exploradores, 8; un caído, 2) y línea de visión por la cuadrícula (los árboles tapan, pero el borde del bosque se ve). Se actualiza cada 0,15 s.
- **Dibujo** (`FogView`): **una** imagen de un píxel por celda, estirada sobre el mapa con filtro lineal (bordes suaves y una sola llamada de dibujo). Opaca en lo no visto y atenuada en lo explorado.
- **Reglas:**
  - Las criaturas fuera de la visión están ocultas.
  - No se pueden apuntar con habilidades ni con clic.
  - Los héroes no luchan contra lo que no ven.
  - No salen números flotantes de la niebla.
  - **La cámara no da visión**: probado con la vista M y zoom al máximo.
- **Persistencia:** las celdas exploradas se guardan por piso en bits + base64 (piso 1: ~1,2 KB) dentro de `tower_maps[floor]["explored"]`. El mapa en sí se reconstruye del snapshot. Las criaturas no se guardan como vistas: la información dinámica nunca es gratis.
- La HUD muestra "explored N %".

## 9. Pueblo

- Si no hay héroes, aparece el aviso "Nobody lives here yet: summon your first heroes…".
- Sobre cada edificio, una etiqueta con quién está dentro ("Zz 3" durmiendo, "inside 2" trabajando), así que de noche el pueblo ya no parece abandonado.
- Probado: cada héroe vivo tiene cuerpo en el pueblo, y un héroe muerto (permadeath) desaparece.

## 10. Cohesión visual (D-055)

- **Auditoría** (`tools/art_cohesion.gd`): el contorno de los héroes tiene luminosidad **0,12** (#2a1657); el de las criaturas, mediana **0,37** y máximo **0,68** (el gólem). La diferencia es real.
- **Solución:** 183 **copias** de las hojas usadas con el contorno exterior oscurecido hacia el color de los héroes (conserva un 25 % del tono propio), en `assets/processed/outline/` (968 KB). Pasan a ~0,13. Los originales y los héroes no se tocan. `EnemySprites.USE_COHESION_COPIES` vuelve a los originales.
- Licencias: Voxel Dungeon es CC0 y Pixel Crawler permite uso comercial sin reventa. Guía para futuros assets en `docs/specs/ART_DIRECTION.md`.
- **No verificado:** el efecto en partida a la escala normal; solo se ha visto en una captura estática.

## 11. Rendimiento (headless, máquina de desarrollo; **no** en el Ryzen 5 5600GT)

| Medida | Resultado |
|---|---|
| Tick con 5 héroes y 74 criaturas en un mapa de 120×104 (`bench_feel`) | media 0,17 ms, pico 7,3 ms |
| Actualización de visión (5 héroes, radio 8) | 1,1 ms cada 0,15 s |
| Refresco de la imagen del fog | 1,5 ms |
| Generación de un piso | 5–8 ms |
| Bake del arte del piso 1 | 0,64 s; textura de 4416×3840 en RGB8 (~49 MB; antes del cambio, 65 MB en RGBA) |

Sin medir: FPS reales con dibujado, memoria de GPU en la iGPU.

## 12. Pruebas ejecutadas

- `tools/Run-Tests.ps1`: **22/22 PASS** (las 21 de antes + la nueva `expedition`).
- `tests/smoke_expedition.tscn` (31 comprobaciones): generador v2, zonas, encuentros, snapshot JSON, legado v1, migración v9→v10, fog con overview, exploradores, pack/unpack, control 1–5, cambio sin perder cooldowns, obediencia, habilidad apuntada al suelo, curandero, rango, tamaños, alerta de grupo, dificultad del héroe solo, pueblo y héroe muerto.
- Tests existentes actualizados por las decisiones nuevas (no para esconder fallos):
  - `smoke_orders`: esquiva por tirada y revivir correctamente al enemigo de prueba.
  - `smoke_mission`: la bola de fuego hace daño al llegar.
  - `smoke_sandbox`: los demás siguen al héroe controlado.
  - `smoke_combat_core`: el enemigo clicado debe estar dentro de la visión.

## 13. Pendiente

- Jugar una expedición completa a mano y cronometrarla; ajustar los números con esa experiencia.
- Minimapa / mapa de lo explorado; puntos de interés con nombre; recursos recolectables (vertical slice).
- Trust, Composure, memorias y relaciones en la autonomía; diálogo por eventos (P-24).
- Raids de 10: hay teclas (Shift+1–5), pero no contenido ni arena.
- La refresco del fog recorre toda la imagen; si en la iGPU pesa, se puede actualizar solo lo que cambia.
- Decidir qué hacer con los pisos v1 ya guardados en tu cuenta.
