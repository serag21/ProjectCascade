#!/usr/bin/env python3
"""Generate data/test_vectors.json from the reference implementation.

Every vector carries its full input and the expected output, so R/Loop.luau,
S/LoopService.luau and Challenge.loop can be tested against it without Python.
tools/validate.py recomputes every expectation and fails on any difference.
Usage: python3 design/fable/tools/gen_test_vectors.py
"""
import json, math
from pathlib import Path
import loop_reference as L

ROOT = Path(__file__).resolve().parents[1]
T = L.load_tuning()
r3 = lambda v: round(v, 3)

def walk(points_fn, seconds, dt=0.1):
    return [[r3(c) for c in points_fn(i * dt)] + [r3(i * dt)] for i in range(int(round(seconds / dt)) + 1)]

def circle(r, speed, turns=1.0, cx=0.0, cz=0.0, phase=0.0):
    w = speed / r
    return (lambda t: (cx + r * math.cos(phase + w * t), cz + r * math.sin(phase + w * t))), turns * 2 * math.pi * r / speed

def run_closure(samples):
    ribbon = L.new_ribbon(); result = None
    for i, (x, z, t) in enumerate(samples):
        L.push(ribbon, x, z, t, T)
        poly, kind = L.try_close(ribbon, T, (x, z, t, 0.0))
        if poly:
            result = {"closes": True, "atSample": i, "kind": kind, "vertices": len(poly), "area": round(L.area(poly), 1), "perimeter": round(L.perimeter(poly), 1)}
            break
    return result or {"closes": False}

closure = []
def add_closure(name, why, samples):
    closure.append({"name": name, "why": why, "samples": samples, "expect": run_closure(samples)})

f, s = circle(8, 24, 1.1); add_closure("circle_r8_walk", "the standard pod loop: snaps shut just before the full turn", walk(f, s))
f, s = circle(4, 24, 1.2); add_closure("circle_r4_single", "smallest practical loop around one Spark", walk(f, s))
f, s = circle(2, 24, 2.0); add_closure("circle_r2_double_wound", "one turn is 12.6 studs (< snapMinPath 16), so it only closes part-way through the second turn; the non-zero winding rule still contains the centre", walk(f, s))
f, s = circle(15, 24, 1.1); add_closure("circle_r15_large", "near the largest solo loop (94 studs, 3.9 s)", walk(f, s))
f, s = circle(17, 24, 1.2); add_closure("circle_r17_too_long", "perimeter 107 > maxLength: the tail expires first", walk(f, s))
f, s = circle(8, 10, 1.2); add_closure("circle_r8_slow", "5 s per turn > lifetime: the tail fades before the ring meets", walk(f, s))
add_closure("straight_line", "no closure on a straight run", walk(lambda t: (24 * t, 0.0), 3.0))
add_closure("out_and_back", "returning along your own ribbon encloses nothing: rejected for area", walk(lambda t: ((24 * t, 0.0) if t <= 1.25 else (30 - 24 * (t - 1.25), 0.4)), 2.5))
def square(t):
    d = 24 * t; side = 20
    if d < side: return (d, 0.0)
    if d < 2 * side: return (side, d - side)
    if d < 3 * side: return (side - (d - 2 * side), side)
    return (0.0 + 1.0, side - (d - 3 * side) * 1.15)   # last side drifts 1 stud inward and overshoots: crosses the first side
add_closure("square_return", "a square that comes back to its first side: snaps as soon as the head is within 4.5 of that side", walk(square, 4.2))
add_closure("fast_crossing", "dash-speed samples 7 studs apart jump straight over the ribbon without ever being within 4.5 of it: closes by crossing", [[0, 0, 0], [7, 0, 0.1], [14, 0, 0.2], [21, 0, 0.3], [28, 0, 0.4], [32, 6, 0.5], [28, 12, 0.6], [21, 12, 0.7], [14, 10, 0.8], [10.5, 5, 0.9], [10.5, -5, 1.0]])
def eight(t):
    a = 24 * t / 9
    return (9 * math.sin(a), 9 * math.sin(a) * math.cos(a) * 1.6)
