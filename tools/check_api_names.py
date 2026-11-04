"""Static Roblox API name check for game Luau against the public API dump.

Checks every literal Instance.new("Class"), GetService("Service") and Enum.Type.Item
in game/** exists in the Roblox API dump (and that Instance.new classes are
creatable). Catches typos that compile fine but fail at runtime in Studio.

Data: .tools/api/Full-API-Dump.json from
https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Full-API-Dump.json
Usage: python tools/check_api_names.py [--dump PATH]
"""
from pathlib import Path
import argparse
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dump", type=Path, default=ROOT / ".tools" / "api" / "Full-API-Dump.json")
    args = parser.parse_args()
    if not args.dump.exists():
        print(f"BLOCKED: API dump missing at {args.dump}; download it from the URL in this file's docstring")
        return 2
    dump = json.loads(args.dump.read_text(encoding="utf-8"))
    classes = {c["Name"]: c for c in dump["Classes"]}
    enums = {e["Name"]: {i["Name"] for i in e["Items"]} for e in dump["Enums"]}
    problems, checked = [], 0
    for path in sorted((ROOT / "game").rglob("*.luau")):
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            code = line.split("--", 1)[0]
            where = f"{path.relative_to(ROOT).as_posix()}:{number}"
            for name in re.findall(r'Instance\.new\(\s*"(\w+)"', code):
                checked += 1
                info = classes.get(name)
                tags = set(info.get("Tags", []) or []) if info else set()
                if not info:
                    problems.append(f"{where}: unknown class {name}")
                elif "NotCreatable" in tags or "Service" in tags:
                    problems.append(f"{where}: class {name} is not creatable")
            for name in re.findall(r'GetService\(\s*"(\w+)"', code):
                checked += 1
                if name not in classes:
                    problems.append(f"{where}: unknown service {name}")
            for enum, item in re.findall(r"\bEnum\.(\w+)\.(\w+)", code):
                checked += 1
                if enum not in enums:
                    problems.append(f"{where}: unknown enum {enum}")
                elif item not in enums[enum] and item not in ("Name", "Value", "EnumType"):
                    problems.append(f"{where}: unknown item Enum.{enum}.{item}")
    for problem in problems:
        print("FAIL", problem)
    print(f"check_api_names: {checked} references checked, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
