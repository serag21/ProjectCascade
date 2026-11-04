"""Run the client's marked pure blocks in the official Luau CLI (no Studio).

Ports tests/SparkClientLayoutSmoke.ps1 and tests/SparkStarterVisibilitySmoke.ps1
(PowerShell is unavailable in the cloud session) and adds checks for the combo
meter rectangle, the menu tab strip geometry and the UI tier labels.
NOT TESTED: rendering, font measurement, CoreGui bounds, touch input, gamepad focus.

Usage: python tests/test_spark_client_blocks.py [--luau PATH]
"""
from pathlib import Path
import argparse
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CLIENT = ROOT / "game/StarterPlayer/StarterPlayerScripts/Spark"

LAYOUT_CHECKS = r'''
local function overlap(a,b)
    return a.x<b.x+b.w and b.x<a.x+a.w and a.y<b.y+b.h and b.y<a.y+a.h
end
local cases={
    {320,480,true},{320,532,true},{360,604,true},{390,808,true},
    {568,284,true},{667,339,true},{844,354,true},{1024,732,true},
    {320,480,false},{1280,684,false},{1920,1044,false},
    {600,320,true},{700,500,false},{640,360,false},{1366,768,true},
}
local checks=0
for _,case in ipairs(cases) do
    local width,height,touch=table.unpack(case)
    local layout=layoutFor(width,height,touch)
    local id=string.format('%dx%d touch=%s',width,height,tostring(touch))
    for name,r in pairs(layout) do
        assert(r.x>=0 and r.y>=0 and r.x+r.w<=width and r.y+r.h<=height,'Out of bounds: '..name..' '..id)
        assert(r.w>0 and r.h>0,'Degenerate rect: '..name..' '..id)
        checks+=1
    end
    assert(not overlap(layout.capture,layout.dash),'Action buttons overlap '..id)
    checks+=1
    -- Combo meter never covers controls, the objective, the menu button or the bank guide.
    for _,key in ipairs({'capture','dash','bank','objective','collection'}) do
        assert(not overlap(layout.combo,layout[key]),'Combo conflict: '..key..' '..id)
        checks+=1
    end
    assert(layout.combo.w>=100,'Combo too narrow to read '..id); checks+=1
    if touch then
        -- Conservative reserved boxes, not a claim about live CoreGui geometry.
        local thumbstick={x=0,y=height-160,w=160,h=160}
        local jump={x=width-122,y=height-104,w=122,h=104}
        for _,key in ipairs({'capture','dash','bank','combo'}) do
            local r=layout[key]
            assert(not overlap(r,thumbstick),'Thumbstick reserved-area conflict: '..key..' '..id)
            assert(not overlap(r,jump),'Jump reserved-area conflict: '..key..' '..id)
            checks+=2
        end
        for _,key in ipairs({'capture','dash','bank'}) do
            local r=layout[key]
            assert(not overlap(r,layout.objective),'Objective conflict: '..key..' '..id)
            assert(not overlap(r,layout.collection),'Collection-button conflict: '..key..' '..id)
            checks+=2
        end
        assert(not overlap(layout.bank,layout.capture) and not overlap(layout.bank,layout.dash),'Bank guide conflict '..id)
        checks+=1
    end
end
print(string.format('PASS pure client layout: %d usable-canvas cases, %d geometric assertions',#cases,checks))
'''

VISIBILITY_CHECKS = r'''
local function signal()
    local callbacks={}
    return {
        Connect=function(_,callback)
            local key={}; callbacks[key]=callback
            return {Disconnect=function() callbacks[key]=nil end}
        end,
        Fire=function(_,...) for _,callback in pairs(callbacks) do callback(...) end end,
        Count=function() local n=0; for _ in pairs(callbacks) do n+=1 end; return n end,
    }
end
local function item(class,properties)
    properties.IsA=function(_,kind) return class==kind end
    return properties
end
local changed,added,removed=signal(),signal(),signal()
local body=item('BasePart',{LocalTransparencyModifier=.25})
local cue=item('BillboardGui',{Enabled=true})
local dormantCue=item('BillboardGui',{Enabled=false})
local model={owner=nil,items={body,cue,dormantCue},DescendantAdded=added,DescendantRemoving=removed}
function model:GetAttribute() return self.owner end
function model:GetAttributeChangedSignal() return changed end
function model:GetDescendants() return self.items end
local disconnect=watchStarter(model,101)
local checks=0
local function check(condition,message) assert(condition,message); checks+=1 end
check(body.LocalTransparencyModifier==.25 and cue.Enabled,'Shared herd must remain visible')
model.owner=101; changed:Fire()
check(body.LocalTransparencyModifier==.25 and cue.Enabled,'Own starters must remain visible')
model.owner=202; changed:Fire()
check(body.LocalTransparencyModifier==1 and not cue.Enabled,'Late owner replication must mask foreign starters')
local latePart=item('BasePart',{LocalTransparencyModifier=0})
local lateCue=item('BillboardGui',{Enabled=true})
table.insert(model.items,latePart); added:Fire(latePart)
table.insert(model.items,lateCue); added:Fire(lateCue)
check(latePart.LocalTransparencyModifier==1 and not lateCue.Enabled,'Late descendants must also be masked')
changed:Fire()
model.owner=101; changed:Fire()
check(body.LocalTransparencyModifier==.25 and cue.Enabled,'Repeated masks must preserve original presentation')
check(not dormantCue.Enabled,'Originally disabled billboard must stay disabled')
check(latePart.LocalTransparencyModifier==0 and lateCue.Enabled,'New descendants must restore for their owner')
model.owner=202; changed:Fire()
removed:Fire(latePart); table.remove(model.items,4)
check(latePart.LocalTransparencyModifier==0,'Removed descendants must not carry a local mask elsewhere')
disconnect()
check(body.LocalTransparencyModifier==.25 and cue.Enabled and lateCue.Enabled,'Untracking must restore presentation')
check(changed:Count()==0 and added:Count()==0 and removed:Count()==0,'Untracking must disconnect all model listeners')
model.owner=nil; changed:Fire()
check(body.LocalTransparencyModifier==.25,'Disconnected listener must not mutate presentation')
print(string.format('PASS starter visibility: %d assertions with event doubles',checks))
'''