add_closure("figure_eight", "closes on the FIRST crossing only (one lobe), not the whole figure", walk(eight, 4.0))
def horseshoe(gap):
    def fn(t):
        a = min(24 * t / 8, 2 * math.pi - gap / 8)
        return (8 * math.cos(a), 8 * math.sin(a))
    return fn
add_closure("snap_inside_radius", "head stops 4.0 studs of arc short of the start: inside snapRadius 4.5", walk(horseshoe(4.0), 2.4))
add_closure("snap_outside_radius", "head stops 5.2 studs short: outside snapRadius, stays open", walk(horseshoe(5.2), 2.4))

SQ = [(0, 0, 0), (10, 0, 0), (10, 10, 0), (0, 10, 0)]
contain = []
for name, x, z, inflate in [("centre", 5, 5, 0), ("inside_near_edge", 9.9, 5, 0), ("outside_no_inflate", 10.5, 5, 0), ("outside_within_inflate", 10.7, 5, 0.75),
                            ("outside_beyond_inflate", 10.8, 5, 0.75), ("corner_within_inflate", 10.5, 10.5, 0.75), ("corner_beyond_inflate", 10.6, 10.6, 0.75), ("far", 30, 30, 0.75)]:
    contain.append({"name": name, "polygon": [list(p[:2]) for p in SQ], "x": x, "z": z, "inflate": inflate, "expect": L.contains(SQ, x, z, inflate)})
DOUBLE = [(r3(3 * math.cos(i * 2 * math.pi / 8)), r3(3 * math.sin(i * 2 * math.pi / 8)), 0) for i in range(16)]
contain.append({"name": "double_wound_centre", "polygon": [list(p[:2]) for p in DOUBLE], "x": 0, "z": 0, "inflate": 0, "expect": L.contains(DOUBLE, 0, 0, 0)})

# ---- validation: a client polygon against the server-observed path
def client_polygon(r, offset=(0.0, 0.0), n=24, reverse=False):
    pts = [(r3(offset[0] + r * math.cos(2 * math.pi * i / n)), r3(offset[1] + r * math.sin(2 * math.pi * i / n)), 0.0) for i in range(n)]
    return list(reversed(pts)) if reverse else pts
def server_circle(r, t0=10.0, speed=24, frac=1.0, hole=None, wobble=0.0):
    out = []; total = 2 * math.pi * r / speed; steps = 30
    for i in range(int(steps * frac) + 1):
        t = total * i / steps
        if hole and hole[0] < t < hole[1]: continue
        a = 2 * math.pi * i / steps
        rr = r + wobble * math.sin(7 * a)
        out.append([r3(rr * math.cos(a)), r3(rr * math.sin(a)), r3(t0 + t), 0.0])
    return out
NOW = 10.0 + 2 * math.pi * 8 / 24
validation = []
def add_val(name, why, poly, path, now=NOW, ribbon_start=0.0):
    ok, reason, server_area = L.validate(poly, [tuple(s) for s in path], now, ribbon_start, T)
    validation.append({"name": name, "why": why, "polygon": [list(p[:2]) for p in poly], "serverPath": path, "now": r3(now), "ribbonStart": ribbon_start, "expect": {"ok": ok, "reason": reason, "serverArea": server_area, "clientArea": round(L.area(poly), 1)}})
