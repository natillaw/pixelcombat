#!/usr/bin/env python3
"""Herramienta de diseno de los pisos hechos a mano (tier 1, bosque del Cuervo).

    python3 tools/floors/build_floors.py [--preview DIR] [piso ...]

Cada piso se dibuja con primitivas (rios, lagos, fuertes, caminos, bosquetes) y se exporta a
`data/floors/floor_NN.txt` (mapa) y `floor_NN.json` (anclas y decorado). El juego los carga con
`AuthoredFloor`. Para retocar un piso a mano basta con editar el .txt (un caracter por casilla:
`.` suelo, `=` camino/puente, `~` agua, `#` muro/bosque denso, `S` entrada, `X` salida) o las
coordenadas [columna, fila] del .json. Esta herramienta valida que todo este conectado y andable.
El generador procedural del juego NO se toca: sigue siendo la base para los demas tiers.
"""
import json
import math
import os
import random
import sys
from collections import deque

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "data", "floors")
WALK = set(".=SX")


class FloorMap:
    def __init__(self, n, cols, rows, seed):
        self.n, self.cols, self.rows = n, cols, rows
        self.rng = random.Random(seed)
        self.g = [["." for _ in range(cols)] for _ in range(rows)]
        self.anchors = {}
        self.props = []
        self.keep = set()
        self.spawn = None
        self.exit = None
        self.notes = []

    # --- dibujo ---------------------------------------------------------------------
    def set(self, x, y, ch):
        if 0 <= x < self.cols and 0 <= y < self.rows:
            self.g[y][x] = ch

    def get(self, x, y):
        if 0 <= x < self.cols and 0 <= y < self.rows:
            return self.g[y][x]
        return "#"

    def rect(self, x0, y0, x1, y1, ch):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, ch)

    def ring(self, x0, y0, x1, y1, ch, t=1):
        for k in range(t):
            for x in range(x0 + k, x1 - k + 1):
                self.set(x, y0 + k, ch)
                self.set(x, y1 - k, ch)
            for y in range(y0 + k, y1 - k + 1):
                self.set(x0 + k, y, ch)
                self.set(x1 - k, y, ch)

    def ellipse(self, cx, cy, rx, ry, ch):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    self.set(x, y, ch)

    def ellipse_ring(self, cx, cy, rx, ry, ch, t=1.4):
        for y in range(int(cy - ry) - 2, int(cy + ry) + 3):
            for x in range(int(cx - rx) - 2, int(cx + rx) + 3):
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if 1.0 - t / max(rx, ry) <= d <= 1.0:
                    self.set(x, y, ch)

    def stamp(self, x, y, w, ch, only=None):
        r = w / 2.0
        for yy in range(int(y - r) - 1, int(y + r) + 2):
            for xx in range(int(x - r) - 1, int(x + r) + 2):
                if (xx - x) ** 2 + (yy - y) ** 2 <= r * r + 0.3:
                    if only is None or self.get(xx, yy) in only:
                        self.set(xx, yy, ch)

    def line(self, p0, p1, w, ch, only=None):
        steps = int(max(abs(p1[0] - p0[0]), abs(p1[1] - p0[1])) * 2) + 1
        for i in range(steps + 1):
            t = i / steps
            self.stamp(p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t, w, ch, only)

    def polyline(self, pts, w, ch, only=None, wobble=0.0):
        for a, b in zip(pts, pts[1:]):
            self.line(a, b, w, ch, only)

    def river(self, pts, w, wobble=1.2):
        """Rio sinuoso: pasa por los puntos con un pequeno vaiven."""
        out = []
        for a, b in zip(pts, pts[1:]):
            steps = int(math.hypot(b[0] - a[0], b[1] - a[1]) / 3) + 1
            for i in range(steps):
                t = i / steps
                out.append((a[0] + (b[0] - a[0]) * t + math.sin(t * 6 + len(out)) * wobble, a[1] + (b[1] - a[1]) * t + math.cos(t * 5 + len(out)) * wobble))
        out.append(pts[-1])
        for a, b in zip(out, out[1:]):
            self.line(a, b, w, "~")

    def keep_around(self, pts, r):
        for (px, py) in pts:
            for y in range(int(py - r), int(py + r) + 1):
                for x in range(int(px - r), int(px + r) + 1):
                    if (x - px) ** 2 + (y - py) ** 2 <= r * r:
                        self.keep.add((x, y))

    def keep_route(self, pts, r):
        for a, b in zip(pts, pts[1:]):
            steps = int(max(abs(b[0] - a[0]), abs(b[1] - a[1]))) + 1
            self.keep_around([(a[0] + (b[0] - a[0]) * i / steps, a[1] + (b[1] - a[1]) * i / steps) for i in range(steps + 1)], r)

    def thickets(self, count, rmin, rmax, only_on="."):
        placed = 0
        tries = 0
        while placed < count and tries < count * 40:
            tries += 1
            cx = self.rng.randint(4, self.cols - 5)
            cy = self.rng.randint(4, self.rows - 5)
            r = self.rng.uniform(rmin, rmax)
            cells = [(x, y) for y in range(int(cy - r) - 1, int(cy + r) + 2) for x in range(int(cx - r) - 1, int(cx + r) + 2) if (x - cx) ** 2 + (y - cy) ** 2 <= r * r]
            if any((c in self.keep) or self.get(*c) not in only_on for c in cells):
                continue
            for (x, y) in cells:
                self.set(x, y, "#")
            placed += 1

    def trees(self, count):
        """Arboles sueltos de 1 casilla (muro) fuera de las zonas despejadas."""
        placed = 0
        tries = 0
        while placed < count and tries < count * 30:
            tries += 1
            x = self.rng.randint(3, self.cols - 4)
            y = self.rng.randint(3, self.rows - 4)
            if (x, y) in self.keep or self.get(x, y) != ".":
                continue
            self.set(x, y, "#")
            placed += 1

    def border(self, t=3):
        self.ring(0, 0, self.cols - 1, self.rows - 1, "#", t)

    # --- puntos ---------------------------------------------------------------------
    def mark_spawn(self, x, y):
        self.spawn = (x, y)
        self.rect(x - 4, y - 4, x + 4, y + 4, ".")
        self.set(x, y, "S")
        self.keep_around([(x, y)], 7)

    def mark_exit(self, x, y):
        self.exit = (x, y)
        self.rect(x - 4, y - 4, x + 4, y + 4, ".")
        self.set(x, y, "X")
        self.keep_around([(x, y)], 7)

    def snap(self, x, y, r=6):
        if self.get(x, y) in WALK:
            return (x, y)
        best = None
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if self.get(x + dx, y + dy) in ".=" and (best is None or dx * dx + dy * dy < best[0]):
                    best = (dx * dx + dy * dy, x + dx, y + dy)
        if best is None:
            raise ValueError("piso %d: ancla (%d,%d) sin suelo cerca" % (self.n, x, y))
        self.notes.append("ancla (%d,%d) movida a (%d,%d)" % (x, y, best[1], best[2]))
        return (best[1], best[2])

    def anchor(self, key, *points):
        for (x, y) in points:
            self.keep_around([(x, y)], 3)
        self.anchors.setdefault(key, []).extend([list(p) for p in points])

    def prop(self, kind, x, y, variant=0):
        self.props.append({"kind": kind, "at": [x, y], "variant": variant})

    def clearing(self, cx, cy, r):
        self.ellipse(cx, cy, r, r * 0.8, ".")
        self.keep_around([(cx, cy)], r + 1)

    # --- validacion y exportacion -----------------------------------------------------
    def reach(self):
        seen = {self.spawn}
        q = deque([self.spawn])
        while q:
            x, y = q.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if n not in seen and self.get(*n) in WALK:
                    seen.add(n)
                    q.append(n)
        return seen

    def connect(self, target):
        """Abre un pasillo de 2 casillas desde `target` hasta el terreno alcanzable (cruza muros; el agua se convierte en puente)."""
        import heapq
        seen = self.reach()
        if target in seen:
            return
        pq = [(0, target)]
        best = {target: 0}
        prev = {}
        goal = None
        while pq:
            cost, cur = heapq.heappop(pq)
            if cost > best.get(cur, 1e9):
                continue
            if cur in seen:
                goal = cur
                break
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (cur[0] + dx, cur[1] + dy)
                if not (3 <= n[0] < self.cols - 3 and 3 <= n[1] < self.rows - 3):
                    continue
                ch = self.get(*n)
                step = 1 if ch in WALK else (3 if ch == "#" else 7)
                if cost + step < best.get(n, 1e9):
                    best[n] = cost + step
                    prev[n] = cur
                    heapq.heappush(pq, (cost + step, n))
        if goal is None:
            raise ValueError("piso %d: no se pudo conectar %s" % (self.n, str(target)))
        node = goal
        while node != target:
            for ox, oy in ((0, 0), (1, 0), (0, 1)):
                cx, cy = node[0] + ox, node[1] + oy
                ch = self.get(cx, cy)
                if ch == "#":
                    self.set(cx, cy, ".")
                elif ch == "~":
                    self.set(cx, cy, "=")
            node = prev[node]
        self.notes.append("pasillo abierto hacia %s" % str(target))

    def thin_out(self):
        """Rellena la hierba que no cabe en un cuadrado de 2x2 (rendijas de 1 casilla entre arboles): el heroe no cabe
        ni el pathfinding de los bots las usa, y quedaban bolsas sin salida. Se respetan caminos, puentes, entrada, salida y anclas."""
        keep = {tuple(self.spawn)}
        if self.exit:
            keep.add(tuple(self.exit))
        for pts in self.anchors.values():
            for (x, y) in pts:
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        keep.add((x + dx, y + dy))
        def walk(x, y):
            return self.get(x, y) in WALK
        fat = set()
        for y in range(1, self.rows - 1):
            for x in range(1, self.cols - 1):
                for ox in (0, -1):
                    for oy in (0, -1):
                        if all(walk(x + ox + i, y + oy + j) for i in (0, 1) for j in (0, 1)):
                            for i in (0, 1):
                                for j in (0, 1):
                                    fat.add((x + ox + i, y + oy + j))
        filled = 0
        for y in range(1, self.rows - 1):
            for x in range(1, self.cols - 1):
                if self.get(x, y) == "." and (x, y) not in fat and (x, y) not in keep:
                    self.set(x, y, "#")
                    filled += 1
        self.notes.append("rendijas rellenadas: %d" % filled)

    def finalize(self):
        for key, pts in list(self.anchors.items()):
            self.anchors[key] = [list(self.snap(x, y)) for x, y in pts]
        if self.exit:
            self.connect(self.exit)
        for key, pts in list(self.anchors.items()):
            for (x, y) in pts:
                self.connect((x, y))
        self.thin_out()
        if self.exit:
            self.connect(self.exit)
        for key, pts in list(self.anchors.items()):
            for (x, y) in pts:
                self.connect((x, y))
        seen = self.reach()
        problems = []
        if self.exit not in seen:
            problems.append("la salida no es alcanzable desde la entrada")
        for key, pts in self.anchors.items():
            for (x, y) in pts:
                if (x, y) not in seen:
                    problems.append("ancla %s (%d,%d) inalcanzable" % (key, x, y))
        return problems

    def write(self, preview_dir=None):
        os.makedirs(OUT, exist_ok=True)
        with open(os.path.join(OUT, "floor_%02d.txt" % self.n), "w") as f:
            f.write("\n".join("".join(row) for row in self.g) + "\n")
        meta = {"floor": self.n, "size": [self.cols, self.rows], "anchors": self.anchors, "props": self.props}
        with open(os.path.join(OUT, "floor_%02d.json" % self.n), "w") as f:
            json.dump(meta, f, indent="\t", ensure_ascii=False)
            f.write("\n")
        if preview_dir:
            self.preview(preview_dir)

    def preview(self, directory):
        from PIL import Image, ImageDraw
        s = 8
        im = Image.new("RGB", (self.cols * s, self.rows * s))
        d = ImageDraw.Draw(im)
        colors = {".": (70, 120, 60), "=": (150, 120, 80), "~": (50, 90, 170), "#": (25, 55, 30), "S": (240, 240, 80), "X": (240, 80, 240)}
        for y in range(self.rows):
            for x in range(self.cols):
                d.rectangle([x * s, y * s, x * s + s - 1, y * s + s - 1], fill=colors.get(self.g[y][x], (0, 0, 0)))
        palette = {"camp": (230, 60, 60), "pack": (250, 150, 60), "village": (80, 230, 230), "hunt": (255, 255, 255), "mini_boss": (255, 0, 0), "boss": (255, 0, 0)}
        for key, pts in self.anchors.items():
            col = palette.get(key, (240, 220, 120))
            for (x, y) in pts:
                d.ellipse([x * s - 4, y * s - 4, x * s + 12, y * s + 12], outline=col, width=2)
        os.makedirs(directory, exist_ok=True)
        im.save(os.path.join(directory, "floor_%02d.png" % self.n))


