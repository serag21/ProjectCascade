#!/usr/bin/env python3
"""Validate design/fable data for internal consistency and render the arena maps.

Usage (from the repository root):  python3 design/fable/tools/validate.py [--no-render]
Exit code 0 = consistent. Stdlib only. Never touches game/.
"""
import json, math, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
DATA = ROOT / "data"
errors, notes = [], []
def err(msg): errors.append(msg)
def load(name): return json.loads((DATA / name).read_text())

tuning, creatures, events = load("tuning.json"), load("creatures.json"), load("events.json")
audio, ui, assets, wps = load("audio_events.json"), load("ui_layout.json"), load("asset_manifest.json"), load("work_packages.json")
arenas = {p.stem: json.loads(p.read_text()) for p in sorted((DATA / "arenas").glob("*.json"))}

# ---------- geometry ----------
def pip(pt, poly):
    x, z = pt; inside = False
    for i in range(len(poly)):
        (x1, z1), (x2, z2) = poly[i], poly[(i + 1) % len(poly)]
        if (z1 > z) != (z2 > z) and x < (x2 - x1) * (z - z1) / (z2 - z1) + x1: inside = not inside
    return inside
def seg_dist(p, a, b):
    (px, pz), (ax, az), (bx, bz) = p, a, b
    dx, dz = bx - ax, bz - az; l2 = dx * dx + dz * dz
    t = 0 if l2 == 0 else max(0, min(1, ((px - ax) * dx + (pz - az) * dz) / l2))
    return math.hypot(px - (ax + dx * t), pz - (az + dz * t))
def poly_dist(p, pts, closed):
    n = len(pts); rng = range(n if closed else n - 1)
    return min(seg_dist(p, pts[i], pts[(i + 1) % n]) for i in rng)
def seg_seg_dist(a, b, c, d):
    # sampled; adequate for 1-stud design tolerances
    best = 1e9
    for i in range(41):
        t = i / 40; p = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
        best = min(best, seg_dist(p, c, d))
    return best
def blocker_clearance(p, f):
    """Distance from point p to the edge of blocking feature f (negative = inside)."""
    if "points" in f:
        half = f.get("width", 2) / 2
        return poly_dist(p, f["points"], False) - half
    if "rx" in f:
        dx, dz = p[0] - f["x"], p[1] - f["z"]
        k = math.hypot(dx / f["rx"], dz / f["rz"])
        return (k - 1) * min(f["rx"], f["rz"])
    return math.hypot(p[0] - f["x"], p[1] - f["z"]) - f["r"]
def blocks(f): return f.get("solid") or f.get("creatureBlock")

# ---------- creatures vs live Config ----------
cfg = (REPO / "game/ReplicatedStorage/Spark/Config.luau").read_text()
live = {}
for m in re.finditer(r'\{id="(\w+)", name="([^"]+)", shape="\w+", color=\{(\d+),(\d+),(\d+)\}, value=(\d+), speed=\d+, behavior="\w+", signature="(\w+)", biome=(\d), rarity="(\w+)"', cfg):
    live[m.group(1)] = dict(name=m.group(2), color=[int(m.group(i)) for i in (3, 4, 5)], value=int(m.group(6)), signature=m.group(7), biome=int(m.group(8)), rarity=m.group(9))
species = {s["id"]: s for s in creatures["species"]}
if len(live) != 12: err(f"expected 12 live Config creatures, parsed {len(live)}")
if set(live) != set(species): err(f"species ids differ from Config: {set(live) ^ set(species)}")
for sid, l in live.items():
    s = species.get(sid)
    if not s: continue
    for k in ("name", "value", "signature", "biome", "rarity"):
        if s[k] != l[k]: err(f"{sid}.{k} = {s[k]!r} differs from Config {l[k]!r} (save/album compatibility)")
    if s["palette"]["body"] != l["color"]: err(f"{sid} body colour differs from Config")
    if s["silhouette"]["parts"] > tuning["performance"]["creaturePartsMax"]["value"]: err(f"{sid} exceeds creature part budget")
    if s["signature"] not in creatures["signatureRemap"]: err(f"{sid} signature not remapped")
    if s["speed"].get("flee", 0) >= tuning["movement"]["walkSpeed"]["value"] and s["behavior"] not in ("runner",):
        err(f"{sid} flee speed >= walk speed: cannot be circled")
