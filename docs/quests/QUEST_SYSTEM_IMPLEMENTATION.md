# Sistema de misiones — implementacion

Hecho: biblioteca validada, generador determinista con repeticion y rareza, tracker, gestor con limite 3, cadenas lineal y ramificada, 3 secretos, recompensas generadas/entregadas por separado, guardado versionado tolerante a datos corruptos, UI en gremio y HUD, 77 comprobaciones.

Limitaciones conocidas:
- El contenido de un piso (objetos) se vuelve a sortear en cada visita; los objetivos de interactuar/descubrir solo estan garantizados en la primera visita.
- El evento `survival_completed` aun no lo emite `Mission`; el objetivo `survive` esta soportado por el tracker pero no cableado.
- Solo piso 1-10 (tier 1).
