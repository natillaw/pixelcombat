import numpy as np, json, os, shutil
from PIL import Image

SRC = '/home/claude/tpf/Sprite'
OUT = '/mnt/user-data/outputs/tpf_bandidos'
shutil.rmtree(OUT, ignore_errors=True)
CELL, COLS, ROWS = 48, 12, 8
def load(rel):
    p = f'{SRC}/{rel}'; im = Image.open(p).convert('RGBA')
    return np.array(im) if im.size == (576, 384) else np.zeros((384, 576, 4), np.uint8)
def save(arr, layer, name):
    d = f'{OUT}/Sprite/{layer}'; os.makedirs(d, exist_ok=True)
    Image.fromarray(arr).save(f'{d}/{name}.png'); return f'{layer}/{name}.png'

NAVY = (25, 6, 87)
GREY = [(221, 246, 247), (194, 210, 217), (161, 179, 198), (110, 121, 166)]
BROWN = [(192, 139, 76), (149, 113, 75), (114, 73, 48), (90, 35, 20)]
RED = [(228, 59, 0), (191, 25, 41), (133, 27, 19)]
GOLDS = [(255, 231, 119), (252, 196, 88), (255, 158, 71), (215, 152, 62), (215, 110, 53), (171, 94, 32), (171, 52, 32)]
# rampas de bandido, solo con colores de la paleta del pack (claro, claro2, medio, oscuro)
RAMP = {
    'cuero':        [(192, 139, 76), (149, 113, 75), (114, 73, 48), (90, 35, 20)],
    'cuero_oscuro': [(149, 113, 75), (118, 60, 28), (90, 35, 20), (49, 52, 65)],
    'verde_bosque': [(101, 165, 32), (19, 133, 19), (26, 102, 38), (49, 52, 65)],
    'negro':        [(110, 121, 166), (85, 90, 109), (49, 52, 65), (25, 6, 87)],
    'rojo_sangre':  [(191, 25, 41), (171, 52, 32), (133, 27, 19), (90, 35, 20)],
    'morado':       [(110, 121, 166), (63, 59, 147), (19, 35, 133), (25, 6, 87)],
    'acero_sucio':  [(161, 179, 198), (110, 121, 166), (85, 90, 109), (49, 52, 65)],
    'hueso':        [(246, 220, 175), (228, 193, 156), (192, 139, 76), (114, 73, 48)],
}
def recolor(arr, mapping):
    out = arr.copy(); orig = arr[:, :, :3]
    masks = [((orig == src).all(-1) & (arr[:, :, 3] > 0), dst) for src, dst in mapping.items()]
    for m, dst in masks: out[:, :, :3][m] = dst
    return out
def ramp_map(name, extra=None):
    r = RAMP[name]; m = {GREY[0]: r[0], GREY[1]: r[1], GREY[2]: r[2], GREY[3]: r[3]}
    if extra: m.update(extra)
    return m

body = load('Body/1.png'); eyes = load('Eyes/1.png'); pants_ref = load('Bottom/3_1.png')
SKIN = {(255, 242, 202): 0, (246, 220, 175): 1, (228, 193, 156): 2}
OUTL_A = (114, 73, 48)

def cells():
    for r in range(ROWS):
        for c in range(COLS):
            yield r, c, slice(r * CELL, (r + 1) * CELL), slice(c * CELL, (c + 1) * CELL)

def upright(b):
    ys, xs = np.nonzero(b[:, :, 3])
    return len(ys) > 0 and (ys.max() - ys.min()) > (xs.max() - xs.min())

