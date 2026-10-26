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
    return "[" + eq + "[" + value + "]" + eq + "]"


def main():
    files = sorted(SOURCE.rglob("*.luau"))
    assert files, "No staged source"
    compiler = ROOT / ".tools" / "luau" / "luau-compile.exe"
    if not compiler.exists():
        raise SystemExit("Install the official Luau compiler into .tools/luau before building")
    compiled = subprocess.run([str(compiler), "--null", *map(str, files)], capture_output=True, text=True)
    if compiled.returncode:
        raise SystemExit(compiled.stdout + compiled.stderr)
    OUT.mkdir(exist_ok=True)
    manifest = []
    chunks = []
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
        chunks.append("install({" + ",".join(map(quote, parts)) + "}," + quote(kind) + "," + long_string(source) + "," + quote(digest) + ")\ntask.wait()")
    prefix = f'''-- Generated from Git source. Local Edit-mode install only; never publish.
assert(game.PlaceId == {PLACE_ID}, "Unexpected place; refusing to install")
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before installation")
local HttpService=game:GetService("HttpService")
local sync=game:GetService("InstanceFileSyncService")
local installed={{}}
local function install(parts,className,source,hash)
    local parent=game:GetService(parts[1])
    for index=2,#parts-1 do
        local child=parent:FindFirstChild(parts[index])
        if not child then child=Instance.new("Folder");child.Name=parts[index];child.Parent=parent end
        parent=child
    end
    local existing=parent:FindFirstChild(parts[#parts])
    if existing then
        assert(existing.ClassName==className,"Unexpected class at "..existing:GetFullName())
        assert(sync:GetStatus(existing)==Enum.InstanceFileSyncStatus.NotSynced,"Spark must not have a second sync writer")
    end
    local item=existing or Instance.new(className)
    item.Name=parts[#parts]
    if item:IsA("BaseScript") then item.Enabled=false end
    item.Source=source
    if className=="Script" then item.RunContext=Enum.RunContext.Server end
    item:SetAttribute("SourceSHA256",hash)
    item.Parent=parent
    table.insert(installed,item)
end
'''
    suffix = '''
-- Preserve existing Cascade objects and source; only suspend the old runtime.
local recovery=game.ServerStorage:FindFirstChild("CascadeRecovery")
if not recovery then recovery=Instance.new("Folder");recovery.Name="CascadeRecovery";recovery.Parent=game.ServerStorage end
for _,container in ipairs({game.ServerScriptService:FindFirstChild("Cascade"),game.StarterPlayer.StarterPlayerScripts:FindFirstChild("Cascade")}) do
    if container then for _,item in ipairs(container:GetDescendants()) do
        if item:IsA("BaseScript") then
            if item:GetAttribute("CascadeOriginalEnabled")==nil then item:SetAttribute("CascadeOriginalEnabled",item.Enabled) end
            item.Enabled=false
        end
    end end
end
for _,name in ipairs({"Baseplate","SpawnLocation","Script"}) do
    local old=workspace:FindFirstChild(name)
    if old then
        if old:IsA("BaseScript") then old.Enabled=false end
        old.Parent=recovery
    end
end
for _,item in ipairs(installed) do if item:IsA("BaseScript") then item.Enabled=true end end
game:SetAttribute("SparkSourceMode","GitExplicitInstall")
local result={}
for _,item in ipairs(installed) do table.insert(result,{path=item:GetFullName(),bytes=#item.Source,sha256=item:GetAttribute("SourceSHA256")}) end
return HttpService:JSONEncode(result)
'''
    (OUT / "install-spark.luau").write_text(prefix + "\n".join(chunks) + suffix, encoding="utf-8", newline="\n")
    (OUT / "spark-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"compiled": len(files), "installer": str(OUT / "install-spark.luau"), "manifest": str(OUT / "spark-manifest.json")}))


if __name__ == "__main__":
    main()
