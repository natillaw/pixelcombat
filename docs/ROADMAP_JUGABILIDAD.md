# Roadmap de jugabilidad — de "prototipo pulido" a "juego bueno"

Fecha: 13 nov 2026. Sale de la valoracion "como jugador" hecha tras la ronda de pulido
(rama `feat/beta-polish-review`). Complementa `docs/ROADMAP.md` (vision y fases tecnicas):
aqui solo hay lo que cambia **lo que siente el jugador**.

**Aviso de honestidad:** nadie ha jugado esto a mano todavia. Lo marcado como (H) es una
hipotesis sobre la sensacion de juego y hay que confirmarla jugando (fase 0). Lo demas esta
medido (bots, capturas, datos, 63 suites en verde).

Reglas que no se rompen: la simulacion sigue determinista y separada de la presentacion,
el contenido va en `data/*.json`, la regla PvE/PvP no se toca sin medir con
`tools/balance/duel_lab.gd`, el jefe del piso 10 no se toca hasta que el dueno lo pruebe,
y los sprites de heroes no se modifican.

---

## Fase 0 — Verdad antes que opinion (1-2 dias, el dueno + una sesion)

Objetivo: sustituir las hipotesis (H) por datos.

| Que | Como | Hecho cuando |
|---|---|---|
| Partida completa a mano, 4 clases | El dueno juega pisos 1-10 con cada clase y anota en `docs/NOTAS_PLAYTEST.md` (plantilla: piso, clase, muertes, "aburrido/injusto/genial", minutos) | 4 clases x 10 pisos anotados |
| Medir tiempo por piso | `CampaignLab` ya mide segundos de bot; comparar con el tiempo humano. Objetivo: 4-7 min por piso, 8-12 en los de mision larga | Tabla humano vs bot |
| Sensacion de golpe | Probar con `Settings.hit_stop` en 0/1/2 y `shake` en 0/1; el dueno elige por defecto | Valores por defecto decididos |
| Audio real | El dueno escucha musica por zona (`MusicDirector`) y SFX con altavoces/cascos; lista de huecos | Lista en `PLACEHOLDERS_PENDIENTES.md` |
| Rendimiento en GPU | Mostrar FPS (opcion F3) y jugar el piso 9 con muchos enemigos | >= 60 FPS estables o lista de cuellos |

Entregable de codigo: contador de FPS en pantalla (F3), registro opcional de telemetria local
(`user://playtest_log.json`: piso, causa de muerte, tiempo) para que el playtest deje datos.

---

## Fase 1 — Lo critico para una beta cerrable (1-2 semanas)

### 1.1 Combate: que el golpe pese (H)
**Problema:** el combate esta bien disenado en papel, pero no se ha medido la sensacion.
**Como:**
- Anticipacion y recuperacion visibles: cada ataque enemigo tiene `windup` (telegrafo) y
  `recovery`. Revisar en `data/enemies/*.json` que ningun ataque tenga windup < 0.35 s si hace
  mas del 15 % de la vida; los jefes >= 0.6 s.
- Particulas y destello al impactar usando los FX que ya hay en `assets/pixel/fx` (KILN,
  Sprite Kitchen, SpritePilot); un registro `data/fx.json` por tipo de golpe, no codigo.
- Sonido de impacto por material (carne, metal, madera) y por "peso" (ligero/fuerte).
- Ventana de esquiva generosa (I-frames) y feedback claro: la esquiva exitosa da un destello y
  un "ESQUIVA" (ya existe el texto; falta el efecto).
- Pruebas: `tests/test_juice.gd` que verifique que cada skill tiene `fx` y `sfx` asignados.

**Mejorar lo bueno:** los telegrafos rojos ya son justos; anadir a cada jefe una linea de
"lectura" en pantalla la primera vez (consejo de tutorial por jefe).

### 1.2 Enemigos: variedad real (el cambio con mejor relacion coste/efecto)
**Problema:** ~21 definiciones (tier1 + bandidos) para 10 pisos; varias solo difieren en numeros.
**Como:** objetivo 30 enemigos distintos para el tier 1, cada uno con un **verbo** propio:

