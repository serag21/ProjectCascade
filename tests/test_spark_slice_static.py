"""Static acceptance checks for the loop redesign (WP-03/WP-04 "grep" items).

T-D1: no server-created physics constraint (the dash is client-predicted).
WP-04: Targeting has no callers under ServerScriptService; Capture is not bound
on the client; loop claims go through LoopService.
Offline text checks only: they prove the source shape, not runtime behaviour.
"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SERVER = sorted((ROOT / "game/ServerScriptService/Spark").glob("*.luau"))
CLIENT = sorted((ROOT / "game/StarterPlayer/StarterPlayerScripts/Spark").glob("*.luau"))


def code(path):
    # Strip line comments so documentation that names the removed APIs is allowed.
    return "\n".join(line.split("--", 1)[0] for line in path.read_text(encoding="utf-8").splitlines())


def main() -> int:
    problems, checks = [], 0
    constraint = re.compile(r'Instance\.new\("(LinearVelocity|BodyVelocity|VectorForce|AlignPosition|BodyPosition)"')
    for path in SERVER:
        text = code(path)
        checks += 1
        if constraint.search(text):
            problems.append(f"{path.name}: server creates a physics constraint (dash must be client-predicted)")
        checks += 1
        if re.search(r"\bTargeting\.", text) or re.search(r'require\([^)]*Targeting', text):
            problems.append(f"{path.name}: Targeting still has a caller on the server")
    main_text = code(ROOT / "game/ServerScriptService/Spark/Main.server.luau")
    checks += 1
    if "LoopService.validate" not in main_text or "LoopService.receive" not in main_text:
        problems.append("Main: loop claims must be received and validated through LoopService")
    checks += 1
    if re.search(r"local function capture\(|local function dashSweep\(", main_text):
        problems.append("Main: proximity capture or dash-through catching still exists")
    checks += 1
    if re.search(r"World\.creature\(|World\.gild\(", main_text):
        problems.append("Main: the server must not build creature Instances (T-N2, WP-06)")
    for path in CLIENT:
        text = code(path)
        checks += 1
        if re.search(r'BindAction\("SparkCapture"', text) or re.search(r'FireServer\("Capture"', text):
            problems.append(f"{path.name}: a catch input still exists")
    movement = code(ROOT / "game/StarterPlayer/StarterPlayerScripts/Spark/Movement.luau")
    checks += 1
    if 'Instance.new("LinearVelocity")' not in movement:
        problems.append("Movement: the client-side dash actuator is missing")
    for p in problems:
        print("FAIL", p)
    print(f"SparkSliceStatic: {checks} checks, {len(problems)} problems (source text; not runtime proof)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
