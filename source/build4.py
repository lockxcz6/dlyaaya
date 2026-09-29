import json,base64,io,glob
from PIL import Image,ImageSequence
exec(open('build.py').read().split("print(len(out)")[0])
W='/home/claude/wbb/'
def stat(n):
    im=Image.open(f'{W}static/{n:03d}_we_bare_bears.webp').convert('RGB');im.thumbnail((400,400))
    b=io.BytesIO();im.save(b,'WEBP',quality=70);return 'data:image/webp;base64,'+base64.b64encode(b.getvalue()).decode()
def gif(n):
    im=Image.open(f'{W}gif/{n:03d}_we_bare_bears.gif');d=im.info.get('duration',60) or 60
    fr=[x.convert('RGBA').copy() for x in ImageSequence.Iterator(im)];step=2 if len(fr)>40 else 1;fr=fr[::step]
    for x in fr:x.thumbnail((300,300))
    b=io.BytesIO();fr[0].save(b,'WEBP',save_all=True,append_images=fr[1:],duration=max(40,d*step),loop=0,quality=55,method=4)
    return 'data:image/webp;base64,'+base64.b64encode(b.getvalue()).decode()
IM={}
peek={'gp':16,'gi':11,'gg':23,'gt':21}
for k,n in peek.items():IM[k]=gif(n)
# stickers: transparent gifs 1..26 minus peeks
stk=[f'g{n}' for n in range(1,27) if n not in peek.values()]
gm=[f'g{n}' for n in range(27,51)]
for n in range(1,51):
    if f'g{n}' in stk or f'g{n}' in gm:IM[f'g{n}']=gif(n)
# statics interleaved panda(1-45) grizz(46-82) ice(83-100)
grp=[list(range(1,46)),list(range(46,83)),list(range(83,101))]
order=sorted((x/len(g)+ (gi*0.013),gi,n) for gi,g in enumerate(grp) for x,n in enumerate(g))
st=[f's{o[2]}' for o in order]
for k in st:IM[k]=stat(int(k[1:]))
main=st[:]
for x,k in enumerate(gm):main.insert(int((x+.5)*len(main)/len(gm)),k)
IM['__main']=main;IM['__stk']=stk
data=json.dumps(out,ensure_ascii=False).replace('</','<\\/')
h=open('tpl4.html',encoding='utf-8').read().replace('__DATA__',data).replace('__IMG__',json.dumps(IM))
import os,shutil,zipfile,glob
F='/home/claude/fonts/node_modules/@fontsource/nunito/files/nunito-%s-%s-normal.woff2'
for sub in('cyrillic','latin'):
    for w in('600','900'):
        h=h.replace('__F_%s_%s__'%(sub,w),'data:font/woff2;base64,'+base64.b64encode(open(F%(sub,w),'rb').read()).decode())
bg=Image.open('/mnt/user-data/uploads/5f70e6c0-17f2-4b2a-9e2a-88a817a01e16.png').convert('RGB');bg.thumbnail((1600,900))
bb=io.BytesIO();bg.save(bb,'WEBP',quality=76);BG=bb.getvalue()
h=h.replace('__BG__','data:image/webp;base64,'+base64.b64encode(BG).decode())
open('/mnt/user-data/outputs/index.html','w',encoding='utf-8').write(h)
# ---- archive
R='/home/claude/pkg';shutil.rmtree(R,ignore_errors=True)
for d in('assets/media','assets/fonts','source'):os.makedirs(f'{R}/{d}')
open(f'{R}/index.html','w',encoding='utf-8').write(h)
open(f'{R}/assets/background.webp','wb').write(BG)
for k,v in IM.items():
    if isinstance(v,str):open(f'{R}/assets/media/{k}.webp','wb').write(base64.b64decode(v.split(',',1)[1]))
for sub in('cyrillic','latin'):
    for w in('600','900'):shutil.copy(F%(sub,w),f'{R}/assets/fonts/')
for f in('tpl4.html','build4.py','patch4.py','build.py'):shutil.copy('/home/claude/'+f,f'{R}/source/'+f)
shutil.copy('/mnt/user-data/uploads/История.md',f'{R}/source/История.md')
open(f'{R}/README.txt','w',encoding='utf-8').write('''Та, которую невозможно забыть — книга-сайт

КАК ВЫЛОЖИТЬ
- index.html — готовый сайт одним файлом (картинки, гифки, шрифты и фон внутри). Открывается двойным щелчком.
- Netlify: app.netlify.com/drop — перетащи папку с index.html (или сам файл) на страницу. Ссылку можно отправить.

ЧТО ВНУТРИ
- assets/background.webp — фон
- assets/media/ — все 150 картинок и гифок (s* — кадры, g* — анимации)
- assets/fonts/ — шрифт Nunito
- source/ — твоя история (История.md) и файлы, из которых собран сайт (tpl4.html — шаблон, build4.py — сборка)

Картинки медведей принадлежат правообладателям (Cartoon Network); используются в личных целях.
''')
zp='/mnt/user-data/outputs/kniga-sait.zip'
if os.path.exists(zp):os.remove(zp)
with zipfile.ZipFile(zp,'w',zipfile.ZIP_DEFLATED) as z:
    for root,_,fs in os.walk(R):
        for f in fs:
            p=os.path.join(root,f);z.write(p,os.path.relpath(p,R))
print(os.path.getsize(zp)//1024,'KB zip')
print(len(h)//1024,'KB')
