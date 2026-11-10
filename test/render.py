import json, re, html, sys
from playwright.sync_api import sync_playwright
ops=json.load(open('ops.json'))
def fixkeys(o):
    if isinstance(o,dict): return {(int(k) if isinstance(k,str) and k.isdigit() else k):fixkeys(v) for k,v in o.items()}
    if isinstance(o,list): return [fixkeys(x) for x in o]
    return o
ops=fixkeys(ops)
COL={'ok':'#59d959','warn':'#ffb333','bad':'#f24d4d','unknown':'#9e9e9e','gold':'#ffd100','grey':'#9e9e9e','white':'#ebebeb','blue':'#73b3ff'}
def rgb(c): return 'rgb(%d,%d,%d)'%tuple(int(v*255) for v in c) if isinstance(c,list) else '#ebebeb'
def wow(s):
    if s is None: return ''
    s=str(s)
    s=re.sub(r'\|T[^|]*ReadyCheck-Ready[^|]*\|t','\x01ok\x02',s)
    s=re.sub(r'\|T[^|]*ReadyCheck-NotReady[^|]*\|t','\x01bad\x02',s)
    s=re.sub(r'\|T[^|]*ReadyCheck-Waiting[^|]*\|t','\x01warn\x02',s)
    s=re.sub(r'\|H[^|]*\|h(\[[^\]]*\])\|h','\x03\\1\x04',s)
    s=html.escape(s)
    s=re.sub(r'\|c[fF]{2}([0-9a-fA-F]{6})',r'<span style="color:#\1">',s).replace('|r','</span>')
    s=s.replace('\x03','<span class="epic">').replace('\x04','</span>')
    s=re.sub('\x01(\\w+)\x02',lambda m:'<i class="ic %s"></i>'%m.group(1),s)
    return s