for l in creatures["legends"]:
    if l["silhouette"]["parts"] > tuning["performance"]["creaturePartsMax"]["value"]: err(f"legend {l['id']} part budget")
model_ids = set(assets["creatureModels"]["ids"])
for cid in list(species) + [l["id"] for l in creatures["legends"]] + [h["id"] for h in creatures["hazards"]]:
    if cid not in model_ids: err(f"asset manifest lacks creature model {cid}")

# ---------- arenas ----------
builders = {b["type"] for b in assets["featureBuilders"]}
cap = tuning["density"]["baseLiveCapPerArena"]["value"]
min_sep = tuning["density"]["minPodSeparation"]["value"]
for aid, a in arenas.items():
    B = a["bounds"]; tag = f"[{aid}]"
    ids = set()
    def uid(i):
        if i in ids: err(f"{tag} duplicate id {i}")
        ids.add(i)
    feats = {f["id"]: f for f in a["features"]}
    for f in a["features"]:
        uid(f["id"])
        if f["type"] not in builders: err(f"{tag} feature type {f['type']} has no builder in asset_manifest")
        pts = f.get("points") or [[f["x"], f["z"]]]
        for p in pts:
            if not pip(p, B): err(f"{tag} feature {f['id']} point {p} outside bounds")
        if "points" not in f:
            r = max(f.get("r", 0), f.get("rx", 0), f.get("rz", 0))
            if poly_dist((f["x"], f["z"]), B, True) < min(r, 6) - 0.01 and f["type"] != "records_board":
                err(f"{tag} feature {f['id']} overlaps the boundary")
    elev = {e["id"]: e for e in a["elevation"]}
    for e in a["elevation"]:
        uid(e["id"])
        for p in e.get("poly", []) + ([[e["x"], e["z"]]] if "x" in e else []) + ([e["from"], e["to"]] if "from" in e else []):
            if not pip(p, B): err(f"{tag} elevation {e['id']} point {p} outside bounds")
    def ground_y(p):
        y = 0
        for e in a["elevation"]:
            if e["type"] != "plateau": continue
            inside = pip(p, e["poly"]) if "poly" in e else math.hypot(p[0] - e["x"], p[1] - e["z"]) <= e["r"]
            if inside: y = max(y, e["y"])
        return y
    blockers = [f for f in a["features"] if blocks(f)]
    sp = (a["spawn"]["x"], a["spawn"]["z"])
    if not pip(sp, B): err(f"{tag} spawn outside bounds")
    for f in blockers:
        if blocker_clearance(sp, f) < 6: err(f"{tag} spawn too close to {f['id']}")
    routes = {r["id"]: r for r in a["routes"]}
    for r in a["routes"]:
        uid(r["id"])
        n = len(r["points"]); closed = r.get("closed", False)
        for p in r["points"]:
            if not pip(p, B): err(f"{tag} route {r['id']} point {p} outside bounds")
        for i in range(n if closed else n - 1):
            p, q = r["points"][i], r["points"][(i + 1) % n]
            for f in blockers:
                if f["type"] in ("cliff_line",) and r["kind"] in ("wind",): continue
                if "points" in f:
                    fp = f["points"]
                    d = min(seg_seg_dist(p, q, fp[j], fp[j + 1]) for j in range(len(fp) - 1)) - f.get("width", 2) / 2
                else:
                    d = min(blocker_clearance((p[0] + (q[0] - p[0]) * t / 20, p[1] + (q[1] - p[1]) * t / 20), f) for t in range(21))
                if d < 3: err(f"{tag} route {r['id']} segment {i} within {d:.1f} of blocker {f['id']} (need 3)")
        for rs in r.get("restStones", []):
            if rs not in feats: err(f"{tag} route {r['id']} rest stone {rs} missing")
            elif poly_dist((feats[rs]["x"], feats[rs]["z"]), r["points"], closed) > 3: err(f"{tag} rest stone {rs} not on route")
    rings = a["bankRings"]
    for i, b in enumerate(rings):
        uid(b["id"]); p = (b["x"], b["z"])
        if not pip(p, B) or poly_dist(p, B, True) < b["r"] + 2: err(f"{tag} bank ring {b['id']} outside/too near boundary")
        if ground_y(p) != b.get("y", 0): err(f"{tag} bank ring {b['id']} y {b.get('y',0)} != ground {ground_y(p)}")
        for f in blockers:
            if blocker_clearance(p, f) < b["r"] + 2: err(f"{tag} bank ring {b['id']} too close to {f['id']}")
        for c in rings[i + 1:]:
            if math.hypot(b["x"] - c["x"], b["z"] - c["z"]) < 40: err(f"{tag} bank rings {b['id']}/{c['id']} closer than 40")
        for r in a["routes"]:
            if r["kind"] == "stampede" and poly_dist(p, r["points"], False) < b["r"] + 3: err(f"{tag} stampede route {r['id']} crosses bank ring {b['id']}")
    for r in a["routes"]:
        if r["kind"] == "stampede" and poly_dist(sp, r["points"], False) < 12: err(f"{tag} stampede route {r['id']} too close to spawn")
    habs = {h["id"]: h for h in a["habitats"]}
    for h in a["habitats"]:
        uid(h["id"])
        if "route" in h:
            if h["route"] not in routes: err(f"{tag} habitat {h['id']} route missing")
            continue
        p = (h["x"], h["z"])
        if not pip(p, B) or poly_dist(p, B, True) < h["r"]: err(f"{tag} habitat {h['id']} leaves bounds")
        if ground_y(p) != h.get("y", 0): err(f"{tag} habitat {h['id']} y {h.get('y',0)} != ground {ground_y(p)}")
        allowed = set(h.get("around", [])) | ({h["on"]} if "on" in h else set())
        for f in blockers:
            if f["id"] in allowed: continue
            if blocker_clearance(p, f) < 3: err(f"{tag} habitat {h['id']} centre within 3 of blocker {f['id']}")
        for b in rings:
            if math.hypot(p[0] - b["x"], p[1] - b["z"]) < h["r"] + b["r"]: err(f"{tag} habitat {h['id']} overlaps bank ring {b['id']}")
    hl = [h for h in a["habitats"] if "x" in h]
    for i, h in enumerate(hl):
        for g in hl[i + 1:]:
            if math.hypot(h["x"] - g["x"], h["z"] - g["z"]) < min_sep: err(f"{tag} habitats {h['id']}/{g['id']} closer than {min_sep}")
    total = 0; seen_species = set()
    for pod in a["pods"]:
        s = species.get(pod["species"]); h = habs.get(pod["habitat"])
        if not s or not h: err(f"{tag} pod {pod} references unknown species/habitat"); continue
        if s["biome"] != a["biomeIndex"]: err(f"{tag} pod species {s['id']} belongs to biome {s['biome']}")
        if h["kind"] not in s["pod"]["habitats"]: err(f"{tag} {s['id']} not allowed in habitat kind {h['kind']}")
        lo, hi = s["pod"]["size"]
        if not lo <= pod["count"] <= hi: err(f"{tag} pod count {pod['count']} outside {s['id']} pod size")
        total += pod["count"]; seen_species.add(s["id"])
    if total > cap: err(f"{tag} base live creatures {total} > cap {cap}")
    want = {sid for sid, s in species.items() if s["biome"] == a["biomeIndex"]}
    if seen_species != want: err(f"{tag} species without a pod: {want - seen_species}")
    for sh in a.get("spareHabitats", []):
        if sh not in habs: err(f"{tag} spare habitat {sh} missing")
    for ea in a["eventAnchors"]:
        uid(ea["id"])
        if "feature" in ea and ea["feature"] not in feats: err(f"{tag} event anchor {ea['id']} feature missing")
        if "x" in ea and not pip((ea["x"], ea["z"]), B): err(f"{tag} event anchor {ea['id']} outside bounds")
        if ea["event"] not in {e["id"] for e in events["events"]}: err(f"{tag} event anchor {ea['id']} unknown event")
    if sum(1 for r in a["routes"] if r["kind"] == "stampede") != 2: err(f"{tag} needs exactly 2 stampede routes")
    if sum(1 for r in a["routes"] if r["kind"] in ("legend", "run")) < 1: err(f"{tag} needs a legend route")
    notes.append(f"{aid}: {len(a['features'])} features, {len(hl)} habitats, {total}/{cap} base creatures, bounds {max(p[0] for p in B)-min(p[0] for p in B)}x{max(p[1] for p in B)-min(p[1] for p in B)} studs")

