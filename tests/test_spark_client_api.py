"""Check client Luau against the public Roblox API dump (data only, offline).

Validates: Instance.new/make class names, property keys passed to make(),
Enum.Type.Item references and every `.Name =` style property assignment name
(must exist on at least one class). This catches typos that compilation cannot.
It does NOT prove rendering, layout, behaviour or that values are sensible.

Usage: python tests/test_spark_client_api.py [--dump .tools/api/Full-API-Dump.json]
"""
from pathlib import Path
import argparse
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
FILES = sorted((ROOT / "game/StarterPlayer/StarterPlayerScripts/Spark").glob("*.luau"))
# Assignment targets that are Luau tables in our own code, not engine properties.
OWN_TABLES = {"Effects", "Menu", "renderers", "cooldownUntil", "Ui", "self"}
OWN_FIELDS = {
    "selected", "boardKind", "boardBiome", "tagNext", "tagSerial", "burstCount", "serial", "visible", "center",
    "target", "radius", "active", "Fill",
}


def load(dump_path):
    data = json.loads(dump_path.read_text(encoding="utf-8"))
    classes = {c["Name"]: c for c in data["Classes"]}
    enums = {e["Name"]: {i["Name"] for i in e["Items"]} for e in data["Enums"]}

    def members(name):
        found = set()
        while name and name in classes:
            for m in classes[name]["Members"]:
                found.add(m["Name"])
            name = classes[name].get("Superclass")
        return found

    every_property = {m["Name"] for c in data["Classes"] for m in c["Members"] if m["MemberType"] == "Property"}
    return classes, enums, members, every_property


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dump", type=Path, default=ROOT / ".tools/api/Full-API-Dump.json")
    args = parser.parse_args()
    if not args.dump.exists():
        print("BLOCKED: API dump missing; download Full-API-Dump.json from MaximumADHD/Roblox-Client-Tracker into .tools/api")
        return 2
    classes, enums, members, every_property = load(args.dump)
    problems, checks = [], 0
    for path in FILES:
        text = path.read_text(encoding="utf-8")
        rel = path.relative_to(ROOT).as_posix()
        for match in re.finditer(r'(?:make|Instance\.new)\("(\w+)"\s*(?:,\s*[^,{)]+\s*,\s*\{([^{}]*)\})?', text):
            cls, props = match.group(1), match.group(2)
            checks += 1
            if cls not in classes:
                problems.append(f"{rel}: unknown class {cls}")
                continue
            if props:
                available = members(cls)
                for key in re.findall(r"(?:^|,|\{)\s*(\w+)\s*=", props):
                    checks += 1
                    if key not in available:
                        problems.append(f"{rel}: {cls} has no property {key}")
        for type_name, item in re.findall(r"Enum\.(\w+)\.(\w+)", text):
            checks += 1
            if type_name not in enums or item not in enums[type_name]:
                problems.append(f"{rel}: unknown Enum.{type_name}.{item}")
        for receiver, name in re.findall(r"\b(\w+)\.([A-Z]\w*)\s*=(?!=)", text):
            if receiver in OWN_TABLES:
                continue
            checks += 1
            if name not in every_property and name not in OWN_FIELDS:
                problems.append(f"{rel}: '.{name} =' is not a Roblox property")
        for svc in re.findall(r'GetService\("(\w+)"\)', text):
            checks += 1
            if svc not in classes:
                problems.append(f"{rel}: unknown service {svc}")
    for p in problems:
        print("FAIL", p)
    print(f"SparkClientApi: {len(FILES)} files, {checks} API references checked, {len(problems)} problems (Roblox API dump; not rendering)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