def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


# ===================================================================================
# Los 10 pisos. (x = columna, y = fila; origen arriba a la izquierda)
# ===================================================================================


def floor_1():
    fm = FloorMap(1, 84, 58, 101)
    fm.mark_spawn(8, 48)
    fm.mark_exit(76, 9)
    route = [(8, 48), (22, 44), (34, 38), (42, 30), (52, 24), (64, 16), (76, 9)]
    fm.keep_route(route, 4)
    # Arroyo estrecho con piedras para cruzar.
    fm.river([(36, 3), (38, 16), (36, 30), (40, 44), (38, 55)], 2.4)
    for (x, y) in ((38, 38), (37, 39), (38, 40)):
        fm.stamp(x, y, 3, ".")
    fm.stamp(40, 29, 3, "=", only="~.")
    # Claro con la fuente de bienvenida y camino de tierra.
    fm.clearing(44, 28, 7)
    fm.polyline(route, 2, "=", only=".")
    fm.thickets(70, 2.0, 4.5)
    fm.trees(150)
    fm.anchor("camp", (24, 36), (50, 14), (66, 28), (30, 20), (58, 46))
    fm.anchor("pack", (18, 30), (56, 38), (72, 20), (44, 44))
    fm.anchor("chest_wood", (30, 50), (58, 8), (70, 40))
    fm.anchor("note", (14, 40), (60, 22))
    fm.prop("camp_banner", 14, 46)
    return fm


