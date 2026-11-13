# Roadmap — PixelCombat

Action RPG 2D pixel art. Combate tipo **Drakantos + Battlerite**, torre de 100
pisos procedurales, crafting, items con rarezas, ciudad hub y futuro PvP.

Estado de partida (commit base `8a860a49`, 6 nov 2026): Warrior jugable en un
patio de entrenamiento, simulación determinista a 60 Hz separada de la
presentación, capa de red dormida (cliente/servidor/predicción/reconciliación),
LPC con composición por capas, 188 checks de test headless en verde.

Fecha del roadmap: 10 nov 2026. Todo es provisional y se revisa al cerrar cada fase.

---

## 1. Qué tomamos de Drakantos

Solo mecánicas y estructura, nunca arte, nombres ni lore.

| Drakantos | En PixelCombat |
|---|---|
| Combate de acción 100 % ratón, sin target; el personaje mira al cursor | Todo es skillshot. El personaje siempre encara el cursor (salvo skills que lo bloquean) |
| Movimiento libre, no por casillas | Ya es así (WASD + colisión) |
| Ultimate que se carga conectando golpes | Ultimate = Charge 0–100 que sube al golpear (ya diseñado en EVOLUCIONES_V1) |
| Héroes con kit propio, intercambiables | 4 clases base; cada una con subclases. Cambio de clase/personaje en la ciudad |
| Orbes y artefactos que modifican habilidades | **Orbes de skill**: modifican una skill concreta (alcance, efecto, coste) sin hacerla más fuerte, sino distinta |
| Roles tanque / healer / daño | Warrior = frontline, Rogue = burst, Mage = control/área, Archer = rango. El soporte llega vía subclases |

## 2. Principios de diseño (no negociables)

1. **Simulación determinista separada de la presentación** (ya existe). Nada de
   `randf()`, `Time` ni nodos dentro de un tick. Esto es lo que permite PvP
   justo, replays, tests de balance headless y red autoritativa más adelante.
2. **Todo skillshot con telegraph legible.** Nada falla por tirada invisible.
3. **Rareza ≠ poder.** Skills, clases y subclases raras/únicas/legendarias
   cambian la forma de jugar, no son más fuertes. Necesario para el PvP.
4. **Contenido dirigido por datos.** Skills, items, recetas, enemigos, pisos y
   tiers viven en archivos de datos (`data/`), no en código. Con 100 pisos y 10
   tiers, el código no puede escalar con el contenido.
5. **Un solo sitio para los números.** Balance centralizado y medido con
   simulaciones headless, no a ojo.
6. **No se borra historia:** lo que deja de usarse se archiva.

## 3. Decisiones abiertas (hay que cerrarlas pronto)

Cada una con mi recomendación; marca las que cambies.

| # | Decisión | Recomendación |
|---|---|---|
| D1 | ¿Single-player primero u online desde el inicio? | **Single-player primero**, pero con la sim ya preparada para servidor autoritativo. El hub multijugador y el PvP llegan en las Fases 8–9 |
| D2 | Nombre del proyecto/juego (hoy "Reflections" en `project.godot`) | Cerrarlo en la Fase 0; el repo ya es `pixelcombat` |
| D3 | Las "misiones difíciles en los pisos 5 y 10": ¿pisos 5 y 10 de **cada** tier de 10, o solo los absolutos? | Asumo **5 y 10 de cada tier** (mini-jefe + jefe/guardián con misión opcional dura). Confírmalo |
| D4 | Cantidad de pisos "base" vs. variantes por tier | 10 tiers × 10 pisos; el tier cambia materiales, items, temática visual, enemigos y paleta |
| D5 | Subclases: ¿cuántas por clase y cuántas rarezas? | Empezar con **3 por clase** (comunes) en la Fase 7, y abrir el catálogo (raras, únicas, legendarias) por oleadas |
| D6 | Archer en lugar de Ranger/Cleric | Ya decidido: Warrior, Rogue, Mage, Archer. Cleric y Ranger quedan fuera de alcance. El soporte se cubre con subclases |
| D7 | Licencia de LPC | LPC mezcla CC-BY-SA / CC-BY / GPL. Hay que **llevar créditos por archivo** (ya existe `assets/pixel/lpc/CREDITS.csv`) y revisar el efecto share-alike sobre el arte derivado antes de publicar. Fase 0 |
| D8 | PvP: ¿arena instanciada o mundo abierto? | **Arena instanciada** (1v1, 2v2, 3v3), igual que Battlerite. Más fácil de balancear |

