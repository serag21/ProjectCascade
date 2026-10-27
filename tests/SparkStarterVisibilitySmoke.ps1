param([string]$Luau='')
$ErrorActionPreference='Stop'
$repoRoot=Split-Path -Parent $PSScriptRoot
if (-not $Luau) { $Luau=Join-Path $repoRoot '.tools/luau/luau.exe' }
$source=Get-Content -LiteralPath (Join-Path $repoRoot 'game/StarterPlayer/StarterPlayerScripts/Spark/Client.client.luau') -Raw
$section=[regex]::Match($source,'(?s)-- BEGIN STARTER VISIBILITY[^\n]*\n(.*?)-- END STARTER VISIBILITY')
if (-not $section.Success) { throw 'Starter visibility section is missing' }
$checks=@'
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
print('NOT TESTED: Roblox replication timing, rendering or real multiplayer clients')
'@
$tempFile=Join-Path ([IO.Path]::GetTempPath()) ('spark-visibility-'+[guid]::NewGuid().ToString('N')+'.luau')
try {
    [IO.File]::WriteAllText($tempFile,$section.Groups[1].Value+"`n"+$checks,[Text.UTF8Encoding]::new($false))
    & $Luau $tempFile
    if ($LASTEXITCODE -ne 0) { throw "Starter visibility smoke failed: $LASTEXITCODE" }
} finally {
    if (Test-Path -LiteralPath $tempFile) { Remove-Item -LiteralPath $tempFile }
}