def floor_2():
    """El Vado: un rio ancho parte el piso; la aldea esta en la orilla oeste, el Cuervo cobra peaje en la este."""
    fm = FloorMap(2, 92, 66, 202)
    fm.mark_spawn(8, 56)
    fm.mark_exit(84, 9)
    route = [(8, 56), (22, 48), (34, 40), (46, 33), (60, 28), (72, 20), (84, 9)]
    fm.keep_route(route, 4)
    fm.river([(46, 2), (44, 14), (47, 28), (45, 42), (46, 56), (45, 64)], 5.0, 1.6)
    # Vado de piedras (centro), puente roto al norte y una pasarela al sur.
    fm.stamp(46, 33, 5, ".", only="~")
    fm.line((44, 13), (48, 13), 3, "=", only="~.")
    fm.line((44, 52), (48, 52), 3, "=", only="~.")
    fm.clearing(20, 40, 8)
    fm.polyline(route, 2, "=", only=".")
    fm.thickets(90, 2.0, 5.0)
    fm.trees(170)
    fm.anchor("village", (20, 40))
    fm.anchor("camp", (62, 44), (70, 26), (58, 14), (80, 40))
    fm.anchor("pack", (32, 16), (34, 56), (76, 54))
    fm.anchor("waypoint", (14, 50), (30, 36), (52, 30), (66, 22), (78, 12))
    fm.anchor("slay_pack", (60, 48), (72, 32), (54, 10))
    fm.anchor("cache_kaito", (64, 47), (72, 29))
    fm.anchor("chest_wood", (30, 24), (74, 46), (56, 56))
    fm.anchor("note", (18, 54), (66, 16), (36, 10))
    fm.anchor("event", (34, 50), (58, 38))
    fm.anchor("hazard_mud", (30, 44), (38, 26), (52, 48), (64, 36))
    fm.anchor("campfire", (50, 22), (40, 30))
    fm.prop("wagon", 40, 46)
    fm.prop("camp_watchtower", 56, 30)
    return fm


