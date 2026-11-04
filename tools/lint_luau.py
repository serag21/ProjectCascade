"""Undefined-variable gate for game Luau using the official luau-analyze.

luau-analyze has no Roblox type definitions here, so type errors about engine
types are expected noise and ignored. What it reliably finds is any global name
that is not a Roblox engine global: a typo, a missing local, or a helper used
before declaration. Those fail this check. Lint warnings (shadowing etc.) are
reported but do not fail.

Usage: python tools/lint_luau.py [--analyze PATH]
"""
from pathlib import Path
import argparse
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
# Roblox engine globals and Luau builtins available to game scripts.
ROBLOX_GLOBALS = {
    "game", "workspace", "script", "plugin", "shared", "Instance", "Vector3", "Vector2", "CFrame", "Color3",
    "UDim", "UDim2", "Enum", "Rect", "Ray", "Region3", "BrickColor", "NumberSequence", "NumberSequenceKeypoint",
    "ColorSequence", "ColorSequenceKeypoint", "NumberRange", "TweenInfo", "PhysicalProperties", "Random",
    "DateTime", "task", "warn", "tick", "time", "wait", "delay", "spawn", "typeof", "elapsedTime", "settings",
    "UserSettings", "Font", "Faces", "Axes", "OverlapParams", "RaycastParams", "PathWaypoint", "SharedTable",
    "buffer", "debug", "utf8", "bit32", "vector",
}
GLOBAL = re.compile(r"^(?P<file>.+?):(?P<line>\d+):\S*: \(W\d+\) TypeError: Unknown global '(?P<name>[^']+)'")
LINT = re.compile(r"^(?P<file>.+?):(?P<line>\d+):\S*: \(W\d+\) (?P<kind>LocalShadow|LocalUnused|FunctionUnused|ImportUnused|UnreachableCode|UnknownGlobal|GlobalUsedAsLocal|SameLineStatement|MultiLineStatement|DuplicateLocal|DuplicateFunction|DuplicateCondition|UninitializedLocal|BuiltinGlobalWrite|PlaceholderRead|ImplicitReturn|FormatString|TableLiteral|MisleadingAndOr|ComparisonPrecedence)[^:]*: (?P<message>.*)$")


REQUIRE = re.compile(r"local\s+(\w+)\s*=\s*(?:if script then )?require\((?:[^()]*?[.:](?:WaitForChild\(\"(\w+)\"\))|[^()]*?\.(\w+))\)")


def module_members(path: Path) -> set:
    text = path.read_text(encoding="utf-8")
    names = set(re.findall(r"^\s*(?:local\s+)?function\s+\w+[.:](\w+)", text, re.M))
    names |= set(re.findall(r"^\s*\w+\.(\w+)\s*(?:=|\+=)", text, re.M))
    # Table-literal modules (Config): top-level keys one tab deep.
    names |= set(re.findall(r"^\t(\w+)\s*=", text, re.M))
    return names


def member_check(files) -> list:
    modules = {p.stem: p for p in (ROOT / "game").rglob("*.luau") if not p.stem.endswith((".server", ".client"))}
    problems = []
    for file in files:
        path = Path(file)
        text = path.read_text(encoding="utf-8")
        aliases = {}
        for match in REQUIRE.finditer(text):
            name = match.group(2) or match.group(3)
            if name in modules:
                aliases[match.group(1)] = name
        for alias, name in aliases.items():
            defined = module_members(modules[name])
            for number, line in enumerate(text.splitlines(), 1):
                code = line.split("--", 1)[0]
                for member in re.findall(r"(?<![\w.:])" + re.escape(alias) + r"[.:](\w+)", code):
                    if member not in defined:
                        problems.append(f"{path.relative_to(ROOT).as_posix()}:{number}: {alias}.{member} is not defined by {name}")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--analyze", type=Path, default=ROOT / ".tools" / "luau" / "luau-analyze")
    args = parser.parse_args()
    files = sorted(str(p) for p in (ROOT / "game").rglob("*.luau"))
    result = subprocess.run([str(args.analyze), "--formatter=plain", *files], capture_output=True, text=True, cwd=ROOT)
    output = (result.stdout + result.stderr).splitlines()
    unknown, lints = [], []
    for line in output:
        match = GLOBAL.match(line)
        if match and match["name"] not in ROBLOX_GLOBALS:
            unknown.append(f"{Path(match['file']).as_posix()}:{match['line']}: unknown global '{match['name']}'")
            continue
        lint = LINT.match(line)
        if lint:
            lints.append(f"{Path(lint['file']).as_posix()}:{lint['line']}: {lint['kind']}: {lint['message']}")
    unknown += member_check(files)
    for line in lints:
        print("LINT", line)
    for line in unknown:
        print("FAIL", line)
    print(f"lint_luau: {len(files)} files, {len(unknown)} undefined globals, {len(lints)} lint warnings")
    return 1 if unknown else 0


if __name__ == "__main__":
    sys.exit(main())