add_val("honest_exact", "client polygon equals the path the server saw", client_polygon(8), server_circle(8))
add_val("honest_wobble", "server samples wobble 1 stud around the client path (replication noise)", client_polygon(8), server_circle(8, wobble=1.0))
add_val("honest_shift_3", "3-stud systematic offset is inside the 4-stud tolerance", client_polygon(8, (3, 0)), server_circle(8))
add_val("shift_5_rejected", "5-stud offset is outside tolerance", client_polygon(8, (5, 0)), server_circle(8))
add_val("inflated_r11", "client claims a ring 3 studs wider than it ran: inside tolerance, so allowed (this is the exploit bound)", client_polygon(11), server_circle(8))
add_val("inflated_r13_rejected", "5 studs wider: rejected", client_polygon(13), server_circle(8))
add_val("fabricated_elsewhere", "polygon 60 studs from anywhere the player has been", client_polygon(8, (60, 0)), server_circle(8))
add_val("reversed_order", "vertices listed against the direction of travel: direction does not matter, only the corridor does (last vertex is still the head)", [client_polygon(8)[0]] + list(reversed(client_polygon(8)[1:])) + [client_polygon(8)[0]], server_circle(8))
add_val("server_path_hole", "the server lost 1.2 s of positions: it cannot prove the loop", client_polygon(8), server_circle(8, hole=(0.5, 1.7)))
add_val("head_not_reached", "server has only seen 70% of the ring when the deferral ends", client_polygon(8), server_circle(8, frac=0.7), now=10.0 + 0.7 * 2 * math.pi * 8 / 24)
add_val("corner_cut_allowed_not_tight", "client claims the inscribed triangle of the ring it ran. It is inside the corridor, so the catch stands, but serverArea (the real ring) decides TIGHT", [(-4.0, 6.928, 0.0), (-4.0, -6.928, 0.0), (8.0, 0.0, 0.0)], server_circle(8))
add_val("after_ribbon_cut", "a cut at t=11.2 invalidates the earlier half of the ring", client_polygon(8), server_circle(8), ribbon_start=11.2)
add_val("too_many_vertices", "57 vertices", client_polygon(8, n=57), server_circle(8))
add_val("too_small", "perimeter below minPerimeter", client_polygon(2), server_circle(2))

# ---- resolution: lag compensation, uncatchable states, layers
ring = client_polygon(8)
def hist(points): return [[r3(c) if isinstance(c, float) else c for c in p] for p in points]
resolution = []
def add_res(name, why, creatures, view_clock, now):
    caught, escaped = L.resolve(ring, creatures, view_clock, now, T)
    resolution.append({"name": name, "why": why, "polygon": [list(p) for p in ring], "creatures": creatures, "viewClock": view_clock, "now": now, "expect": {"caught": caught, "escaped": escaped}})
flee = {"id": 1, "history": hist([(20.0, 5.0, 0.0, 0.0, True), (20.1, 6.0, 0.0, 0.0, True), (20.2, 7.0, 0.0, 0.0, True), (20.3, 8.0, 0.0, 0.0, True), (20.4, 9.0, 0.0, 0.0, True), (20.5, 10.0, 0.0, 0.0, True)])}
add_res("lag_150ms_favours_player", "the Spark left the ring 0.2 s ago, but the player closed around where they saw it (view clock 20.25)", [flee], 20.25, 20.5)
add_res("lag_clamped_at_350ms", "a claim asking for 0.6 s of rewind is clamped to 0.35 s (clock 20.15): still inside", [flee], 19.9, 20.5)
add_res("no_lag_miss", "with no latency the same Spark has already left", [flee], 20.5, 20.5)
hop = {"id": 2, "history": hist([(20.0, 2.0, 1.0, 0.0, True), (20.1, 2.0, 1.0, 0.0, True), (20.2, 2.5, 1.0, 0.0, False), (20.3, 3.5, 1.0, 0.0, False), (20.4, 4.5, 1.0, 0.0, False)])}
add_res("hopper_airborne_escapes", "Bunvolt is airborne (uncatchable) at the view clock: listed as escaped so the client plays the 'nope' hop", [hop], 20.3, 20.4)
add_res("hopper_caught_in_crouch", "the same Bunvolt 0.2 s earlier, still crouching", [hop], 20.1, 20.4)
shelf = {"id": 3, "history": hist([(20.0, 1.0, -2.0, 12.0, True), (20.4, 1.0, -2.0, 12.0, True)])}
floor = {"id": 4, "history": hist([(20.0, -1.0, 2.0, 0.0, True), (20.4, -1.0, 2.0, 0.0, True)])}
add_res("layer_rule", "ring drawn on the canyon floor (g=0): the Sunshell on the 12-stud shelf inside the same outline is not caught", [shelf, floor], 20.4, 20.4)
edge = {"id": 5, "history": hist([(20.0, 8.6, 0.0, 0.0, True), (20.4, 8.6, 0.0, 0.0, True)])}
edge2 = {"id": 6, "history": hist([(20.0, 9.0, 0.0, 0.0, True), (20.4, 9.0, 0.0, 0.0, True)])}
add_res("edge_inflate", "0.6 outside the line is caught (inflate 0.75); 1.0 outside is not", [edge, edge2], 20.4, 20.4)

