#!/usr/bin/env python3
"""Round model: what do different ways of playing a Meadow round earn?

A Monte-Carlo model, NOT a playtest. It answers one design question: under the scoring
rules in data/tuning.json, does repetitive low-skill play (farming single creatures)
beat herding? It uses the real Meadow layout (habitat and bank-ring coordinates), the
real species values, and the scoring functions in loop_reference.py. Player behaviour
(loop sizes, success rates, hesitation) is ASSUMED per archetype; the assumptions are
listed in ARCHETYPES and repeated in 10_PLAY_PATTERNS_AND_CATCH_RESOLUTION.md.

Usage: python3 design/fable/tools/play_model.py [--write]   (--write refreshes data/play_model_results.json)
"""
import json, math, random, sys
from pathlib import Path
import loop_reference as L

ROOT = Path(__file__).resolve().parents[1]
ARENA = json.loads((ROOT / "data/arenas/meadow.json").read_text())
SPECIES = {s["id"]: s for s in json.loads((ROOT / "data/creatures.json").read_text())["species"]}
TUNING = json.loads((ROOT / "data/tuning.json").read_text())
WALK = TUNING["movement"]["walkSpeed"]["value"]
ROUND = TUNING["round"]["playSeconds"]["value"]
RESPAWN = sum(TUNING["density"]["podRespawnSeconds"]["value"]) / 2

T2 = L.load_tuning()
# Rules as first published in db5dd1b, kept only to show what the change fixes.
T1 = dict(T2, sizeMult={1: 1.0, 2: 1.2, 3: 1.5, 4: 1.8, 5: 2.2, 6: 2.2, 7: 2.2, 8: 3.0},
          chainLinks=None, chainTiers=[[1, 1], [2, 2], [4, 3], [6, 4]], tightBase=60, tightPer=45, tightSolo=True, chainWindowPer=0.0)
T2["tightSolo"] = False

ARCHETYPES = {
    # group: how many of a pod one loop takes. overhead: seconds lost per loop to hesitation and lining up.
    # whiff: chance a loop catches nothing. p_species: chance a loop on that species works at all.
    # event numbers: creatures taken per loop from Bloom Burst (8 available) and the Stampede (14 pass).
    "beginner_single_pip": dict(label="Beginner: circles one Spark at a time", group="one", radius=9.0, slop=1.3, overhead=3.5,
        whiff=0.25, snap=0.05, tight=0.0, p_species={"pip": 1.0, "cubloom": 0.5, "bunvolt": 0.35, "flutter": 0.0},
        bank_at=3, bloom=[3], bloom_p=0.6, stampede=[3], merge=False),
    "competent_roundup": dict(label="Competent: rounds up whole pods", group="pod", radius=None, slop=1.1, overhead=1.2,
        whiff=0.08, snap=0.30, tight=0.35, p_species={"pip": 1.0, "cubloom": 0.85, "bunvolt": 0.6, "flutter": 0.4},
        bank_at=8, bloom=[6], bloom_p=0.7, stampede=[6, 3], merge=False),
    "optimizer_singles": dict(label="Optimizer A: expert hands, farms singles", group="one", radius=4.0, slop=1.0, overhead=0.4,
        whiff=0.03, snap=0.80, tight=1.0, p_species={"pip": 1.0, "cubloom": 1.0, "bunvolt": 0.9, "flutter": 0.8},
        bank_at=12, bloom=[1] * 8, bloom_p=1.0, stampede=[1] * 7, merge=False),
    "optimizer_herder": dict(label="Optimizer B: expert hands, merges pods, plans bank routes", group="pod", radius=None, slop=1.0, overhead=0.4,
        whiff=0.03, snap=0.80, tight=0.60, p_species={"pip": 1.0, "cubloom": 1.0, "bunvolt": 0.9, "flutter": 0.8},
        bank_at=12, bloom=[8], bloom_p=0.9, stampede=[9, 5], merge=True),
}
BLOOM = dict(start=30, end=44, at=(22, 26), values=[3] * 5 + [5] * 3)
STAMPEDE = dict(start=55, end=69, at=(-12, -48), values=[3, 4, 5, 3, 4, 3, 5, 3, 4, 3, 5, 3, 4, 3])
MERGE_PAIRS = [("lawn_s", "flowers"), ("grass", "pens_field")]
MERGE_COST = 3.5
SPAWN = (ARENA["spawn"]["x"], ARENA["spawn"]["z"])
RINGS = [(b["x"], b["z"]) for b in ARENA["bankRings"]]
HAB = {h["id"]: (h["x"], h["z"]) for h in ARENA["habitats"] if "x" in h}


def loop_seconds(n, a):
    radius = a["radius"] if a["radius"] else 4.5 + 1.2 * math.sqrt(n)
    return 2 * math.pi * radius / WALK * a["slop"], math.pi * radius * radius

