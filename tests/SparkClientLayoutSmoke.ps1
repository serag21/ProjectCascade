param([string]$Luau='')
$ErrorActionPreference='Stop'
$repoRoot=Split-Path -Parent $PSScriptRoot
if (-not $Luau) { $Luau=Join-Path $repoRoot '.tools/luau/luau.exe' }
$source=Get-Content -LiteralPath (Join-Path $repoRoot 'game/StarterPlayer/StarterPlayerScripts/Spark/Client.client.luau') -Raw
$section=[regex]::Match($source,'(?s)-- BEGIN PURE LAYOUT[^\n]*\n(.*?)-- END PURE LAYOUT')
if (-not $section.Success) { throw 'Client pure layout section is missing' }
$checks=@'
local function overlap(a,b)
    return a.x<b.x+b.w and b.x<a.x+a.w and a.y<b.y+b.h and b.y<a.y+a.h
end
local cases={
    {320,480,true},{320,532,true},{360,604,true},{390,808,true},
    {568,284,true},{667,339,true},{844,354,true},{1024,732,true},
    {320,480,false},{1280,684,false},{1920,1044,false},
}
local checks=0
for _,case in ipairs(cases) do
    local width,height,touch=table.unpack(case)
    local layout=layoutFor(width,height,touch)
    local id=string.format('%dx%d touch=%s',width,height,tostring(touch))
    for name,r in pairs(layout) do
        assert(r.x>=0 and r.y>=0 and r.x+r.w<=width and r.y+r.h<=height,'Out of bounds: '..name..' '..id)
        checks+=1
    end
    assert(not overlap(layout.capture,layout.dash),'Action buttons overlap '..id)
    checks+=1
    if touch then
        -- Conservative reserved boxes, not a claim about live CoreGui geometry.
        local thumbstick={x=0,y=height-160,w=160,h=160}
        local jump={x=width-122,y=height-104,w=122,h=104}
        local objective=layout.objective
        local collection=layout.collection
        for _,key in ipairs({'capture','dash','bank'}) do
            local r=layout[key]
            assert(not overlap(r,thumbstick),'Thumbstick reserved-area conflict: '..key..' '..id)
            assert(not overlap(r,jump),'Jump reserved-area conflict: '..key..' '..id)
            assert(not overlap(r,objective),'Objective conflict: '..key..' '..id)
            assert(not overlap(r,collection),'Collection-button conflict: '..key..' '..id)
            checks+=4
        end
        assert(not overlap(layout.bank,layout.capture) and not overlap(layout.bank,layout.dash),'Bank guide conflict '..id)
        checks+=1
    end
end
print(string.format('PASS pure client layout: %d usable-canvas cases, %d geometric assertions',#cases,checks))
print('NOT TESTED: Roblox rendering, font measurement, actual CoreGui bounds, touch input, gamepad focus or safe-area reporting')
'@
$tempFile=Join-Path ([IO.Path]::GetTempPath()) ('spark-layout-'+[guid]::NewGuid().ToString('N')+'.luau')
try {
    [IO.File]::WriteAllText($tempFile,$section.Groups[1].Value+"`n"+$checks,[Text.UTF8Encoding]::new($false))
    & $Luau $tempFile
    if ($LASTEXITCODE -ne 0) { throw "Client layout smoke failed: $LASTEXITCODE" }
} finally {
    if (Test-Path -LiteralPath $tempFile) { Remove-Item -LiteralPath $tempFile }
}
