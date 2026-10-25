param([string]$Luau = '')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $Luau) { $Luau = Join-Path $repoRoot '.tools/luau/luau.exe' }
if (-not (Test-Path -LiteralPath $Luau)) { throw "Luau CLI missing: $Luau" }
$mock = @'
-- Offline constructor smoke only: no rendering, Roblox physics, or engine API validation.
local registry = {}
local vectors = {}
vectors.__index = function(self, key)
    if key == "Magnitude" then return math.sqrt(self.X^2 + self.Y^2 + self.Z^2) end
    return vectors[key]
end
local Vector3 = {}
function Vector3.new(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},vectors) end
Vector3.one=Vector3.new(1,1,1)
function vectors.__add(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
function vectors.__sub(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
function vectors.__mul(a,b)
    if type(a)=="number" then return Vector3.new(a*b.X,a*b.Y,a*b.Z) end
    if type(b)=="number" then return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
    return Vector3.new(a.X*b.X,a.Y*b.Y,a.Z*b.Z)
end
function vectors.__div(a,b) return Vector3.new(a.X/b,a.Y/b,a.Z/b) end
local frames = {}
frames.__index=frames
local CFrame={}
local identity={1,0,0,0,1,0,0,0,1}
function CFrame.new(x,y,z)
    return setmetatable({Position=if type(x)=="table" then x else Vector3.new(x,y,z),rotation=identity},frames)
end
function frames.__mul(a,b)
    local r={}
    for i=1,3 do for j=1,3 do
        local v=0
        for k=1,3 do v += a.rotation[(i-1)*3+k]*b.rotation[(k-1)*3+j] end
        r[(i-1)*3+j]=v
    end end
    local br=b.Position
    local ar=a.rotation
    local out=CFrame.new(a.Position+Vector3.new(ar[1]*br.X+ar[2]*br.Y+ar[3]*br.Z,ar[4]*br.X+ar[5]*br.Y+ar[6]*br.Z,ar[7]*br.X+ar[8]*br.Y+ar[9]*br.Z))
    out.rotation=r
    return out
end
function CFrame.Angles(x,y,z)
    local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
    local rx,ry,rz=CFrame.new(),CFrame.new(),CFrame.new()
    rx.rotation={1,0,0,0,cx,-sx,0,sx,cx}
    ry.rotation={cy,0,sy,0,1,0,-sy,0,cy}
    rz.rotation={cz,-sz,0,sz,cz,0,0,0,1}
    return rx*ry*rz
end
function CFrame.lookAt(position, _target) return CFrame.new(position) end
CFrame.identity=CFrame.new()
local colors={}
colors.__index=colors
local Color3={}
function Color3.fromRGB(r,g,b)
    assert(r>=0 and r<=255 and g>=0 and g<=255 and b>=0 and b<=255,"Invalid RGB")
    return setmetatable({R=r,G=g,B=b},colors)
end
function colors:Lerp(other,t)
    return Color3.fromRGB(self.R+(other.R-self.R)*t,self.G+(other.G-self.G)*t,self.B+(other.B-self.B)*t)
end
local Enum=setmetatable({},{__index=function(self,key)
    local group=setmetatable({},{__index=function(_,item) return key.."."..item end})
    rawset(self,key,group)
    return group
end})
local UDim2={fromOffset=function(a,b) return {a,b} end,fromScale=function(a,b) return {a,b} end}
local UDim={new=function(a,b) return {a,b} end}
local Instance={}
function Instance.new(class)
    local object={ClassName=class,attributes={}}
    function object:SetAttribute(key,value) self.attributes[key]=value end
    function object:FindFirstChild(name)
        for _,child in registry do if child.Parent==self and child.Name==name then return child end end
        return nil
    end
    table.insert(registry,object)
    return object
end
local lighting=Instance.new("Lighting")
local workspace=Instance.new("Workspace")
local game={GetService=function(_,name) assert(name=="Lighting");return lighting end}
local yields=0
local task={wait=function() yields+=1 end}
'@
$configSource = Get-Content -LiteralPath (Join-Path $repoRoot 'game/ReplicatedStorage/Spark/Config.luau') -Raw
$worldSource = Get-Content -LiteralPath (Join-Path $repoRoot 'game/ServerScriptService/Spark/World.luau') -Raw
$checks = @'
local result=World.build(Config)
assert(#result.arenas==3,"Expected three arenas")
assert(result.root.Parent==workspace,"World must be mounted")
assert(result.root:FindFirstChild("Creatures"),"Shared creatures folder missing")
assert(result.hub.Z<=65,"Hub must remain reachable")
local worldInstances=#registry
local worldParts,colliders,floors,banks=0,0,0,0
for _,object in registry do
    if object.ClassName=="Part" then
        worldParts+=1
        assert(object.Anchored==true,"World part must be anchored")
        assert(object.CanTouch==false,"Decoration touch must be disabled")
        assert(object.Size.X>0 and object.Size.Y>0 and object.Size.Z>0,"Invalid size")
        if object.CanCollide then colliders+=1 end
        if object.Name=="ArenaFloor" then
            floors+=1
            assert(object.CanCollide,"Floor must collide")
            assert(math.abs(object.CFrame.rotation[4]-1)<0.00001,"Cylinder axis must be vertical")
            assert(object.CFrame.Position.Y+object.Size.X/2==0,"Floor surface must be Y=0")
        end
        if object.Name=="CanopyTrunk" then
            assert(math.abs(object.CFrame.rotation[4]-1)<0.00001,"Tree cylinder axis must be vertical")
        end
        if object.Name=="BankPad" then
            banks+=1
            assert(object.CFrame.Position.Z==44,"Bank marker must match gameplay position")
        end
    end
end
for index,arena in result.arenas do
    assert(arena.origin.X==(index-1)*300 and arena.origin.Y==0,"Wrong arena origin")
    assert(arena.radius==65 and arena.spawn.Z==38 and arena.bank.Z==44,"Gameplay geometry contract mismatch")
    assert((arena.spawn-arena.bank).Magnitude<10,"First bank must be accessible from spawn")
end
assert(floors==3 and banks==3,"Every arena needs floor and bank")
assert(worldParts<1000,"World primitive budget exceeded")
assert(yields>=24,"Build must yield between batches")
local seen={}
local creatureParts=0
for _,def in Config.Creatures do
    local before=#registry
    local creature=World.creature(def,result.root:FindFirstChild("Creatures"))
    assert(creature.PrimaryPart and creature.PrimaryPart.Name=="Root","Creature requires stable primary root")
    assert(creature.attributes.Species==def.id,"Species identity missing")
    assert(not seen[creature.attributes.Silhouette],"Creature silhouettes must be unique")
    seen[creature.attributes.Silhouette]=true
    local detailCount=0
    for i=before+1,#registry do
        local object=registry[i]
        if object.ClassName=="Part" then
            creatureParts+=1
            detailCount+=1
            assert(object.Parent==creature and object.Anchored and not object.CanCollide and not object.CanQuery,"Creature collision contract")
        end
    end
    assert(detailCount>=15 and detailCount<=35,"Unexpected creature primitive budget for "..def.id..": "..detailCount)
end
assert(#Config.Creatures==12,"Twelve species required")
print(string.format("PASS offline constructor smoke: 3 arenas, 12 distinct shape ids, %d world instances, %d world parts, %d colliders, %d creature parts, %d construction yields",worldInstances,worldParts,colliders,creatureParts,yields))
print("NOT TESTED: Roblox rendering, physics, camera, client FPS, device scaling, live navigation, gameplay, sound")
'@
$generated = $mock + "`nlocal Config=(function()`n" + $configSource + "`nend)()`nlocal World=(function()`n" + $worldSource + "`nend)()`n" + $checks
$tempFile = Join-Path ([IO.Path]::GetTempPath()) ('spark-world-smoke-' + [guid]::NewGuid().ToString('N') + '.luau')
try {
    [IO.File]::WriteAllText($tempFile, $generated, [Text.UTF8Encoding]::new($false))
    & $Luau $tempFile
    if ($LASTEXITCODE -ne 0) { throw "World constructor smoke failed with exit $LASTEXITCODE" }
} finally {
    if (Test-Path -LiteralPath $tempFile) { Remove-Item -LiteralPath $tempFile }
}