def chain_after(state, n, T, now):
    if now > state["chain_until"]: state["links"] = 0
    if T["chainLinks"] is None:  # v1: one link per loop
        state["links"] += 1
    else:
        state["links"] += L.chain_links(n, T)
    state["chain_until"] = now + L.chain_window(n, T)
    return L.chain_mult(state["links"], T)

def play(name, T, seed):
    a = ARCHETYPES[name]; rng = random.Random(seed)
    pods = {p["habitat"] + ":" + p["species"]: dict(hab=p["habitat"], species=p["species"], left=p["count"], full=p["count"], back=0.0) for p in ARENA["pods"]}
    st = dict(t=0.0, pos=SPAWN, carry=[], links=0, chain_until=-99.0, loop_pts=0, bank_pts=0, style=0, loops=0, catching_loops=0,
              creatures=0, banks=0, singles=0, x4_time=0.0, by_phase=[0, 0, 0, 0], sizes=[])
    used = dict(bloom=0, stampede=0); last_snap = -99.0

    def phase(t): return 0 if t < 25 else 1 if t < 55 else 2 if t < 85 else 3
    def travel(to):
        d = math.hypot(to[0] - st["pos"][0], to[1] - st["pos"][1]); st["t"] += d / WALK; st["pos"] = to
    def bank():
        ring = min(RINGS, key=lambda r: math.hypot(r[0] - st["pos"][0], r[1] - st["pos"][1]))
        travel(ring)
        if st["t"] > ROUND: return
        pts, _ = L.bank_points(st["carry"], T)
        st["bank_pts"] += pts; st["by_phase"][phase(st["t"])] += pts; st["carry"] = []; st["banks"] += 1
        if T["chainLinks"] is not None and st["t"] <= st["chain_until"]: st["chain_until"] = st["t"] + T["chainWindow"]
    def do_loop(values, species_set, at, extra_time=0.0):
        nonlocal last_snap
        n = len(values); secs, loop_area = loop_seconds(n, a)
        travel(at); st["t"] += a["overhead"] + extra_time + secs
        if st["t"] > ROUND: return
        st["loops"] += 1
        if rng.random() < a["whiff"] or n == 0: return
        techs = set()
        if rng.random() < a["snap"] and st["t"] - last_snap >= 2.4: techs.add("SNAP"); last_snap = st["t"]
        tight_ok = (n >= 2 or T["tightSolo"]) and loop_area <= T["tightBase"] + T["tightPer"] * n
        if tight_ok and rng.random() < a["tight"]: techs.add("TIGHT")
        if len(species_set) >= 3: techs.add("MEDLEY")
        mult = chain_after(st, n, T, st["t"])
        if mult >= 4: st["x4_time"] += secs + a["overhead"]
        room = max(0, T["capacity"] - len(st["carry"])); kept = values[:room]
        base = sum(kept) + T["overflowScale"] * sum(values[room:])
        pts = base * L.size_mult(n, T) * (1 + T["techBonus"] * len(techs)) * mult * (T["finaleMult"] if st["t"] >= 85 else 1)
        pts = int(pts + 0.5)
        st["loop_pts"] += pts; st["by_phase"][phase(st["t"])] += pts; st["carry"] += kept
        st["catching_loops"] += 1; st["creatures"] += n; st["sizes"].append(n); st["singles"] += 1 if n == 1 else 0

    while st["t"] < ROUND:
        t = st["t"]
        if len(st["carry"]) >= a["bank_at"]: bank(); continue
        # scheduled opportunities first
        if BLOOM["start"] - 4 <= t < BLOOM["end"] and used["bloom"] < len(a["bloom"]):
            if t < BLOOM["start"]: travel(BLOOM["at"]); st["t"] = max(st["t"], BLOOM["start"])
            k = a["bloom"][used["bloom"]]; used["bloom"] += 1
            if rng.random() > a["bloom_p"]: k = max(1, k // 2)
            vals = BLOOM["values"][:k]; BLOOM_species = {"pip"} | ({"cubloom"} if k > 5 else set())
            do_loop(vals, BLOOM_species, BLOOM["at"])
            if k == 8 and st["sizes"] and st["sizes"][-1] == 8: st["style"] += 40
            continue
        if STAMPEDE["start"] - 5 <= t < STAMPEDE["end"] and used["stampede"] < len(a["stampede"]):
            if t < STAMPEDE["start"]:
                if len(st["carry"]) >= 6 and a["bank_at"] >= 8: bank()
                travel(STAMPEDE["at"]); st["t"] = max(st["t"], STAMPEDE["start"])
            k = a["stampede"][used["stampede"]]; used["stampede"] += 1
            do_loop(STAMPEDE["values"][:k], {"pip", "bunvolt", "cubloom"} if k >= 3 else {"pip"}, STAMPEDE["at"], extra_time=1.0)
            continue
        # otherwise the nearest live pod
        live = [p for p in pods.values() if p["left"] > 0 or t >= p["back"]]
        for p in live:
            if p["left"] == 0: p["left"] = p["full"]
        live = [p for p in live if a["p_species"][p["species"]] > 0]
        if not live: st["t"] += 1.0; continue
        p = min(live, key=lambda q: math.hypot(HAB[q["hab"]][0] - st["pos"][0], HAB[q["hab"]][1] - st["pos"][1]))
        sp = SPECIES[p["species"]]
        if rng.random() > a["p_species"][p["species"]]:
            do_loop([], set(), HAB[p["hab"]]); continue
        if a["group"] == "one":
            take = 1 if (name.startswith("optimizer") or rng.random() < 0.7) else min(2, p["left"])
            do_loop([sp["value"]] * take, {sp["id"]}, HAB[p["hab"]], extra_time=0.5 if p["left"] < p["full"] else 0)
            p["left"] -= take
        else:
            vals = [sp["value"]] * p["left"]; species = {sp["id"]}; extra = 0.0; partner = None
            if a["merge"]:
                for h1, h2 in MERGE_PAIRS:
                    other = h2 if p["hab"] == h1 else h1 if p["hab"] == h2 else None
                    cand = [q for q in pods.values() if q["hab"] == other and q["left"] > 0 and q["species"] != "flutter"]
                    if cand and len(vals) + cand[0]["left"] <= 7: partner = cand[0]
                if partner:
                    vals += [SPECIES[partner["species"]]["value"]] * partner["left"]; species.add(partner["species"]); extra = MERGE_COST
            if p["species"] == "bunvolt" and not name.startswith("optimizer") and rng.random() < 0.4: vals = vals[:1]
            do_loop(vals, species, HAB[p["hab"]], extra_time=extra + (3.0 if p["species"] == "flutter" else 0))
            p["left"] = 0
            if partner: partner["left"] = 0; partner["back"] = st["t"] + RESPAWN
        if p["left"] == 0: p["back"] = st["t"] + RESPAWN
    auto = sum(st["carry"])  # buzzer auto-bank at x1.0
    st["bank_pts"] += auto; st["by_phase"][3] += auto
    st["score"] = st["loop_pts"] + st["bank_pts"] + st["style"]
    return st

def summarise(name, T, runs=400):
    rows = [play(name, T, 1000 + i) for i in range(runs)]
    mean = lambda k: sum(r[k] for r in rows) / runs
    scores = sorted(r["score"] for r in rows)
    sizes = [n for r in rows for n in r["sizes"]]
    return {
        "label": ARCHETYPES[name]["label"], "score_mean": round(mean("score")), "score_p10": scores[runs // 10], "score_p90": scores[runs * 9 // 10],
        "loop_points": round(mean("loop_pts")), "bank_points_and_glow": round(mean("bank_pts")), "loops": round(mean("loops"), 1),
        "creatures": round(mean("creatures"), 1), "banks": round(mean("banks"), 1),
        "mean_loop_size": round(sum(sizes) / max(1, len(sizes)), 2), "single_loop_share": round(sum(1 for n in sizes if n == 1) / max(1, len(sizes)), 2),
        "seconds_at_x4": round(mean("x4_time"), 1),
        "score_by_phase": [round(sum(r["by_phase"][i] for r in rows) / runs) for i in range(4)],
    }

def run_all():
    return {rules: {name: summarise(name, T) for name in ARCHETYPES} for rules, T in (("v1_db5dd1b", T1), ("v2_current", T2))}

if __name__ == "__main__":
    out = run_all()
    for rules, table in out.items():
        print(f"\n{rules}")
        print(f"  {'archetype':22} {'score':>6} {'p10':>6} {'p90':>6} {'loopPts':>8} {'bank':>5} {'loops':>6} {'caught':>7} {'avg n':>6} {'singles':>8} {'x4 s':>6}  by phase")
        for name, r in table.items():
            print(f"  {name:22} {r['score_mean']:6} {r['score_p10']:6} {r['score_p90']:6} {r['loop_points']:8} {r['bank_points_and_glow']:5} {r['loops']:6} {r['creatures']:7} {r['mean_loop_size']:6} {r['single_loop_share']:8} {r['seconds_at_x4']:6}  {r['score_by_phase']}")
    if "--write" in sys.argv:
        (ROOT / "data/play_model_results.json").write_text(json.dumps({"_note": "Generated by tools/play_model.py --write. A model with assumed player behaviour, not playtest data.", "runsPerArchetype": 400, "results": out}, indent=2) + "\n")
        print("\nwrote data/play_model_results.json")