| Verbo | Ejemplo | Que obliga al jugador a hacer |
|---|---|---|
| Carga | Jabali, escarabajo | Esquivar de lado, castigar tras el choque |
| Zona | Hechicero | Salir del circulo, interrumpir el canalizado |
| Proyectil | Arquero, ballestero | Cubrirse, acercarse en zigzag |
| Escudo frontal | Escudero | Rodear o romper con golpe fuerte |
| Invocador | Nigromante pequeno | Priorizar el objetivo |
| Emboscada | Aranas en techo | Mirar el minimapa |
| Curandero | Chaman | Matarlo primero |
| Tanque lento | Troll | Kitear |

Pasos: (1) crear 9-10 enemigos nuevos en `data/enemies/` (solo JSON si reutilizan patrones
existentes: `cone`, `line`, `circle`, `charge`, `summon`); (2) asignarlos por bioma en
`data/biomes.json` y `MissionGen` (grupos mixtos: nunca solo un tipo); (3) un `test_enemy_roster`
que compruebe que cada piso 1-10 tiene >= 4 verbos distintos y que ningun verbo supera el 40 %.
**Mejorar lo bueno:** los telegrafos ya existentes; cada enemigo nuevo reutiliza el sistema de
avisos, asi la lectura es consistente.

### 1.3 Audio (H, y casi seguro placeholder)
**Como:** (1) lista de huecos tras la fase 0; (2) el dueno trae SFX/musica propios o libres a
`assets/audio/`; (3) registrar licencias en `docs/ASSET_REGISTRY.md`; (4) `MusicDirector` ya
cambia por zona y momento, solo hay que cargar mas pistas (data-driven en `data/lore.json`);
(5) mezcla: bus Musica -6 dB, SFX 0 dB, UI -3 dB, con opcion de volumen por bus (ya existe).
**Mejorar lo bueno:** la transicion musical al combatir ya existe: anadir un "sting" al entrar
en pelea de jefe y otro al ganar.

### 1.4 Coherencia visual
**Problema:** LPC + Caz + Pixel Crawler + Dragon Regalia = kit de assets, no estilo propio.
**Como (sin tocar los sprites de heroes):**
- Un **filtro de paleta comun** como shader de pantalla (`assets/shaders/`): ligera
  cuantizacion + tinte por bioma. Se activa en Ajustes (opcion "Estilo unificado").
- Contorno uniforme en monstruos: ya existe `tools/art_cohesion.gd`; aplicarlo a todos los
  enemigos nuevos.
- Sustituir progresivamente las formas dibujadas por codigo por sprites (lista en
  `PLACEHOLDERS_PENDIENTES.md`); el dueno trae assets mejores desde casa.
**Mejorar lo bueno:** el HUD dorado/azul ya es coherente; usar esa misma paleta en los
telegrafos y en el cursor.

### 1.5 Interfaz: lo que queda desalineado
- Hoja de personaje (tecla C): rehacer con `UiStyle.draw_panel`, ranuras `draw_slot_bg` y
  marco de rareza; quitar el pergamino CraftPix.
- Panel de objetivos y misiones: ya reajustado; revisar a 1280x720 y 1920x1080 con integer scale.
- Usar los iconos sin usar de `assets/pixel/ui/ts_kit/icons` (recursos, social, estrellas):
  iconos en materiales, en la barra de recursos del inventario y en las recompensas.
- Traducir los nombres de habilidades (decision pendiente del dueno; ver 2.3).
- Reducir el ruido del HUD: modo "limpio" (ocultar consejos y el panel de datos tras 10 s
  sin combate; vuelven al pulsar Alt).
- Prueba: un test de capturas (`tests/capture_ui_all.gd`) que abra cada panel y falle si algun
  texto desborda su rectangulo (medir con `Font.get_string_size`).