PURE_UI = r'''
local Color3={fromRGB=function(r,g,b) return {r,g,b} end,new=function(r,g,b) return {r,g,b} end}
local Ui=(function()
UI_SOURCE
end)()
local Menu={}
TAB_GEOMETRY
local n=0
local function check(ok,m) assert(ok,m); n+=1 end
check(Ui.tier(1).label=="x1" and Ui.tier(4).label=="x4 STAMPEDE!" and Ui.tier(99).label=="x4 STAMPEDE!" and Ui.tier(nil).label=="x1","Tier labels are text")
check(Ui.tier(0/0).label=="x1" or Ui.tier(0/0).label~=nil,"NaN tier safe")
for m=1,4 do check(Ui.tier(m).label:find("x"..m)~=nil,"Tier text matches multiplier") end
check(Ui.clock(65)=="1:05" and Ui.clock(-3)=="0:00" and Ui.clock(nil)=="0:00","Clock")
check(Ui.get({a={b=3}},"a","b")==3 and Ui.get({a=1},"a","b")==nil and Ui.get(nil,"x")==nil,"Safe nested get")
for _,medal in ipairs({"Radiant","Gold","Silver","Bronze","Unranked"}) do check(Ui.medals[medal] and Ui.medals[medal].label,"Medal "..medal) end
for available=208,1200,16 do
    local g=Menu.tabGeometry(available,7)
    check(g.width>=80,"Tabs readable at "..available)
    check(g.scroll or g.width*7<=available,"Fixed tabs fit at "..available)
    check(not g.scroll or g.canvas==g.width*7,"Scroll canvas covers tabs")
end
print("PASS client pure UI helpers: "..n.." assertions")
'''


def block(source, start, end):
    match = re.search(r"(?s)" + re.escape(start) + r"[^\n]*\n(.*?)" + re.escape(end), source)
    if not match:
        raise SystemExit(f"Missing block {start}")
    return match.group(1)


def run(luau, code, name):
    with tempfile.TemporaryDirectory(prefix="spark-client-") as directory:
        path = Path(directory) / f"{name}.luau"
        path.write_text(code, encoding="utf-8")
        result = subprocess.run([str(luau), str(path)], capture_output=True, text=True, timeout=30)
        print((result.stdout + result.stderr).strip())
        return result.returncode


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--luau", type=Path, default=ROOT / ".tools/luau/luau")
    args = parser.parse_args()
    client = (CLIENT / "Client.client.luau").read_text(encoding="utf-8")
    failures = 0
    failures += run(args.luau, block(client, "-- BEGIN PURE LAYOUT", "-- END PURE LAYOUT") + "\n" + LAYOUT_CHECKS, "layout") != 0
    failures += run(args.luau, block(client, "-- BEGIN STARTER VISIBILITY", "-- END STARTER VISIBILITY") + "\n" + VISIBILITY_CHECKS, "visibility") != 0
    ui = (CLIENT / "Ui.luau").read_text(encoding="utf-8")
    menu = (CLIENT / "Menu.luau").read_text(encoding="utf-8")
    geometry = re.search(r"(?s)(function Menu\.tabGeometry.*?\nend\n)", menu)
    if not geometry:
        raise SystemExit("Missing Menu.tabGeometry")
    failures += run(args.luau, PURE_UI.replace("UI_SOURCE", ui).replace("TAB_GEOMETRY", geometry.group(1)), "pureui") != 0
    print("NOT TESTED: Roblox rendering, font measurement, CoreGui bounds, touch input, gamepad focus or replication")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