## 4. Fases

### Fase 0 — Fundación del repo (1–3 días)
- Primer commit y push a `natillaw/pixelcombat`.
- Actualizar README y AGENTS: nombre, visión nueva (hoy dicen "sin builds ni variantes", lo cual contradice subclases y orbes).
- ~~Decidir qué hacer con `archive/legacy_ts/`~~ Hecho: eliminado del repo (ver DECISIONES).
- Pasar los scripts de test y CI a la nueva ruta (los de `README` apuntan a `C:\dev\combat`).
- Crear `docs/DECISIONES.md` (bitácora) y cerrar D1–D8.
- Auditoría de licencias de assets (D7) y `CREDITS` globales.

**Hecho cuando:** el repo clona limpio, abre en Godot 4.7.2, y los tests headless pasan en CI.

### Fase 1 — Combate núcleo estilo Drakantos (2–3 semanas)
Objetivo: que el Warrior *se sienta* bien. Todo lo demás depende de esto.
- [x] Encarar siempre al cursor (con bloqueo durante ataques/channels). *Hecho 10 nov: `PlayerActor.facing_for`, con histéresis y test.*
- [x] Esquiva con i-frames cortos y coste/cooldown. *Hecho 10 nov: `WarriorKit.DODGE`, `tests/test_dodge.gd`.*
- [x] Pipeline de skills genérico y dirigido por datos: windup → activo → recovery, formas cono/línea/círculo, coste, cooldown, límite de objetivos, movimiento por fase. *Hecho 10 nov: `data/skills/warrior.json`, `SkillCatalog`, S1/S2 jugables.* Pendiente: proyectiles, estados (stun, slow...) y telegraph en enemigos.
- [x] M1 con cargas y M2 que se potencia manteniendo el botón (referencia Drakantos). *Hecho 10 nov: `tests/test_basics.gd`.*
- [x] Slots de loadout: M1, M2, S1–S5, Special y Ultimate, con panel para equipar (Tab). *Hecho 10 nov: `PlayerSim.equip/unequip`, `LoadoutPanel`.*
- [x] Special: Iron Counter (postura que bloquea y contraataca). *Hecho 10 nov: `tests/test_special.gd`.*
- [x] Niveles, XP y skills desbloqueadas por nivel (no todas desde el nivel 1). *Hecho 10 nov: `Progression`, `unlock_level`, `tests/test_progression.gd`.* Pendiente: guardar loadout/nivel en disco y limitar el cambio de loadout a la ciudad.
- [x] Ultimate con Charge por golpes (War God's Descent). *Hecho 10 nov: `tests/test_ultimate.gd`.*
- [x] Estados: stun, slow y veneno (con tope, resistencia e inmunidad tras un control). *Hecho 10 nov: `data/statuses.json`, `StatusSet`, `tests/test_status.gd`.* Pendiente: silencio, escudo, sangrado y empuje.
- [x] IA de enemigos con telegraph (cono, línea con embestida, círculo) dirigida por datos: `data/enemies/tier1.json`, `EnemyCatalog`, `EnemySim`, `EnemyActor`; 4 enemigos (Slime, Bat, Spider, Beetle). *Hecho 10 nov: `tests/test_enemies.gd`.* *Ampliado el 10 nov con enemigos a distancia (Wisp, Hornet) y el jefe Brood Beetle de 3 fases (`tests/test_ranged_boss.gd`).* Pendiente: estados (stun, slow...), grupos coordinados y los jefes de los demás tiers.
- "Game feel": hit-stop, screen shake, números de daño, SFX, trails (hoy hay `SlashArc`, `ImpactBurst`, `DamageNumber`).
- Panel de loadout simple (Tab) para equipar skills.

**Hecho cuando:** un Warrior completo (M1, M2, 5 skills, Special, Ultimate) derrota una oleada de 3 tipos de enemigos y los tests de sim cubren cada skill.

### Fase 2 — Las 4 clases + laboratorio de balance (3–4 semanas)
- [x] Rogue (Energy), Mage (Mana), Archer (Energy). Cada una con M1, M2, Special, Ultimate y tres skills normales jugables; el resto de su Skill Book de 15 está previsto en `data/classes/*.json` (`planned`). *Hecho 10 nov: `tests/test_classes.gd`, `test_projectiles.gd`, `test_class_skills.gd`.* Pendiente: completar los Skill Books.
- Recursos propios por clase en una escala común 0–100.
- [x] **Laboratorio de balance headless:** *Hecho 10 nov: `tools/balance/balance_lab.gd`, `game/sim/bot_brain.gd` y `tests/test_balance.gd`; mide DPS, ráfaga y oleada del tier 1 con bots. Faltan los duelos entre clases (requieren un segundo jugador en la simulación, Fase 8).* Descripción original: duelos 1v1, DPS en muñeco, matriz clase×clase con N repeticiones, edición de stats y guardado. (El proyecto 3D anterior ya lo tenía en `tools/balance`; conviene portar la idea, no el código.)
- Presupuesto de stats por nivel para que las 4 clases sean comparables.

**Hecho cuando:** la matriz de duelos entre las 4 clases queda entre 40 % y 60 % de victorias y se puede regenerar con un comando.

### Fase 3 — Items, stats y rarezas (2–3 semanas)
- Rarezas: Normal, Poco común, Raro, Épico, Único, Legendario (afijos 0/1/2/3/3/4, como ya se probó).
- Slots de equipo, inventario, comparación de items, tooltips.
- Daño por arma (tirada min–max + AP) y armadura como reducción.
- Items **dirigidos por datos**, con generador de afijos y reglas por tier.
- Apariencia: cada item mapea a capas LPC (`LpcWardrobe`) para que se vea en el personaje.
- Drops: tablas por enemigo, por piso y por tier.

> **Estado:** hecho el catalogo (`data/items.json`: 5 rarezas, 6 ranuras, 15 items base, afijos), la generacion determinista, el botin de enemigos y el cofre de piso, la mochila (40) y el equipo por clase con stats reales, y el panel de inventario (I). Tambien hecho: rareza Unica, comparacion con lo equipado, tablas de botin por enemigo (`loot` en `data/enemies`), oro y venta. El botin cae al suelo y se recoge con clic al acercarse. El equipo se ve en el sprite (capas LPC).

**Hecho cuando:** un jugador mata enemigos, recibe items de varias rarezas, los equipa y los ve en su sprite.

### Fase 4 — Mundo y ciudad hub (3–4 semanas)
- Tilemaps con los tilesets LPC; cámara, colisión y zonas.
- Ciudad a pie de la torre: plaza, puerta/portal de la torre, edificios entrables (herrería, alquimia, carpintería, sastrería/peletería, taberna, banco).
- NPCs con idle/paseo y diálogos mínimos.
- Zona segura: aquí se cambia loadout, clase y equipo.
- Guardado en disco (versionado desde el día uno).

> **Estado:** hecho el esqueleto (plaza, torre, patio, 5 fachadas con puerta que avisa "proximamente", zona segura, guardado versionado). Faltan tilemaps LPC, NPCs y el interior de los edificios.

**Hecho cuando:** se camina por la ciudad, se entra a cada edificio y se cruza el portal a un piso de prueba.

### Fase 5 — La torre (4–6 semanas)
- **Generador de pisos procedural determinista:** semilla = f(semilla_mundo, nº de piso). Layout, enemigos, nodos de recursos y cofres salen de ahí.
- **Persistencia por piso:** se guarda la semilla y solo las diferencias (cofres abiertos, nodos recolectados, misiones, jefe muerto). Al reentrar, el piso es el mismo y los enemigos reaparecen. Nunca queda vacío.
- 10 tiers × 10 pisos. Cada tier cambia materiales, items, tema visual, enemigos y paleta.
- **Pisos 5 y 10 (D3):** mini-jefe / jefe, con misión difícil opcional y recompensa mayor.
- Misiones de piso (objetivos procedurales), recompensas y curva de nivel.
- **Candado de avance (D9):** no se puede subir de piso sin completar el actual; los pisos completados se pueden revisitar y respawnean.
- Portal de ida/vuelta con pisos ya desbloqueados.

> **Estado:** pisos grandes y procedurales (mapa de casillas: campo, cuevas, ruinas y mixto), 10 misiones distintas, mision doble con dos mini-jefes en los x5, pruebas de jefe en los x10 y misiones opcionales. Tileset LPC 4-season con biomas, minimapa y ciudad grande de varias filas de edificios. Faltan jefes propios de los tiers 2-10 (provisionales), hojas de terreno propias de los tiers altos y NPCs.

> **Recoleccion y crafting:** ver Fase 6 (hecho el primer corte).

**Hecho cuando:** se sube del piso 1 al 10 (tier 1), se sale, se vuelve a entrar y el piso conserva su estado con enemigos respawneados.

### Fase 6 — Recolección y crafting (3 semanas)
- Nodos de recolección: minería, herbolario, madera, (pesca y piel a definir). Herramientas por nivel.
- Profesiones con nivel propio.
- Recetas dirigidas por datos con calidad aleatoria (resultado normal / bueno / excelente).
- UI de crafteo estilo WoW en los edificios de la ciudad.
- Materiales y recetas por tier (10 tiers, así que el sistema debe aceptar un tier nuevo solo con datos).

**Hecho cuando:** se mina en el piso 3, se fabrica un arma en la herrería y se equipa con su rareza correcta.

### Fase 7 — Progresión: subclases, skills y orbes (4–6 semanas)
- Skill Book de 15 por clase: desbloqueo por progresión, jefes, misiones y secretos.
- Subclases (evoluciones): 3 por clase al inicio, cada una con pasiva, M1/M2 con combo, 5 skills firma, Special y Ultimate (ya diseñadas en `EVOLUCIONES_V1.md`).
- Rarezas de subclase: raras, únicas y legendarias (D5), cada una difícil de conseguir y con un estilo distinto, no más fuerte.
- **Orbes y artefactos** (referencia Drakantos): modifican una skill (daño por proyectil extra, mayor radio, nuevo efecto, coste distinto). Siempre con trade-offs.
- Sistema de respec y cambio de subclase.

**Hecho cuando:** un Warrior puede evolucionar a Berserker o Guardian y equipar un orbe que cambia una skill de forma visible.

### Fase 8 — PvP y balance competitivo (4 semanas)
- Arena instanciada (D8): 1v1 y 2v2 locales primero, con bots que usan la misma sim.
- Estadísticas normalizadas en PvP (el equipo del PvE no decide el resultado).
- Iteración de balance continua con el laboratorio de la Fase 2.
- Replays deterministas para depurar desbalances.

**Hecho cuando:** dos jugadores locales se enfrentan en arena y el laboratorio detecta cualquier desbalance antes de que lo note un jugador.

### Fase 9 — Online (6+ semanas, depende de D1)
- Activar la capa de red: servidor autoritativo, predicción y reconciliación del cliente.
- Hub multijugador, cuentas, guardado en servidor, anticheat básico.
- Matchmaking de PvP y ranking.

### Fase 10 — Escalado de contenido y pulido
- Tiers 2–10: arte, enemigos, jefes, materiales, items y música.
- Más subclases raras, únicas y legendarias por oleadas.
- Pasada de UI/UX, accesibilidad, rendimiento, localización.
- Empaquetado, builds y herramientas de telemetría de balance.

## 5. Riesgos

| Riesgo | Mitigación |
|---|---|
| El alcance (MMO + 100 pisos + 4 clases + subclases) es enorme | Entregar por **cortes verticales jugables** al final de cada fase y no abrir la siguiente hasta que la actual se sienta bien |
| Desbalance entre clases con tanto contenido | Laboratorio headless desde la Fase 2 y stats normalizadas en PvP |
| Contenido procedural aburrido o repetitivo | Generador por reglas + "rooms" hechas a mano que se combinan; revisar el piso 1–10 antes de escalar |
| Guardado por piso crece sin control | Guardar solo diferencias respecto a la semilla; versionar el esquema |
| Licencias de LPC | Auditar en Fase 0 y mantener `CREDITS.csv` actualizado |
| Dependencia excesiva del arte LPC (estilo uniforme) | Aceptarlo como identidad visual; ampliar con las extensiones LPC (armaduras, armas, criaturas) en vez de mezclar estilos |

## 6. Primeras tareas concretas (siguiente sesión)

1. Primer commit y push a `natillaw/pixelcombat`.
2. Cerrar D1–D3 y D6 (nombre, single-player primero, 5 y 10 de cada tier).
3. Actualizar README/AGENTS con la visión nueva y las rutas correctas.
4. Hacer que el Warrior encare siempre al cursor y añadir la esquiva.
5. Diseñar el esquema de datos de skills (`data/skills/*.tres` o JSON) y portar M1/M2 del Warrior a él.

## Balance de campana (medido con `tools/balance/run_campaign.gd`)
Un bot (FloorBot) recorre los pisos con el mismo input que una persona. Resultado, 4 clases, sin pociones:
- Pisos normales 1-4: 1-3 min, 5-90 % de la vida perdida, nivel 8 al llegar al piso 5.
- Pisos normales 6-15: 2-3 min, 15-95 % de vida perdida; el nivel sube ~1 por piso.
- Pisos x5 y x10 (picos): 300-500 % de la vida perdida, 1-4 muertes del bot; son el pico de dificultad buscado, no hace falta bajar la escala (+10 %/piso).
- La vida no se regeneraba: ahora regenera 1,5 %/s tras 5 s sin recibir dano (`PlayerSim.regen_per_second`).
- Pendiente: el bot aun se atasca a veces (piso 7, ~1600 s), y no recoge items con la mochila llena.

## Bandidos del Cuervo (tier 1)
Los enemigos reales de los pisos 1-10 son bandidos LPC (`data/enemies/bandits.json`, generado por `tools/gen_bandits.py`): matón, espadachín, arquero, hechicero, degollador y escudero, con su kit de ataques; mini-jefes Rask y Veyra y jefe del piso 10 Garrick Blackhand (escala 2.3, 8 ataques elegidos por distancia, 4 fases con refuerzos mixtos). Las bestias (slime, bat, spider, beetle, wisp, hornet) son minoría en la mezcla y ya no sueltan equipo, solo cuero y quitina. Lore y nombre del tier: Bosque del Cuervo. Captura: `tests/capture_bandits.tscn`.

## Botin, materiales y crafteo (tier 1)
- Los bandidos y jefes sueltan sus propios items con probabilidad (`loot.items` en `data/enemies/bandits.json`; las tiradas van antes del botin generico). Tablas y equipo nuevo: `tools/add_gear.py` (35 items base, 26 recetas).
- Las bestias son animales sin lore: solo sueltan materiales (cuero, quitina, seda, esencia). 7 tipos de material x 10 tiers = 70: mineral, hierba y madera se recolectan; cuero, quitina, seda y esencia son botin de animales. Un test exige que cada material tenga uso en alguna receta y fuente.

## Kits rediseñados (5 skills por clase)
Cada clase empieza con 5 skills: M1, M2, S1 (control/utilidad), Special (postura o mejora) y Ultimate; el resto son *skills de mundo* (`"world": true`) que se aprenden con `PlayerSim.learn_skill` (libros, jefes, maestros) y se guardan. Cada clase tiene su movilidad (`mobility` en la clase): guerrero carga (aturde 1 s), picaro rueda, mago blink, arquero salto atras. Cada una carga la ultimate a su manera (`ult_charge`): guerrero golpeando y aguantando, picaro esquivando y rematando envenenados, mago lanzando hechizos, arquero con aciertos lejanos y criticos. `tests/legacy_kit.gd` restaura el kit antiguo para los tests de mecanicas.

## Profundidad de combate
- Estados nuevos (data/statuses.json): sangrado, silencio (el jugador solo usa M1/M2/movilidad), escudo (absorbe, tambien en aliados enemigos) y empuje (`knockback`, instantaneo). Ataques `buff` de enemigos (escudos de grupo) y `zone` (grietas/charcos en el suelo con dano y estados: `GroundZone`, dibujado por `ZoneActor`).
- Campamentos coordinados: despiertan juntos y solo 2 cuerpo a cuerpo atacan a la vez (los demas rodean).
- Elite errante (Cornelius the Deserter): en cada partida hay un 50 % de que aparezca una vez en un piso del 5 al 10 (`TowerCatalog.elite_floor`); al caer no vuelve. Mini-jefe con botin propio.
- Cursor del juego: espada (PixelRPGCursors Lite) sobre enemigos y puntero propio. El runner de tests ahora falla ante cualquier `SCRIPT ERROR`.

## Menus, ajustes y varios personajes
- Menu principal (Continuar, Personajes, Ajustes, Salir), pausa con Esc (Continuar, Ajustes, Personajes, Salir) y 3 ranuras de guardado (`SaveGame.slot_path`), con su personaje cada una; el guardado antiguo se copia a la ranura 1. `GameSession.load_slot` carga o crea una partida; sin menu en tests (headless) y capturas.
- Ajustes (`Settings`, user://settings.json): volumen general y de efectos (bus `SFX`), pantalla completa y reasignacion de 15 acciones (teclas o botones del raton, con intercambio si chocan). El HUD y el panel F1 muestran las teclas actuales.

## Consumibles, taberna, gremio, mercader, banco y ciudad viva
- Consumibles (`data/consumables.json`, `ConsumableCatalog`): pociones de vida y energia (teclas H/J, enfriamiento compartido de 14 s) y comida de 10 minutos (pan = regeneracion, estofado = +8 % dano, infusion = +8 % velocidad); se guardan fuera de la mochila y se usan tambien desde el inventario. Los enemigos sueltan pociones a veces y los jefes siempre.
- Servicios (`Services`, ventana `ServicePanel`): la **taberna** cocina (materiales -> comida y pociones), vende y deja descansar (cura todo + comida + rumores); el **mercader** vende equipo (existencias fijas por piso completado) y pociones; el **banco** guarda 30 items; el **gremio** tiene el tablon de encargos (`Bounties`, 3 ofertas deterministas, hasta 3 aceptados, progreso por muertes, materiales y pisos) y la instructora que ensena las skills de mundo por oro.
- Ciudad: PNJ nuevos (Dara del gremio, Orla la mercader, Tessin el banquero) y 6 paseantes que van y vienen por la avenida.

## Narrativa del tier 1 (mitologia B aprobada)
Canon en `Narrative/` (mitologia, cronologia, estructura de 100 pisos, pisos 1-10, facciones, PNJ, jefes, estado del mundo, arquitectura). En el juego: titulo y frase de cada piso 1-10, dialogos de Rask, Veyra, Garrick y Cornelius, PNJ que cambian de linea segun el progreso (4 etapas), banderas persistentes (`TowerState.flags`), cierre del tier 1 y rumores nuevos tras vencer a Garrick; validado por `tests/test_narrative.gd`.