### 1.6 Cierre de beta
- Jefe del piso 10: playtest manual del dueno; ajustar solo con su feedback.
- Pantalla final de la beta: resumen (tiempo, muertes, nivel) y mensaje de "proximas versiones".
- Pagina de "Novedades" y de creditos (licencias de assets) en el menu.

---

## Fase 2 — Hacer que quieras otra partida (3-5 semanas)

### 2.1 Mapas con memoria
**Problema:** "bosque + caminos + puerta" se repite.
**Como:**
- Pisos "hito" (3, 5, 7, 10) con un mapa **autorado** (a mano, en datos) y un evento propio:
  puente que se rompe, campamento al amanecer, cueva a oscuras con antorchas.
- Para los procedurales: **plantillas de sala** con un gancho unico (arena circular, pasillo
  de trampas, claro con ruinas) combinadas por `TowerGenerator`. Test: ninguna combinacion
  repite la misma plantilla en pisos consecutivos.
- Mecanicas de entorno ligeras: barriles explosivos, trampas de pinchos, charcos que ralentizan,
  puertas que se cierran hasta limpiar la sala. Todo como objetos de `Interactable`/`GroundZone`.
- Variedad de iluminacion por piso (el `Vignette` ya tiñe el ambiente).
**Mejorar lo bueno:** las misiones con lore (piso 2-9) ya dan identidad; anadirles una
decision (p. ej. salvar a un prisionero o tomar el botin) con consecuencia pequena.

### 2.2 Botin con efectos que cambian como juegas
**Problema:** 38 objetos, 8 afijos, numeros sobre numeros.
**Como:**
- **Afijos con efecto** (no solo +stat): "al esquivar, deja una zona de dano", "tus golpes
  fuertes aplican sangrado", "al matar, 10 % de curar". Van en `data/items.json > affixes` con un
  `effect` que la simulacion ya sabe aplicar (`StatusSet`, `GroundZone`).
- **Orbes de skill** (ya en la vision de `ROADMAP.md`): modifican una habilidad concreta.
- Items **unicos** por jefe (uno por tier) con un nombre y una historia.
- Rareza != poder en PvP: en regla PvP el afijo con efecto se normaliza (ya existe `RuleSet`).
- Prueba: `tests/test_affix_effects.gd` por cada afijo.
**Mejorar lo bueno:** el marco de rareza y la mochila de 40 huecos ya se ven bien; anadir
comparar-con-lo-equipado al pasar el raton.

### 2.3 Clases y habilidades
- **Paridad:** llevar Archer (8) y Mage (11) a >= 14 habilidades cada una, siguiendo el patron
  de Warrior (16) y Rogue (15). Todo en `data/skills/*.json`. Medir con `duel_lab` tras cada lote.
- **Nombres en espanol** y descripciones cortas; decision del dueno: traducir todo o mantener
  nombres propios en ingles como marca. Recomendado: traducir.
- **Subclases** (ya en el roadmap): una por clase para el final de la fase 2.
- Arbol de talentos sencillo: 3 rutas por clase, 1 punto por nivel (hasta nivel 10 hay pocos
  niveles; ampliar el tope con el tier 2).

### 2.4 Ciudad con razon para volver
- Gremio: **tablon con encargos diarios** y rotacion semanal (ya hay `Bounties`).
- Taller: recetas desbloqueables por pisos y por encontrar planos.
- Mercader: stock que cambia por piso (ya) y **precio dinamico** por reputacion.
- Vecinos (10 residentes): mini-misiones con recompensa cosmetica o de dialogo.
- Un **banco de entrenamiento** (ya existe) con desafios: "mata 20 munecos en 30 s".

### 2.5 Ritmo y dificultad
- Curva medida con `CampaignLab` + telemetria humana: muertes por piso objetivo
  (piso 1-3: <0.3, 4-7: 0.5-1, 8-10: 1-2).
- **Dificultad seleccionable** (Relajada / Normal / Dura): escalado de vida y dano enemigos en
  `data/rules.json`; la Dura anade enemigos de elite extra.
- Descansos: hogueras ya curan; asegurar una cada ~2 combates largos.
- Velocidad de movimiento y ataques: ya reducida; el jugador la ajusta en Ajustes si sobra.

