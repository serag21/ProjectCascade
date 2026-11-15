#!/usr/bin/env python3
"""Draw the hand-authored reference sheets (creature silhouettes, loop anatomy) as SVG.
Usage: python3 design/fable/tools/mockups.py   (stdlib only; reads data/creatures.json for sizes/colours)"""
import json, math
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
C = json.loads((ROOT / "data/creatures.json").read_text())
INK = "#1b2440"; rgb = lambda c: "rgb(%d,%d,%d)" % tuple(c)

def face(cx, cy, s, look=0):
    """Shared face kit: two glossy ink eyes with a glint (no whites), matching data/models."""
    e = s * .17
    return (f'<ellipse cx="{cx-s*.2+look}" cy="{cy}" rx="{e*.72}" ry="{e}" fill="{INK}"/><ellipse cx="{cx+s*.2+look}" cy="{cy}" rx="{e*.72}" ry="{e}" fill="{INK}"/>'
            f'<circle cx="{cx-s*.2+look-e*.2}" cy="{cy-e*.35}" r="{e*.26}" fill="#fff"/><circle cx="{cx+s*.2+look-e*.2}" cy="{cy-e*.35}" r="{e*.26}" fill="#fff"/>')

def draw(sid, x, g, u, b, a):
    """x = centre, g = ground y, u = px per stud, b/a = body/accent colours."""
    st = f'stroke="{INK}" stroke-width="2" stroke-linejoin="round"'
    P = lambda pts: " ".join(f"{x+px*u:.1f},{g-py*u:.1f}" for px, py in pts)
    o = []
    if sid == "pip":
        o += [f'<ellipse cx="{x}" cy="{g-1.0*u}" rx="{1.1*u}" ry="{1.0*u}" fill="{b}" {st}/>',
              f'<ellipse cx="{x-.45*u}" cy="{g-2.05*u}" rx="{.5*u}" ry="{.22*u}" fill="{a}" {st} transform="rotate(-30 {x-.45*u} {g-2.05*u})"/>',
              f'<ellipse cx="{x+.45*u}" cy="{g-2.05*u}" rx="{.5*u}" ry="{.22*u}" fill="{a}" {st} transform="rotate(30 {x+.45*u} {g-2.05*u})"/>', face(x, g-1.05*u, 1.5*u)]
    elif sid == "bunvolt":
        o += [f'<polygon points="{P([(-.55,1.5),(-.9,3.6),(-.35,2.7),(-.5,3.3),(-.1,1.7)])}" fill="{a}" {st}/>', f'<polygon points="{P([(.55,1.5),(.9,3.6),(.35,2.7),(.5,3.3),(.1,1.7)])}" fill="{a}" {st}/>',
              f'<ellipse cx="{x}" cy="{g-.9*u}" rx="{.95*u}" ry="{.9*u}" fill="{b}" {st}/>', face(x, g-.95*u, 1.3*u)]
    elif sid == "cubloom":
        o += [f'<rect x="{x-1.3*u}" y="{g-2.0*u}" width="{2.6*u}" height="{2.0*u}" rx="{.55*u}" fill="{b}" {st}/>']
        for k in range(5):
            t = k * 1.2566; o.append(f'<circle cx="{x+math.cos(t)*.34*u}" cy="{g-2.2*u+math.sin(t)*.3*u}" r="{.26*u}" fill="{a}" {st}/>')
        o += [f'<circle cx="{x}" cy="{g-2.2*u}" r="{.18*u}" fill="#ffd95a" {st}/>', face(x, g-1.05*u, 1.7*u)]
    elif sid == "flutter":
        for sgn in (-1, 1):
            o.append(f'<path d="M{x+sgn*.5*u} {g-1.3*u} Q{x+sgn*2.9*u} {g-3.2*u} {x+sgn*2.8*u} {g-1.4*u} Q{x+sgn*2.4*u} {g-.2*u} {x+sgn*.5*u} {g-.9*u}z" fill="{b}" {st}/><circle cx="{x+sgn*1.9*u}" cy="{g-1.6*u}" r="{.38*u}" fill="{a}" {st}/>')
            o.append(f'<path d="M{x+sgn*.25*u} {g-1.9*u} q{sgn*.5*u} {-.9*u} {sgn*.9*u} {-.5*u}" fill="none" stroke="{INK}" stroke-width="2"/>')
        o += [f'<ellipse cx="{x}" cy="{g-1.1*u}" rx="{.7*u}" ry="{.85*u}" fill="{b}" {st}/>', face(x, g-1.2*u, 1.0*u)]
    elif sid == "sunshell":
        o += [f'<ellipse cx="{x+.45*u}" cy="{g-1.45*u}" rx="{1.45*u}" ry="{1.25*u}" fill="{a}" {st}/>',
              f'<path d="M{x+.45*u} {g-1.45*u} m{-.9*u} 0 a{.9*u} {.8*u} 0 1 1 {.9*u} {.8*u} a{.55*u} {.5*u} 0 1 1 {-.5*u} {-.55*u} a{.25*u} {.25*u} 0 1 1 {.3*u} {.2*u}" fill="none" stroke="{b}" stroke-width="3" stroke-linecap="round"/>',
              f'<ellipse cx="{x-1.0*u}" cy="{g-.65*u}" rx="{.75*u}" ry="{.65*u}" fill="{b}" {st}/>', face(x-1.05*u, g-.7*u, .95*u)]
    elif sid == "ziptail":
        for k, r in enumerate((.42, .32, .22)):
            o.append(f'<ellipse cx="{x+(.9+k*.75)*u}" cy="{g-(.75+k*.12)*u}" rx="{r*1.5*u}" ry="{r*u}" fill="{a if k%2==0 else b}" {st}/>')
        o += [f'<path d="M{x-.9*u} {g-.75*u} Q{x-.5*u} {g-1.9*u} {x+.6*u} {g-1.2*u} Q{x+.9*u} {g-.3*u} {x-.2*u} {g-.05*u} Q{x-.9*u} {g-.1*u} {x-.9*u} {g-.75*u}z" fill="{b}" {st}/>', face(x-.25*u, g-.95*u, 1.0*u, -2)]
    elif sid == "prickle":
        for px, py, dx, dy in ((0, 2.0, 0, .85), (-1.0, 1.2, -.85, 0), (1.0, 1.2, .85, 0), (0, .45, 0, -.4)):
            o.append(f'<polygon points="{P([(px-.22+dy*.0,py),(px+.22,py),(px+dx,py+dy)]) if dx==0 else P([(px,py-.22),(px,py+.22),(px+dx,py+dy)])}" fill="{a}" {st}/>')
        o += [f'<polygon points="{P([(0,2.2),(1.1,1.2),(0,.2),(-1.1,1.2)])}" fill="{b}" {st}/>', face(x, g-1.2*u, 1.2*u)]
    elif sid == "dunefin":
        o += [f'<polygon points="{P([(-.1,1.6),(.5,3.0),(.9,1.5)])}" fill="{a}" {st}/>',
              f'<path d="M{x-2.1*u} {g-.9*u} Q{x-1.0*u} {g-1.9*u} {x} {g-1.7*u} Q{x+1.0*u} {g-1.9*u} {x+2.1*u} {g-.9*u} Q{x+1.0*u} {g-.3*u} {x} {g-.25*u} Q{x-1.0*u} {g-.3*u} {x-2.1*u} {g-.9*u}z" fill="{b}" {st}/>', face(x, g-1.0*u, 1.3*u)]
    elif sid == "crownlet":
        o += [f'<polygon points="{P([(-.7,2.1),(-.7,2.9),(-.35,2.5),(0,3.0),(.35,2.5),(.7,2.9),(.7,2.1)])}" fill="{b}" {st}/>',
              f'<path d="M{x} {g-2.3*u} C{x+1.2*u} {g-2.2*u} {x+1.3*u} {g-.1*u} {x} {g-.1*u} C{x-1.3*u} {g-.1*u} {x-1.2*u} {g-2.2*u} {x} {g-2.3*u}z" fill="{b}" {st}/>',
              f'<ellipse cx="{x}" cy="{g-.55*u}" rx="{1.25*u}" ry="{.32*u}" fill="{a}" {st}/>', face(x, g-1.35*u, 1.25*u)]
    elif sid == "ribbubble":
        for sgn in (-1, 1):
            o.append(f'<path d="M{x+sgn*.3*u} {g-.9*u} q{sgn*.9*u} {.3*u} {sgn*.6*u} {.9*u} q{-sgn*.3*u} {.3*u} {sgn*.2*u} {.6*u}" fill="none" stroke="{b}" stroke-width="5" stroke-linecap="round"/>')
            o.append(f'<ellipse cx="{x+sgn*.75*u}" cy="{g-3.0*u}" rx="{.6*u}" ry="{.35*u}" fill="{b}" {st} transform="rotate({sgn*-25} {x+sgn*.75*u} {g-3.0*u})"/>')
        o += [f'<circle cx="{x}" cy="{g-2.0*u}" r="{1.15*u}" fill="{a}" fill-opacity=".75" {st}/>', f'<path d="M{x-.7*u} {g-2.5*u} q{.2*u} {-.5*u} {.6*u} {-.5*u}" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round"/>', face(x, g-1.95*u, 1.3*u)]
    elif sid == "starwhirl":
        pts = []
        for k in range(10):
            r = 1.5 if k % 2 == 0 else .7; t = -math.pi/2 + k * math.pi / 5 + .25
            pts.append((math.cos(t) * r, 1.5 - math.sin(t) * r))
        o += [f'<polygon points="{P(pts)}" fill="{b}" {st}/>', f'<circle cx="{x}" cy="{g-1.5*u}" r="{.72*u}" fill="{a}" {st}/>', face(x, g-1.5*u, .95*u)]
    elif sid == "antlume":
        for sgn in (-1, 1):
            o.append(f'<path d="M{x+sgn*.35*u-.9*u} {g-3.3*u} l{sgn*.5*u} {-1.2*u} l{sgn*.7*u} {-.3*u} M{x+sgn*.6*u-.9*u} {g-4.0*u} l{-sgn*.1*u} {-.9*u} M{x+sgn*.85*u-.9*u} {g-4.5*u} l{sgn*.5*u} {-.6*u}" fill="none" stroke="{a}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>')
        for lx in (-.9, -.4, .7, 1.2):
            o.append(f'<rect x="{x+lx*u-.14*u}" y="{g-1.4*u}" width="{.28*u}" height="{1.4*u}" rx="3" fill="{b}" {st}/>')
        o += [f'<ellipse cx="{x+.2*u}" cy="{g-1.9*u}" rx="{1.5*u}" ry="{.8*u}" fill="{b}" {st}/>',
              f'<path d="M{x-.6*u} {g-2.1*u} L{x-.9*u} {g-3.0*u}" stroke="{b}" stroke-width="{.7*u}" stroke-linecap="round"/>',
              f'<ellipse cx="{x-.95*u}" cy="{g-3.1*u}" rx="{.62*u}" ry="{.52*u}" fill="{b}" {st}/>', face(x-.98*u, g-3.1*u, .8*u, -2)]
    return "".join(o)

