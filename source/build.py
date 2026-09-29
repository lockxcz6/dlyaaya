import re,json,html
src=open('/mnt/user-data/uploads/История.md',encoding='utf-8').read()
def inl(s):
    s=html.escape(s,quote=False)
    s=re.sub(r'\*\*(.+?)\*\*',r'<b>\1</b>',s)
    s=re.sub(r'(?<!\*)\*(?!\s)(.+?)(?<!\s)\*(?!\*)',r'<i>\1</i>',s)
    return s
parts=re.split(r'<!-- CHAPTER id="CH-\d+" mood="([^"]+)" -->',src)
out=[]
for i in range(1,len(parts),2):
    mood,body=parts[i],parts[i+1]
    def media(m):
        cap=re.search(r'Подпись: «(.*)»\s*\n',m.group(0));return '\n@@M|%s|%s\n'%(m.group(1),cap.group(1) if cap else '')
    body=re.sub(r'<!-- MEDIA_SLOT[^>]*kind="(\w+)"[^>]*-->.*?<!-- /MEDIA_SLOT -->',media,body,flags=re.S)
    lines=[l.rstrip('\n') for l in body.split('\n')]
    t=None;date='';blocks=[];q=[]
    def fq():
        global q
        if q: blocks.append(['q','<br>'.join(inl(x) for x in q)]);q=[]
    for l in lines:
        s=l.strip()
        if s.startswith('## '):
            t=s[3:];continue
        if s.startswith('>'):
            q.append(s[1:].strip()) if s[1:].strip() else None;continue
        fq()
        if not s or s=='---' or s=='*Конец письма.*':continue
        if s.startswith('@@M|'):
            _,k,c=s.split('|',2);blocks.append(['m',k,html.escape(c)]);continue
        if s.startswith('### '):blocks.append(['h',inl(s[4:])]);continue
        if s.startswith('*') and s.endswith('*') and not s.startswith('**') and not date and not blocks:
            date=s.strip('*');continue
        if s.startswith('*') and s.endswith('*') and not s.startswith('**'):
            blocks.append(['n',inl(s.strip('*'))]);continue
        blocks.append(['p',inl(s)])
    fq()
    m=re.match(r'(\d+)\.\s*(.*)',t)
    num,title=(int(m.group(1)),m.group(2)) if m else (0,t)
    ln=sum(len(b[1]) for b in blocks if b[0]!='m')
    out.append(dict(num=num,t=html.escape(title,quote=False),date=html.escape(date),mood=mood,b=blocks,len=ln))
print(len(out),[c['t'] for c in out][:3],out[0]['b'][:5])
data=json.dumps(out,ensure_ascii=False).replace('</','<\\/')
open('/mnt/user-data/outputs/index.html','w',encoding='utf-8').write(open('tpl.html',encoding='utf-8').read().replace('__DATA__',data))