# ---------- capa nueva: máscara / pañuelo ----------
def make_mask(rname):
    r = RAMP[rname]; out = np.zeros_like(body)
    for _, _, ys, xs in cells():
        B = body[ys, xs]; E = eyes[ys, xs]; O = out[ys, xs]
        if not upright(B): continue
        ey_, ex_ = np.nonzero(E[:, :, 3])
        if len(ey_):
            ey = ey_.max()
            for y in (ey + 1, ey + 2):
                row = B[y, :, 3] > 0
                for x in range(CELL):
                    if not row[x]: continue
                    col = tuple(int(v) for v in B[y, x, :3])
                    if col in SKIN: O[y, x, :3] = [r[1], r[2], r[3]][SKIN[col]] if y == ey + 2 else [r[0], r[1], r[2]][SKIN[col]]
                    elif col == OUTL_A: O[y, x, :3] = r[3]
                    else: O[y, x, :3] = NAVY
                    O[y, x, 3] = 255
        else:
            ys2, xs2 = np.nonzero(B[:, :, 3]); top = ys2.min(); y = top + 9
            if y >= CELL: continue
            run = np.nonzero(B[y, :, 3])[0]
            if len(run) < 4: continue
            for x in run[1:-1]: O[y, x] = (*r[2], 255)
            cx = int((run[0] + run[-1]) / 2)
            for (dx, dy, k) in ((0, 0, 1), (1, 0, 1), (0, 1, 3), (1, 2, 3), (-1, 1, 2)): O[y + dy, cx + dx] = (*r[k], 255)
    return out

# ---------- capa nueva: parche en el ojo ----------
def make_patch():
    out = np.zeros_like(body); P = (49, 52, 65)
    for _, _, ys, xs in cells():
        B = body[ys, xs]; E = eyes[ys, xs]; O = out[ys, xs]
        if not upright(B): continue
        ey_, ex_ = np.nonzero(E[:, :, 3])
        if not len(ey_): continue
        ex = ex_.max(); ey = ey_[ex_.argmax()]
        for y in (ey - 1, ey):
            for x in (ex - 1, ex): O[y, x] = (*P, 255)
        x, y = ex - 2, ey - 2
        for _ in range(4):
            if B[y, x, 3] and O[y, x, 3] == 0: O[y, x] = (*P, 255)
            x -= 1; y -= 1
    return out

# ---------- capa nueva: cinturón con daga y bolsa ----------
def make_belt():
    out = np.zeros_like(body)
    for r, c, ys, xs in cells():
        Pn = pants_ref[ys, xs]; O = out[ys, xs]
        if not upright(body[ys, xs]): continue
        py, px = np.nonzero(Pn[:, :, 3])
        if not len(py): continue
        top = py.min(); run = np.nonzero(Pn[top, :, 3])[0]
        x0, x1 = run.min(), run.max()
        for x in range(x0, x1 + 1):
            O[top, x] = (*BROWN[2], 255); O[top + 1, x] = (*BROWN[3], 255) if x in (x0, x1) else O[top + 1, x]
        O[top, x0] = (*NAVY, 255); O[top, x1] = (*NAVY, 255)
        back = (r == 3)
        if not back:
            cxm = (x0 + x1) // 2; O[top, cxm] = (252, 196, 88, 255)
            dx = x1 - 1 if r != 1 else x0 + 1
            O[top + 1, dx] = (*BROWN[0], 255); O[top + 2, dx] = (194, 210, 217, 255); O[top + 3, dx] = (161, 179, 198, 255)
            bx = x0 + 1 if r != 1 else x1 - 1
            O[top + 1, bx] = (*BROWN[1], 255); O[top + 2, bx] = (*BROWN[2], 255)
    return out

# ---------- armas derivadas de las del pack ----------
sword = load('Held_Item/2.png'); staff = load('Held_Item/3.png')
HILT = [(215, 152, 62), (171, 94, 32)]
def make_club():
    return recolor(sword, {GREY[0]: BROWN[0], GREY[1]: BROWN[1], GREY[3]: BROWN[2], HILT[0]: BROWN[2], HILT[1]: BROWN[3]})
