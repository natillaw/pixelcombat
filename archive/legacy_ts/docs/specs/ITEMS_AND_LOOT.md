# Equipo, inventario, loot, afijos y sets

## 1. Equipo — CONFIRMADO (D-021)
- Los stats vienen **solo de los objetos**. La ropa y el pelo base del generador son cosméticos y no dan stats.
- La armadura equipada **reemplaza** la capa base correspondiente al dibujar; nunca se dibuja encima. El aspecto base guardado nunca cambia.
- Capas disponibles en la hoja de Caz: `Held_Item/2..6` (hojas completas con el arma en cada frame, incluido el lunge), `Top` (11 estilos), `Bottom` (5), `Hat` (5), cada uno en 5 colores. Armas o armaduras fuera de esto requieren arte nuevo para **todos** los frames (solo si la EULA lo permite; D-020/D-023). No hay frames de arco dibujados.
- Cada objeto: id, slot, archivo de capa, stats, clases permitidas. Cada pack nuevo: rejilla de 48 px o mapa de frames propio, estilo coherente y licencia registrada.
- Abierto: ropa interior por defecto o cuerpo base (P-14); slots; qué clase usa qué tipo de arma; drops y pérdida al morir (D-011 exige definir qué pasa con el equipo de un héroe muerto).
- Antigua tarea T-030: tabla de datos de objetos, slots, cargador multi-pack con mapa de frames, el objeto equipado oculta la capa base, stats solo desde objetos.

## 2. Inventario (P-19)
El Bible exige guardar y cargar inventario/equipo. Sin diseño.

## 3. Loot procedural, afijos y sets (P-19)
Pedidos por el dueño (2026-10-30). Sin spec: rarezas de objeto, tablas de botín por piso y bioma, afijos (prefijos y sufijos con rangos), bonificaciones de set y su relación con el crafting y la economía. **No implementar hasta escribir y aprobar esta sección.**
Restricciones que ya aplican: determinismo con semilla guardada (D-004), números en datos (no en la UI) y nada de pagar por ganar (Bible).