# ---------- events ----------
starts = tuning["round"]["phaseStarts"]["value"]
if [b["start"] for b in events["roundBeats"]] != starts: err("roundBeats do not match tuning.round.phaseStarts")
biomes = {a["biomeIndex"] for a in arenas.values()}
for e in events["events"]:
    if not e["telegraphAt"] < e["start"]: err(f"event {e['id']} telegraph not before start")
    if e["start"] - e["telegraphAt"] < 2: err(f"event {e['id']} telegraph shorter than 2s")
    if e["start"] + e["duration"] > 110 and e["id"] != "legend": err(f"event {e['id']} runs past the round")
    if not set(e["arenas"]) <= biomes: err(f"event {e['id']} unknown arena")
for a in arenas.values():
    sig = [e for e in events["events"] if e["start"] == 30 and a["biomeIndex"] in e["arenas"]]
    if len(sig) != 1: err(f"[{a['id']}] needs exactly one signature event at t=30")
    elif not any(x["event"] == sig[0]["id"] for x in a["eventAnchors"]): err(f"[{a['id']}] no anchors for {sig[0]['id']}")

# ---------- audio ----------
aids = [s["id"] for s in audio["sfx"]]
if len(aids) != len(set(aids)): err("duplicate audio ids")
for s in audio["sfx"]:
    if not 0 < s["volume"] <= 1: err(f"audio {s['id']} volume")
    if "desc" not in s and "existing" not in s: err(f"audio {s['id']} needs desc or existing")