def make_dagger():
    out = np.zeros_like(sword)
    for _, _, ys, xs in cells():
        S = sword[ys, xs]; O = out[ys, xs]
        hy, hx_ = np.nonzero(((S[:, :, :3] == HILT[0]).all(-1) | (S[:, :, :3] == HILT[1]).all(-1)) & (S[:, :, 3] > 0))
        if not len(hy): continue
        cy, cx = hy.mean(), hx_.mean()
        yy, xx = np.nonzero(S[:, :, 3])
        for y, x in zip(yy, xx):
            if (y - cy) ** 2 + (x - cx) ** 2 <= 4.5 ** 2: O[y, x] = S[y, x]
    return out
def make_rusty_sword():
    return recolor(sword, {GREY[0]: (194, 210, 217), GREY[1]: (161, 179, 198), GREY[3]: (85, 90, 109), HILT[0]: (171, 52, 32), HILT[1]: (133, 27, 19)})
def make_orb_staff(kind):
    out = staff.copy()
    orb = [(255, 231, 119), (255, 158, 71), (228, 59, 0)] if kind == 'fuego' else [(221, 246, 247), (137, 200, 38), (19, 133, 19)]
    for _, _, ys, xs in cells():
        S = staff[ys, xs]; O = out[ys, xs]
        yy, xx = np.nonzero(S[:, :, 3])
        if not len(yy): continue
        i = yy.argmin(); ty, tx = yy[i], xx[i]
        for dy, dx, k in ((-1, 0, 1), (-1, 1, 2), (-2, 0, 0), (-2, 1, 1), (-3, 0, 2), (-1, -1, 2), (-2, -1, 1)):
            y, x = ty + dy, tx + dx
            if 0 <= y < CELL and 0 <= x < CELL: O[y, x] = (*orb[k], 255)
        for y, x in ((ty - 4, tx), (ty - 2, tx + 2), (ty - 2, tx - 2)):
            if 0 <= y < CELL and 0 <= x < CELL and O[y, x, 3] == 0: O[y, x] = (*NAVY, 255)
    return out

L = {}
for rn in ('rojo_sangre', 'negro', 'cuero', 'morado', 'verde_bosque'):
    L[f'mascara_{rn}'] = save(make_mask(rn), 'Mascara', f'panuelo_{rn}')
L['parche'] = save(make_patch(), 'Mascara', 'parche_ojo')
L['cinturon'] = save(make_belt(), 'Accesorio', 'cinturon_daga')
L['garrote'] = save(make_club(), 'Held_Item', 'garrote')
L['daga'] = save(make_dagger(), 'Held_Item', 'daga')
L['espada_oxidada'] = save(make_rusty_sword(), 'Held_Item', 'espada_oxidada')
L['baston_fuego'] = save(make_orb_staff('fuego'), 'Held_Item', 'baston_fuego')
L['baston_vida'] = save(make_orb_staff('vida'), 'Held_Item', 'baston_vida')
L['arco'] = 'orig:Held_Item/4.png'; L['pico'] = 'orig:Held_Item/6.png'

