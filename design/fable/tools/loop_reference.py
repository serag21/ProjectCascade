#!/usr/bin/env python3
"""Executable reference for the ribbon/loop rules and loop scoring.

This is the SPEC that R/Loop.luau, S/LoopService.luau and Challenge.loop must match.
It is deliberately small and unoptimised. data/test_vectors.json is generated from it
(tools/gen_test_vectors.py) and re-verified by tools/validate.py.

Conventions: 2D arena-relative studs (x, z). A ribbon point is (x, z, t, d, g):
time, cumulative path distance, and ground height of the layer the player stood on.
"""
import json, math
from pathlib import Path

DATA = Path(__file__).resolve().parents[1] / "data"


def load_tuning():
    raw = json.loads((DATA / "tuning.json").read_text())
    def v(section, key): return raw[section][key]["value"]
    return {
        "lifetime": v("ribbon", "lifetime"), "maxLength": v("ribbon", "maxLength"),
        "spacing": v("ribbon", "sampleSpacing"), "snapRadius": v("ribbon", "snapRadius"),
        "snapMinPath": v("ribbon", "snapMinPathDistance"), "minPerimeter": v("ribbon", "minPerimeter"),
        "minArea": v("ribbon", "minArea"), "maxVertices": v("ribbon", "maxVertices"),
        "tolerance": v("ribbon", "serverPathTolerance"), "inflate": v("ribbon", "captureInflate"),
        "layerTolerance": v("ribbon", "layerTolerance"), "viewClockMaxAge": v("ribbon", "viewClockMaxAge"),
        "pathGapMax": v("ribbon", "pathGapMax"),
        "sizeMult": {int(k): m for k, m in v("scoring", "sizeMultiplier").items()},
        "techBonus": v("scoring", "techBonusEach"), "chainTiers": v("scoring", "chainTiers"),
        "chainWindow": v("scoring", "chainWindow"), "chainWindowPer": v("scoring", "chainWindowPerCreature"),
        "chainWindowMax": v("scoring", "chainWindowMax"), "chainLinks": v("scoring", "chainLinks"),
        "tightBase": v("scoring", "tightAreaBase"), "tightPer": v("scoring", "tightAreaPerCreature"),
        "finaleMult": v("scoring", "finaleMultiplier"), "bankTiers": v("parade", "bankMultiplier"),
        "capacity": v("parade", "capacity"), "overflowScale": v("parade", "overflowScoreScale"),
        "snapWindow": v("scoring", "snapWindow"),
    }


# ---------------------------------------------------------------- ribbon
def new_ribbon(): return []

def push(ribbon, x, z, t, T, g=0.0):
    """Append a sample when it is >= spacing from the last; expire by time and by length."""
    if ribbon:
        lx, lz, _, ld, _ = ribbon[-1]
        step = math.hypot(x - lx, z - lz)
        if step < T["spacing"]:
            added = False
        else:
            ribbon.append((x, z, t, ld + step, g)); added = True
    else:
        ribbon.append((x, z, t, 0.0, g)); added = True
    while len(ribbon) > 1 and (ribbon[0][2] < t - T["lifetime"] or ribbon[-1][3] - ribbon[0][3] > T["maxLength"]):
        ribbon.pop(0)
    return added

def truncate(ribbon, from_time):
    """Ribbon cut: forget every point at or before from_time."""
    ribbon[:] = [p for p in ribbon if p[2] > from_time]

def _seg_intersect(a, b, c, d):
    """Proper intersection of segments ab and cd -> (u along ab, point) or None."""
    r = (b[0] - a[0], b[1] - a[1]); s = (d[0] - c[0], d[1] - c[1])
    den = r[0] * s[1] - r[1] * s[0]
    if abs(den) < 1e-9: return None
    qp = (c[0] - a[0], c[1] - a[1])
    u = (qp[0] * s[1] - qp[1] * s[0]) / den
    w = (qp[0] * r[1] - qp[1] * r[0]) / den
    if 0 <= u <= 1 and 0 <= w <= 1: return u, (a[0] + r[0] * u, a[1] + r[1] * u)
    return None

def area(poly):
    return abs(sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))) / 2

def perimeter(poly):
    return sum(math.hypot(poly[(i + 1) % len(poly)][0] - poly[i][0], poly[(i + 1) % len(poly)][1] - poly[i][1]) for i in range(len(poly)))

def centroid(poly):
    return sum(p[0] for p in poly) / len(poly), sum(p[1] for p in poly) / len(poly)

def _resample(poly, n):
    if len(poly) <= n: return poly
    return [poly[int(i * len(poly) / n)] for i in range(n)]