def floor_3():
    """El Primer Campamento: una colina fortificada con empalizada y torres."""
    fm = FloorMap(3, 92, 66, 303)
    fm.mark_spawn(8, 54)
    fm.mark_exit(84, 10)
    route = [(8, 54), (20, 48), (32, 44), (44, 40), (56, 34), (68, 26), (84, 10)]
    fm.keep_route(route, 4)
    # Fuerte: muralla con dos puertas y patio.
    fm.ring(44, 14, 74, 40, "#", 2)
    for (x, y) in ((44, 27), (45, 27), (46, 27), (74, 27), (73, 27), (72, 27), (58, 40), (59, 40), (60, 40), (58, 39), (59, 39), (60, 39)):
        fm.set(x, y, ".")
    fm.rect(46, 16, 72, 38, ".")
    fm.keep_around([(59, 27)], 14)
    # Tramo de rio detras del fuerte.
    fm.river([(28, 2), (30, 12), (28, 24), (22, 36), (24, 50), (20, 64)], 3.6, 1.4)
    fm.stamp(26, 44, 4, ".", only="~")
    fm.line((24, 20), (30, 20), 3, "=", only="~.")
    fm.clearing(18, 40, 6)
    fm.polyline(route, 2, "=", only=".")
    fm.thickets(70, 2.0, 4.5)
    fm.trees(150)
    fm.anchor("camp", (59, 26), (52, 32), (66, 20), (36, 20), (20, 24))
    fm.anchor("pack", (36, 48), (70, 50), (80, 30), (16, 58))
    fm.anchor("nest", (52, 20), (66, 34))
    fm.anchor("slay_pack", (62, 22), (54, 34), (68, 28))
    fm.anchor("cache_lysa", (86, 56), (10, 6))
    fm.anchor("chest_wood", (30, 56), (78, 46), (14, 14))
    fm.anchor("chest_iron", (56, 22), (68, 36))
    fm.anchor("note", (22, 56), (80, 18), (38, 30))
    fm.anchor("event", (36, 34), (74, 46))
    fm.anchor("hazard_spikes", (50, 42), (64, 44), (42, 30), (76, 38))
    fm.anchor("hazard_mud", (30, 54), (14, 28))
    fm.anchor("campfire", (40, 36), (80, 18))
    for (x, y) in ((44, 14), (74, 14), (44, 40), (74, 40)):
        fm.prop("camp_watchtower", x, y)
    for x in range(50, 70, 4):
        fm.prop("camp_palisade", x, 40)
    return fm