if set(audio["creatureVoices"]) - {"_rule"} != set(species): err("creatureVoices must cover exactly the 12 species")
if set(audio["music"]["arenas"]) != set(arenas): err("music arenas mismatch")
for st in audio["music"]["stems"]:
    if st["enters"] not in starts + [49]: err(f"music stem {st['id']} does not enter on a round beat")

# ---------- ui ----------
def overlap(a, b): return a[0] < b[0] + b[2] and b[0] < a[0] + a[2] and a[1] < b[1] + b[3] and b[1] < a[1] + a[3]
el = {e["id"]: e for e in ui["elements"]}
for vn, v in ui["viewports"].items():
    W, H = v["size"]; rects = v["rects"]; area = 0; tarea = 0
    for k, r in rects.items():
        if k not in el: err(f"ui {vn}: unknown element {k}")
        if r[0] < 0 or r[1] < 0 or r[0] + r[2] > W or r[1] + r[3] > H: err(f"ui {vn}: {k} outside viewport")
        if el.get(k, {}).get("transient"): tarea += r[2] * r[3]
        else: area += r[2] * r[3]
    items = list(rects.items()) + [("reserved:" + k, r) for k, r in v["reserved"].items()]
    for i, (k1, r1) in enumerate(items):
        for k2, r2 in items[i + 1:]:
            if overlap(r1, r2): err(f"ui {vn}: {k1} overlaps {k2}")
    cov = area / (W * H)
    if cov > ui["rules"]["maxCoverage"]: err(f"ui {vn}: coverage {cov:.3f} > {ui['rules']['maxCoverage']}")
    if tarea / (W * H) > ui["rules"]["maxTransientCoverage"]: err(f"ui {vn}: transient coverage {tarea/(W*H):.3f} too high")
    touch = "dashButton" in rects
    for e in ui["elements"]:
        need = (e["input"] == "all") or (touch and "touch" in e["input"]) or (not touch and "keyboard" in e["input"])
        if need and e["id"] not in rects: err(f"ui {vn}: missing {e['id']}")
    notes.append(f"ui {vn}: persistent coverage {cov*100:.1f}%, transient +{tarea/(W*H)*100:.1f}%")

# ---------- assets / vfx ----------
vfx_total = sum(v["budgetParts"] for v in assets["vfx"])
if vfx_total > assets["vfxBudgetCheck"]["maxLocalEffectParts"]: err(f"vfx parts {vfx_total} > budget")
notes.append(f"vfx worst-case local effect parts: {vfx_total}/{assets['vfxBudgetCheck']['maxLocalEffectParts']}")
used = {f["type"] for a in arenas.values() for f in a["features"]} | {"bank_ring"}
for b in builders - used: err(f"feature builder {b} unused")