def try_close(ribbon, T, head=None):
    """-> (polygon [(x, z, g)], kind) or (None, reason). Does not mutate the ribbon.

    `head` is the player's CURRENT position (x, z, t, g); it need not be a stored sample.
    Snap is tested first against ribbon SEGMENTS (not just sample points), so coarse sampling
    leaves no holes; a true crossing is the fallback for a head that jumped over the ribbon
    between two frames. Only ribbon at least snapMinPath back along the path can close."""
    if len(ribbon) < 2: return None, "short"
    if head is None: head = ribbon[-1]
    last = ribbon[-1]
    stored = (head[0], head[1]) == (last[0], last[1])
    prev = ribbon[-2] if stored else last          # start of the newest movement segment
    head_d = last[3] + math.hypot(head[0] - last[0], head[1] - last[1])
    hg = head[4] if len(head) > 4 else last[4]
    best = None
    for i in range(len(ribbon) - 1):
        if head_d - ribbon[i + 1][3] < T["snapMinPath"]: break
        hit = _seg_intersect(prev, head, ribbon[i], ribbon[i + 1])
        if hit and (best is None or hit[0] < best[0]): best = (hit[0], hit[1], i)
    if best:
        _, pt, i = best
        poly = [(pt[0], pt[1], ribbon[i + 1][4])] + [(p[0], p[1], p[4]) for p in (ribbon[i + 1:-1] if stored else ribbon[i + 1:])]
        kind = "cross"
    else:
        near = None
        for i in range(len(ribbon) - 1):
            if head_d - ribbon[i + 1][3] < T["snapMinPath"]: break
            dist, u = _seg_dist(head[0], head[1], ribbon[i], ribbon[i + 1])
            if dist <= T["snapRadius"] and (near is None or dist <= near[0]): near = (dist, i, u)
        if near is None: return None, "open"
        _, i, u = near
        a, b = ribbon[i], ribbon[i + 1]
        poly = [(a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u, a[4])] + [(p[0], p[1], p[4]) for p in ribbon[i + 1:]]
        if not stored: poly.append((head[0], head[1], hg))
        kind = "snap"
    poly = _resample(poly, T["maxVertices"])
    if len(poly) < 3: return None, "short"
    if perimeter(poly) < T["minPerimeter"]: return None, "perimeter"
    if area(poly) < T["minArea"]: return None, "area"
    return poly, kind


# ---------------------------------------------------------------- containment
def _pip(x, z, poly):
    """Non-zero winding rule: a point enclosed by ANY turn of the ribbon is inside, so a ring
    walked twice around one Spark (or a self-overlapping loop) still contains it."""
    wn = 0
    for i in range(len(poly)):
        x1, z1 = poly[i][0], poly[i][1]; x2, z2 = poly[(i + 1) % len(poly)][0], poly[(i + 1) % len(poly)][1]
        side = (x2 - x1) * (z - z1) - (x - x1) * (z2 - z1)
        if z1 <= z:
            if z2 > z and side > 0: wn += 1
        elif z2 <= z and side < 0: wn -= 1
    return wn != 0

def _seg_dist(px, pz, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]; l2 = dx * dx + dz * dz
    u = 0 if l2 == 0 else max(0, min(1, ((px - a[0]) * dx + (pz - a[1]) * dz) / l2))
    return math.hypot(px - (a[0] + dx * u), pz - (a[1] + dz * u)), u

def edge_distance(x, z, poly):
    return min(_seg_dist(x, z, poly[i], poly[(i + 1) % len(poly)])[0] for i in range(len(poly)))

def contains(poly, x, z, inflate=0.0):
    return _pip(x, z, poly) or (inflate > 0 and edge_distance(x, z, poly) <= inflate)

def layer_ok(poly, x, z, g, T):
    """Height rule: compare the creature's ground height with that of the nearest polygon vertex."""
    nearest = min(poly, key=lambda p: (p[0] - x) ** 2 + (p[1] - z) ** 2)
    return abs(nearest[2] - g) <= T["layerTolerance"]