def floor_4():
    """Hondonada: una cuenca con un lago central; la aldea vive en una peninsula."""
    fm = FloorMap(4, 96, 68, 404)
    fm.mark_spawn(8, 58)
    fm.mark_exit(88, 10)
    route = [(8, 58), (20, 56), (30, 50), (28, 36), (34, 22), (50, 12), (68, 10), (88, 10)]
    fm.keep_route(route, 4)
    fm.ellipse(52, 36, 19, 13, "~")          # lago
    fm.ellipse(34, 44, 6, 5, ".")            # peninsula de la aldea
    fm.keep_around([(34, 44)], 9)
    fm.line((30, 44), (22, 52), 5, ".", only="~.")
    fm.stamp(72, 36, 6, ".", only="~")
    fm.polyline(route, 2, "=", only=".")
    # Pasarela de madera sobre el brazo este del lago.
    fm.line((66, 28), (74, 24), 3, "=", only="~.")
    fm.thickets(80, 2.0, 4.8)
    fm.trees(150)
    fm.anchor("village", (34, 44))
    fm.anchor("camp", (60, 16), (76, 26), (78, 50), (56, 58), (20, 18))
    fm.anchor("pack", (40, 14), (66, 52), (84, 36), (14, 40))
    fm.anchor("cache_tob", (45, 51), (70, 49))
    fm.anchor("chest_wood", (20, 30), (82, 60), (48, 8))
    fm.anchor("chest_iron", (60, 54), (80, 18))
    fm.anchor("note", (16, 50), (70, 12), (36, 56))
    fm.anchor("event", (44, 22), (74, 44))
    fm.anchor("hazard_spikes", (44, 50), (50, 52), (70, 48), (30, 28))
    fm.anchor("hazard_mud", (24, 40), (40, 20), (60, 48), (76, 18))
    fm.anchor("campfire", (26, 28), (72, 40))
    fm.prop("planter", 30, 40)
    return fm


def floor_5():
    """El Puesto Avanzado: un fuerte de piedra en medio del camino, con patio, torres y dos tenientes."""
    fm = FloorMap(5, 100, 70, 505)
    fm.mark_spawn(8, 58)
    fm.mark_exit(92, 12)
    route = [(8, 58), (22, 54), (36, 48), (50, 40), (64, 30), (78, 22), (92, 12)]
    fm.keep_route(route, 4)
    # Fuerte principal.
    fm.ring(38, 16, 76, 48, "#", 2)
    for (x, y) in ((38, 32), (39, 32), (40, 32), (38, 33), (39, 33), (40, 33), (76, 32), (75, 32), (74, 32), (76, 33), (75, 33), (74, 33), (56, 48), (57, 48), (58, 48), (56, 47), (57, 47), (58, 47), (56, 16), (57, 16), (58, 16), (56, 17), (57, 17), (58, 17)):
        fm.set(x, y, ".")
    fm.rect(40, 18, 74, 46, ".")
    fm.ring(52, 26, 62, 38, "#", 1)             # torre central con puerta sur
    for (x, y) in ((56, 38), (57, 38), (58, 38)):
        fm.set(x, y, ".")
    fm.rect(53, 27, 61, 37, ".")
    fm.keep_around([(57, 32)], 20)
    fm.river([(88, 38), (80, 52), (70, 58), (56, 66)], 3.2, 1.0)
    fm.line((74, 55), (78, 55), 3, "=", only="~.")
    fm.polyline(route, 2, "=", only=".")
    fm.thickets(80, 2.0, 5.0)
    fm.trees(150)
    fm.anchor("camp", (14, 40), (24, 22), (86, 44), (88, 24), (30, 56), (68, 60))
    fm.anchor("pack", (46, 56), (84, 8), (12, 22))
    fm.anchor("hunt", (57, 32), (66, 24))
    fm.anchor("mini_boss", (46, 24), (68, 40))
    fm.anchor("cache_sunna", (14, 43), (86, 47), (30, 59))
    fm.anchor("chest_iron", (44, 40), (70, 22), (24, 46))
    fm.anchor("note", (18, 56), (84, 30), (50, 12))
    fm.anchor("event", (30, 34), (70, 54))
    fm.anchor("hazard_spikes", (36, 54), (60, 56), (82, 38), (28, 40), (48, 12))
    fm.anchor("hazard_mud", (16, 32), (44, 58))
    fm.anchor("key", (24, 24), (88, 26))
    fm.anchor("vault", (82, 8), (14, 12))
    fm.anchor("campfire", (30, 46), (82, 36))
    for (x, y) in ((38, 16), (76, 16), (38, 48), (76, 48), (52, 26), (62, 26), (52, 38), (62, 38)):
        fm.prop("camp_watchtower", x, y)
    fm.prop("camp_banner", 56, 20)
    fm.prop("camp_banner", 58, 44)
    return fm


