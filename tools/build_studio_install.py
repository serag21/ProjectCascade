"""Build a deterministic Studio MCP installer. Does not connect, publish or upload."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "game"
OUT = ROOT / "build"
PLACE_ID = 127090454461830


def quote(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def long_string(value: str) -> str:
    eq = "="
    while "]" + eq + "]" in value:
        eq += "="
    # Luau strips the first newline after a long-string opener. Add that newline
    # explicitly so a source file's own leading newline is preserved exactly.
    return "[" + eq + "[\n" + value + "]" + eq + "]"


def main():
    files = sorted(SOURCE.rglob("*.luau"))
    assert files, "No staged source"
    compiler = ROOT / ".tools" / "luau" / "luau-compile.exe"
    if not compiler.exists():
        raise SystemExit("Install the official Luau compiler into .tools/luau before building")
    compiled = subprocess.run([str(compiler), "--null", str(ROOT / "tools" / "StudioInstaller.luau"), *map(str, files)], capture_output=True, text=True)
    if compiled.returncode:
        raise SystemExit(compiled.stdout + compiled.stderr)
    OUT.mkdir(exist_ok=True)
    manifest = []
    chunks = []
    runtime_path = ROOT / "tools" / "StudioInstaller.luau"
    for path in files:
        source = path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
        relative = path.relative_to(SOURCE)
        name = path.stem
        kind = "ModuleScript"
        if name.endswith(".server"):
            kind, name = "Script", name[:-7]
        elif name.endswith(".client"):
            # StarterPlayerScripts must use a LocalScript, avoiding template execution.
            kind, name = "LocalScript", name[:-7]
        parts = [*relative.parts[:-1], name]
        digest = hashlib.sha256(source.encode("utf-8")).hexdigest()
        manifest.append({"file": relative.as_posix(), "path": ".".join(parts), "class": kind, "sha256": digest, "bytes": len(source.encode("utf-8"))})
        chunks.append("{parts={" + ",".join(map(quote, parts)) + "},class=" + quote(kind) + ",source=" + long_string(source) + ",sha256=" + quote(digest) + "}")
    runtime = runtime_path.read_text(encoding="utf-8")
    installer = (
        "-- Generated from Git. Edit-mode only; no publishing.\n"
        "local installBuild=(function()\n" + runtime + "\nend)()\n"
        "local entries={\n" + ",\n".join(chunks) + "\n}\n"
        "return installBuild({game=game,Instance=Instance,Enum=Enum,task=task},entries," + str(PLACE_ID) + ")\n"
    )
    (OUT / "install-spark.luau").write_text(installer, encoding="utf-8", newline="\n")
    (OUT / "spark-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"compiled": len(files), "installer": str(OUT / "install-spark.luau"), "manifest": str(OUT / "spark-manifest.json")}))


if __name__ == "__main__":
    main()
