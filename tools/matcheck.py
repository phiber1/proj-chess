import re, sys, os

VAL = {'p':100,'n':320,'b':330,'r':500,'q':900,'k':0}
def start_board():
    b={}
    back='rnbqkbnr'
    for f,c in enumerate(back):
        b[(f,7)]=c; b[(f,0)]=c.upper()
    for f in range(8):
        b[(f,6)]='p'; b[(f,1)]='P'
    return b
def sq(s): return (ord(s[0])-97, int(s[1])-1)
def apply(b,mv):
    fr=sq(mv[0:2]); to=sq(mv[2:4]); promo=mv[4] if len(mv)>4 else None
    p=b.pop(fr,None)
    if p is None: return
    # en passant
    if p in 'Pp' and fr[0]!=to[0] and to not in b:
        b.pop((to[0],fr[1]),None)
    # castling
    if p in 'Kk' and abs(fr[0]-to[0])==2:
        rk=fr[1]
        if to[0]==6: r=b.pop((7,rk),None); b[(5,rk)]=r
        elif to[0]==2: r=b.pop((0,rk),None); b[(3,rk)]=r
    b[to]=p
    if promo:
        b[to]= promo.upper() if p.isupper() else promo.lower()
def material(b):
    w=sum(VAL[v.lower()] for v in b.values() if v.isupper())
    bl=sum(VAL[v.lower()] for v in b.values() if v.islower())
    return w-bl

def analyze(path):
    if not os.path.exists(path):
        print(f"--- {path}: NOT FOUND ---"); return
    moves=None; rows=[]
    posre=re.compile(r"position startpos(?: moves (.*?))?'")
    evre=re.compile(r"info depth 5 score cp (-?\d+)")
    for line in open(path,errors='replace'):
        m=posre.search(line)
        if m: moves=(m.group(1) or '').split()
        e=evre.search(line)
        if e and moves is not None:
            b=start_board()
            for mv in moves: apply(b,mv)
            rows.append((len(rows)+1, int(e.group(1)), material(b)))
    if not rows:
        print(f"--- {path}: no d5 searches parsed ---"); return
    print(f"=== {path}  ({len(rows)} ELPH searches, ELPH=White) ===")
    print(" mv | eval  | material | positional(eval-mat)")
    # downsample to <=28 rows but always include peak & first-loss
    peak=max(rows,key=lambda r:r[1])
    firstloss=next((r for r in rows if r[2]<=-150), None)
    step=max(1,len(rows)//24)
    show={r[0] for i,r in enumerate(rows) if i%step==0}
    show.add(peak[0])
    if firstloss: show.add(firstloss[0])
    for mv,ev,mat in rows:
        if mv in show:
            tag=''
            if (mv,ev,mat)==peak: tag=' <- PEAK eval'
            if firstloss and mv==firstloss[0]: tag=' <- material first <= -150'
            print(f"{mv:3d} | {ev:5d} | {mat:6d}   | {ev-mat:6d}{tag}")
    # verdict
    delu=[r for r in rows if r[1]>=150 and r[2]<=50]   # eval winning-ish, material even-or-behind
    print(f"  VERDICT: peak eval +{peak[1]} at mv{peak[0]} (material {peak[2]:+d}, positional {peak[1]-peak[2]:+d})")
    if firstloss:
        print(f"           material first <= -150 at mv{firstloss[0]} (eval there {firstloss[1]:+d})")
    print(f"           'delusion' searches (eval>=+150 while material<=+50): {len(delu)}")
    if delu:
        avgp=sum(r[1]-r[2] for r in delu)//len(delu)
        avgm=sum(r[2] for r in delu)//len(delu)
        print(f"           ...avg material {avgm:+d}, avg positional inflation {avgp:+d}")
    print()

for p in sys.argv[1:]:
    analyze(p)