def floor_6():
    """Las Brasas: un pantano quemado con islas secas, una fragua en ruinas y el contrabando del Cuervo."""
    fm = FloorMap(6, 100, 70, 606)
    fm.mark_spawn(8, 12)
    fm.mark_exit(92, 58)
    route = [(8, 12), (20, 18), (32, 26), (44, 34), (56, 40), (70, 48), (82, 52), (92, 58)]
    fm.keep_route(route, 4)
    # Charcas y marismas dispersas.
    for (cx, cy, rx, ry) in ((30, 40, 9, 6), (62, 20, 10, 6), (76, 34, 7, 5), (24, 58, 10, 5), (50, 56, 8, 5), (88, 18, 6, 6), (46, 14, 7, 4)):
        fm.ellipse(cx, cy, rx, ry, "~")
    fm.clearing(26, 22, 7)
    fm.polyline(route, 2, "=", only=".")
    # Pasos de tierra sobre las charcas del camino.
    for (x, y) in ((44, 34), (57, 40), (70, 47)):
        fm.stamp(x, y, 5, "=", only="~.")
    fm.thickets(60, 2.0, 4.0)
    fm.trees(120)
    fm.anchor("village", (26, 22))
    fm.anchor("camp", (56, 22), (40, 46), (70, 58), (84, 32), (14, 44), (60, 8))
    fm.anchor("pack", (34, 8), (78, 46), (48, 62), (90, 44))
    fm.anchor("relic", (74, 24), (50, 50))
    fm.anchor("relic_altar", (20, 10), (36, 14))
    fm.anchor("slay_pack", (58, 26), (42, 50), (72, 56))
    fm.anchor("cache_grix", (94, 40), (8, 64), (60, 66))
    fm.anchor("chest_iron", (40, 24), (76, 8), (30, 62))
    fm.anchor("note", (16, 34), (66, 14), (84, 52))
    fm.anchor("event", (44, 22), (62, 48))
    fm.anchor("hazard_poison_pool", (36, 38), (54, 30), (68, 26), (28, 52), (50, 46), (80, 40))
    fm.anchor("hazard_mud", (20, 40), (60, 36), (86, 56))
    fm.anchor("campfire", (44, 28), (76, 54))
    fm.prop("camp_armory", 60, 20)
    fm.prop("camp_banner", 82, 30)
    return fm


def floor_7():
    """La Vigia Perdida: ruinas de una torre de vigia en un bosque cerrado y oscuro."""
    fm = FloorMap(7, 96, 68, 707)
    fm.mark_spawn(8, 56)
    fm.mark_exit(88, 12)
    route = [(8, 56), (22, 50), (36, 46), (48, 36), (60, 30), (74, 22), (88, 12)]
    fm.keep_route(route, 3)
    # Ruinas de la vigia: anillo roto con huecos.
    fm.ring(42, 22, 66, 44, "#", 2)
    for (x, y) in ((42, 30), (43, 30), (42, 31), (43, 31), (54, 44), (55, 44), (54, 43), (55, 43), (66, 36), (65, 36), (66, 37), (65, 37), (50, 22), (51, 22), (50, 23), (51, 23), (46, 44), (47, 44), (60, 22), (61, 22)):
        fm.set(x, y, ".")
    fm.rect(44, 24, 64, 42, ".")
    fm.keep_around([(54, 33)], 11)
    fm.river([(88, 62), (74, 56), (66, 62), (52, 64)], 3.0, 1.0)
    fm.line((70, 58), (74, 58), 3, "=", only="~.")
    fm.polyline(route, 2, "=", only=".")
    fm.thickets(130, 2.0, 5.5)     # mas bosque: piso cerrado
    fm.trees(260)
    fm.anchor("clue", (14, 52), (32, 40), (54, 33), (72, 26), (84, 18))
    fm.anchor("camp", (26, 30), (30, 60), (70, 40), (82, 56), (60, 12), (12, 18))
    fm.anchor("pack", (40, 14), (50, 56), (86, 30), (20, 44))
    fm.anchor("cache_veyd_none", (1, 1))
    fm.anchor("chest_iron", (34, 28), (62, 52), (78, 8))
    fm.anchor("note", (18, 42), (66, 34), (44, 54), (86, 40))
    fm.anchor("event", (28, 46), (70, 14), (48, 18))
    fm.anchor("event", (82, 44))
    fm.anchor("hazard_spikes", (36, 36), (60, 46), (74, 36), (24, 52))
    fm.anchor("hazard_mud", (30, 22), (52, 52), (80, 62))
    fm.anchor("key", (30, 28), (82, 54))
    fm.anchor("vault", (12, 14), (88, 64))
    fm.anchor("campfire", (22, 46), (50, 28), (78, 20))
    fm.prop("camp_watchtower", 42, 22)
    fm.prop("camp_watchtower", 66, 44)
    del fm.anchors["cache_veyd_none"]
    return fm