# ---------- ropa recoloreada (misma forma que el pack, paleta bandida) ----------
REDS2BROWN = {RED[0]: BROWN[1], RED[1]: BROWN[2], RED[2]: BROWN[3]}
GOLD2DULL = {(255, 231, 119): (192, 139, 76), (252, 196, 88): (149, 113, 75), (255, 158, 71): (171, 94, 32), (215, 152, 62): (149, 113, 75), (215, 110, 53): (118, 60, 28), (171, 94, 32): (118, 60, 28)}
CLOTH = [
    ('Top', '2_1', 'harapos_cuero', ramp_map('cuero')),
    ('Top', '2_1', 'harapos_sucios', {BROWN[1]: (85, 90, 109), BROWN[2]: (49, 52, 65), BROWN[3]: (25, 6, 87)}),
    ('Top', '3_1', 'tunica_verde', ramp_map('verde_bosque')),
    ('Top', '3_1', 'tunica_negra', ramp_map('negro')),
    ('Top', '3_1', 'tunica_gris', ramp_map('acero_sucio')),
    ('Top', '6_1', 'tunica_cinturon_roja', ramp_map('rojo_sangre')),
    ('Top', '7_1', 'tunica_mago_morada', ramp_map('morado')),
    ('Top', '4_1', 'tunica_chaman', ramp_map('verde_bosque', {RED[0]: (246, 220, 175), RED[1]: (228, 193, 156), RED[2]: (192, 139, 76), (0, 172, 228): (228, 193, 156), (25, 107, 191): (192, 139, 76), (19, 35, 133): (114, 73, 48)})),
    ('Top', '8_1', 'capa_capitan', ramp_map('negro', {**{RED[0]: (191, 25, 41), RED[1]: (133, 27, 19), RED[2]: (90, 35, 20)}})),
    ('Top', '9_1', 'armadura_sucia', ramp_map('acero_sucio')),
    ('Top', '9_1', 'armadura_rey', {GREY[0]: (194, 210, 217), GREY[1]: (161, 179, 198), GREY[2]: (110, 121, 166), GREY[3]: (85, 90, 109), OUTL_A: (191, 25, 41)}),
    ('Top', '10_1', 'cuero_y_malla', ramp_map('acero_sucio')),
    ('Hat', '2_1', 'capucha_verde', ramp_map('verde_bosque')),
    ('Hat', '2_1', 'capucha_morada', ramp_map('morado')),
    ('Hat', '2_1', 'capucha_cuero', ramp_map('cuero')),
    ('Hat', '4_1', 'capucha_sombra_negra', ramp_map('negro')),
    ('Hat', '5_1', 'casco_oxidado', ramp_map('acero_sucio', {GREY[1]: (171, 94, 32)})),
    ('Hat', '3_1', 'corona_robada', {}),
    ('Bottom', '3_1', 'pantalon_cuero', ramp_map('cuero_oscuro')),
    ('Bottom', '3_1', 'pantalon_negro', ramp_map('negro')),
    ('Bottom', '3_1', 'pantalon_verde', ramp_map('verde_bosque')),
    ('Bottom', '3_1', 'pantalon_rojo', ramp_map('rojo_sangre')),
]
for layer, src, name, mp in CLOTH:
    L[name] = save(recolor(load(f'{layer}/{src}.png'), mp), layer, name)

# ---------- ropa de facción: un solo color ----------
BANDIDO = [(150, 132, 116), (116, 100, 92), (82, 68, 66), (54, 43, 50)]
def lum(c): return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]
def mono(arr, ramp=BANDIDO):
    a = arr.reshape(-1, 4); cols = np.unique(a[a[:, 3] > 0][:, :3], axis=0)
    cols = [tuple(int(v) for v in c) for c in cols if tuple(int(v) for v in c) != NAVY]
    cols.sort(key=lum, reverse=True); mp = {}
    for i, c in enumerate(cols): mp[c] = ramp[min(3, int(i * 4 / max(len(cols), 1)))]
    return recolor(arr, mp)
MONO = [('Top', '2_1', 'b_harapos'), ('Top', '3_1', 'b_tunica'), ('Top', '7_1', 'b_tunica_mago'), ('Top', '4_1', 'b_tunica_chaman'),
        ('Top', '8_1', 'b_capa'), ('Top', '10_1', 'b_cuero_malla'), ('Top', '6_1', 'b_tunica_cinturon'),
        ('Hat', '2_1', 'b_capucha'), ('Hat', '4_1', 'b_capucha_sombra'), ('Hat', '5_1', 'b_casco'), ('Bottom', '3_1', 'b_pantalon')]
for layer, src, name in MONO: L[name] = save(mono(load(f'{layer}/{src}.png')), layer, name)
L['b_cinturon'] = save(mono(np.array(Image.open(f"{OUT}/Sprite/{L['cinturon']}").convert('RGBA')), [BANDIDO[1], BANDIDO[2], BANDIDO[2], BANDIDO[3]]), 'Accesorio', 'b_cinturon')