---

## Fase 3 — Endgame y retencion (despues de la beta)

1. **Piso 11-20 (tier 2):** abre el crafteo tier 2 (ya preparado en datos). Contenido nuevo:
   bioma de cueva/mina, enemigos nuevos, jefe del piso 20.
2. **Repeticion con modificadores** ("Torre de desafios"): mismos pisos con reglas (sin
   esquiva, enemigos que se curan, tiempo limite) y recompensas cosmeticas.
3. **Torre infinita** a partir del piso 100 (o por tiers), con puntuacion y tabla local.
4. **Logros** (~40) y cosmeticos (tintes de pelo y ropa, marcos de retrato).
5. **PvP:** la base determinista y las reglas PvP estan listas. Pasos: lobby/duelos 1v1 locales
   -> netcode con prediccion (la capa de red esta dormida) -> clasificatoria. No lanzar PvP sin
   medir el balance con `duel_lab` y un playtest de latencia (`InputDelay` ya simula).
6. **Co-op PvE** de 2-4 jugadores sobre la misma capa de red.
7. Localizacion (ES/EN) via un archivo de textos, no cadenas en el codigo.

---

## Lo bueno y como potenciarlo

| Lo bueno hoy | Como mejorarlo |
|---|---|
| Combate con ratón y telegrafos justos | Variedad de enemigos (1.2) + pulido del golpe (1.1) |
| Simulacion determinista (tests, PvP, bots) | Telemetria de playtest humana; bots que prueben builds (afijos) |
| Misiones con lore en los pisos 2-9 | Decisiones con consecuencia (2.1), jefes con dialogo |
| Progreso contenido (nivel <= piso) | Dificultad seleccionable, mas puntos de decision (talentos) |
| 4 clases equilibradas en duelo | Paridad de contenido (2.3), subclases |
| Ciudad con vida | Razones para volver (2.4), eventos de ciudad |
| Interfaz coherente (marco dorado) | Hoja de personaje nueva, modo limpio, iconos sin usar |
| Guardado robusto y suites estables | Test de capturas con desbordes, CI con capturas por PR |

## Lo malo y como arreglarlo (resumen)

| Problema | Arreglo | Fase |
|---|---|---|
| Combate sin medir a mano | Playtest + hit-stop/shake por defecto | 0 |
| Pocos enemigos y se repiten | 9-10 nuevos con verbos distintos | 1.2 |
| Audio placeholder | Pistas/SFX reales, mezcla y stings | 1.3 |
| Mezcla de estilos de arte | Filtro de paleta + contorno uniforme + assets propios | 1.4 |
| HUD cargado, texto pequeno | Modo limpio, desbordes testeados, fuente ya subida | 1.5 |
| Hoja de personaje desentona | Rehacerla con UiStyle | 1.5 |
| Nombres en ingles | Traducir | 1.5/2.3 |
| Mapas repetitivos | Pisos hito, plantillas con gancho, entorno | 2.1 |
| Botin sin emocion | Afijos con efecto, orbes, unicos | 2.2 |
| Clases desiguales | Paridad de habilidades, subclases | 2.3 |
| Sistemas de ciudad como listas | Encargos diarios, planos, vecinos | 2.4 |
| Sin endgame | Tier 2, desafios, torre infinita, logros | 3 |
| PvP inexistente | Duelos locales -> red -> clasificatoria | 3 |

## Orden recomendado (primeras 6 sesiones de trabajo)

1. Fase 0 (playtest + FPS + telemetria) — sin esto el resto es apuesta.
2. 1.2 Enemigos nuevos (mayor impacto por esfuerzo).
3. 1.1 Pulido del golpe + FX por datos.
4. 1.5 Hoja de personaje + modo limpio + iconos.
5. 1.4 Filtro de estilo unificado.
6. 1.3 Audio real (cuando el dueno traiga los archivos).

Cada paso: rama propia, commits pequenos, suites en verde y una captura antes/despues en
`docs/` cuando cambie lo visual.
