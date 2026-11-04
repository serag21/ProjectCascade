"""Cross-platform, fail-closed offline validation runner (Linux/macOS/Windows).

Mirrors tools/run_checks.ps1 for environments without PowerShell (e.g. cloud
sessions). Offline only: never installs into Studio, launches Studio, publishes
or touches game assets. Writes a JSON report with commands, exit codes,
timestamps, environment, git HEAD/dirty state and source hashes, and refuses to
report success if any tested source changed during the run.

Usage: python tools/run_checks.py [--report docs/qa/latest-checks.json] [--luau DIR]
"""
from pathlib import Path
import argparse
import datetime as dt
import hashlib
import json
import platform
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]


def sources():
    files = sorted(list((ROOT / "game").rglob("*.luau")) + list((ROOT / "tests").rglob("*.luau"))
                   + list((ROOT / "tests").glob("*.py")) + list((ROOT / "tools").glob("*.py"))
                   + list((ROOT / "tools").glob("*.luau")))
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}


def git(*args):
    try:
        return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, timeout=30).stdout.strip()
    except Exception as error:  # noqa: BLE001 - recorded, not fatal
        return f"unavailable: {error}"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", default="docs/qa/latest-checks.json")
    parser.add_argument("--luau", type=Path, default=ROOT / ".tools" / "luau")
    parser.add_argument("--timeout", type=int, default=600)
    parser.add_argument("--skip-slow", action="store_true", help="skip suites tagged slow (none by default)")
    args = parser.parse_args()
    exe = ".exe" if platform.system() == "Windows" else ""
    luau, compiler = args.luau / f"luau{exe}", args.luau / f"luau-compile{exe}"
    started = dt.datetime.now(dt.timezone.utc)
    before = sources()
    checks = []

    def run(check_id, command, expected=0):
        t0 = time.monotonic()
        try:
            result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=args.timeout)
            code, out = result.returncode, (result.stdout + result.stderr)
            timed_out = False
        except subprocess.TimeoutExpired as error:
            code, out, timed_out = 124, str(error), True
        except OSError as error:
            code, out, timed_out = 127, str(error), False
        tail = "\n".join(out.strip().splitlines()[-6:])
        checks.append({"id": check_id, "command": [str(c) for c in command], "exit_code": code,
                       "expected_exit_code": expected, "passed": code == expected, "timed_out": timed_out,
                       "seconds": round(time.monotonic() - t0, 3), "output_tail": tail})
        print(("PASS " if code == expected else "FAIL ") + check_id + ("" if code == expected else "\n" + tail))

    for path in sorted((ROOT / "game").rglob("*.luau")):
        run("compile:" + path.relative_to(ROOT).as_posix(), [str(compiler), "--null", str(path)])
    run("lint:undefined-globals-and-members", [sys.executable, "tools/lint_luau.py"])
    run("api:class-service-enum-names", [sys.executable, "tools/check_api_names.py"])
    for path in sorted((ROOT / "tests").glob("*.spec.luau")):
        if path.name.startswith("Cascade"):
            continue  # archived Cascade suite needs Studio globals; not part of Spark
        run("suite:" + path.relative_to(ROOT).as_posix(), [str(luau), str(path)])
    for path in sorted((ROOT / "tests").glob("test_*.py")):
        run("python-suite:" + path.relative_to(ROOT).as_posix(), [sys.executable, str(path)])
    run("audio-format-and-manifest", [sys.executable, "tools/generate_audio.py", "--verify"])
    run("studio-installer-build", [sys.executable, "tools/build_studio_install.py"])
    # Fail-closed probe: the runner must record a failing child as a failure.
    run("runner-fail-closed-probe", [sys.executable, "-c", "import sys; sys.exit(3)"], expected=3)

    after = sources()
    changed = sorted(k for k in set(before) | set(after) if before.get(k) != after.get(k))
    finished = dt.datetime.now(dt.timezone.utc)
    failed = [c["id"] for c in checks if not c["passed"]]
    report = {
        "runner": "tools/run_checks.py", "started_utc": started.isoformat(), "finished_utc": finished.isoformat(),
        "environment": {"platform": platform.platform(), "python": sys.version.split()[0], "luau": str(luau),
                        "studio": "not used (offline)"},
        "git": {"head": git("rev-parse", "HEAD"), "branch": git("rev-parse", "--abbrev-ref", "HEAD"),
                "dirty": bool(git("status", "--porcelain"))},
        "summary": {"total": len(checks), "passed": len(checks) - len(failed), "failed": len(failed),
                    "failed_ids": failed, "sources_changed_during_run": changed},
        "source_sha256": after, "checks": checks,
        "scope_note": "Offline evidence only. Not Studio rendering, physics, real DataStore, audio playback, "
                      "multi-client replication, device performance or human usability.",
    }
    report_path = ROOT / args.report
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    ok = not failed and not changed
    print(f"run_checks: {len(checks) - len(failed)}/{len(checks)} passed; sources changed during run: {len(changed)}; report {args.report}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