# ---------- jefe: el Barón Carmesí ----------
def horns(hat):
    out = hat.copy(); BONE = [(255, 242, 202), (246, 220, 175), (228, 193, 156)]
    for r, c, ys, xs in cells():
        H = out[ys, xs]; yy, xx = np.nonzero(H[:, :, 3])
        if not len(yy) or not upright(body[ys, xs]): continue
        top = yy.min(); x0, x1 = xx.min(), xx.max()
        sides = [(x0 + 1, -1), (x1 - 1, 1)] if r in (0, 3) else ([(x1 - 2, 1)] if r == 2 else [(x0 + 2, -1)])
        for hxp, sgn in sides:
            pts = [(hxp, top + 1), (hxp + sgn, top), (hxp + sgn, top + 1), (hxp + 2 * sgn, top - 1), (hxp + 2 * sgn, top), (hxp + 2 * sgn, top - 2), (hxp + sgn, top - 3)]
            for k, (x, y) in enumerate(pts):
                if 0 <= y < CELL and 0 <= x < CELL:
                    H[y, x] = (*BONE[min(2, k // 2)], 255)
                    for ox, oy in ((-1, 0), (1, 0), (0, -1)):
                        if 0 <= y + oy < CELL and 0 <= x + ox < CELL and H[y + oy, x + ox, 3] == 0: H[y + oy, x + ox] = (*NAVY, 255)
    return out
def greatsword():
    out = recolor(sword, {GREY[0]: (161, 179, 198), GREY[1]: (110, 121, 166), GREY[3]: (49, 52, 65), HILT[0]: (191, 25, 41), HILT[1]: (133, 27, 19)})
    for _, _, ys, xs in cells():
        S = out[ys, xs]; hy, hx_ = np.nonzero(((sword[ys, xs][:, :, :3] == HILT[0]).all(-1)) & (sword[ys, xs][:, :, 3] > 0))
        yy, xx = np.nonzero(S[:, :, 3])
        if not len(hy) or not len(yy): continue
        cy, cx = hy.mean(), hx_.mean(); d = (yy - cy) ** 2 + (xx - cx) ** 2; i = d.argmax()
        ty, tx = yy[i], xx[i]; vy, vx = ty - cy, tx - cx; n = max(1e-6, (vy * vy + vx * vx) ** 0.5); vy, vx = vy / n, vx / n
        for k in range(1, 6):
            y, x = int(round(ty + vy * k)), int(round(tx + vx * k))
            if 0 <= y < CELL and 0 <= x < CELL: S[y, x] = (194, 210, 217, 255) if k < 5 else (221, 246, 247, 255)
    return out
L['casco_cuernos'] = save(horns(recolor(load('Hat/5_1.png'), ramp_map('negro', {(90, 35, 20): (191, 25, 41)}))), 'Hat', 'jefe_casco_cuernos')
L['armadura_jefe'] = save(recolor(load('Top/9_1.png'), {GREY[0]: (110, 121, 166), GREY[1]: (85, 90, 109), GREY[2]: (191, 25, 41), GREY[3]: (49, 52, 65), OUTL_A: (228, 59, 0)}), 'Top', 'jefe_armadura_carmesi')
L['mandoble'] = save(greatsword(), 'Held_Item', 'jefe_mandoble')
L['ojos_rojos'] = save(recolor(eyes, {tuple(int(v) for v in c): (228, 59, 0) for c in np.unique(eyes.reshape(-1, 4)[eyes.reshape(-1, 4)[:, 3] > 0][:, :3], axis=0)}), 'Eyes', 'jefe_ojos_rojos')

# ---------- presets ----------
ORDER = ['Rear_Hair', 'Body', 'Eyes', 'Shoes', 'Bottom', 'Top', 'Accesorio', 'Facial_Hair', 'Mascara', 'Front_Hair', 'Hat', 'Held_Item']
def ref(x): return x if x.startswith('orig:') else 'new:' + x
B = lambda k: ref(L[k])
PRESETS = {
 'bandido_maton':      dict(Body='orig:Body/2.png', Eyes='orig:Eyes/1.png', Front_Hair='orig:Front_Hair/4_4.png', Rear_Hair='orig:Rear_Hair/4_4.png', Facial_Hair='orig:Facial_Hair/2_4.png',
                            Top=B('b_harapos'), Bottom=B('b_pantalon'), Accesorio=B('b_cinturon'), Mascara=B('mascara_rojo_sangre'), Held_Item=B('garrote')),
 'bandido_arquero':    dict(Body='orig:Body/1.png', Eyes='orig:Eyes/2.png', Hat=B('b_capucha'), Top=B('b_tunica'), Bottom=B('b_pantalon'),
                            Accesorio=B('b_cinturon'), Mascara=B('mascara_rojo_sangre'), Held_Item=L['arco']),
 'bandido_degollador': dict(Body='orig:Body/2.png', Eyes='orig:Eyes/3.png', Hat=B('b_capucha_sombra'), Top=B('b_tunica_cinturon'), Bottom=B('b_pantalon'),
                            Mascara=B('mascara_rojo_sangre'), Held_Item=B('daga')),
 'bandido_bruto':      dict(Body='orig:Body/4.png', Eyes='orig:Eyes/1.png', Facial_Hair='orig:Facial_Hair/3_5.png', Hat=B('b_casco'), Top=B('b_cuero_malla'),
                            Bottom=B('b_pantalon'), Mascara=B('mascara_rojo_sangre'), Held_Item=L['pico']),
 'bandido_mago':       dict(Body='orig:Body/1.png', Eyes='orig:Eyes/4.png', Hat=B('b_capucha'), Top=B('b_tunica_mago'), Bottom=B('b_pantalon'),
                            Mascara=B('mascara_rojo_sangre'), Held_Item=B('baston_fuego')),
 'bandido_chaman':     dict(Body='orig:Body/5.png', Eyes='orig:Eyes/3.png', Front_Hair='orig:Front_Hair/4_1.png', Rear_Hair='orig:Rear_Hair/4_1.png', Facial_Hair='orig:Facial_Hair/4_1.png',
                            Top=B('b_tunica_chaman'), Bottom=B('b_pantalon'), Mascara=B('mascara_rojo_sangre'), Held_Item=B('baston_vida')),
 'capitan_bandido':    dict(Body='orig:Body/2.png', Eyes='orig:Eyes/2.png', Front_Hair='orig:Front_Hair/3_5.png', Rear_Hair='orig:Rear_Hair/3_5.png', Facial_Hair='orig:Facial_Hair/2_5.png',
                            Top=B('b_capa'), Bottom=B('b_pantalon'), Accesorio=B('b_cinturon'), Mascara=B('parche'), Held_Item=B('espada_oxidada')),
 'jefe_baron_carmesi': dict(Body='orig:Body/4.png', Eyes=B('ojos_rojos'), Facial_Hair='orig:Facial_Hair/3_5.png', Rear_Hair='orig:Rear_Hair/3_5.png',
                            Hat=B('casco_cuernos'), Top=B('armadura_jefe'), Bottom=B('b_pantalon'), Held_Item=B('mandoble')),
}
def load_ref(rf):
    if rf.startswith('orig:'):
        p = f'{SRC}/{rf[5:]}'
        return load(rf[5:]) if os.path.exists(p) else np.zeros((384, 576, 4), np.uint8)
    return np.array(Image.open(f'{OUT}/Sprite/{rf[4:]}').convert('RGBA'))
os.makedirs(f'{OUT}/presets', exist_ok=True)
comp = {}
for name, p in PRESETS.items():
    p = dict(p); p['Shoes'] = 'orig:Bottom/Shoes_Layer.png'
    canvas = Image.new('RGBA', (576, 384), (0, 0, 0, 0))
    for layer in ORDER:
        if layer in p: canvas.alpha_composite(Image.fromarray(load_ref(p[layer])))
    canvas.save(f'{OUT}/presets/{name}.png'); comp[name] = canvas
    PRESETS[name] = {k: p[k] for k in ORDER if k in p}
big = np.array(comp['jefe_baron_carmesi']).repeat(2, 0).repeat(2, 1)
a = big[:, :, 3] > 0; glow = np.zeros_like(big)
for dy in (-2, -1, 0, 1, 2):
    for dx in (-2, -1, 0, 1, 2):
        if abs(dx) + abs(dy) > 3: continue
        sh = np.roll(np.roll(a, dy, 0), dx, 1)
        glow[sh & ~a & (glow[:, :, 3] == 0)] = (228, 59, 0, 120 if abs(dx) + abs(dy) > 1 else 220)
gimg = Image.fromarray(glow); gimg.alpha_composite(Image.fromarray(big))
gimg.save(f'{OUT}/presets/jefe_baron_carmesi_x2.png'); comp['jefe_x2'] = gimg
json.dump({'orden_capas': ORDER, 'nota': 'orig: = archivo del pack original en Sprite/; new: = capa nueva en tpf_bandidos/Sprite/', 'presets': PRESETS},
          open(f'{OUT}/presets/bandidos_presets.json', 'w'), indent=1, ensure_ascii=False)

# ---------- previews ----------
BG = (82, 122, 61, 255)
names = list(PRESETS)
def crop(im, c, r): return im.crop((c * CELL + 8, r * CELL + 6, c * CELL + 40, r * CELL + 44))
W, H = 32, 38
small = [n for n in names if not n.startswith('jefe')]
sheet = Image.new('RGBA', (len(small) * W + 64, 4 * H), BG)
for i, n in enumerate(small):
    for j, r in enumerate((0, 1, 2, 3)): sheet.alpha_composite(crop(comp[n], 0, r), (i * W, j * H))
for j, r in enumerate((0, 1, 2, 3)):
    sheet.alpha_composite(comp['jefe_x2'].crop((4, r * 96 + 4, 76, r * 96 + 92)).resize((72, 88)).crop((4, 0, 68, 88)).crop((0, 12, 64, 88)).resize((64, 76)).crop((0, 0, 64, H * 2)).crop((0, 0, 64, H)) if False else comp['jefe_x2'].crop((16, r * 96 + 14, 80, r * 96 + 90)).resize((64, 76), Image.NEAREST).crop((0, 76 - H, 64, 76)) if False else comp['jefe_x2'].crop((16, r * 96 + 96 - 2 - H, 80, r * 96 + 94)), (len(small) * W, j * H))
sheet.resize((sheet.width * 5, sheet.height * 5), Image.NEAREST).convert('RGB').save(f'{OUT}/preview_bandidos.png')
poses = Image.new('RGBA', (11 * W, len(names) * H), BG)
for i, n in enumerate(names):
    for c in range(11): poses.alpha_composite(crop(comp[n], c, 0), (c * W, i * H))
poses.resize((poses.width * 3, poses.height * 3), Image.NEAREST).convert('RGB').save(f'{OUT}/preview_poses.png')
frames = []
for d in (0, 2, 3, 1):
    for c in (0, 1, 0, 2) * 2:
        f = Image.new('RGBA', (len(names) * W, H), BG)
        for i, n in enumerate(names): f.alpha_composite(crop(comp[n], c, d), (i * W, 0))
        frames.append(f.resize((f.width * 4, f.height * 4), Image.NEAREST).convert('RGB'))
frames[0].save(f'{OUT}/preview_caminando.gif', save_all=True, append_images=frames[1:], duration=160, loop=0)
print('ok')