def floor_8():
    """Territorio del Cuervo: marisma con una isla fortificada unida por puentes de madera."""
    fm = FloorMap(8, 100, 70, 808)
    fm.mark_spawn(8, 58)
    fm.mark_exit(92, 10)
    route = [(8, 58), (20, 54), (32, 50), (44, 44), (56, 36), (70, 28), (80, 20), (92, 10)]
    fm.keep_route(route, 4)
    fm.ellipse(54, 32, 22, 16, "~")           # gran marisma
    fm.ellipse(54, 32, 9, 7, ".")             # isla central
    fm.ring(46, 26, 62, 38, "#", 1)           # empalizada de la isla
    for (x, y) in ((46, 32), (47, 32), (62, 32), (61, 32), (54, 38), (54, 37)):
        fm.set(x, y, ".")
    # Puentes de madera hacia la isla (camino sobre agua).
    fm.line((34, 32), (46, 32), 3, "=", only="~.")
    fm.line((62, 32), (76, 32), 3, "=", only="~.")
    fm.line((54, 38), (54, 52), 3, "=", only="~.")
    fm.clearing(80, 52, 7)
    fm.polyline(route, 2, "=", only=".")
    for (x, y) in ((44, 44), (56, 36), (70, 28)):
        fm.stamp(x, y, 4, "=", only="~.")
    fm.thickets(70, 2.0, 4.5)
    fm.trees(140)
    fm.anchor("village", (80, 52))
    fm.anchor("camp", (54, 32), (50, 28), (58, 36), (20, 30), (76, 12), (30, 60))
    fm.anchor("pack", (36, 20), (68, 58), (14, 46), (88, 36))
    fm.anchor("beacon", (62, 54))
    fm.anchor("nest", (52, 30), (58, 34), (20, 32))
    fm.anchor("waypoint", (24, 52), (38, 46), (70, 30), (86, 14))
    fm.anchor("cache_nadir", (41, 37), (51, 49), (28, 54))
    fm.anchor("chest_iron", (34, 12), (86, 42), (22, 64))
    fm.anchor("note", (18, 40), (72, 14), (48, 60))
    fm.anchor("event", (30, 46), (66, 20))
    fm.anchor("hazard_poison_pool", (40, 36), (66, 42), (50, 48), (74, 24), (36, 26), (60, 22))
    fm.anchor("hazard_mud", (28, 54), (46, 54), (82, 26), (16, 24))
    fm.anchor("campfire", (30, 56), (84, 22))
    for (x, y) in ((46, 26), (62, 26), (46, 38), (62, 38)):
        fm.prop("camp_watchtower", x, y)
    fm.prop("camp_banner", 54, 28)
    return fm


def floor_9():
    """La Antesala: un castillo en ruinas con foso, puente levadizo y patio de armas."""
    fm = FloorMap(9, 100, 70, 909)
    fm.mark_spawn(8, 56)
    fm.mark_exit(90, 12)
    route = [(8, 56), (22, 52), (34, 46), (44, 40)]
    fm.keep_route(route, 4)
    # Foso y castillo.
    fm.rect(36, 12, 78, 54, "~")
    fm.rect(39, 15, 75, 51, ".")
    fm.ring(39, 15, 75, 51, "#", 2)
    for (x, y) in ((39, 33), (40, 33), (41, 33), (39, 34), (40, 34), (41, 34)):
        fm.set(x, y, ".")
    fm.line((30, 34), (40, 34), 3, "=", only="~.")      # puente levadizo
    for (x, y) in ((75, 33), (74, 33), (73, 33), (75, 34), (74, 34), (73, 34)):
        fm.set(x, y, ".")
    fm.line((76, 34), (90, 12), 3, "=", only="~.#.")
    fm.rect(41, 17, 73, 49, ".")
    # Torres de esquina y salon del trono.
    for (cx, cy) in ((41, 17), (73, 17), (41, 49), (73, 49)):
        fm.rect(cx - 2, cy - 2, cx + 2, cy + 2, "#")
        fm.rect(cx - 1, cy - 1, cx + 1, cy + 1, ".")
    fm.ring(52, 24, 64, 42, "#", 1)
    for (x, y) in ((52, 33), (52, 34), (64, 33), (64, 34), (58, 24), (58, 42)):
        fm.set(x, y, ".")
    fm.rect(53, 25, 63, 41, ".")
    fm.keep_around([(57, 33)], 24)
    fm.polyline(route, 2, "=", only=".")
    fm.polyline([(80, 34), (86, 24), (90, 12)], 2, "=", only=".#")
    fm.river([(8, 6), (14, 14), (12, 26)], 3.0, 1.0)
    fm.stamp(12, 22, 4, ".", only="~")
    fm.thickets(60, 2.0, 4.5)
    fm.trees(110)
    fm.anchor("camp", (46, 22), (68, 22), (46, 44), (68, 44), (57, 33), (20, 44))
    fm.anchor("pack", (82, 50), (26, 18), (20, 62), (88, 28))
    fm.anchor("waypoint", (16, 52), (30, 44), (58, 20), (58, 46), (84, 20))
    fm.anchor("hunt", (57, 33), (58, 28))
    fm.anchor("cache_veyd", (47, 24), (69, 24), (47, 45))
    fm.anchor("chest_iron", (45, 30), (69, 38), (24, 60))
    fm.anchor("note", (20, 52), (82, 40), (58, 52))
    fm.anchor("event", (28, 40), (84, 56))
    fm.anchor("hazard_spikes", (44, 30), (70, 30), (52, 46), (62, 20), (30, 54), (84, 44))
    fm.anchor("hazard_poison_pool", (26, 28), (82, 22))
    fm.anchor("key", (45, 44), (70, 44))
    fm.anchor("vault", (58, 22), (57, 44))
    fm.anchor("campfire", (24, 48), (84, 30))
    for (cx, cy) in ((41, 17), (73, 17), (41, 49), (73, 49)):
        fm.prop("camp_watchtower", cx, cy)
    fm.prop("camp_banner", 57, 28)
    return fm


