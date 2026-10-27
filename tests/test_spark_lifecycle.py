"""Run the production Main.server.luau lifecycle block in the real Luau CLI.

This extracts the exact pure helper block, rather than maintaining a second
implementation in a mock. It exercises tracking and revision semantics only;
Roblox shutdown scheduling and actual DataStore latency still require Studio QA.

Usage: python tests/test_spark_lifecycle.py [--luau PATH]
"""
from pathlib import Path
import argparse
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CASES = r'''
local count=0
local function test(name,run) run();count+=1;print("PASS "..name) end
test("detached removal finalizer remains tracked after active session removal",function()
    local work=Lifecycle.new();local session={};local active={player=session}
    assert(Lifecycle.beginFinalize(work,session));active.player=nil
    work.closing=true
    assert(Lifecycle.pending(work)==1 and next(active)==nil)
    Lifecycle.finishFinalize(work,session);assert(Lifecycle.pending(work)==0)
end)
test("shutdown waits for a pending load and its subsequent lease release",function()
    local work=Lifecycle.new();local session={}
    assert(Lifecycle.beginLoad(work,session));work.closing=true
    assert(Lifecycle.pending(work)==1)
    assert(Lifecycle.finishLoad(work,session,true)=="finalize")
    assert(Lifecycle.pending(work)==1 and work.finalizers[session])
    assert(Lifecycle.beginFinalize(work,session));assert(Lifecycle.pending(work)==1)
    Lifecycle.finishFinalize(work,session);assert(Lifecycle.pending(work)==0)
end)
test("player leaving during load still releases the acquired lease",function()
    local work=Lifecycle.new();local session={}
    Lifecycle.beginLoad(work,session);session.detached=true
    assert(Lifecycle.finishLoad(work,session,true)=="finalize")
    assert(Lifecycle.pending(work)==1)
end)
test("closing rejects new loads and failed late loads need no release",function()
    local work=Lifecycle.new();local first={};local second={}
    Lifecycle.beginLoad(work,first);work.closing=true
    assert(not Lifecycle.beginLoad(work,second))
    assert(Lifecycle.finishLoad(work,first,false)=="discard")
    assert(Lifecycle.pending(work)==0)
end)
test("ordinary load becomes active without residual pending work",function()
    local work=Lifecycle.new();local session={}
    Lifecycle.beginLoad(work,session)
    assert(Lifecycle.finishLoad(work,session,true)=="active" and Lifecycle.pending(work)==0)
end)
test("concurrent removal and shutdown do not start a second finalizer",function()
    local work=Lifecycle.new();local session={}
    assert(Lifecycle.beginFinalize(work,session))
    assert(not Lifecycle.beginFinalize(work,session) and Lifecycle.pending(work)==1)
    Lifecycle.finishFinalize(work,session)
    assert(not Lifecycle.beginFinalize(work,session) and Lifecycle.pending(work)==0)
end)
test("multiple detached saves and pending loads remain independently tracked",function()
    local work=Lifecycle.new();local a,b,c={},{},{}
    Lifecycle.beginLoad(work,a);Lifecycle.beginLoad(work,b);Lifecycle.beginFinalize(work,c)
    assert(Lifecycle.pending(work)==3)
    work.closing=true;Lifecycle.finishLoad(work,a,true);Lifecycle.finishLoad(work,b,false)
    assert(Lifecycle.pending(work)==2)
    Lifecycle.finishFinalize(work,c);assert(Lifecycle.pending(work)==1)
    Lifecycle.beginFinalize(work,a);Lifecycle.finishFinalize(work,a);assert(Lifecycle.pending(work)==0)
end)
test("new progress during an in-flight save must not display Saved",function()
    local session={revision=0,persistedRevision=0,dirty=false,saving=true}
    local snapshotRevision=session.revision
    Lifecycle.markDirty(session)
    assert(session.saveStatus=="Saving earlier progress")
    session.saving=false
    Lifecycle.saveResult(session,true,snapshotRevision,false)
    assert(session.dirty and session.saveStatus=="Save pending" and session.persistedRevision==0)
end)
test("next save of current revision clears dirty state",function()
    local session={revision=2,persistedRevision=1,dirty=true}
    Lifecycle.saveResult(session,true,2,false)
    assert(not session.dirty and session.saveStatus=="Saved" and session.persistedRevision==2)
    Lifecycle.markDirty(session)
    assert(session.revision==3 and session.dirty and session.saveStatus=="Save pending")
end)
test("failed save cannot advance the acknowledged revision",function()
    local session={revision=3,persistedRevision=1,dirty=true}
    Lifecycle.saveResult(session,false,3,false)
    assert(session.dirty and session.persistedRevision==1 and session.saveStatus=="Save retry pending")
end)
test("Studio acknowledgment is explicitly temporary and stale save cannot regress revision",function()
    local session={revision=3,persistedRevision=3,dirty=false}
    Lifecycle.saveResult(session,true,2,true)
    assert(session.persistedRevision==3 and session.saveStatus=="Studio test save")
    Lifecycle.markDirty(session);Lifecycle.saveResult(session,true,3,true)
    assert(session.dirty and session.saveStatus=="Save pending")
end)
test("actions stop at the acknowledged deadline, not response time",function()
    assert(Lifecycle.leaseValid(1120,1119))
    assert(not Lifecycle.leaseValid(1120,1120))
    assert(not Lifecycle.leaseValid(1120,1160))
    assert(not Lifecycle.leaseValid(nil,1000))
    assert(not Lifecycle.leaseValid(0/0,1000))
    assert(not Lifecycle.leaseValid(math.huge,1000))
end)
print("SparkLifecycle: "..count.." production-helper tests passed (NOT Roblox shutdown/DataStore integration)")
'''


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", type=Path, default=ROOT / ".tools" / "luau" / "luau.exe")
    args = parser.parse_args()
    source = (ROOT / "game" / "ServerScriptService" / "Spark" / "Main.server.luau").read_text(encoding="utf-8")
    begin, end = "-- BEGIN PURE LIFECYCLE", "-- END PURE LIFECYCLE"
    assert source.count(begin) == source.count(end) == 1, "Production lifecycle test markers missing or duplicated"
    block = source.split(begin, 1)[1].split(end, 1)[0]
    with tempfile.TemporaryDirectory(prefix="spark-lifecycle-") as directory:
        script = Path(directory) / "lifecycle.spec.luau"
        script.write_text(block + "\n" + CASES, encoding="utf-8")
        result = subprocess.run([str(args.luau), str(script)], cwd=ROOT, check=False)
        raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