# ---- scoring
scoring = []
def add_score(name, why, values, techs, links_before, finale=False, carried=0):
    scoring.append({"name": name, "why": why, "values": values, "techs": sorted(techs), "linksBefore": links_before, "finale": finale, "carried": carried,
                    "expect": L.score_loop(values, set(techs), links_before, T, finale, carried)})
add_score("first_single_pip", "the beginner's first loop", [3], [], 0)
add_score("first_pip_pod", "a pod of three reaches x2 on its own (4 links)", [3, 3, 3], [], 0)
add_score("pod_snap_tight", "same pod, two techniques", [3, 3, 3], ["SNAP", "TIGHT"], 0)
add_score("fourth_single_in_chain", "four singles are needed to reach x2", [3], [], 3)
add_score("cubloom_flock_x3", "flock of four arriving at 10 links", [5, 5, 5, 5], ["TIGHT"], 5)
add_score("bloom_all_eight", "FULL BLOOM ring (the +40 style bonus is added separately)", [3, 3, 3, 3, 3, 5, 5, 5], [], 4)
add_score("stampede_nine_x4_finale", "the best loop a round can contain", [3, 4, 5, 3, 4, 3, 5, 3, 4], ["SNAP", "MEDLEY"], 12, True)
add_score("overflow_two_of_five", "carrying 10 of 12: three are kept, two score half and are released", [3, 3, 3, 3, 3], [], 0, False, 10)
add_score("empty_loop", "nothing inside: no points, chain untouched", [], [], 6)
banks = [{"name": f"bank_{n}", "values": [4] * n, "expect": dict(zip(("points", "multiplier"), L.bank_points([4] * n, T)))} for n in (1, 3, 4, 8, 11, 12, 15)]
chain = {"linksForLoopSize": {str(n): L.chain_links(n, T) for n in range(1, 11)}, "multiplierAtLinks": {str(k): L.chain_mult(k, T) for k in (0, 3, 4, 9, 10, 17, 18, 40)},
         "windowAfterLoopSize": {str(n): L.chain_window(n, T) for n in (1, 2, 3, 5, 8, 12)}}

out = {"_note": "Generated by tools/gen_test_vectors.py from tools/loop_reference.py and data/tuning.json. Do not edit by hand. Regenerate whenever tuning changes; tools/validate.py fails if this file is stale.",
       "tuning": {k: T[k] for k in ("lifetime", "maxLength", "spacing", "snapRadius", "snapMinPath", "minPerimeter", "minArea", "maxVertices", "tolerance", "inflate", "layerTolerance", "viewClockMaxAge", "pathGapMax")},
       "closure": closure, "containment": contain, "validation": validation, "resolution": resolution, "scoring": scoring, "bank": banks, "chain": chain}
(ROOT / "data/test_vectors.json").write_text(json.dumps(out, indent=1) + "\n")
for c in closure: print(f"closure   {c['name']:24} {c['expect']}")
for v in validation: print(f"validate  {v['name']:24} {v['expect']}")
for v in resolution: print(f"resolve   {v['name']:28} {v['expect']}")
for v in scoring: print(f"score     {v['name']:26} {v['expect']}")
print("bank", [(b["name"], b["expect"]) for b in banks]); print(chain)