def floor_10():
    """El Campamento de Garrick: una arena epica rodeada de empalizada, con un camino-trampa de acceso y un lago detras."""
    fm = FloorMap(10, 100, 70, 1010)
    fm.mark_spawn(8, 58)
    fm.mark_exit(92, 12)
    route = [(8, 58), (22, 56), (34, 50), (44, 42), (52, 36)]
    fm.keep_route(route, 4)
    # Lago trasero y rio de acceso.
    fm.ellipse(84, 24, 14, 12, "~")
    fm.river([(60, 2), (58, 12), (64, 22)], 3.0, 1.0)
    # La arena: claro circular grande con anillo de muro y dos puertas.
    cx, cy = 66, 38
    fm.ellipse(cx, cy, 20, 15, ".")
    fm.ellipse_ring(cx, cy, 21, 16, "#", 2.0)
    for (x, y) in ((cx - 21, cy), (cx - 20, cy), (cx - 21, cy + 1), (cx - 20, cy + 1), (cx + 20, cy - 4), (cx + 21, cy - 4), (cx + 20, cy - 3), (cx + 21, cy - 3)):
        fm.set(x, y, ".")
    fm.keep_around([(cx, cy)], 22)
    # Pilares dentro de la arena (cobertura) y estrado del jefe.
    for (dx, dy) in ((-9, -6), (9, -6), (-9, 7), (9, 7), (-14, 1), (14, 1)):
        fm.rect(cx + dx - 1, cy + dy - 1, cx + dx, cy + dy, "#")
    fm.ellipse(cx + 6, cy - 2, 5, 4, ".")
    # Camino de acceso con claros de emboscada.
    fm.polyline(route + [(cx - 22, cy)], 2, "=", only=".")
    fm.polyline([(cx + 22, cy - 4), (90, 20), (92, 12)], 2, "=", only=".#")
    fm.clearing(34, 52, 5)
    fm.thickets(70, 2.0, 5.0)
    fm.trees(140)
    fm.anchor("boss", (cx + 6, cy - 2))
    fm.anchor("seal", (cx - 8, cy - 8), (cx + 8, cy - 9), (cx, cy + 9))
    fm.anchor("hunt", (cx - 10, cy), (cx + 10, cy + 6), (cx, cy - 11))
    fm.anchor("camp", (30, 46), (24, 30), (46, 24), (40, 12), (84, 52), (78, 62))
    fm.anchor("pack", (16, 46), (36, 38), (52, 56), (88, 40))
    fm.anchor("campfire", (18, 52), (50, 46))
    for (dx, dy) in ((-18, -10), (18, -10), (-18, 11), (18, 11)):
        fm.prop("camp_watchtower", cx + dx, cy + dy)
    fm.prop("camp_banner", cx - 4, cy - 12)
    fm.prop("camp_banner", cx + 4, cy - 12)
    return fm


FLOORS = {1: floor_1, 2: floor_2, 3: floor_3, 4: floor_4, 5: floor_5, 6: floor_6, 7: floor_7, 8: floor_8, 9: floor_9, 10: floor_10}


def main(argv):
    preview = None
    wanted = []
    i = 0
    while i < len(argv):
        if argv[i] == "--preview":
            preview = argv[i + 1]
            i += 2
        else:
            wanted.append(int(argv[i]))
            i += 1
    failures = 0
    for n in (wanted or sorted(FLOORS)):
        fm = FLOORS[n]()
        fm.border()
        problems = fm.finalize()
        fm.write(preview)
        walkable = sum(1 for y in range(fm.rows) for x in range(fm.cols) if fm.g[y][x] in WALK)
        print("piso %2d %dx%d  caminable %d%%  anclas %d  %s" % (n, fm.cols, fm.rows, 100 * walkable // (fm.cols * fm.rows), sum(len(v) for v in fm.anchors.values()), "OK" if not problems else "PROBLEMAS"))
        for note in fm.notes:
            print("    nota:", note)
        for p in problems:
            print("    PROBLEMA:", p)
            failures += 1
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
