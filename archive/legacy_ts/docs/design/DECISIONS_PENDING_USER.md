# Decisiones pendientes del dueño

Estas son las preguntas que quedaron abiertas en la sesión del 2026-10-31. En cada una puse una **decisión provisional y reversible** para no bloquear el trabajo. Todas son números o reglas en datos (`EconomyDefs`, `TownTables`, `ItemDefs`), así que cambiarlas no exige reescribir sistemas.

Las decisiones ya tomadas están en `docs/DECISIONS.md`.

---

## Q-01 — ¿Puedo seguir subiendo a mi rama?
- **Contexto.** El master prompt de esta sesión dice "no hagas commits ni pushes automáticamente". En cambio, D-038 me autoriza a hacer push a mi rama. Además, sin Godot local la única forma de ejecutar las pruebas es la CI de GitHub, que solo se lanza al hacer push.
- **Alternativas:**
  1. Seguir con D-038: push solo a mi rama, nunca merge a `main`.
  2. Trabajar sin push y entregar parches sin probar.
- **Ventajas e inconvenientes:**
  1. Con la primera hay pruebas reales.
  2. Con la segunda nada estaría verificado y yo no podría afirmar ningún PASS.
- **Recomendación:** la 1.
- **Decisión provisional:** la 1. Hice push a `claude/tactical-summoners-audit-b3sqpo`; no hubo merge.
- **Archivos afectados:** ninguno.
- **Qué decides tú:** confirmar D-038 o revocarlo.

## Q-02 — Evitar el bloqueo "sin constructores" (riesgo de D-048)
- **Contexto.** D-048: solo construyen héroes con la profesión Constructor. Una partida nueva no tiene héroes.
- **Alternativas:**
  1. Cualquier héroe con un hueco de profesión libre aprende Constructor como aprendiz al asignarlo (eficiencia 0,3).
  2. Un "capataz" del pueblo, sin nombre, que construye despacio.
  3. El primer héroe invocado siempre trae Constructor.
- **Ventajas:**
  1. Respeta D-048 y D-049 y no bloquea.
  2. Nunca bloquea.
  3. Es simple.
- **Desventajas:**
  1. Ocupa uno de los 2 huecos de profesión.
  2. Contradice "solo héroes".
  3. Fuerza la generación de héroes.
- **Recomendación:** la 1.
- **Decisión provisional:** la 1 (implementada en `Game.assign_work`).
- **Archivos afectados:** `game.gd`, `hero_data.gd`.

## Q-03 — Ritmo del reloj del pueblo (D-047)
- **Contexto.** Provisionalmente:
  - **1 hora del pueblo = 30 s reales** mientras estás en el pueblo;
  - **cada piso jugado = 24 h** (ganes o pierdas);
  - botón **"Pass a day"** (pasar un día).
- **Alternativas:**
  - 15, 30 o 60 s por hora.
  - Que un piso cueste 12, 24 o 48 h.
  - Que el tiempo dependa de la duración real del piso.
- **Recomendación:** 30 s y 24 h para empezar, y ajustar jugando.
- **Archivos afectados:** `EconomyDefs.REAL_SECONDS_PER_HOUR`, `HOURS_PER_EXPEDITION`.

## Q-04 — Contagio
- **Contexto.** Hoy solo la *tos de las cuevas* se contagia, con un 6% diario por compañero de dormitorio.
- **Alternativas:**
  1. Sin contagio.
  2. Solo algunas enfermedades, y solo dentro del dormitorio (lo actual).
  3. Contagio también en la taberna y el hospital.
- **Recomendación:** la 2.
- **Decisión provisional:** la 2.
- **Archivos afectados:** `EconomyDefs.DISEASES`.

## Q-05 — ¿Cuántas enfermedades trata el hospital a la vez?
- **Contexto.** Hoy cada médico atiende a 2 pacientes por hora y trata una enfermedad por paciente cada hora. Las camas van de 2 a 6 según el nivel.
- **Alternativas:**
  1. Varias enfermedades a la vez.
  2. Una cada vez (lo actual).
- **Recomendación:** la 2, porque hace que importen el orden y los médicos.
- **Archivos afectados:** `TownSim._treat`.

## Q-06 — Producción cuando el trabajador está en la torre
- **Contexto.** Hoy, si un héroe está desplegado, **su puesto no produce**. Lo empezado queda guardado para cuando vuelva.
- **Alternativas:**
  1. Se detiene (lo actual).
  2. Un suplente automático.
  3. Producción reducida.