def silhouettes():
    u, cw, ch = 19, 250, 240
    cu = u * 1.3   # creatures are drawn at tuning.creatures.globalScale
    W, H = cw * 4 + 40, ch * 3 + 110
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" font-family="Verdana,sans-serif">', f'<rect width="{W}" height="{H}" fill="#fbf7ea"/>',
         f'<text x="20" y="34" font-size="22" font-weight="bold" fill="{INK}">SPARK SILHOUETTE SHEET — one scale, one face kit, twelve unmistakable outlines</text>',
         f'<text x="20" y="54" font-size="12" fill="{INK}">Grey figure = player (5 studs). Black shape = the silhouette test: each species must be identifiable from this alone at 60 studs. Generated by tools/mockups.py from data/creatures.json.</text>']
    names = {1: "POP MEADOW", 2: "FIZZ CANYON", 3: "AURORA ARCADE"}
    for i, s in enumerate(C["species"]):
        col, row = i % 4, i // 4
        x0, y0 = 20 + col * cw, 70 + row * ch; g = y0 + ch - 62; cx = x0 + cw * .44
        o.append(f'<rect x="{x0+4}" y="{y0+4}" width="{cw-8}" height="{ch-8}" rx="14" fill="#fff" stroke="{INK}" stroke-opacity=".15"/>')
        o.append(f'<line x1="{x0+14}" y1="{g}" x2="{x0+cw-14}" y2="{g}" stroke="{INK}" stroke-opacity=".3"/>')
        px = x0 + cw - 34
        o.append(f'<g fill="{INK}" fill-opacity=".16"><circle cx="{px}" cy="{g-4.4*u}" r="{.6*u}"/><rect x="{px-.7*u}" y="{g-3.8*u}" width="{1.4*u}" height="{2.0*u}" rx="4"/><rect x="{px-.6*u}" y="{g-1.8*u}" width="{.5*u}" height="{1.8*u}"/><rect x="{px+.1*u}" y="{g-1.8*u}" width="{.5*u}" height="{1.8*u}"/></g>')
        o.append(draw(s["id"], cx, g, cu, rgb(s["palette"]["body"]), rgb(s["palette"]["accent"])))
        mini = draw(s["id"], 0, 0, 7, INK, INK).replace('fill="#fff"', f'fill="{INK}"').replace('stroke="#fff"', f'stroke="{INK}"').replace('fill="#ffd95a"', f'fill="{INK}"')
        o.append(f'<g transform="translate({x0+34},{y0+62})">{mini}</g>')
        o.append(f'<text x="{x0+16}" y="{g+20}" font-size="14" font-weight="bold" fill="{INK}">{s["name"]}</text><text x="{x0+cw-16}" y="{g+20}" font-size="10" text-anchor="end" fill="{INK}">{s["rarity"]} · {s["value"]} pts</text>')
        o.append(f'<text x="{x0+16}" y="{g+36}" font-size="10" fill="{INK}">{s["behavior"].upper()} — {s["silhouette"]["read"][:36]}</text>')
        o.append(f'<text x="{x0+16}" y="{g+50}" font-size="9" fill="{INK}" fill-opacity=".7">{names[s["biome"]]} · {s["silhouette"]["height"]}h × {s["silhouette"]["width"]}w studs · ≤{s["silhouette"]["parts"]} parts</text>')
    o.append("</svg>")
    (ROOT / "mockups/creature_silhouettes.svg").write_text("\n".join(o))

