# Informe de la sesión de desarrollo — 2026-10-31

Rama: `claude/tactical-summoners-audit-b3sqpo`.

Commits de la sesión:

| Commit | Contenido |
|---|---|
| `3a5a999` | Implementación |
| `2f4744f` | Corrección de tipo |
| `6558c35` | Correcciones tras la CI |

**Pruebas:** **20/20 suites PASS** en GitHub Actions con Godot 4.7.1 Linux ([ejecución 41150421537](https://github.com/natillaw/tactical-summoners/actions/runs/41150421537)).

**Sin merge a `main`.**

## A. Resumen ejecutivo
El cuartel general deja de ser decorativo. Ahora hay una **simulación del pueblo** (`TownSim`) que funciona aunque no haya ninguna escena abierta. Avanza por horas con un reloj propio (D-047) y conecta:
- profesiones con nivel (D-049);
- trabajo en edificios con recetas (no hay producción gratis);
- almacén con límites;
- camas que limitan la población;
- hambre, fatiga y estrés;
- enfermedades que bajan los atributos (y por tanto el combate) y que se tratan en el hospital, con médicos y medicinas;
- taberna con amistades y discusiones;
- construcción por héroes constructores a lo largo del tiempo (D-048), con el **Salón del Invocador** como techo de nivel;
- colocación de edificios en cuadrícula con validación (D-050).

Además hay un **sistema de equipo** completo en datos y lógica:
- 6 rarezas, 18 bases, 11 afijos, 5 únicos, variante mítica y 2 sets;
- almacén de equipo, equipar y desequipar, reglas de dos manos y anillos, desguace;
- botín por piso;
- forja en la herrería con calidad que depende del herrero y de la forja;
- poderes que actúan en combate.

La cadena completa **minero → mineral → herrero → lingote → arma → equipada → más ataque en combate** está probada de punta a punta (`test_hq`).

## B. Estado inicial (auditoría al empezar)
| Hallazgo | Estado comprobado | Severidad |
|---|---|---|
| F-001 HQWorld llamaba a un método inexistente | **Reparado antes**: `hq_world.gd` ya no existe; el pueblo es `TownScreen` | — |
| F-002 ProceduralMap y SandboxMap incompatibles | **Reparado**: base común `NavMap` | — |
| F-003 Reliquia sin extracción | **Reparado**: el relicario nunca está en la casilla de extracción y la misión exige llevarlo | — |
| F-004 Constante inexistente en smoke_combat | **Reparado** (la suite pasa) | — |
| F-005 `id` / `hero_id` en el memorial | **Reparado**: se usa `hero_id` en todas partes | — |
| F-007 Promoción y división por cero | **Reparado**: se protege el caso de pool vacío | — |
| F-008 Versión del generador | **Reparado**: ahora `HeroGenerator.VERSION = 3` | — |
| Producción gratis (cocina/taller/enfermería creaban de la nada) | **Era cierto** → corregido con recetas | HIGH |
| Comida y medicina sin uso | **Era cierto** → ahora se comen y se usan en tratamientos | HIGH |
| La invocación sin camas decía "Not enough gems" | **Bug real** → ahora explica que faltan camas | MEDIUM |
| `IMPLEMENTATION_STATUS` seguía citando `hq_world.gd` | Documentación desfasada → corregida | LOW |
| Dos interfaces de asignación (`hq_screen` y el panel del pueblo) | Comparten los mismos datos; `hq_screen` se actualizó a los mismos datos y reglas | INFO |

## C. Sistemas implementados
| Sistema | Archivos | Integración | Tests |
|---|---|---|---|
| Definiciones de profesiones (D-049) | `scripts/data/profession_defs.gd` (nuevo) | `HeroData.professions/passion`, `Game.assign_work` | `test_hq` |
| Economía: recursos, recetas, enfermedades, necesidades, tiempo | `scripts/data/economy_defs.gd` (nuevo) | `TownSim`, `Game` | `test_hq` |
| Simulación del pueblo | `scripts/core/town_sim.gd` (nuevo) | `Game.pass_time`, `town_tick`, `after_expedition` | `test_hq` (incluye rendimiento) |
| Edificios ampliados | `town_tables.gd` | Puestos, recetas, camas, camas de hospital, requisito de Salón; nuevos: Granja, Tala, Mina, Almacén, 3.er dormitorio; mapa de 44×26 | `test_town`, `test_hq` |
| Estado del héroe | `hero_data.gd` | Profesiones, hambre, fatiga, estrés, enfermedades, cama, equipo, bolsa; las enfermedades modifican los atributos | `test_hq`, `test_items` |
| Construcción (D-048) | `game.gd` | Cola de obras, constructores, techo del Salón, motivo cuando no se puede | `test_town`, `test_hq`, `tower` |
| Colocación (D-050) | `game.gd`, `town_tables.gd`, `town_map.gd`, `town_view.gd`, `town_screen.gd` | Disposición guardada; validación de límites, plaza, solapes, puerta y caminos; vista previa verde/roja | `test_hq` |
| Equipo y botín | `item_defs.gd`, `item_gen.gd` (nuevos), `game.gd` | Estadísticas en `HeroData.get_stats()`; poderes en `SandboxHero` | `test_items`, `skills` |
| Pueblo visible | `town_hero.gd`, `town_view.gd`, `town_screen.gd`, `hero_info_panel.gd`, `hq_screen.gd`, `summon_screen.gd` | Los héroes representan su estado real; paneles de cada edificio | `boot`, `tower` y capturas |
| Expediciones → pueblo | `sandbox_screen.gd`, `game.gd` | Al volver pasa un día; vuelven cansados y estresados; caer o envenenarse puede dejar una enfermedad; botín en el resultado | `test_hq` |
| Guardado v9 | `game.gd`, `hero_data.gd` | Migración v8 → v9 sin rehacer nada al azar | `test_hq`, `memorial` |

**Limitaciones:**
- No hay Salón de investigación.
- No hay demolición.
- No hay rotación de edificios: en una cuadrícula cenital con parcelas rectangulares no aporta nada.
- No hay durabilidad del equipo.
- La bolsa es pequeña y solo admite pociones y antídotos.

## E. Cuartel general: qué es funcional y qué es solo visual
- **Funcional (simulado y probado):**
  - **Reloj:** 1 hora por cada 30 s en el pueblo, botón "Pass a day" y +24 h por expedición.
  - **Actividad de cada héroe:** trabajar, dormir, comer, socializar, en tratamiento, desplegado o libre.
    - Va en este orden de prioridad: hospital → sueño (noche o fatiga ≥ 85) → comer (hambre ≥ 55 y hay comida) → taberna (estrés ≥ 55) → trabajo → libre.
  - **Necesidades por hora:**
    - Dormir sin cama descansa menos y estresa.
    - Pasar hambre estresa.
    - 12 h de fatiga 100 provocan agotamiento.
  - **Producción:** se ejecuta por lotes. Los ingredientes se toman al empezar, así que no se usan dos veces.
    - La eficiencia sale del nivel de profesión, el atributo, el nivel del edificio, la fatiga, el hambre, las enfermedades y la relación con los compañeros (amigos +10%, rivales −15%).
    - Si el almacén está lleno, la producción se para y se avisa.
    - Si nadie está cualificado o falta un material, el edificio muestra un "!" rojo y el motivo.
  - **Construcción:** solo avanza con constructores; cada constructor lleva una obra.
  - **Camas:**
    - Capacidad = camas de los dormitorios construidos (6/8/10/12/14 por nivel).
    - Sin camas no se invoca, y se dice por qué.
    - El héroe desplegado conserva su cama.
    - Si sobran héroes (partidas antiguas), duermen en el suelo; nadie se elimina.
  - **Hospital:**
    - 2–6 camas, con prioridad por gravedad.
    - Cada médico atiende a 2 pacientes por hora y usa 1 medicina (o antídoto) por cada 24 h de tratamiento.
    - Sin médico solo hay reposo, y la herida infectada no se cura sola.
  - **Enfermedades:**

    | Enfermedad | Efecto |
    |---|---|
    | Herida infectada | VIT y FUE bajan; necesita médico |
    | Fiebre del pantano | Se cura con reposo |
    | Toxina persistente | El antídoto la acelera |
    | Tos de las cuevas | Contagio del 6% diario en el dormitorio |
    | Agotamiento | Solo la cura el sueño |

    Todas bajan los atributos y por tanto el combate.
  - **Taberna:**
    - Baja el estrés, más si hay un tabernero y el edificio tiene más nivel.
    - Forma parejas: dos caracteres conflictivos pueden discutir; si no, se crean vínculos.
    - Se guardan recuerdos solo cuando cambia el tipo de relación (no se guarda cada charla).
  - **Compañeros de trabajo:** se conocen un poco cada día, a mediodía.
- **Solo visual:**
  - Los héroes del mapa **representan** el estado de la simulación (caminan con A* a su puesto, cama, cocina, taberna u hospital).
  - Si están en un oficio de exterior, "golpean" en la puerta con la animación de ataque existente. **No hay animaciones específicas** de yunque, cocina ni curación: el generador de Caz solo trae caminar, idle, ataque y lanzamiento.
  - El tiempo libre (pasear, visitar, entrenar, charlar) sigue siendo decorativo y depende de la personalidad.

## F. Objetos y economía
- **Recursos:** materiales, comida, grano, hierbas, madera, piedra, mineral, lingotes, medicina, pociones y antídotos. Límite = 150 + 150 × nivel del almacén.
- **Cadenas:**

  | Producción | Recurso | Transformación | Resultado | Destino |
  |---|---|---|---|---|
  | Granja | Grano | Cocina | Comida | Héroes |
  | Granja | Hierbas | Alquimia | Medicina, pociones y antídotos | Hospital y bolsa |
  | Tala + mina | Madera + piedra | Taller | Materiales | Construcción |
  | Mina | Mineral | Herrería | Lingotes → armas y armaduras | Almacén de equipo |
- **Equipo:**
  - 11 huecos (D-039); las armas de dos manos ocupan las dos manos y los anillos van en 2 huecos.
  - Un héroe sin formación con un arma rinde al 75%.
  - Rarezas de común a mítica.
  - Afijos con rangos, grupos exclusivos y tipo de objeto.
  - Únicos con poderes: quemar al golpear, curar al matar, ralentizar, espinas, inmunidad a la ralentización.
  - La variante mítica aumenta el poder ×1,5.
  - Sets:
    - **Vigilia del Guardián:** con 3 piezas, los escudos que da o recibe el héroe son un 50% más fuertes.
    - **Acechador nocturno:** con 3 piezas, +30% de daño a enemigos ocupados con otro.
  - El robo de vida y las espinas también funcionan en combate.
- **Botín:** 1 + piso/4 objetos por piso (el jefe da +2 y al menos uno raro). Lo que no cabe se queda en la torre y el resultado lo dice.
- **Forja:**
  - Calidad = mínimo(nivel del herrero × 1,5, nivel de la forja × 3) ± 1.
  - Un aprendiz no hace obras maestras aunque la forja sea buena.
- **Bolsa:** cada héroe lleva hasta 3 tipos × 3 unidades (pociones y antídotos). En combate bebe solo una poción por debajo del 35% de vida y usa el antídoto si está envenenado.

## G. Combate y expediciones
- **Integrado:**
  - estadísticas del equipo;
  - poderes de objetos;
  - bolsa;
  - marcas de "cayó" y "envenenado";
  - consecuencias al volver;
  - botín.
- **Pendiente:**
  - IA enemiga por roles (fase 4);
  - jefes con fases (fase 5);
  - vista previa de misión antes de entrar (14.3);
  - incursiones de 10 héroes;
  - uso automático de habilidades (Q-12).

## H. Persistencia
- **Guardado v9.** Se guardan:
  - el reloj y la semilla del pueblo;
  - los trabajos de cada edificio y los lotes empezados;
  - la cola de obras;
  - los pacientes;
  - la disposición de los edificios;
  - el registro del pueblo;
  - el almacén de equipo y el contador de identificadores;
  - y, por héroe: profesiones, pasión, necesidades, enfermedades, cama, equipo y bolsa.
- **Migración v8 → v9:**
  - Los edificios nuevos empiezan en su nivel por defecto.
  - El almacén conserva sus cantidades y añade el resto.
  - Cada héroe recibe su profesión de vida pasada (nivel 2) y una cama.
- **Probado:**
  - Guardar, cargar, volver a guardar y cargar sin duplicar objetos.
  - El pueblo recargado sigue exactamente igual que el original durante 24 h (determinista).
  - Migración de un guardado v8.
  - El memorial sigue idéntico tras guardar y cargar.

## I. Tests
- **Comando:**
  - Linux: `tools/run_tests.sh`.
  - Windows: `tools/Run-Tests.ps1`.
- **Entorno:** GitHub Actions, Ubuntu, Godot 4.7.1 headless.
- **Resultado final:** **20/20 PASS**.
- **Suites nuevas:**
  - **`hq`:** unas 50 comprobaciones de comportamiento real, incluida una prueba de rendimiento con 40 héroes × 240 horas por debajo de 4 s.
  - **`items`:** unas 30.
- **Suites ampliadas:** `skills` (poderes del equipo, pociones y antídotos en combate).
- **Fallos en el camino, todos corregidos y vueltos a ejecutar:**
  - 20/20 FAIL por un error de inferencia de tipos en `town_sim.gd:313`.
  - Después, 18/20:
    - **memorial:** los decimales cambiaban tras el JSON → bug real, corregido.
    - **hq:** 3 tests con una preparación mal hecha por mi parte, también corregidos.
- **Tests antiguos actualizados a las nuevas reglas** (no para forzar el PASS: las reglas cambiaron por decisiones tuyas):

  | Suite | Antes comprobaba | Ahora |
  |---|---|---|
  | `test_town` | Construcción instantánea y +5 de capacidad por dormitorio | Construcción por obras (D-048) y camas por nivel |
  | `test_simulation` y `test_deep_systems` | Producción sin materias primas | Producción con materias primas |
  | `test_procedural` | Capacidad de 15 o más | Capacidad = camas |
  | `smoke_tower` | Edificio construido al instante | Construcción con constructor |
- **No ejecutado:** partida manual en Windows y prueba visual de los paneles de gestión. La CI ahora captura los paneles del Salón y de la Herrería (`01e`, `01f`, commit `0299aff`, 20/20 PASS). **Los revisé:** se dibujan correctamente:
  - el reloj y los recursos;
  - los botones de trabajo (fundir, forjar arma, forjar armadura);
  - los trabajadores 0/1 con candidatos y su nivel de profesión;
  - el equipo de obra;
  - el motivo del bloqueo ("needs 120 materials").

  El pueblo de 44×26 se ve completo, con los edificios nuevos (`01_town`).

## J. Problemas conocidos
- La IA de los héroes no usa habilidades sola.
- No hay animaciones específicas de trabajo (limitación de los sprites de Caz).
- El pueblo con más de 40 héroes visibles no tiene LOD de dibujo; la simulación sí escala.
- `skill_tables.gd` ya no se usa (no lo borré sin permiso).
- La pantalla HQ (`hq_screen`) duplica en parte el panel del Salón.
- El panel del héroe no refresca las estadísticas al equiparse hasta reabrirlo.

## K. Próximos pasos recomendados
1. Responder `docs/design/DECISIONS_PENDING_USER.md` (Q-01, Q-02, Q-09 y Q-12 son las más importantes).
2. Salón de investigación con proyectos (Q-07).
3. Vista previa de la expedición y misión asignada por el juego (14.3).
4. Fase 4 del combate: IA enemiga por roles.
5. Asignación automática de trabajadores (Q-08) y demolición.

## L. Decisiones pendientes
Ver `docs/design/DECISIONS_PENDING_USER.md`.
