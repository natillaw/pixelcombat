import numpy as np, math, json, os
from PIL import Image, ImageDraw

OUTD = '/mnt/user-data/outputs/bandidos'
os.makedirs(OUTD, exist_ok=True)
def hx(h):
    h = h.lstrip('#'); return np.array([int(h[i:i+2], 16) for i in (0, 2, 4)] + [255], np.uint8)
def P(*a): return [hx(x) for x in a]
OUTL = hx('#1a1420'); EYE = hx('#24161a'); WHITE = hx('#fff6dc')
METAL = P('#d6d9de', '#9aa0aa', '#5d6270'); WOOD = P('#a4794d', '#7a5534', '#523722')
GOLD = P('#ffe08a', '#e0a83a', '#9c6a22')

def blank(w, h): return np.zeros((h, w, 4), np.uint8)
def put(img, x, y, c):
    x, y = int(round(x)), int(round(y)); h, w = img.shape[:2]
    if 0 <= x < w and 0 <= y < h: img[y, x] = c
def rect(img, x0, y0, w, h, c):
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w): put(img, x, y, c)
def outer_outline(img, col):
    a = img[:, :, 3] > 0; p = np.pad(a, 1)
    nb = p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]
    img[~a & nb] = col
def inner_outline(img, col):
    a = img[:, :, 3] > 0; p = np.pad(a, 1)
    edge = a & ~(p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:]); img[edge] = col
def over(dst, src):
    a = src[:, :, 3] > 0; dst[a] = src[a]
def blend(dst, src):
    s = src.astype(np.float32); d = dst.astype(np.float32); a = s[:, :, 3:4] / 255
    o = d.copy(); o[:, :, :3] = s[:, :, :3] * a + d[:, :, :3] * (1 - a); o[:, :, 3] = np.maximum(d[:, :, 3], s[:, :, 3])
    dst[:] = o.astype(np.uint8)

# ---------------- especificaciones ----------------
BASE = dict(canvas=32, hw=12, hh=10, tw=8, th=6, lh=4, skin=P('#e8b796', '#c48a6a'))
SPECS = {
 'bandido_maton': dict(BASE, desc='Básico. Garrote, golpea fuerte y lento.', hair=P('#5a3a2a', '#432a1f', '#2e1c15'),
     bandana=P('#c0473b', '#8a2c2a'), tunic=P('#9a7148', '#7a5534', '#553a24'), pants=P('#5b4b3f', '#3f342c'),
     boots=P('#3e2b22', '#2a1d18'), belt=hx('#2e2018'), weapon='club', style='melee'),
 'bandido_arquero': dict(BASE, desc='Artillero. Dispara a distancia, huye si lo alcanzan.', hood=P('#5f8a4a', '#466b38', '#30492a'),
     bandana=P('#8b6a45', '#634a30'), tunic=P('#b59a6a', '#937a4f', '#6b5737'), pants=P('#4e5a3c', '#38412b'),
     boots=P('#4a3426', '#30221a'), belt=hx('#3a2a1c'), weapon='bow', style='bow'),
 'bandido_degollador': dict(BASE, desc='Asesino. Salta a la retaguardia con dos dagas.', hood=P('#4b3f5c', '#352b44', '#221b2e'),
     bandana=P('#2c2433', '#1c1622'), tunic=P('#6e6a78', '#53505d', '#3a3843'), pants=P('#33303a', '#24222a'),
     boots=P('#26202a', '#18141c'), belt=hx('#1e1a22'), weapon='daggers', style='assassin', eyes=hx('#e04848'),
     skin=P('#d9a888', '#b07e62')),
 'bandido_bruto': dict(BASE, desc='Tanque. Escudo y hacha, bloquea el paso.', tw=10, th=7, lh=4, hair=P('#3a2a22', '#2a1f19', '#1c1411'),
     helmet=METAL, bandana=P('#c0473b', '#8a2c2a'), tunic=P('#8a6a5a', '#6c5145', '#4a372f'), pants=P('#4b4038', '#342c27'),
     boots=P('#3a2a22', '#261b16'), belt=hx('#2e2018'), weapon='axe', shield=True, style='brute',
     skin=P('#c98d6c', '#9e684e')),
 'bandido_mago': dict(BASE, desc='Mago. Bolas de fuego en área, frágil.', hood=P('#4a5a9a', '#36437a', '#252e56'),
     bandana=P('#7a3a8a', '#55265f'), tunic=P('#6a4a8a', '#4f3669', '#36244a'), pants=P('#3a3450', '#29243a'),
     boots=P('#2e2436', '#1e1824'), belt=hx('#c9a24a'), weapon='staff_fire', style='mage', robe=True, hood_tip=True),
 'bandido_chaman': dict(BASE, desc='Sanador. Cura a los aliados cercanos, prioridad para matar.', hair=P('#e6dcc4', '#c4b89c', '#968a70'),
     feathers=[hx('#3fa58a'), hx('#e0a83a')], bandana=None, tunic=P('#8a9a5a', '#6c7a42', '#4b552e'), pants=P('#6b5a42', '#4c3f2e'),
     boots=P('#4a3a2a', '#30261c'), belt=hx('#e6dcc4'), weapon='staff_heal', style='healer', paint=hx('#3fa58a'),
     skin=P('#a86c4e', '#7e4e38')),
 'capitan_bandido': dict(BASE, desc='Miniboss del piso 5. Espada y capa, más vida y daño.', hair=P('#2a2a30', '#1c1c22', '#121216'),
     bandana=P('#2c2c34', '#1a1a20'), tunic=P('#a03a34', '#7a2a28', '#521c1c'), pants=P('#3a3440', '#28242e'),
     boots=P('#2e2420', '#1e1814'), belt=hx('#e0a83a'), weapon='sword', cape=P('#3a3440', '#24202a'), style='melee',
     scar=True),
 'rey_bandido': dict(canvas=48, hw=16, hh=13, tw=12, th=9, lh=6, desc='Jefe del piso 10. Mandoble, corona robada, escudo del altar.',
     skin=P('#e0a888', '#b47c60'), hair=P('#7a2a22', '#5a1e19', '#3c1411'), beard=True, crown=True,
     bandana=None, tunic=P('#b8434a', '#8e2f37', '#5e1e26'), armor=METAL, pants=P('#2e2a36', '#1e1c24'),
     boots=P('#2a2228', '#1a1418'), belt=hx('#e0a83a'), weapon='greatsword', cape=P('#7a1f2a', '#521520'), cape_trim=GOLD,
     style='boss', scar=True),
}

