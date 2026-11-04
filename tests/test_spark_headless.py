"""Boot the real SPARK STAMPEDE scripts inside the headless fake Roblox engine.

Usage: python tests/test_spark_headless.py [--luau PATH] [--scenario NAME ...] [--keep]

Copies tests/engine/*.luau into a temp folder, generates Sources.luau from the
current game/** files, and runs each tests/engine/Scenario*.luau with the
official Luau CLI. Exit code is nonzero if any scenario fails or errors.
Proves script/API correctness against the Roblox API dump and server game
logic over virtual time; NOT physics, rendering, replication or real DataStores.
"""
from pathlib import Path
import argparse
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / "tests" / "engine"


def long_string(value: str) -> str:
    eq = "="
    while "]" + eq + "]" in value:
        eq += "="
    return "[" + eq + "[\n" + value + "]" + eq + "]"


def sources_module() -> str:
    lines = ["-- GENERATED per run from game/**; not committed.", "return {"]
    for path in sorted((ROOT / "game").rglob("*.luau")):
        relative = path.relative_to(ROOT / "game").as_posix()
        text = path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
        lines.append(f'["{relative}"]=' + long_string(text) + ",")
    lines.append("}")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--luau", type=Path, default=ROOT / ".tools" / "luau" / "luau")
    parser.add_argument("--scenario", action="append", default=[])
    parser.add_argument("--keep", action="store_true")
    parser.add_argument("--timeout", type=int, default=600)
    args = parser.parse_args()
    if not (ENGINE / "RobloxApi.luau").exists():
        print("tests/engine/RobloxApi.luau missing: run python tools/gen_roblox_api.py")
        return 2
    scenarios = sorted(ENGINE.glob("Scenario*.luau"))
    if args.scenario:
        scenarios = [s for s in scenarios if any(name in s.stem for name in args.scenario)]
    workdir = Path(tempfile.mkdtemp(prefix="spark-headless-"))
    failures = 0
    try:
        for file in ENGINE.glob("*.luau"):
            shutil.copyfile(file, workdir / file.name)
        (workdir / "Sources.luau").write_text(sources_module(), encoding="utf-8")
        for scenario in scenarios:
            started = time.time()
            try:
                result = subprocess.run([str(args.luau), str(workdir / scenario.name)], cwd=workdir,
                                        capture_output=True, text=True, timeout=args.timeout)
                output, code = result.stdout + result.stderr, result.returncode
            except subprocess.TimeoutExpired as error:
                output, code = (error.stdout or "") if isinstance(error.stdout, str) else "", 124
            print(output.rstrip())
            status = "PASS" if code == 0 else "FAIL"
            failures += code != 0
            print(f"{status} {scenario.stem} exit={code} wall={time.time() - started:.1f}s")
    finally:
        if args.keep:
            print(f"kept {workdir}")
        else:
            shutil.rmtree(workdir, ignore_errors=True)
    print(f"SparkHeadless: {len(scenarios) - failures}/{len(scenarios)} scenarios passed "
          "(fake engine: API-validated scripts, virtual time; NOT physics/rendering/replication/real DataStore)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
