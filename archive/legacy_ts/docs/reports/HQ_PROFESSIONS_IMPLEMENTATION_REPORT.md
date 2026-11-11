# Informe de implementación — Cuartel general y profesiones (fase 1)

Fecha: 2026-10-31. Código: commit `6558c35`. CI: **20/20 PASS** ([ejecución](https://github.com/natillaw/tactical-summoners/actions/runs/41150421537)).

El detalle técnico completo está en `docs/reports/MASTER_DEVELOPMENT_SESSION_REPORT.md`. Aquí se sigue el índice que pediste. Lo marcado **NO** no existe en el código.

1. **Arquitectura final.**
   - Las definiciones estáticas están en `scripts/data/`: `town_tables`, `profession_defs`, `economy_defs` e `item_defs`.
   - El estado de la partida vive en `Game` (almacén, reloj, trabajos, obras, pacientes, disposición, registro y equipo guardado) y en `HeroData` (profesiones, necesidades, enfermedades, cama, equipo y bolsa).
   - Las reglas están en `TownSim`: son puras y deterministas y no dependen de ninguna escena.
   - La presentación está en `town_screen`, `town_view`, `town_hero` y `hero_info_panel`, y no contiene lógica económica.
2. **Sistemas implementados:**
   - reloj (D-047);
   - profesiones (D-049);
   - trabajo con recetas;
   - almacén;
   - camas;
   - necesidades;
   - hospital y enfermedades;
   - taberna;
   - construcción (D-048);
   - colocación (D-050);
   - equipo y botín.
3. **Edificios.** Hay 20:
   - Salón del Invocador, Círculo, Cuartel, Sala de guerra, Puerta de la Torre y Memorial;
   - 3 dormitorios;
   - Cocina, Hospital, Herrería, Taller, Alquimia, Taberna y Biblioteca;
   - **nuevos:** Granja, Tala, Mina y Almacén.
4. **Función de cada uno:** ver la tabla de `town_tables.gd` (`desc`, `jobs`) y la sección E del informe de la sesión.
5. **Niveles y progresión.**
   - Niveles del 1 al 5. El Salón limita el nivel de todos los demás.
   - La Alquimia, la Biblioteca y el 3.er dormitorio piden el Salón a nivel 2.
   - Las mejoras añaden puestos de trabajo (+1 cada 2 niveles), velocidad (+10% por nivel), camas, camas de hospital, capacidad del almacén y calidad de la forja.
6. **Profesiones disponibles:** Constructor, Herrero, Carpintero, Minero, Leñador, Agricultor, Cocinero, Alquimista, Médico, Erudito y Tabernero.
7. **Qué produce cada una:**

   | Profesión | Produce |
   |---|---|
   | Agricultor | Grano y hierbas |
   | Leñador | Madera |
   | Minero | Piedra y mineral |
   | Cocinero | Comida |
   | Carpintero | Materiales |
   | Herrero | Lingotes, armas y armaduras |
   | Alquimista | Medicina, pociones y antídotos |
   | Médico | Tratamientos |
   | Constructor | Obras |
   | Erudito | La Biblioteca cuesta un 25% menos |
   | Tabernero | La taberna relaja más y hay menos peleas |

8. **Asignación de trabajadores.**
   - Se hace desde el panel de cada edificio, desde el Salón (equipo de obra) o desde la pantalla HQ.
   - Hay un número limitado de puestos por edificio.
   - Al asignar a un héroe, aprende la profesión del puesto como aprendiz si tiene un hueco libre (máximo 2).
   - Un héroe solo puede estar en una actividad a la vez.
9. **Economía:**
   - No hay producción gratis.
   - Los materiales se toman al empezar cada lote, así que no se pueden usar dos veces.
   - Cada recurso tiene un límite de almacén y la producción se para si está lleno.
   - Si algo no produce, aparece el motivo.
10. **Recursos:** se generan en la granja, la tala y la mina, y como botín y recompensas. Se consumen en la cocina, el taller, la herrería, la alquimia, las comidas de los héroes, los tratamientos, la construcción y la biblioteca.
11. **Dormitorios:** 6, 8, 10, 12 o 14 camas por nivel. La calidad del descanso es ×(0,8 + 0,1 × nivel). Cada héroe tiene una cama asignada.
12. **Capacidad y reglas.**
    - Población máxima = total de camas. Al empezar son 12; el máximo actual es 42.
    - Sin cama libre no se puede invocar, y se explica por qué.
    - Un héroe desplegado o en el hospital conserva su cama.
    - Si sobran héroes, duermen en el suelo; nadie se elimina.
13. **Hospital:**
    - 2–6 camas, con prioridad por gravedad.
    - Cada médico atiende a 2 pacientes por hora y gasta 1 medicina por cada 24 h de tratamiento.
    - Sin médico solo hay reposo.
14. **Enfermedades y tratamientos:**

    | Enfermedad | Cura |
    |---|---|
    | Herida infectada | Solo con médico |
    | Fiebre del pantano | Reposo; el médico la acorta |
    | Toxina | Antídoto |
    | Tos de las cuevas | Se contagia en el dormitorio |
    | Agotamiento | Solo el sueño |

    Todas bajan atributos, la eficiencia en el trabajo y el combate.
15. **Taberna:** acuden los héroes con estrés ≥ 55. Baja el estrés. Se forman parejas que crean vínculos o discuten según sus rasgos. Solo se guardan recuerdos cuando cambia el tipo de relación.
16. **Felicidad, estrés y relaciones:**
    - Valores: hambre, fatiga y estrés, más el ánimo calculado.
    - Usan las relaciones que ya existían, sin un sistema duplicado.
    - Los amigos trabajan un 10% mejor juntos y los rivales un 15% peor.
    - Los compañeros de trabajo se conocen poco a poco.
17. **Investigación:** **NO** implementada (Q-07).
18. **Expediciones:**
    - Cada piso jugado hace pasar 24 h en el pueblo con el escuadrón fuera, sin trabajar.
    - Al volver: hambre, fatiga y estrés (más si murió alguien).
    - Riesgo de enfermedad si el héroe cayó o fue envenenado, según el piso.
    - Botín de equipo.
19. **Héroes:**
    - No se creó otro HeroData.
    - Las profesiones salen de la vida pasada sin tiradas nuevas, con `HeroGenerator.VERSION` 3.
    - Las enfermedades actúan sobre `attributes()` y el equipo sobre `get_stats()`.
20. **Guardado:** versión 9 con migración desde v8 (y desde versiones anteriores, en cadena). Probado: ida y vuelta, sin duplicados, determinista.
21. **Qué se probó:** las suites `hq`, `items`, `skills`, `town`, `tower`, `procedural`, `simulation` y `deep systems` (ver la sección I del informe de la sesión).
22. **Resultado de las pruebas:**
    - Final: 20/20 PASS.
    - Intermedios: 0/20 por un error de compilación y después 18/20; ambos se corrigieron.
23. **Problemas pendientes:**
    - No hay animaciones de trabajo específicas.
    - No se puede demoler.
    - No hay asignación automática.
    - El panel del héroe no se refresca al equipar.
24. **NO implementado:**
    - investigación;
    - mercado;
    - santuario;
    - campo de entrenamiento con maestros;
    - durabilidad y reparación;
    - peso;
    - provisiones de expedición;
    - profesiones de pescador, cazador, sastre, cirujano, cartógrafo y similares.
25. **Decisiones que tomé** (provisionales): están en `docs/design/DECISIONS_PENDING_USER.md`, de Q-02 a Q-14.
26. **Próximas fases recomendadas:**
    1. Investigación.
    2. Vista previa de la expedición.
    3. Asignación automática y demolición.
    4. Animaciones de trabajo (buscar assets libres con licencia).
    5. Equilibrar la economía con simulaciones largas en la CI.