# ---------- work packages ----------
wp = {p["id"]: p for p in wps["packages"]}
if len(wp) != len(wps["packages"]): err("duplicate work package id")
for p in wps["packages"]:
    for d in p["deps"]:
        if d not in wp: err(f"{p['id']} dep {d} missing")
        elif wp[d]["stage"] > p["stage"]: err(f"{p['id']} depends on later-stage {d}")
        elif int(d[3:]) >= int(p["id"][3:]): err(f"{p['id']} dep {d} is not earlier (cycle risk)")
    if p["agent"] not in ("opus", "sonnet"): err(f"{p['id']} agent")
    if not p["accept"]: err(f"{p['id']} has no acceptance criteria")

# ---------- render maps ----------
def render(a):
    S = 4; B = a["bounds"]; pal = a["palette"]
    minx, maxx = min(p[0] for p in B) - 10, max(p[0] for p in B) + 10
    minz, maxz = min(p[1] for p in B) - 10, max(p[1] for p in B) + 14
    W, H = (maxx - minx) * S, (maxz - minz) * S
    X = lambda x: (x - minx) * S; Z = lambda z: (z - minz) * S
    rgb = lambda c: "rgb(%d,%d,%d)" % tuple(c)
    pts = lambda ps: " ".join(f"{X(x):.0f},{Z(z):.0f}" for x, z in ps)
    night = a["lighting"]["clockTime"] < 5
    ink = "#f4f1ff" if night else "#1b2440"
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H+70}" width="{W}" height="{H+70}" font-family="Verdana,sans-serif">',
         f'<rect width="{W}" height="{H+70}" fill="{"#191a3a" if night else "#f7f3e6"}"/>',
         f'<polygon points="{pts(B)}" fill="{rgb(pal["ground"])}" stroke="{rgb(pal["groundDark"])}" stroke-width="6" stroke-linejoin="round"/>']
    for gx in range(int(minx // 20 * 20), int(maxx) + 1, 20):
        o.append(f'<line x1="{X(gx)}" y1="0" x2="{X(gx)}" y2="{H}" stroke="{ink}" stroke-opacity=".08"/><text x="{X(gx)+2}" y="{H-3}" font-size="9" fill="{ink}" fill-opacity=".5">{gx}</text>')
    for gz in range(int(minz // 20 * 20), int(maxz) + 1, 20):
        o.append(f'<line x1="0" y1="{Z(gz)}" x2="{W}" y2="{Z(gz)}" stroke="{ink}" stroke-opacity=".08"/><text x="2" y="{Z(gz)-2}" font-size="9" fill="{ink}" fill-opacity=".5">{gz}</text>')
    lab = lambda x, z, t, size=10, w="normal", col=None: o.append(f'<text x="{X(x):.0f}" y="{Z(z):.0f}" font-size="{size}" font-weight="{w}" text-anchor="middle" fill="{col or ink}" stroke="{"#191a3a" if night else "#fff"}" stroke-width="2.5" paint-order="stroke">{t}</text>')
    for e in a["elevation"]:
        fill = rgb(pal["path"])
        if "poly" in e: o.append(f'<polygon points="{pts(e["poly"])}" fill="{fill}" fill-opacity=".75" stroke="{rgb(pal["wall"])}" stroke-width="3"/>')
        elif "from" in e:
            o.append(f'<line x1="{X(e["from"][0])}" y1="{Z(e["from"][1])}" x2="{X(e["to"][0])}" y2="{Z(e["to"][1])}" stroke="{rgb(pal["wall"])}" stroke-width="{e["width"]*S}" stroke-opacity=".85"/>')
        else:
            o.append(f'<circle cx="{X(e["x"])}" cy="{Z(e["z"])}" r="{e["r"]*S}" fill="{fill}" fill-opacity="{.75 if e["type"]=="plateau" else .35}" stroke="{rgb(pal["groundDark"])}" stroke-dasharray="{"0" if e["type"]=="plateau" else "6 5"}" stroke-width="2"/>')
        for rp in e.get("ramps", []):
            o.append(f'<line x1="{X(rp["from"][0])}" y1="{Z(rp["from"][1])}" x2="{X(rp["to"][0])}" y2="{Z(rp["to"][1])}" stroke="{rgb(pal["path"])}" stroke-width="{rp["width"]*S}"/>')
            lab(rp["from"][0], rp["from"][1] + 4, "ramp", 8)
    wind = [r for r in a["routes"] if r["kind"] == "wind"]
    for f in a["features"]:
        t = f["type"]; col = rgb(pal["wall"])
        if t in ("water", "water_band", "ice"): col = rgb(pal["water"])
        if t in ("bloom_bud", "geyser", "perch_flower", "lake_marker", "rest_stone", "bounce_ring", "mound"): col = rgb(pal["accent"])
        if t.startswith("landmark"): col = rgb(pal["accent2"])
        if "points" in f:
            o.append(f'<polyline points="{pts(f["points"])}" fill="none" stroke="{col}" stroke-width="{max(f.get("width",2),2)*S}" stroke-linejoin="round" stroke-linecap="round" stroke-opacity=".9"/>')
            mid = f["points"][len(f["points"]) // 2]; lab(mid[0], mid[1] - 4, f["id"], 9)
        elif "rx" in f:
            o.append(f'<ellipse cx="{X(f["x"])}" cy="{Z(f["z"])}" rx="{f["rx"]*S}" ry="{f["rz"]*S}" fill="{col}" fill-opacity=".8" stroke="#fff" stroke-opacity=".6" stroke-width="2"/>')
            lab(f["x"], f["z"] + f["rz"] - 4, f["id"], 10, "bold")
        else:
            dash = "" if f.get("solid") else ' stroke-dasharray="4 3"'
            o.append(f'<circle cx="{X(f["x"])}" cy="{Z(f["z"])}" r="{max(f["r"],1.5)*S}" fill="{col}" fill-opacity="{.95 if f.get("solid") else .45}" stroke="{ink}" stroke-width="{3 if t.startswith("landmark") else 1}"{dash}/>')
            if t.startswith("landmark") or f["r"] >= 5: lab(f["x"], f["z"] - f["r"] - 2, f["id"], 10, "bold")
            elif t not in ("perch_flower", "mound", "lake_marker"): lab(f["x"], f["z"] - f["r"] - 1.5, f["id"], 8)
    rc = {"stampede": "#e2452f", "run": "#ff9a1f", "legend": "#8a4fd6", "wind": "#19b8a6", "burrow": "#3d74d9"}
    for r in a["routes"]:
        tag = "polygon" if r.get("closed") else "polyline"
        o.append(f'<{tag} points="{pts(r["points"])}" fill="none" stroke="{rc[r["kind"]]}" stroke-width="3" stroke-dasharray="10 6" stroke-linejoin="round"/>')
        p0, p1 = r["points"][0], r["points"][1]
        o.append(f'<circle cx="{X(p0[0])}" cy="{Z(p0[1])}" r="5" fill="{rc[r["kind"]]}"/>')
        lab((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2 - 2, r["id"], 9, "bold", rc[r["kind"]])
    for h in a["habitats"]:
        if "x" not in h: continue
        sp = [f'{p["species"]} x{p["count"]}' for p in a["pods"] if p["habitat"] == h["id"]] or ["(spare)"]
        o.append(f'<circle cx="{X(h["x"])}" cy="{Z(h["z"])}" r="{h["r"]*S}" fill="#fff" fill-opacity=".18" stroke="{ink}" stroke-width="2" stroke-dasharray="2 5"/>')
        lab(h["x"], h["z"] + 1, sp[0], 10, "bold"); lab(h["x"], h["z"] + 5, h["id"], 8)
    for b in a["bankRings"]:
        o.append(f'<circle cx="{X(b["x"])}" cy="{Z(b["z"])}" r="{b["r"]*S}" fill="none" stroke="#ffcf2e" stroke-width="5"/><circle cx="{X(b["x"])}" cy="{Z(b["z"])}" r="{b["r"]*S}" fill="none" stroke="{ink}" stroke-width="1"/>')
        lab(b["x"], b["z"] + 1.5, "BANK", 9, "bold")
    for ea in a["eventAnchors"]:
        if "x" in ea:
            o.append(f'<path d="M{X(ea["x"])} {Z(ea["z"])-8} l3 6 6 1 -5 4 2 6 -6 -4 -6 4 2 -6 -5 -4 6 -1z" fill="#ffe36b" stroke="{ink}" stroke-width=".8"/>')
    s = a["spawn"]
    o.append(f'<path d="M{X(s["x"])-9} {Z(s["z"])+7} L{X(s["x"])} {Z(s["z"])-11} L{X(s["x"])+9} {Z(s["z"])+7}z" fill="#fff" stroke="{ink}" stroke-width="2"/>')
    lab(s["x"], s["z"] + 6, "SPAWN", 9, "bold")
    o.append(f'<text x="14" y="{H+24}" font-size="20" font-weight="bold" fill="{ink}">{a["name"].upper()} — {a["identity"].split(" - ")[0]}</text>')
    o.append(f'<text x="14" y="{H+42}" font-size="11" fill="{ink}">{a["identity"].split(" - ")[1]}. Grid 20 studs; +x east, +z south. Generated from data/arenas/{a["id"]}.json — do not edit by hand.</text>')
    lx = 14
    for name, col in [("stampede route", rc["stampede"]), ("run / burrow circuit", rc["run"]), ("legend route", rc["legend"]), ("wind lane", rc["wind"]), ("bank ring", "#ffcf2e"), ("habitat (dotted)", ink), ("solid = filled, soft = dashed", ink)]:
        o.append(f'<rect x="{lx}" y="{H+52}" width="14" height="8" fill="{col}"/><text x="{lx+18}" y="{H+60}" font-size="10" fill="{ink}">{name}</text>'); lx += 26 + len(name) * 6.2
    o.append("</svg>")
    (ROOT / "maps" / f"{a['id']}.svg").write_text("\n".join(o))

def render_hud(vn, out):
    v = ui["viewports"][vn]; W, H = v["size"]; r = v["rects"]
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" font-family="Verdana,sans-serif">',
         '<defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8fd8ff"/><stop offset="1" stop-color="#e9fbe6"/></linearGradient></defs>',
         f'<rect width="{W}" height="{H}" fill="url(#sky)"/>',
         f'<path d="M0 {H*.42} Q{W*.25} {H*.30} {W*.5} {H*.40} T{W} {H*.36} V{H} H0z" fill="#6cd68e"/>',
         f'<path d="M0 {H*.62} Q{W*.3} {H*.52} {W*.6} {H*.60} T{W} {H*.58} V{H} H0z" fill="#58c583"/>',
         f'<ellipse cx="{W*.2}" cy="{H*.36}" rx="{W*.07}" ry="{H*.09}" fill="#ffd648"/><rect x="{W*.195}" y="{H*.36}" width="{W*.01}" height="{H*.14}" fill="#7a5a48"/>',
         f'<path d="M{W*.5} {H*.78} C{W*.38} {H*.80} {W*.34} {H*.62} {W*.46} {H*.56} C{W*.58} {H*.50} {W*.68} {H*.60} {W*.62} {H*.70}" fill="none" stroke="#fff36b" stroke-width="7" stroke-linecap="round" stroke-opacity=".95"/>',
         f'<path d="M{W*.62} {H*.70} L{W*.5} {H*.78}" stroke="#fff" stroke-width="3" stroke-dasharray="6 6"/>']
    for i, (cx, cy, c) in enumerate([(.47, .64, "#ffd241"), (.52, .66, "#ffd241"), (.5, .61, "#ffd241"), (.56, .63, "#ff84b1")]):
        o.append(f'<ellipse cx="{W*cx}" cy="{H*cy}" rx="{H*.022}" ry="{H*.026}" fill="{c}" stroke="#1b2440" stroke-width="1.5"/>')
    o.append(f'<circle cx="{W*.5}" cy="{H*.80}" r="{H*.03}" fill="#fff" stroke="#1b2440" stroke-width="2"/>')
    o.append(f'<text x="{W*.5}" y="{H*.50}" font-size="{H*.045:.0f}" font-weight="bold" text-anchor="middle" fill="#fff" stroke="#1b2440" stroke-width="4" paint-order="stroke">+86</text>')
    o.append(f'<text x="{W*.5}" y="{H*.535}" font-size="{H*.024:.0f}" font-weight="bold" text-anchor="middle" fill="#ffe36b" stroke="#1b2440" stroke-width="3" paint-order="stroke">SNAP · TIGHT · x2</text>')
    panel = lambda k: f'<rect x="{r[k][0]}" y="{r[k][1]}" width="{r[k][2]}" height="{r[k][3]}" rx="10" fill="#1b2440" fill-opacity=".65"/>'
    txt = lambda k, t, size, col="#fff9e7", w="bold": f'<text x="{r[k][0]+r[k][2]/2}" y="{r[k][1]+r[k][3]/2+size*.36}" font-size="{size}" font-weight="{w}" text-anchor="middle" fill="{col}">{t}</text>'
    o += [panel("timer"), txt("timer", "1:12", r["timer"][3] * .62), txt("phase", "GATHER", r["phase"][3] * .8, "#1b2440")]
    o.append(panel("parade")); px, py, pw, ph = r["parade"]; d = ph * .42
    for i in range(12):
        o.append(f'<circle cx="{px+10+d/2+i*(d+3)}" cy="{py+ph/2}" r="{d/2}" fill="{"#ffd241" if i<5 else "#ff84b1" if i<7 else "none"}" stroke="#fff9e7" stroke-opacity=".6" stroke-width="1.2"/>')
    o.append(f'<text x="{px+pw-8}" y="{py+ph/2+ph*.2}" font-size="{ph*.55}" font-weight="bold" text-anchor="end" fill="#ffe36b">×1.25</text>')
    o += [panel("score"), txt("score", "1,240", r["score"][3] * .62)]
    cx, cy, cw, ch = r["chain"]
    o.append(f'<rect x="{cx}" y="{cy+ch-5}" width="{cw}" height="5" rx="2.5" fill="#1b2440" fill-opacity=".5"/><rect x="{cx}" y="{cy+ch-5}" width="{cw*.6}" height="5" rx="2.5" fill="#63edc2"/>')
    o.append(f'<text x="{cx+cw}" y="{cy+ch-8}" font-size="{ch*.6}" font-weight="bold" text-anchor="end" fill="#1b2440">x2 CHAIN</text>')
    o += [panel("menu"), txt("menu", "≡", r["menu"][3] * .6)]
    o += [panel("toast"), txt("toast", "STAMPEDE incoming from the west!", r["toast"][3] * .5, "#fff9e7", "normal")]
    o += [panel("hint"), txt("hint", "Run a circle around the Sparks", r["hint"][3] * .5, "#ffe36b", "normal")]
    if "dash" in r:
        dx, dy, dw, dh = r["dash"]
        for i in range(2):
            mx = dx + dw * (.27 + .46 * i); my = dy + dh / 2; q = dh * .42
            o.append(f'<path d="M{mx} {my-q} L{mx+q} {my} L{mx} {my+q} L{mx-q} {my}z" fill="{"#ffe36b" if i==0 else "#1b2440"}" fill-opacity="{1 if i==0 else .55}" stroke="#fff9e7" stroke-width="2"/>')
    if "dashButton" in r:
        bx, by, bw, bh = r["dashButton"]
        o.append(f'<circle cx="{bx+bw/2}" cy="{by+bh/2}" r="{bw/2}" fill="#ffe36b" fill-opacity=".85" stroke="#1b2440" stroke-width="3"/><text x="{bx+bw/2}" y="{by+bh/2+6}" font-size="16" font-weight="bold" text-anchor="middle" fill="#1b2440">DASH</text>')
    for k, q in v["reserved"].items():
        o.append(f'<rect x="{q[0]}" y="{q[1]}" width="{q[2]}" height="{q[3]}" rx="{q[2]/2}" fill="#fff" fill-opacity=".25" stroke="#1b2440" stroke-dasharray="5 4"/><text x="{q[0]+q[2]/2}" y="{q[1]+q[3]/2+4}" font-size="10" text-anchor="middle" fill="#1b2440">{k} (Roblox)</text>')
    o.append(f'<text x="8" y="{H-6}" font-size="9" fill="#1b2440" fill-opacity=".7">HUD v2 mockup · {vn} · generated from data/ui_layout.json · scene is schematic, HUD rects are exact</text></svg>')
    (ROOT / "mockups" / out).write_text("\n".join(o))

if "--no-render" not in sys.argv:
    for a in arenas.values(): render(a)
    render_hud("desktop_1280x684", "hud_desktop.svg"); render_hud("phone_756x354", "hud_phone.svg")
for m in assets["mockups"]:
    if not (ROOT / m).exists(): err(f"listed mockup missing: {m}")

for n in notes: print("  ", n)
if errors:
    print(f"FAIL: {len(errors)} problem(s)")
    for e in errors: print("  -", e)
    sys.exit(1)
print("OK: design data is internally consistent")