def loop_anatomy():
    W, H = 1180, 560
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" font-family="Verdana,sans-serif">', f'<rect width="{W}" height="{H}" fill="#fbf7ea"/>',
         f'<text x="20" y="34" font-size="22" font-weight="bold" fill="{INK}">LOOP ANATOMY — the one verb: run a ring around them</text>']
    def panel(i, title, sub):
        x = 20 + i * 290
        o.append(f'<rect x="{x}" y="56" width="270" height="420" rx="16" fill="#6cd68e"/><rect x="{x}" y="476" width="270" height="64" rx="0" fill="#fbf7ea"/>')
        o.append(f'<text x="{x+8}" y="500" font-size="15" font-weight="bold" fill="{INK}">{i+1}. {title}</text>')
        for k, line in enumerate(sub): o.append(f'<text x="{x+8}" y="{518+k*14}" font-size="10.5" fill="{INK}">{line}</text>')
        return x
    def spark(cx, cy, c="#ffd241", r=11): o.append(f'<ellipse cx="{cx}" cy="{cy}" rx="{r}" ry="{r*1.1}" fill="{c}" stroke="{INK}" stroke-width="1.6"/><circle cx="{cx-3.5}" cy="{cy-1}" r="2" fill="{INK}"/><circle cx="{cx+3.5}" cy="{cy-1}" r="2" fill="{INK}"/>')
    def player(cx, cy): o.append(f'<circle cx="{cx}" cy="{cy}" r="10" fill="#fff" stroke="{INK}" stroke-width="2.5"/><circle cx="{cx}" cy="{cy}" r="4" fill="#3d74d9"/>')
    x = panel(0, "DRAW", ["Your ribbon is always on: 4.2 s / 100 studs.", "Sparks shy away from you and bunch up."])
    o.append(f'<path d="M{x+60} 400 C{x+20} 330 {x+30} 220 {x+110} 180" fill="none" stroke="#fff36b" stroke-width="9" stroke-linecap="round"/><path d="M{x+60} 400 l-6 26" stroke="#fff36b" stroke-width="9" stroke-opacity=".35" stroke-linecap="round"/>')
    for cx, cy in ((150, 270), (176, 300), (140, 310)): spark(x + cx, cy); o.append(f'<path d="M{x+cx+14} {cy+4} l14 6" stroke="{INK}" stroke-width="1.5" stroke-dasharray="3 3"/>')
    player(x + 110, 180)
    x = panel(1, "CLOSE (or SNAP)", ["Cross your own ribbon, or get within 4.5 studs", "and it snaps shut. Dash to close = SNAP bonus."])
    o.append(f'<path d="M{x+60} 400 C{x+10} 300 {x+50} 150 {x+150} 160 C{x+250} 170 {x+250} 330 {x+190} 380 C{x+160} 405 {x+120} 410 {x+92} 404" fill="none" stroke="#fff36b" stroke-width="9" stroke-linecap="round"/>')
    o.append(f'<path d="M{x+92} 404 L{x+60} 400" stroke="#fff" stroke-width="4" stroke-dasharray="6 5"/><circle cx="{x+60}" cy="400" r="36" fill="none" stroke="#fff" stroke-dasharray="4 5" stroke-opacity=".8"/><text x="{x+20}" y="452" font-size="10" fill="{INK}">snap radius</text>')
    for cx, cy in ((140, 270), (162, 292), (136, 300)): spark(x + cx, cy)
    spark(x + 170, 250, "#ff84b1"); player(x + 92, 404)
    x = panel(2, "CINCH", ["0.30 s: the ring tightens, Sparks pop one by one", "on a rising scale. (Hides the server round trip.)"])
    o.append(f'<ellipse cx="{x+146}" cy="282" rx="52" ry="46" fill="#fff36b" fill-opacity=".25" stroke="#fff36b" stroke-width="9"/><ellipse cx="{x+146}" cy="282" rx="98" ry="110" fill="none" stroke="#fff36b" stroke-width="3" stroke-opacity=".5" stroke-dasharray="3 9"/>')
    for k, (cx, cy) in enumerate(((132, 276), (156, 286), (140, 296), (160, 266))): spark(x + cx, cy, "#ff84b1" if k == 3 else "#ffd241", 9)
    for a in range(0, 360, 45): o.append(f'<line x1="{x+146+math.cos(math.radians(a))*112}" y1="{282+math.sin(math.radians(a))*124}" x2="{x+146+math.cos(math.radians(a))*74}" y2="{282+math.sin(math.radians(a))*74}" stroke="#fff" stroke-width="2.5" stroke-linecap="round"/>')
    x = panel(3, "PAYOUT + PARADE", ["Score and technique tags appear in the world.", "Caught Sparks follow you until you run a bank ring."])
    o.append(f'<text x="{x+140}" y="200" font-size="40" font-weight="bold" text-anchor="middle" fill="#fff" stroke="{INK}" stroke-width="5" paint-order="stroke">+86</text><text x="{x+140}" y="228" font-size="15" font-weight="bold" text-anchor="middle" fill="#fff36b" stroke="{INK}" stroke-width="3.5" paint-order="stroke">SNAP · MEDLEY · x2</text>')
    player(x + 190, 300)
    for k in range(4): spark(x + 160 - k * 28, 318 + k * 16, "#ff84b1" if k == 1 else "#ffd241", 9)
    o.append(f'<ellipse cx="{x+215}" cy="390" rx="14" ry="40" fill="none" stroke="#ffcf2e" stroke-width="8"/><text x="{x+215}" y="448" font-size="11" font-weight="bold" text-anchor="middle" fill="{INK}">BANK RING</text><path d="M{x+192} 312 Q{x+205} 350 {x+212} 380" fill="none" stroke="{INK}" stroke-width="1.5" stroke-dasharray="4 4"/>')
    o.append("</svg>")
    (ROOT / "mockups/loop_anatomy.svg").write_text("\n".join(o))

silhouettes(); loop_anatomy(); print("mockups written")