# ---------------------------------------------------------------- server validation
def validate(poly, server_path, now, ribbon_start, T, bounds=None):
    """server_path: [(x, z, t, g)] oldest first, appended only after Rules.movement accepted the position.
    -> (ok, reason, serverArea). serverArea is the area of the loop as the SERVER saw it (its own path
    between the earliest and latest matched times, closed); TIGHT is decided from it, never from the
    client polygon, so a client cannot shrink its claim to earn TIGHT."""
    n = len(poly)
    if n < 3 or n > T["maxVertices"]: return False, "vertex-count", None
    for p in poly:
        if not all(isinstance(c, (int, float)) and math.isfinite(c) for c in p[:2]): return False, "not-finite", None
        if bounds and not _pip(p[0], p[1], bounds): return False, "out-of-bounds", None
    per = perimeter(poly)
    if per < T["minPerimeter"]: return False, "perimeter-small", None
    if per > T["maxLength"] + T["snapRadius"] + 6: return False, "perimeter-large", None
    if area(poly) < T["minArea"]: return False, "area-small", None
    oldest = max(ribbon_start, now - T["lifetime"] - 0.6)
    path = [s for s in server_path if s[2] >= oldest]
    if len(path) < 2: return False, "no-path", None
    for a, b in zip(path, path[1:]):
        if b[2] - a[2] > T["pathGapMax"]: return False, "path-gap", None
    last = path[-1]
    if math.hypot(poly[-1][0] - last[0], poly[-1][1] - last[1]) > T["tolerance"]: return False, "head-not-reached", None
    matched = []
    for p in poly:
        best = None
        for a, b in zip(path, path[1:]):
            dist, u = _seg_dist(p[0], p[1], a, b)
            if best is None or dist < best[0]: best = (dist, a[2] + (b[2] - a[2]) * u)
        if best[0] > T["tolerance"]: return False, "off-path", None
        matched.append(best[1])
    lo, hi = min(matched), max(matched)
    for s_ in path:
        if lo <= s_[2] <= hi and edge_distance(s_[0], s_[1], poly) > T["tolerance"]: return False, "path-leaves-polygon", None
    proof = [s_ for s_ in path if lo <= s_[2] <= hi]
    return True, "ok", (round(area(proof), 1) if len(proof) >= 3 else None)

def resolve(poly, creatures, view_clock, now, T):
    """creatures: [{id, history: [(clock, x, z, g, catchable)]}]. Lag compensation: evaluate at the claim's
    view clock, clamped to [now - viewClockMaxAge, now]. -> (caught ids, escaped ids)."""
    clock = min(now, max(view_clock, now - T["viewClockMaxAge"]))
    caught, escaped = [], []
    for c in creatures:
        h = c["history"]
        before = [s for s in h if s[0] <= clock]
        a = before[-1] if before else h[0]
        after = [s for s in h if s[0] > clock]
        if after and before and after[0][0] > a[0]:
            b = after[0]; u = (clock - a[0]) / (b[0] - a[0])
            x, z, g = a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u, a[3]
        else:
            x, z, g = a[1], a[2], a[3]
        if not contains(poly, x, z, T["inflate"]) or not layer_ok(poly, x, z, g, T): continue
        (caught if a[4] else escaped).append(c["id"])
    return caught, escaped


# ---------------------------------------------------------------- scoring
def size_mult(n, T):
    return T["sizeMult"][min(n, max(T["sizeMult"]))]

def chain_links(n, T):
    for lo, links in reversed(T["chainLinks"]):
        if n >= lo: return n + links
    return n

def chain_window(n, T):
    """Seconds the chain survives after a loop that caught n (n = 1 for a bank or a wrap)."""
    return min(T["chainWindowMax"], T["chainWindow"] + T["chainWindowPer"] * max(0, n - 1))

def chain_mult(links, T):
    m = 1
    for need, mult in T["chainTiers"]:
        if links >= need: m = mult
    return m

def is_tight(n, loop_area, T, solo_tight_area=None):
    if n >= 2: return loop_area <= T["tightBase"] + T["tightPer"] * n
    return solo_tight_area is not None and loop_area <= solo_tight_area

def score_loop(values, techs, links_before, T, finale=False, carried=0):
    """values: base values of creatures caught, in pop order. techs: set of SNAP/TIGHT/PINCH/MEDLEY.
    Chain multiplier uses the links AFTER this loop is added (the loop that reaches a tier earns it).
    Creatures beyond parade capacity score at overflowScale and are released.
    -> dict(points, links, multiplier, kept, overflow)."""
    n = len(values)
    if n == 0: return {"points": 0, "links": links_before, "multiplier": chain_mult(links_before, T), "kept": 0, "overflow": 0}
    links = links_before + chain_links(n, T)
    mult = chain_mult(links, T)
    room = max(0, T["capacity"] - carried)
    kept = min(n, room)
    base = sum(values[:kept]) + T["overflowScale"] * sum(values[kept:])
    pts = base * size_mult(n, T) * (1 + T["techBonus"] * len(techs)) * mult * (T["finaleMult"] if finale else 1)
    return {"points": int(math.floor(pts + 0.5)), "links": links, "multiplier": mult, "kept": kept, "overflow": n - kept}

def bank_points(values, T):
    n = len(values); m = 1.0
    for need, mult in T["bankTiers"]:
        if n >= need: m = mult
    return int(math.floor(sum(values) * m + 0.5)), m