# ---------------- dibujo ----------------
def local_vec(d):
    f = {'down': (0, 1), 'up': (0, -1), 'right': (1, 0)}[d]
    s = (-f[1], f[0]) if d != 'right' else (0, 1)
    return f, s
def lp(hxp, hyp, f, s, u, v): return hxp + u * f[0] + v * s[0], hyp + u * f[1] + v * s[1]

def draw_line(img, x0, y0, ang, L, cols, width=1):
    dx, dy = math.cos(math.radians(ang)), math.sin(math.radians(ang))
    px, py = -dy, dx
    for i in range(L):
        c = cols[min(i, len(cols) - 1)]
        for w in range(width): put(img, x0 + dx * i + px * w * 0.9, y0 + dy * i + py * w * 0.9, c)
    return x0 + dx * (L - 1), y0 + dy * (L - 1), dx, dy

def draw_weapon(img, fx, kind, hxp, hyp, ang, glow=0, big=1):
    if kind == 'club':
        ex, ey, dx, dy = draw_line(img, hxp, hyp, ang, 4, [WOOD[2]])
        draw_line(img, ex, ey, ang, 4, [WOOD[0], WOOD[1]], 2)
    elif kind == 'sword':
        draw_line(img, hxp, hyp, ang + 180, 2, [WOOD[2]])
        ex, ey, dx, dy = draw_line(img, hxp, hyp, ang, 1, [GOLD[1]])
        for k in (-1, 1): put(img, hxp - dy * k, hyp + dx * k, GOLD[1])
        draw_line(img, hxp + dx, hyp + dy, ang, 8, [METAL[0], METAL[1]])
    elif kind == 'greatsword':
        draw_line(img, hxp, hyp, ang + 180, 3, [WOOD[2], GOLD[2], GOLD[0]])
        dx, dy = math.cos(math.radians(ang)), math.sin(math.radians(ang))
        for k in (-2, -1, 1, 2): put(img, hxp - dy * k, hyp + dx * k, GOLD[1])
        draw_line(img, hxp + dx, hyp + dy, ang, 14, [METAL[0], METAL[1]], 2)
        put(img, hxp + dx * 15, hyp + dy * 15, METAL[0])
    elif kind == 'axe':
        ex, ey, dx, dy = draw_line(img, hxp, hyp, ang, 9, [WOOD[1], WOOD[2]])
        for k in range(-1, 3):
            for j in range(3): put(img, ex - dx * j - dy * k, ey - dy * j + dx * k, METAL[0] if k == 2 else METAL[1])
    elif kind == 'dagger':
        draw_line(img, hxp, hyp, ang, 1, [WOOD[2]])
        draw_line(img, hxp + math.cos(math.radians(ang)), hyp + math.sin(math.radians(ang)), ang, 4, [METAL[1], METAL[0]])
    elif kind in ('staff_fire', 'staff_heal'):
        ex, ey, dx, dy = draw_line(img, hxp - math.cos(math.radians(ang)) * 4, hyp - math.sin(math.radians(ang)) * 4, ang, 14, [WOOD[1], WOOD[2]])
        orb = P('#fff2a0', '#ff9a3a', '#c8402a') if kind == 'staff_fire' else P('#e0ffe8', '#6ee0a0', '#2a9a6a')
        ox, oy = ex + dx * 1.5, ey + dy * 1.5
        for yy in range(-1, 2):
            for xx in range(-1, 2):
                if abs(xx) + abs(yy) < 2: put(img, ox + xx, oy + yy, orb[1])
        put(img, ox - 1, oy - 1, orb[0]); put(img, ox, oy, orb[0])
        if glow:
            r = glow + 1
            for a in range(0, 360, 30):
                if (a // 30 + glow) % 2 == 0:
                    put(fx, ox + math.cos(math.radians(a)) * r, oy + math.sin(math.radians(a)) * r, orb[0] if r < 3 else orb[1])

def draw_bow(img, fx, d, hxp, hyp, pull, arrow):
    f, s = local_vec(d)
    if d == 'right': s = (0, 1)
    for v in range(-5, 6):
        u = 2.2 - (v * v) / 12.5
        put(img, *lp(hxp, hyp, f, s, u + 1, v), WOOD[0] if v < 0 else WOOD[1])
    for v in range(-4, 5):
        u = 1 - pull * (1 - abs(v) / 5)
        put(img, *lp(hxp, hyp, f, s, u, v), hx('#e8e0c8'))
    if arrow:
        for u in range(int(1 - pull), 6): put(img, *lp(hxp, hyp, f, s, u, 0), WOOD[0] if u < 5 else METAL[0])

def draw_head(img, sp, d, x0, y0):
    hw, hh = sp['hw'], sp['hh']; skin, skd = sp['skin']
    hooded = 'hood' in sp; cov = sp.get('hood') or sp['hair']
    top = 4 if hooded else 3; side = 2 if hooded else 1
    if sp.get('canvas') == 48: top, side = 5, 2
    for yy in range(hh):
        for xx in range(hw):
            if yy in (0, hh - 1) and xx in (0, hw - 1): continue
            if yy == 0 and xx in (1, hw - 2): continue
            if d == 'up':
                c = cov[0] if (xx < 3 and yy < hh - 3) or yy < 2 else cov[2] if xx > hw - 4 else cov[1]
            elif d == 'down':
                if yy < top or xx < side or xx >= hw - side:
                    c = cov[0] if (yy < 2 and xx < hw - 3) else cov[2] if xx >= hw - side else cov[1]
                else: c = skd if (xx >= hw - side - 2 or yy == hh - 1) else skin
            else:
                if yy < top or xx < hw // 2 - 1:
                    c = cov[0] if yy < 2 else cov[2] if xx < 3 else cov[1]
                else: c = skd if (yy == hh - 1 or xx == hw - 1) else skin
            put(img, x0 + xx, y0 + yy, c)
    if hooded and sp.get('hood_tip'):
        if d == 'down': put(img, x0 + hw // 2, y0 - 1, cov[1]); put(img, x0 + hw // 2 - 1, y0 - 1, cov[0])
        else: put(img, x0 + (2 if d == 'right' else hw // 2), y0 - 1, cov[1])
    ey = y0 + top + 1 if sp.get('canvas') != 48 else y0 + top + 1
    eye = sp.get('eyes', EYE)
    if d == 'down':
        for ex in (x0 + side + 1, x0 + hw - side - 2):
            put(img, ex, ey, eye); put(img, ex, ey + 1, eye)
        if sp.get('paint') is not None: put(img, x0 + side + 1, ey + 2, sp['paint']); put(img, x0 + hw - side - 2, ey + 2, sp['paint'])
        if sp.get('scar'): put(img, x0 + hw - side - 2, ey - 1, hx('#a0504a')); put(img, x0 + hw - side - 3, ey + 2, hx('#a0504a'))
    elif d == 'right':
        put(img, x0 + hw - 3, ey, eye); put(img, x0 + hw - 3, ey + 1, eye)
        if sp.get('paint') is not None: put(img, x0 + hw - 3, ey + 2, sp['paint'])
        if sp.get('scar'): put(img, x0 + hw - 4, ey - 1, hx('#a0504a'))
    if sp.get('bandana'):
        bl, bd = sp['bandana']
        if d == 'down':
            for xx in range(side, hw - side):
                put(img, x0 + xx, y0 + hh - 3, bl); put(img, x0 + xx, y0 + hh - 2, bd)
                if 1 <= xx <= hw - 2: put(img, x0 + xx, y0 + hh - 1, bd)
        elif d == 'right':
            for xx in range(hw // 2 - 1, hw):
                put(img, x0 + xx, y0 + hh - 3, bl); put(img, x0 + xx, y0 + hh - 2, bd)
                if xx <= hw - 2: put(img, x0 + xx, y0 + hh - 1, bd)
            put(img, x0 + 1, y0 + hh - 4, bl); put(img, x0, y0 + hh - 3, bd)
        else:
            put(img, x0 + hw // 2, y0 + hh - 4, bl); put(img, x0 + hw // 2 - 1, y0 + hh - 3, bd); put(img, x0 + hw // 2 + 1, y0 + hh - 2, bd)
    if sp.get('beard') and d != 'up':
        bc = sp['hair']
        rng = range(side, hw - side) if d == 'down' else range(hw // 2, hw)
        for xx in rng:
            put(img, x0 + xx, y0 + hh - 2, bc[1]); put(img, x0 + xx, y0 + hh - 1, bc[2])
            if (xx + 1) % 3 == 0: put(img, x0 + xx, y0 + hh, bc[2])
        mx = x0 + hw // 2 if d == 'down' else x0 + hw - 2
        put(img, mx - 1, y0 + hh - 3, bc[1]); put(img, mx, y0 + hh - 3, bc[1])
    if sp.get('helmet'):
        m = sp['helmet']
        for yy in range(0, 4):
            for xx in range(hw):
                if yy == 0 and (xx < 2 or xx > hw - 3): continue
                put(img, x0 + xx, y0 + yy, m[0] if xx < 3 else m[2] if xx > hw - 3 else m[1])
        for xx in range(hw): put(img, x0 + xx, y0 + 3, m[2])
        if d == 'down': put(img, x0 + hw // 2, y0 + 4, m[1]); put(img, x0 + hw // 2, y0 + 5, m[1])
        if d == 'right': put(img, x0 + hw - 2, y0 + 4, m[1])
    if sp.get('feathers'):
        a, b = sp['feathers']
        fxp = x0 + hw // 2 if d != 'right' else x0 + 3
        for k in range(3): put(img, fxp - 1, y0 - 1 - k, a); put(img, fxp + 1, y0 - k, b)
    if sp.get('crown'):
        g = GOLD
        for xx in range(2, hw - 2): put(img, x0 + xx, y0 - 1, g[1]); put(img, x0 + xx, y0, g[2] if d == 'up' else g[1])
        for xx in range(2, hw - 2, 3): put(img, x0 + xx, y0 - 2, g[0]); put(img, x0 + xx, y0 - 3, g[0])
        if d == 'down': put(img, x0 + hw // 2, y0 - 1, hx('#3fd0c0'))

def draw_torso(img, sp, d, x0, y0, tw):
    th = sp['th']; tl, tm, td = sp['tunic']
    for yy in range(th):
        for xx in range(tw):
            c = tl if xx == 0 else td if xx == tw - 1 else tm
            put(img, x0 + xx, y0 + yy, c)
    if sp.get('armor') and d != 'up':
        m = sp['armor']
        for yy in range(1, th - 3):
            for xx in range(2, tw - 2): put(img, x0 + xx, y0 + yy, m[0] if xx < tw // 2 else m[1])
        put(img, x0 + tw // 2, y0 + 2, GOLD[1])
    if sp.get('robe'):
        for xx in range(-1, tw + 1):
            put(img, x0 + xx, y0 + th, td if xx in (-1, tw) else tm)
    by = y0 + th - 2
    for xx in range(tw): put(img, x0 + xx, by, sp['belt'])
    if d == 'down': put(img, x0 + tw // 2, by, GOLD[0])
    if d == 'down' and not sp.get('armor'): put(img, x0 + tw // 2 - 1, y0, td); put(img, x0 + tw // 2, y0, td)

def draw_cape(img, sp, d, x0, y0, tw, flutter, layer):
    if 'cape' not in sp: return
    cl, cd = sp['cape']; trim = sp.get('cape_trim')
    bottom = y0 + sp['th'] + sp['lh'] - 1
    if d == 'down' and layer == 'back':
        for y in range(y0, bottom + 1):
            put(img, x0 - 2, y + (flutter if y > bottom - 2 else 0), cd); put(img, x0 + tw + 1, y, cd)
            put(img, x0 - 1, y, cl); put(img, x0 + tw, y, cd)
    if d == 'up' and layer == 'front':
        for y in range(y0, bottom + 1):
            for x in range(x0 - 1, x0 + tw + 1):
                c = cl if x < x0 + tw // 2 else cd
                if y >= bottom - 1 and trim: c = trim[1]
                put(img, x + (flutter if y > bottom - 3 else 0), y, c)
    if d == 'right' and layer == 'back':
        for y in range(y0, bottom + 1):
            w = 2 + (y - y0) // 3
            for k in range(w): put(img, x0 - 1 - k + (flutter if y > bottom - 2 else 0), y, cd if k else cl)
            if trim and y == bottom: put(img, x0 - w, y, trim[1])

def draw_legs(img, sp, d, cx, ytop, lift, shift):
    lh = sp['lh']; pm, pd = sp['pants']; bm, bd = sp['boots']
    lw = 3 if sp['canvas'] == 32 else 4
    if d in ('down', 'up'):
        xs = [cx - lw, cx]
        for i in range(2):
            h = lh - lift[i]
            for yy in range(h):
                c = (pm if i == 0 else pd) if yy < h - 2 else (bm if i == 0 else bd)
                rect(img, xs[i], ytop + yy, lw, 1, c)
    else:
        order = [(cx - 2 + shift[1], pd, bd, lift[1]), (cx - 1 + shift[0], pm, bm, lift[0])]
        for x, pc, bc, lf in order:
            h = lh - lf
            for yy in range(h):
                rect(img, x, ytop + yy, lw, 1, pc if yy < h - 2 else bc)
            if lf == 0: put(img, x + lw, ytop + h - 1, bc)

def draw_shield(img, d, x, y, big):
    w, h = (5, 7) if not big else (7, 9)
    if d == 'right': w = 3
    for yy in range(h):
        for xx in range(w):
            if yy == h - 1 and xx in (0, w - 1): continue
            c = METAL[1] if (xx in (0, w - 1) or yy == 0) else WOOD[1] if d != 'up' else WOOD[2]
            put(img, x + xx, y + yy, c)
    if d == 'down': put(img, x + w // 2, y + h // 2, METAL[0])

ATK = {
 'melee':    dict(rel=[-100, -140, -150, 0, 25, -40], lunge=[0, 0, -1, 2, 2, 0], slash=[3, 4]),
 'assassin': dict(rel=[-120, -140, -30, 20, 30, -60], lunge=[0, -1, 2, 3, 2, 0], slash=[2, 3]),
 'brute':    dict(rel=[-120, -170, -180, 10, 40, 0], lunge=[0, -1, -1, 2, 2, 0], slash=[3], crack=[3, 4]),
 'boss':     dict(rel=[-110, -160, -175, 0, 30, -20], lunge=[0, -1, -1, 3, 3, 0], slash=[3, 4], crack=[3, 4, 5]),
 'mage':     dict(rel=[-60, -80, -100, -100, -80, -60], lunge=[0] * 6, glow=[0, 1, 2, 3, 1, 0]),
 'healer':   dict(rel=[-60, -80, -95, -95, -85, -60], lunge=[0] * 6, glow=[0, 1, 2, 2, 1, 0], rings=[2, 3, 4]),
 'bow':      dict(pull=[0, 1, 2, 0, 0, 0], arrow=[1, 1, 1, 0, 0, 0], lunge=[0, 0, 0, -1, 0, 0]),
}
REST = {'down': -70, 'up': -110, 'right': -60}

def render(sp, d, anim, f):
    S = sp['canvas']; img = blank(S, S); fx = blank(S, S)
    hw, hh, tw, th, lh = sp['hw'], sp['hh'], sp['tw'], sp['th'], sp['lh']
    big = S == 48
    cx = S // 2; feet = S - 3
    bob = 0; lift = [0, 0]; shift = [0, 0]; armsw = [0, 0]; flutter = 0
    st = sp['style']; a = ATK.get(st, ATK['melee']); rel = None; glow = 0; pull = 0; arrow = 0; lunge = 0
    if anim == 'idle':
        bob = [0, 0, 1, 1][f]; flutter = [0, 1, 1, 0][f]
    elif anim == 'walk':
        ph = f / 6 * 2 * math.pi
        lift = [max(0, round(1.4 * math.sin(ph))), max(0, round(1.4 * math.sin(ph + math.pi)))]
        shift = [round(1.8 * math.sin(ph)), -round(1.8 * math.sin(ph))]
        bob = [0, 1, 0, 0, 1, 0][f]; armsw = [round(math.sin(ph + math.pi)), round(math.sin(ph))]; flutter = [1, 0, -1, 1, 0, -1][f]
    elif anim == 'attack':
        if 'rel' in a: rel = a['rel'][f]
        glow = a.get('glow', [0] * 6)[f]; pull = a.get('pull', [0] * 6)[f]; arrow = a.get('arrow', [0] * 6)[f]
        lunge = a['lunge'][f]; bob = 1 if f in (2, 3) else 0
    tws = tw if d != 'right' else tw - 2
    ytop_leg = feet - lh + 1
    ty0 = feet - lh - th + 1 + bob
    tx0 = cx - tws // 2
    hy0 = ty0 - hh + 1
    hx0 = cx - hw // 2
    f_, s_ = local_vec(d)
    if d == 'down': hand = (tx0 + tws + 1, ty0 + th - 2 + armsw[1])
    elif d == 'up': hand = (tx0 - 2, ty0 + th - 2 + armsw[0])
    else: hand = (cx + 2 + (1 if big else 0), ty0 + th - 3)
    weapon = sp['weapon']
    def wang():
        if rel is None: return REST[d]
        base = {'down': 90, 'up': -90, 'right': 0}[d]
        if d == 'down': return base - rel if st != 'mage' and st != 'healer' else REST[d] + (rel + 60)
        if d == 'up': return base + rel * -1 - 180 if st not in ('mage', 'healer') else REST[d] - (rel + 60)
        return rel
    layer_back = blank(S, S)
    # capa y brazo trasero
    draw_cape(img, sp, d, tx0, ty0, tws, flutter, 'back')
    if d == 'up' and weapon not in ('bow',):
        if weapon == 'daggers': draw_weapon(img, fx, 'dagger', tx0 + tws + 1, ty0 + th - 2, -90 + (rel or 0) * 0.3)
    if d == 'right':
        put(img, cx - 2, ty0 + 2 + armsw[0], sp['tunic'][2]); put(img, cx - 2, ty0 + 3 + armsw[0], sp['tunic'][2]); put(img, cx - 2, ty0 + 4 + armsw[0], sp['skin'][1])
        if sp.get('shield'): pass
    draw_legs(img, sp, d, cx, ytop_leg, lift, shift)
    draw_torso(img, sp, d, tx0, ty0, tws)
    if d in ('down', 'up'):
        for side, sw in ((tx0 - (3 if big else 2), armsw[0]), (tx0 + tws, armsw[1])):
            aw = 3 if big else 2
            for yy in range(1, th - 1):
                rect(img, side, ty0 + yy + sw, aw, 1, sp['tunic'][1] if yy < th - 2 else sp['skin'][1 if d == 'up' else 0])
    draw_cape(img, sp, d, tx0, ty0, tws, flutter, 'front')
    draw_head(img, sp, d, hx0, hy0)
    # escudo
    if sp.get('shield'):
        if d == 'down': draw_shield(img, d, tx0 - 4, ty0 + 1, big)
        elif d == 'right': draw_shield(img, d, cx + 2, ty0, big)
        else: draw_shield(img, d, tx0 + tws - 1, ty0 + 1, big)
    # arma
    if weapon == 'bow':
        if d == 'up':
            draw_bow(img, fx, d, cx, hy0 + 2, pull, arrow)
        else:
            draw_bow(img, fx, d, hand[0] - (1 if d == 'right' else 0), hand[1] - (0 if d == 'right' else 0), pull, arrow)
    elif weapon == 'daggers':
        ang = wang()
        draw_weapon(img, fx, 'dagger', hand[0], hand[1], ang)
        if d == 'down': draw_weapon(img, fx, 'dagger', tx0 - 2, ty0 + th - 2 + armsw[0], 180 - ang)
    else:
        draw_weapon(img, fx, weapon, hand[0], hand[1], wang(), glow, big)
    put(img, hand[0], hand[1], sp['skin'][0])
    outer_outline(img, OUTL)
    # efectos
    if anim == 'attack':
        if f in a.get('slash', []):
            L = 10 if not big else 16
            for k in range(-50, 60, 12):
                ang2 = wang() - 40 + k * 0.9
                put(fx, hand[0] + math.cos(math.radians(ang2)) * (L + 1), hand[1] + math.sin(math.radians(ang2)) * (L + 1), WHITE if k < 30 else hx('#f0e0b0'))
        if f in a.get('crack', []):
            r = (f - a['crack'][0] + 1) * (4 if big else 3)
            gx, gy = lp(cx, feet - 1, f_, s_, 8 if big else 6, 0)
            for ang2 in range(0, 360, 20):
                put(fx, gx + math.cos(math.radians(ang2)) * r, gy + math.sin(math.radians(ang2)) * r * 0.5, hx('#e8d8b0') if ang2 % 40 else hx('#a08a68'))
        if f in a.get('rings', []):
            r = 5 + (f - 2) * 3
            for ang2 in range(0, 360, 30):
                if (ang2 // 30 + f) % 2: put(fx, cx + math.cos(math.radians(ang2)) * r, feet - 6 + math.sin(math.radians(ang2)) * r * 0.6, hx('#9affc8'))
    if lunge:
        dx, dy = int(lunge * f_[0]), min(0, int(lunge * f_[1] * 0.5))
        img = shift_img(img, dx, dy); fx = shift_img(fx, dx, dy)
    over(img, fx)
    return img

def shift_img(a, dx, dy):
    o = np.zeros_like(a); h, w = a.shape[:2]
    ys, yd = (slice(0, h - dy), slice(dy, h)) if dy >= 0 else (slice(-dy, h), slice(0, h + dy))
    xs, xd = (slice(0, w - dx), slice(dx, w)) if dx >= 0 else (slice(-dx, w), slice(0, w + dx))
    o[yd, xd] = a[ys, xs]; return o
def ground_it(a, feet, cx=None):
    ys, xs = np.nonzero(a[:, :, 3])
    if len(ys) == 0: return a
    dy = feet - ys.max(); dx = 0
    if cx is not None: dx = int(cx - (xs.min() + xs.max()) / 2)
    return shift_img(a, dx, dy)
def death_frames(sp, d):
    base = render(sp, d, 'idle', 0); S = base.shape[0]; cx, feet = S // 2, S - 3
    out = []
    w = base.copy(); m = w[:, :, 3] > 0; w[m, :3] = (w[m, :3] * 0.3 + 255 * 0.7).astype(np.uint8); out.append(w)
    r = base.copy(); m = r[:, :, 3] > 0; r[m, 0] = np.minimum(255, r[m, 0].astype(int) + 60); r[m, 1] = (r[m, 1] * 0.8).astype(np.uint8)
    back = -1 if d == 'right' else 0
    out.append(shift_img(r, back, 0))
    sign = 1 if d == 'right' else -1
    for ang in (25, 55):
        im = Image.fromarray(base).rotate(sign * ang, resample=Image.NEAREST, center=(cx, feet), expand=False)
        out.append(ground_it(np.array(im), feet))
    pad = np.zeros((S * 2, S * 2, 4), np.uint8); pad[S // 2:S // 2 + S, S // 2:S // 2 + S] = base
    rot = np.rot90(pad, 1 if sign > 0 else -1)
    lying = ground_it(rot, feet + S // 2, S)[S // 2:S // 2 + S, S // 2:S // 2 + S]
    out.append(lying)
    last = lying.copy(); m = last[:, :, 3] > 0
    last[m, :3] = (last[m, :3] * 0.75).astype(np.uint8); out.append(last)
    return out

ANIMS = [('idle', 4), ('walk', 6), ('attack', 6), ('death', 6)]
DIRS = ['down', 'left', 'right', 'up']
FPS = {'idle': 6, 'walk': 10, 'attack': 12, 'death': 10}

def build_sheet(name, sp):
    S = sp['canvas']; sheet = blank(S * 6, S * len(ANIMS) * len(DIRS)); rows = {}
    r = 0
    for anim, n in ANIMS:
        for d in DIRS:
            dd = 'right' if d == 'left' else d
            frames = death_frames(sp, dd) if anim == 'death' else [render(sp, dd, anim, i) for i in range(n)]
            for i, fr in enumerate(frames):
                if d == 'left': fr = fr[:, ::-1]
                sheet[r * S:(r + 1) * S, i * S:(i + 1) * S] = fr
            rows[f'{anim}_{d}'] = {'row': r, 'frames': n, 'fps': FPS[anim], 'loop': anim in ('idle', 'walk')}
            r += 1
    Image.fromarray(sheet).save(f'{OUTD}/{name}.png')
    return {'frame_size': S, 'desc': sp['desc'], 'animations': rows}

META = {'enemies': {}, 'fx': {}, 'props': {}}
for name, sp in SPECS.items(): META['enemies'][name] = build_sheet(name, sp)

# ---------------- efectos y proyectiles ----------------
def fx_strip(name, frames):
    h, w = frames[0].shape[:2]; st = blank(w * len(frames), h)
    for i, f in enumerate(frames): st[:, i * w:(i + 1) * w] = f
    Image.fromarray(st).save(f'{OUTD}/fx_{name}.png'); META['fx'][name] = {'frame_size': [w, h], 'frames': len(frames)}
arrow = blank(10, 3)
for x in range(1, 8): put(arrow, x, 1, WOOD[0])
put(arrow, 8, 1, METAL[0]); put(arrow, 9, 1, METAL[1]); put(arrow, 7, 0, METAL[1]); put(arrow, 7, 2, METAL[1])
for x in (0, 1): put(arrow, x, 0, hx('#e8e0c8')); put(arrow, x, 2, hx('#e8e0c8'))
fx_strip('flecha', [arrow])
fb = []
for i in range(4):
    im = blank(14, 12)
    for y in range(12):
        for x in range(14):
            dx, dy = x - 9.5, (y - 5.5) * 1.15
            dd = math.hypot(dx, dy)
            tail = x < 9 and abs(dy) < (x - 1) * 0.55 and ((x + i * 2) % 4 != 0)
            if dd < 2: put(im, x, y, hx('#fff6c0'))
            elif dd < 3.4: put(im, x, y, hx('#ffb040'))
            elif dd < 4.5 or tail: put(im, x, y, hx('#d84a2a') if (x + y + i) % 3 else hx('#ff7a30'))
    fb.append(im)
fx_strip('bola_fuego', fb)
ex = []
for i in range(5):
    im = blank(20, 20); r = 3 + i * 2
    for y in range(20):
        for x in range(20):
            dd = math.hypot(x - 9.5, y - 9.5)
            if i < 3 and dd < r - 2: put(im, x, y, hx('#fff2b0') if dd < r - 4 else hx('#ffa040'))
            elif abs(dd - r) < 1 and (x + y + i) % 2: put(im, x, y, hx('#d84a2a') if i < 4 else hx('#5a4a44'))
    ex.append(im)
fx_strip('explosion', ex)
hl = []
for i in range(4):
    im = blank(16, 16)
    for k in range(6):
        a = k * 60 + i * 20; r = 3 + i * 1.5
        x, y = 8 + math.cos(math.radians(a)) * r, 9 - i * 1.5 + math.sin(math.radians(a)) * r * 0.5
        put(im, x, y, hx('#e0ffe8')); put(im, x, y - 1, hx('#6ee0a0')); put(im, x + 1, y, hx('#6ee0a0'))
    hl.append(im)
fx_strip('curacion', hl)
sh = []
for i in range(4):
    im = blank(48, 48)
    for y in range(48):
        for x in range(48):
            dd = math.hypot((x - 23.5) / 21, (y - 25) / 23)
            if dd < 1:
                a = int(30 + 70 * dd ** 6)
                c = np.array([95, 207, 191, a], np.uint8); im[y, x] = c
                if dd > 0.93: im[y, x] = np.array([160, 255, 238, 200], np.uint8)
    for k in range(6):
        a = math.radians(k * 60 + i * 15); x, y = 23.5 + math.cos(a) * 17, 25 + math.sin(a) * 19
        for dx, dy in ((0, 0), (1, 0), (0, 1), (0, -1)): put(im, x + dx, y + dy, hx('#d2fff4'))
    for x in range(14, 20): put(im, x - i, 8 + (x - 14) // 2, np.array([255, 255, 255, 170], np.uint8))
    sh.append(im)
fx_strip('escudo_altar', sh)

# ---------------- props de campamento ----------------
def save_prop(name, img, origin): META['props'][name] = {'size': [img.shape[1], img.shape[0]], 'origin': origin}; PROPS[name] = img
PROPS = {}
CANVAS = P('#d8c49a', '#b8a078', '#8e7856'); RED = P('#c0473b', '#8a2c2a', '#5e1e1e')
def tent():
    im = blank(34, 30)
    for y in range(3, 27):
        hwid = (y - 3) * 0.68 + 1
        for x in range(34):
            dx = x - 16.5
            if abs(dx) > hwid: continue
            c = CANVAS[0] if dx < -hwid * 0.3 else CANVAS[1] if dx < hwid * 0.4 else CANVAS[2]
            if abs(dx) < (y - 10) * 0.28 and y > 12: c = hx('#2a1e1a')
            if y > 22 and abs(dx) < (y - 10) * 0.28 + 1 and abs(dx) >= (y - 10) * 0.28: c = CANVAS[2]
            put(im, x, y, c)
    for y in range(8, 14):
        for x in range(21, 25): put(im, x - (y - 8) // 3, y, RED[1] if (x + y) % 4 else RED[2])
    for y in range(0, 4): put(im, 16, y, WOOD[1]); put(im, 17, y, WOOD[2])
    put(im, 18, 0, RED[0]); put(im, 19, 1, RED[0]); put(im, 18, 1, RED[1])
    for x, y in ((2, 27), (31, 27)): put(im, x, y, WOOD[1]); put(im, x, y - 1, WOOD[0])
    inner_outline(im, OUTL); return im
save_prop('tienda', tent(), [17, 27])
fire = []
for i in range(4):
    im = blank(16, 18)
    for k, (x0, y0, x1, y1) in enumerate(((2, 15, 13, 12), (3, 12, 14, 15))):
        for t in range(12):
            x = x0 + (x1 - x0) * t / 11; y = y0 + (y1 - y0) * t / 11
            put(im, x, y, WOOD[1]); put(im, x, y + 1, WOOD[2])
    for x in (3, 12): put(im, x, 16, METAL[2]); put(im, x + 1, 16, METAL[1])
    rng = np.random.default_rng(i)
    for y in range(2, 14):
        hwid = (13 - y) * 0.42 * (1 if y > 6 else 0.8) + 0.5 * math.sin(y * 1.3 + i * 1.7)
        cxp = 8 + math.sin(y * 0.8 + i) * 0.8
        for x in range(16):
            dx = abs(x + 0.5 - cxp)
            if dx < hwid:
                c = hx('#fff2b0') if dx < hwid * 0.35 and y > 7 else hx('#ffb040') if dx < hwid * 0.7 else hx('#e05a2a')
                put(im, x, y, c)
    for k in range(2):
        put(im, 5 + rng.integers(0, 6), rng.integers(0, 4), hx('#ffb040'))
    fire.append(im)
st = blank(16 * 4, 18)
for i, f in enumerate(fire): st[:, i * 16:(i + 1) * 16] = f
Image.fromarray(st).save(f'{OUTD}/prop_fogata_anim.png'); META['props']['fogata_anim'] = {'frame_size': [16, 18], 'frames': 4, 'fps': 8, 'origin': [8, 16]}
def palisade():
    im = blank(16, 26)
    for i, x0 in enumerate((0, 5, 10)):
        top = 2 + (i % 2) * 2
        for y in range(top, 26):
            for x in range(x0, x0 + 5):
                if y - top < 2 and abs(x - x0 - 2) > (y - top): continue
                c = WOOD[0] if x == x0 else WOOD[2] if x == x0 + 4 else WOOD[1]
                put(im, x, y, c)
    for x in range(16): put(im, x, 15, hx('#5a4a3a')); put(im, x, 16, hx('#3a2e24'))
    inner_outline(im, OUTL); return im
save_prop('empalizada', palisade(), [8, 25])
def crate():
    im = blank(14, 14)
    rect(im, 0, 0, 14, 14, WOOD[1]); rect(im, 0, 0, 14, 4, WOOD[0])
    for k in range(10): put(im, 2 + k, 13 - k, WOOD[2]) if k < 10 else None
    for x in range(14): put(im, x, 4, WOOD[2])
    inner_outline(im, OUTL); return im
save_prop('caja', crate(), [7, 13])
def barrel():
    im = blank(12, 15)
    for y in range(15):
        for x in range(12):
            if (y in (0, 14) and x in (0, 1, 10, 11)): continue
            c = WOOD[0] if x < 4 else WOOD[1] if x < 9 else WOOD[2]
            if y in (3, 11): c = METAL[2]
            if y < 2: c = WOOD[0] if x < 8 else WOOD[1]
            put(im, x, y, c)
    inner_outline(im, OUTL); return im
save_prop('barril', barrel(), [6, 14])
def sack():
    im = blank(14, 12)
    for y in range(2, 12):
        for x in range(14):
            dx, dy = (x - 6.5) / 6.5, (y - 7.5) / 4.5
            if dx * dx + dy * dy < 1: put(im, x, y, CANVAS[0] if dx < -0.2 else CANVAS[1] if dx < 0.4 else CANVAS[2])
    for x in (5, 6, 7): put(im, x, 2, CANVAS[2]); put(im, x, 1, CANVAS[1])
    inner_outline(im, OUTL)
    for x, y in ((9, 10), (11, 10), (10, 9), (12, 11), (8, 11)): put(im, x, y, GOLD[1]); 
    put(im, 10, 9, GOLD[0]); return im
save_prop('saco_botin', sack(), [7, 11])
def cart():
    im = blank(36, 24)
    rect(im, 4, 6, 26, 9, WOOD[1]); rect(im, 4, 6, 26, 2, WOOD[0]); rect(im, 4, 13, 26, 2, WOOD[2])
    for x in range(30, 36): put(im, x, 12, WOOD[2])
    for y in range(2, 6):
        for x in range(8, 26): put(im, x, y, CANVAS[1] if (x // 4) % 2 else CANVAS[0])
    for cxp in (9, 25):
        for y in range(13, 24):
            for x in range(cxp - 5, cxp + 6):
                dd = math.hypot(x - cxp, y - 18)
                if 3.5 < dd < 5.2: put(im, x, y, WOOD[2])
                elif dd < 1.2: put(im, x, y, METAL[1])
                elif dd < 3.5 and (x == cxp or y == 18): put(im, x, y, WOOD[1])
    inner_outline(im, OUTL); return im
save_prop('carreta', cart(), [17, 22])
def banner():
    im = blank(14, 32)
    for y in range(32): put(im, 3, y, WOOD[1]); put(im, 4, y, WOOD[2])
    for x in range(2, 13): put(im, x, 2, WOOD[0])
    for y in range(3, 20):
        for x in range(5, 13):
            if y > 16 and abs(x - 8.5) < (y - 16): continue
            put(im, x, y, RED[0] if x < 7 else RED[1])
    for x, y in ((8, 8), (9, 8), (7, 9), (10, 9), (8, 10), (9, 10), (8, 12), (9, 12), (7, 11), (10, 11)): put(im, x, y, hx('#e8dcc0'))
    put(im, 8, 9, OUTL); put(im, 9, 9, OUTL)
    inner_outline(im, OUTL); return im
save_prop('estandarte', banner(), [4, 31])
def cage():
    im = blank(22, 24)
    rect(im, 0, 19, 22, 5, WOOD[1]); rect(im, 0, 19, 22, 1, WOOD[0]); rect(im, 0, 23, 22, 1, WOOD[2])
    rect(im, 1, 1, 20, 2, METAL[2]); rect(im, 1, 1, 20, 1, METAL[1])
    for x in range(1, 21, 3):
        for y in range(2, 19): put(im, x, y, METAL[1]); put(im, x + 1, y, METAL[2])
    inner_outline(im, OUTL); return im
save_prop('jaula', cage(), [11, 23])
def tower():
    im = blank(32, 52)
    for leg in (4, 25):
        for y in range(14, 52): put(im, leg, y, WOOD[1]); put(im, leg + 1, y, WOOD[2]); put(im, leg + 2, y, WOOD[2])
    for y0 in (24, 38):
        for t in range(19): put(im, 6 + t, y0 + t * 0.6, WOOD[1]); put(im, 25 - t, y0 + t * 0.6, WOOD[2])
    rect(im, 1, 12, 30, 4, WOOD[1]); rect(im, 1, 12, 30, 1, WOOD[0])
    for x in range(2, 30, 3):
        for y in range(6, 12): put(im, x, y, WOOD[1]); put(im, x + 1, y, WOOD[2])
    for y in range(0, 6):
        hwid = 4 + y * 2.6
        for x in range(32):
            if abs(x - 15.5) < hwid: put(im, x, y, RED[1] if x < 16 else RED[2])
    inner_outline(im, OUTL); return im
save_prop('torre_vigia', tower(), [16, 51])
def rack():
    im = blank(20, 18)
    rect(im, 1, 4, 18, 2, WOOD[1]); rect(im, 1, 12, 18, 2, WOOD[2])
    for x in (2, 17):
        for y in range(2, 18): put(im, x, y, WOOD[2])
    for i, x in enumerate((5, 9, 13)):
        for y in range(0, 16): put(im, x, y, METAL[1] if y < 10 else WOOD[2])
        put(im, x - 1, 10, GOLD[1]); put(im, x + 1, 10, GOLD[1])
    inner_outline(im, OUTL); return im
save_prop('armero', rack(), [10, 17])
def bedroll():
    im = blank(18, 9)
    rect(im, 0, 1, 18, 7, RED[1]); rect(im, 0, 1, 18, 2, RED[0]); rect(im, 13, 1, 5, 7, CANVAS[1])
    for y in range(1, 8): put(im, 6, y, RED[2])
    inner_outline(im, OUTL); return im
save_prop('saco_dormir', bedroll(), [9, 8])
# pack props estáticos
names = list(PROPS); W = 160; x = y = rh = 0; rects = {}
for n in sorted(names, key=lambda k: -PROPS[k].shape[0]):
    h, w = PROPS[n].shape[:2]
    if x + w > W: x = 0; y += rh + 1; rh = 0
    rects[n] = (x, y, w, h); x += w + 1; rh = max(rh, h)
atlas = blank(W, y + rh)
for n, (px, py, w, h) in rects.items(): atlas[py:py + h, px:px + w] = PROPS[n]; META['props'][n]['rect'] = [px, py, w, h]
Image.fromarray(atlas).save(f'{OUTD}/props_campamento.png')
json.dump(META, open(f'{OUTD}/bandidos.json', 'w'), indent=1, ensure_ascii=False)

# ---------------- previews ----------------
GRASS = (82, 122, 61, 255)
names = list(SPECS)
def lineup():
    cell = 48; sc = 4
    im = Image.new('RGBA', (cell * len(names) * sc, cell * 4 * sc), GRASS)
    for i, n in enumerate(names):
        sheet = np.array(Image.open(f'{OUTD}/{n}.png')); S = SPECS[n]['canvas']
        for j, row in enumerate(['walk_down', 'walk_right', 'attack_down', 'death_down']):
            r = META['enemies'][n]['animations'][row]['row']; col = {'walk_down': 0, 'walk_right': 1, 'attack_down': 3, 'death_down': 5}[row]
            fr = Image.fromarray(sheet[r * S:(r + 1) * S, col * S:(col + 1) * S]).resize((S * sc, S * sc), Image.NEAREST)
            im.alpha_composite(fr, (i * cell * sc + (cell - S) * sc // 2, j * cell * sc + (cell - S) * sc))
    im.convert('RGB').save(f'{OUTD}/preview_enemigos.png')
lineup()
def gif():
    cell = 48; sc = 3; frames = []
    seq = [('walk_down', 6)] * 2 + [('attack_down', 6), ('walk_right', 6), ('attack_right', 6), ('walk_up', 6), ('death_down', 6)]
    for anim, n in seq:
        for k in range(n):
            im = Image.new('RGBA', (cell * len(names) * sc, cell * sc), GRASS)
            for i, nm in enumerate(names):
                sheet = np.array(Image.open(f'{OUTD}/{nm}.png')); S = SPECS[nm]['canvas']
                r = META['enemies'][nm]['animations'][anim]['row']
                fr = Image.fromarray(sheet[r * S:(r + 1) * S, k * S:(k + 1) * S]).resize((S * sc, S * sc), Image.NEAREST)
                im.alpha_composite(fr, (i * cell * sc + (cell - S) * sc // 2, (cell - S) * sc))
            frames.append(im.convert('RGB'))
    frames[0].save(f'{OUTD}/preview_animado.gif', save_all=True, append_images=frames[1:], duration=110, loop=0)
gif()
print('ok')