def draw(op):
    t=op.get('t')
    if t=='gap': return '<div style="height:%dpx"></div>'%op.get('h',8)
    if t=='note': return '<div class="note">%s</div>'%wow(op['text'])
    if t=='bar':
        pct=100*op.get('v',0)/max(1,op.get('max',1))
        return '<div class="bar"><div style="width:%.0f%%;background:%s"></div><span>%s</span></div>'%(pct,rgb(op.get('col')),wow(op.get('text')))
    if t=='row':
        btns=''.join('<b class="btn sm">%s</b>'%wow(b.get(1) if isinstance(b,dict) else b[0]) for b in (op.get('btns') or []))
        ic=wow(op.get('icon'))
        ind=op.get('indent',0)
        return '<div class="row"><span class="l" style="color:%s;padding-left:%dpx">%s%s</span><span class="r" style="color:%s">%s</span>%s</div>'%(rgb(op.get('lc')),ind,ic,wow(op.get('l')),rgb(op.get('rc',[.62,.62,.62])),wow(op.get('r')),btns)
    if t=='input':
        lab='<span class="lab">%s</span>'%wow(op['label']) if op.get('label') else ''
        val=wow(op.get('value') or '')
        if len(val)>60: val=val[:60]+'…'
        b='<b class="btn">%s</b>'%op['btn'] if op.get('btn') else ''
        return '<div class="inp">%s<span class="eb">%s</span>%s</div>'%(lab,val,b)
    if t=='btns':
        return '<div class="btns">%s</div>'%''.join('<b class="btn" style="width:%dpx">%s</b>'%((b.get('w') or 110) if isinstance(b,dict) else 110, wow(b.get(1) if isinstance(b,dict) else b[0])) for b in op['list'])
    if t=='cols':
        sp=op.get('split',0.5)
        return '<div class="cols"><div style="flex:%s">%s</div><div style="flex:%s">%s</div></div>'%(sp,''.join(draw(x) for x in op.get('left') or []),1-sp,''.join(draw(x) for x in op.get('right') or []))
    if t=='head':
        return '<div class="hd"><span>%s</span><span class="g">%s</span></div>'%(wow(op.get('text')),wow(op.get('r')))
    if t=='itemrow':
        btns=''.join('<b class="btn sm">%s</b>'%wow(b.get(1) if isinstance(b,dict) else b[0]) for b in (op.get('btns') or []))
        q=op.get('qcol')
        ring=rgb(q) if q else '#888'
        nm=re.sub(r'<[^>]+>','',wow(op.get('name')))
        ini=''.join(w[0] for w in nm.strip('[]').split()[:2])
        hue=(sum(map(ord,nm))*37)%360
        ic='<i class="iic%s" style="border-color:%s;background:linear-gradient(135deg,hsl(%d,45%%,38%%),hsl(%d,40%%,14%%))">%s</i>'%(' dim' if op.get('dim') else '',ring,hue,hue,ini)
        return '<div class="ir">%s<div class="tx"><div class="n">%s</div><div class="s">%s</div></div>%s</div>'%(ic,wow(op.get('name')),wow(op.get('sub')),btns)
    if t=='paperdoll':
        S,G=38,5
        def slot(sl,x,y,pos=None):
            d=(op.get('slots') or {}).get(str(sl)) if isinstance(op.get('slots'),dict) else None
            if d is None and isinstance(op.get('slots'),dict): d=op['slots'].get(sl)
            lab={'shirt':'Shirt','tabard':'Tab'}.get(sl, SN.get(sl,''))
            if not d or isinstance(sl,str):
                return '<div class="sl dim" style="%s;top:%dpx">%s</div>'%(pos or 'left:%dpx'%x,y,lab)
            col={'ok':'#59d959','warn':'#ffb333','unknown':'#777'}.get(d.get('state'),'#444')
            if d.get('empty'): col='#3a3a3a'
            if op.get('sel')==sl: col='#ffd100'
            if d.get('empty'): inner='<span class="e">%s</span>'%lab
            else:
                nm=NAMES.get(d.get('id'),'?')
                hue=(d.get('id',0)*47)%360
                inner='<span class="it" style="background:linear-gradient(135deg,hsl(%d,45%%,38%%),hsl(%d,40%%,16%%))">%s</span>'%(hue,hue,''.join(w[0] for w in nm.split()[:2]))
            return '<div class="sl" style="%s;top:%dpx;background:%s">%s</div>'%(pos or 'left:%dpx'%x,y,col,inner)
        W=516; h=[]
        L=[1,2,3,15,5,'shirt','tabard',9]; R=[10,6,7,8,11,12,13,14]
        for i,sl in enumerate(L): h.append(slot(sl,0,i*(S+G)))
        for i,sl in enumerate(R): h.append(slot(sl,0,i*(S+G),'right:0px'))
        by=8*(S+G)+6; bx=(W-(3*S+2*G))//2
        for i,sl in enumerate([16,17,18]): h.append(slot(sl,0,by,'left:calc(50%% + %dpx)'%((i-1)*(S+G)-S//2)))
        cen=''.join('<div style="color:%s;font-size:%dpx;margin-bottom:4px">%s</div>'%(rgb(l.get('2')) if isinstance(l,dict) else (rgb(l[1]) if len(l)>1 else '#ebebeb'), 17 if i==0 else (13 if i==3 else 11), wow(l.get('1') if isinstance(l,dict) else l[0])) for i,l in enumerate(op.get('center',[])))
        h.append('<div class="cen" style="left:%dpx;right:%dpx">%s</div>'%(S+16,S+16,cen))
        if op.get('tryOn'):
            h.append('<div class="model" style="left:%dpx;right:%dpx;top:110px;height:%dpx"><div class="fig"></div><span>3D preview of the planned set</span></div>'%(S+16,S+16,by-118))
        return '<div class="doll" style="height:%dpx">%s</div>'%(by+S+8,''.join(h))
    if t=='card':
        hd=''
        if op.get('title'): hd='<div class="ch"><span>%s</span><span style="color:%s">%s</span></div>'%(wow(op['title']),rgb(op.get('rc',[.62,.62,.62])),wow(op.get('right')))
        return '<div class="card">%s%s</div>'%(hd,''.join(draw(x) for x in op.get('items',[])))
    return ''
SN={1:'Head',2:'Neck',3:'Shld',15:'Back',5:'Chest',9:'Wrist',10:'Hand',6:'Wst',7:'Legs',8:'Feet',11:'Ring',12:'Ring',13:'Trnk',14:'Trnk',16:'MH',17:'OH',18:'Rng'}
NAMES={101:'Lionheart Helm',102:'Onyxia Tooth Pendant',103:"Blackhand's Breadth",104:'Hand of Justice',105:"Don Julio's Band",107:'Arcanite Reaper',108:'Savage Gladiator Chain',12936:'Battleborn Armbraces',13361:'Skullforge Reaver'}
CSS='''.cols{display:flex;gap:12px;align-items:flex-start}.cols>div{min-width:0}
.hd{display:flex;justify-content:space-between;color:#ffd100;font-size:11px;border-bottom:1px solid rgba(255,209,0,.25);margin:6px 0 4px;padding-bottom:2px}.hd .g{color:#9e9e9e}
.ir{display:flex;align-items:center;gap:6px;height:32px;margin-bottom:2px}.ir .tx{flex:1;min-width:0}.ir .n{font-size:12px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.ir .s{font-size:10px;color:#9e9e9e;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.iic{display:flex;width:26px;height:26px;border:1px solid;align-items:center;justify-content:center;font-style:normal;font-size:9px;font-weight:bold;color:#fff;flex:none}.iic.dim{filter:grayscale(1);opacity:.6}
.doll{position:relative;margin:4px 0 8px}.sl{position:absolute;width:38px;height:38px;box-sizing:border-box;padding:2px;box-shadow:0 0 0 3px #1b1b1b,0 0 0 4px #5a5040,inset 0 0 6px #000}.sl.dim{background:#262626;color:#555;font-size:8px;display:flex;align-items:center;justify-content:center;opacity:.6}
.sl .it,.sl .e{display:flex;width:100%;height:100%;align-items:center;justify-content:center;font-size:11px;font-weight:bold;color:#fff;text-shadow:0 0 3px #000}.sl .e{background:#111;color:#666;font-size:8px;font-weight:normal}
.cen{position:absolute;top:6px;text-align:center}.model{position:absolute;background:radial-gradient(ellipse at 50% 60%,#2a2418,#0a0a0d 70%);border-radius:6px;display:flex;flex-direction:column;align-items:center;justify-content:flex-end;color:#776;font-size:10px;padding-bottom:6px;box-sizing:border-box}.fig{width:70px;height:150px;margin-bottom:8px;background:#3b3324;opacity:.7;clip-path:polygon(40% 0,60% 0,63% 12%,80% 16%,92% 50%,82% 52%,74% 30%,70% 55%,66% 100%,54% 100%,50% 62%,46% 100%,34% 100%,30% 55%,26% 30%,18% 52%,8% 50%,20% 16%,37% 12%)}
body{margin:0;background:#1a1712;font-family:"Friz Quadrata TT","Trebuchet MS",sans-serif;font-size:12px;color:#ebebeb;padding:20px}
.win{width:560px;background:rgba(10,10,13,.97);border:3px solid #8c7333;border-radius:8px;padding:12px 14px;box-shadow:0 0 20px #000}
.top{display:flex;justify-content:space-between;align-items:center}.title{color:#ffd100;font-size:17px}
.btn{display:inline-block;background:linear-gradient(#8e1414,#4d0a0a);border:1px solid #b88a2e;border-radius:3px;color:#ffd100;font-weight:normal;font-size:11px;text-align:center;padding:2px 6px;margin-left:2px;box-sizing:border-box}
.btn.sel{background:linear-gradient(#c22,#7a1010);color:#fff}.btn.sm{padding:1px 6px;min-width:22px}
.pick{margin:8px 0 10px;display:flex;align-items:center;gap:6px}.pick .who{width:200px;text-align:center}
.card{background:#0c0c0e;border:1px solid #3a3530;box-shadow:inset 0 0 8px #000;border-radius:3px;padding:8px 10px;margin-bottom:8px}
.bz{position:relative;width:820px;margin:30px 10px 40px 30px;background:#151413;border:6px solid;border-image:linear-gradient(#8a8a8a,#3e3e3e 30%,#6b6b6b 60%,#2d2d2d) 1;box-shadow:0 0 0 1px #000,0 6px 20px #000;padding:66px 10px 12px 10px;box-sizing:border-box}
.por{position:absolute;left:-22px;top:-22px;width:62px;height:62px;border-radius:50%;background:radial-gradient(circle at 40% 35%,#8a5a3a,#3a2214 70%);border:4px solid #7a7a7a;box-shadow:0 0 0 2px #222}
.ttl{position:absolute;top:0;left:0;right:0;height:22px;line-height:22px;text-align:center;color:#ffd100;font-size:13px;background:linear-gradient(#2e2b27,#1a1917);border-bottom:1px solid #000}
.x{position:absolute;right:2px;top:1px;width:20px;height:20px;border-radius:3px;background:linear-gradient(#a11,#500);color:#fc0;font-size:11px;text-align:center;line-height:20px;border:1px solid #b88a2e}
.bz .pick{position:absolute;top:30px;left:60px;margin:0}.inset{background:#0a0a0b;border:1px solid #2e2b28;box-shadow:inset 0 0 10px #000;padding:8px}
.tabs{position:absolute;left:12px;bottom:-31px;display:flex;gap:3px}.tab{background:linear-gradient(#3a3631,#1c1a18);border:2px solid #6b6255;border-top:none;border-radius:0 0 8px 8px;color:#ffd100;font-weight:normal;font-size:12px;padding:6px 16px 7px}.tab.on{background:linear-gradient(#1c1a18,#151413);color:#fff;margin-top:-3px;padding-top:9px}

.ch{display:flex;justify-content:space-between;color:#ffd100;font-size:13px;margin-bottom:6px}.ch span:last-child{font-size:11px}
.row{display:flex;align-items:center;height:20px;gap:4px}.row .l{flex:1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.row .r{text-align:right;font-size:11px;white-space:nowrap}
.note{color:#9e9e9e;font-size:11px;margin:2px 0 6px}
.bar{position:relative;height:14px;background:#262626;margin:2px 0 6px}.bar div{height:100%}.bar span{position:absolute;inset:0;text-align:center;font-size:10px;line-height:14px}
.inp{display:flex;align-items:center;gap:6px;margin:2px 0 6px}.lab{width:150px;color:#ffd100}.eb{flex:1;height:16px;border:1px solid #555;background:#000;border-radius:3px;padding:1px 5px;font-size:11px;overflow:hidden;white-space:nowrap}
.btns{margin:2px 0 6px}.epic{color:#a335ee}
.ic{display:inline-block;width:12px;height:12px;border-radius:50%;margin-right:5px;vertical-align:-2px}
.ic.ok{background:#3c3}.ic.ok::after{content:"✓";color:#000;font-size:9px;font-style:normal;display:block;text-align:center;line-height:12px}
.ic.bad{background:#d33}.ic.bad::after{content:"✕";color:#fff;font-size:8px;font-style:normal;display:block;text-align:center;line-height:12px}
.ic.warn{background:#e9a521}.ic.warn::after{content:"?";color:#000;font-size:9px;font-style:normal;display:block;text-align:center;line-height:12px}'''
tabs=['Ready','Gear','Lockouts','Prep','Settings']
import os
shots=[t for t in ops if not t.startswith('_')]
with sync_playwright() as p:
    b=p.chromium.launch(); pg=b.new_page(viewport={'width':900,'height':900},device_scale_factor=2)
    for t in shots:
        tb=''.join('<b class="btn%s">%s</b>'%(' sel' if x==t else '',x) for x in tabs)
        tb=''.join('<b class="tab%s">%s</b>'%(' on' if t.startswith(x) else '',x) for x in tabs)
        body='<div class="bz"><div class="por"></div><div class="ttl">Forever Warband Raiders</div><b class="x">✕</b><div class="pick"><b class="btn sm">&lt;</b><span class="who">Quail <span style="color:#9e9e9e">60 Warrior · Main</span></span><b class="btn sm">&gt;</b></div><div class="inset">%s</div><div class="tabs">%s</div></div>'%(''.join(draw(o) for o in ops[t]),tb)
        pg.set_content('<html><head><style>%s</style></head><body><div id="shot" style="display:inline-block;padding:4px 4px 44px 4px">%s</div></body></html>'%(CSS,body))
        pg.locator('#shot').screenshot(path='fwr-%s.png'%t.lower())
    b.close()
print('ok')