- **Recomendación:** la 1, que da peso a la decisión de a quién llevas.
- **Archivos afectados:** `TownSim._hour`.

## Q-07 — Investigación (Salón de investigación)
- **Contexto.** **No está implementada.** La profesión Erudito solo abarata la Biblioteca.
- **Alternativas:**
  1. Árbol de tecnologías.
  2. Proyectos independientes con requisitos.
  3. Una combinación de ambos.
- **Recomendación:** la 2, con unos 15 proyectos que desbloqueen recetas o mejoras concretas.
- **Qué decides tú:** cuál prefieres y si va antes o después del rediseño de la taberna.

## Q-08 — Automatización con mucha población
- **Contexto.** Hoy cada trabajador se asigna a mano, con botones en el panel del edificio o en el Salón.
- **Alternativas:**
  1. "Asignación automática" que llene los puestos con los mejores en esa profesión.
  2. Prioridades por héroe al estilo RimWorld.
  3. Solo a mano.
- **Recomendación:** la 1 como botón, sin quitar el control manual.
- **Archivos afectados:** futuros `Game.auto_assign()` y los paneles.

## Q-09 — Edificios obligatorios u opcionales
- **Contexto.** Hoy empiezan construidos el Salón, el Círculo, el Cuartel, la Sala de guerra, la Puerta, el Memorial, 2 dormitorios, la cocina, el hospital, la herrería, el taller, la taberna, la granja, la tala, la mina y el almacén.
  - Los que se construyen: alquimia (Salón nivel 2), Biblioteca (Salón 2) y un 3.er dormitorio (Salón 2).
  - **No se puede demoler.**
- **Pregunta:** ¿quieres empezar con menos edificios construidos, para que el jugador elija el orden, y permitir la demolición?
- **Recomendación:** que empiecen construidos solo el Salón, el Círculo, la Puerta, el Memorial, 1 dormitorio, la granja y la cocina. Lo demás se construye. Demolición solo con el edificio vacío.

## Q-10 — Durabilidad y reparación del equipo
- **Contexto.** **No existen.** El equipo no se gasta.
- **Recomendación:** dejarlo fuera hasta que el combate y el botín estén equilibrados.

## Q-11 — Peso e inventario de expedición
- **Contexto.** Hoy cada héroe lleva una bolsa de 3 tipos × 3 unidades (pociones y antídotos) que usa por su cuenta. No hay peso.
  - El botín va directo al almacén. Si no cabe, se queda en la torre y el resultado lo dice.
- **Alternativas:**
  1. Peso por objeto.
  2. Huecos (lo actual).
  3. Bolsa grupal del escuadrón.
- **Recomendación:** huecos, más una bolsa grupal pequeña cuando haya provisiones de expedición.

## Q-12 — ¿Uso automático de habilidades por la IA?
- **Contexto.** Las habilidades solo se lanzan con Q, W, E y R. Con 5 héroes sin pausa puede ser mucha microgestión.
- **Alternativas:**
  1. Que la IA use las habilidades básicas.
  2. Que use las que marques como "auto" en cada héroe.
  3. Solo manual.
- **Recomendación:** la 2.

## Q-13 — Rarezas y números del botín
- **Contexto.** Los pesos provisionales de rareza son:

  | Rareza | Peso |
  |---|---|
  | Común | 60 |
  | Poco común | 28 |
  | Rara | 9 |
  | Épica | 2,5 |
  | Legendaria | 0,45 |
  | Mítica | 0,05 |

  - Las rarezas altas suben con el piso.
  - El jefe da al menos un objeto raro.
  - Hay 5 únicos y 2 sets.
- **Qué decides tú:** si esa curva te parece bien, o si los míticos solo deben salir de jefes.

## Q-14 — ¿Profesiones de vida pasada que no encajan?
- **Contexto.** Al traducir las 20 profesiones de vida pasada a 11 profesiones del pueblo, algunas se adaptaron:
  - guardia → constructor;
  - explorador → leñador;
  - sastre → carpintero;
  - pescador y cazador → cocinero.
- **Recomendación:** añadir Pescador, Cazador y Sastre como profesiones del pueblo cuando existan sus edificios (muelle, cabaña de caza, sastrería).
