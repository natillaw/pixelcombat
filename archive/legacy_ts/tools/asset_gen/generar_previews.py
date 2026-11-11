from PIL import Image
O='/mnt/user-data/outputs/tpf_bandidos/'
small=['bandido_maton','bandido_arquero','bandido_degollador','bandido_bruto','bandido_mago','bandido_chaman','capitan_bandido']
BG=(82,122,61,255); W,H=32,40
imgs={n:Image.open(O+'presets/%s.png'%n) for n in small}; boss=Image.open(O+'presets/jefe_baron_carmesi_x2.png')
heroish=Image.open('/home/claude/tpf/Sprite/Body/1.png')
RH=84
sheet=Image.new('RGBA',(len(small)*W+80,4*RH),BG)
for j in range(4):
    for i,n in enumerate(small):
        sheet.alpha_composite(imgs[n].crop((8,j*48+4,40,j*48+44)),(i*W,j*RH+RH-H))
    sheet.alpha_composite(boss.crop((8,j*96,88,j*96+96)).crop((0,96-RH,80,96)),(len(small)*W,j*RH))
sheet.resize((sheet.width*4,sheet.height*4),Image.NEAREST).convert('RGB').save(O+'preview_bandidos.png')
frames=[]
for d in (0,2,3,1):
    for c in (0,1,0,2)*2:
        f=Image.new('RGBA',(len(small)*W+80,RH),BG)
        for i,n in enumerate(small): f.alpha_composite(imgs[n].crop((c*48+8,d*48+4,c*48+40,d*48+44)),(i*W,RH-H))
        f.alpha_composite(boss.crop((c*96+8,d*96,c*96+88,d*96+96)).crop((0,96-RH,80,96)),(len(small)*W,0))
        frames.append(f.resize((f.width*3,f.height*3),Image.NEAREST).convert('RGB'))
frames[0].save(O+'preview_caminando.gif',save_all=True,append_images=frames[1:],duration=160,loop=0)
