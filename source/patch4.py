s=open('tpl3.html',encoding='utf-8').read()
def r(a,b):
    global s
    assert a in s,a[:50]
    s=s.replace(a,b)
r('<link href="https://fonts.googleapis.com/css2?family=Pangolin&family=Caveat+Brush&family=Rubik:wght@600;800&display=swap" rel="stylesheet">','')
r('<div id="fx"></div>','<div id="bg"></div><div id="fx"></div>')
ff=''
CY="U+0301,U+0400-045F,U+0490-0491,U+04B0-04B1,U+2116";LT="U+0000-00FF,U+0131,U+0152-0153,U+2013-2014,U+2018-201D,U+2022,U+2026,U+20AC"
for w,rng in [('600','400 700'),('900','800 900')]:
    for sub,ur in [('cyrillic',CY),('latin',LT)]:
        ff+="@font-face{font-family:Nunito;font-weight:%s;font-display:swap;src:url(__F_%s_%s__) format('woff2');unicode-range:%s}\n"%(rng,sub,w,ur)
css=ff+r'''
:root{--bgimg:url(__BG__);--hd:'Nunito','Trebuchet MS',system-ui,sans-serif;--tx:'Nunito',system-ui,sans-serif}
body{background:#e9d9b6;font-weight:600}
#bg{position:fixed;inset:-4%;z-index:-2;background:var(--bgimg) 16% 62%/cover;animation:pan 46s ease-in-out infinite alternate;will-change:transform}
@keyframes pan{to{transform:scale(1.07) translate(-1.6%,-1.2%)}}
body:before{background:linear-gradient(var(--m1),var(--m2))!important;opacity:.38}
:root[data-theme=dark] body:before{opacity:.7}@media(prefers-color-scheme:dark){:root:not([data-theme=light]) body:before{opacity:.7}}
h1,h2,h3,.hd,.cta,.rt,.rib,.logo,.dnav button,.tabs button,.chip,.rr,.note,.sec a{font-weight:900}
.logo{font-size:27px;line-height:1;text-shadow:0 2px 0 #fff9,0 4px 10px #0003;letter-spacing:-.3px}.logo b{text-shadow:0 2px 0 #fff9,0 4px 10px #0003}
.sec h2{font-size:30px;text-shadow:0 2px 0 #fff9,0 3px 8px #0002}.bk h2{font-size:29px}.ttl{font-size:32px;letter-spacing:-.4px}.rt{font-size:19px}
.cta{font-size:18px;letter-spacing:.2px}.cta.sm{font-size:15px}.rib{font-size:17px}.card h3{font-size:19px}.row h3{font-size:17px}.feat h3{font-size:24px}.gc h3{font-size:15.5px}.txt h3{font-size:20px}.rr{font-size:17px!important}
.txt{font-size:17.5px;line-height:1.62;font-weight:600}.txt p.n{font-weight:600}.bk p{font-weight:600}.card .d{font-weight:600}
.card,.row,.gc,.feat,.side,.dnav{background:color-mix(in srgb,var(--pg) 90%,transparent);backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px)}
.row.on{background:var(--pk)}.tabs>div{background:color-mix(in srgb,var(--pg) 92%,transparent);backdrop-filter:blur(10px);-webkit-backdrop-filter:blur(10px)}
.hero .peek img,.dpk{image-rendering:auto}
.top{padding:6px 0}.sec h2::after{content:"";display:block;height:5px;width:46px;border-radius:4px;background:var(--co);margin-top:4px;opacity:.85}
.bk{background:linear-gradient(90deg,color-mix(in srgb,var(--pg) 96%,transparent) 48%,var(--ln) 50%,color-mix(in srgb,var(--pg) 96%,transparent) 52%)}
#cover{background:var(--bgimg) 18% 60%/cover}
#cover:before{content:"";position:absolute;inset:0;background:radial-gradient(circle,#fff3 0,#0004 100%)}
.top{background:color-mix(in srgb,var(--pg) 88%,transparent);border-radius:22px;padding:8px 12px;backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px);box-shadow:0 4px 12px #6b3f2a22}
.logo{text-shadow:none!important}.sec{background:color-mix(in srgb,var(--pg) 86%,transparent);border-radius:18px;padding:8px 14px;backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px)}.sec h2,.sec h2::after{text-shadow:none}
@media(min-width:900px){body{background:#e9d9b6}body:before{background:linear-gradient(var(--m1),var(--m2))!important}#bg{background-position:center 60%}
.logo{font-size:30px}.bk h2{font-size:46px}.ttl{font-size:44px}.sec h2{font-size:34px}.sp h2{font-size:44px}.cta{font-size:19px}.rt{font-size:22px}.txt{font-size:19px}.card h3{font-size:20px}.side>button,.dnav button{font-weight:800}}
'''
r("</style>",css+"</style>")
open('tpl4.html','w',encoding='utf-8').write(s)
