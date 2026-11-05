-- Responsive input, HUD and bounded local effects. All rewards originate on server.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
local ContextActionService=game:GetService("ContextActionService")
local RunService=game:GetService("RunService")
local SoundService=game:GetService("SoundService")
local StarterGui=game:GetService("StarterGui")
local GuiService=game:GetService("GuiService")
local player=Players.LocalPlayer
-- The default player list covers the score HUD. Retry while CoreScripts initialize.
task.spawn(function()
	for _=1,10 do
		local ok=pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false) end)
		if ok then return end
		task.wait(.5)
	end
	warn("[Spark] PlayerList could not be hidden; check HUD overlap")
end)
local Shared=ReplicatedStorage:WaitForChild("Spark")
local Config=require(Shared:WaitForChild("Config"))
local Profile=require(Shared:WaitForChild("Profile"))
local Targeting=require(Shared:WaitForChild("Targeting"))
local Ui=require(script.Parent:WaitForChild("Ui"))
local Menu=require(script.Parent:WaitForChild("Menu"))
local Effects=require(script.Parent:WaitForChild("Effects"))
local Podium=require(script.Parent:WaitForChild("Podium"))
local CreatureView=require(script.Parent:WaitForChild("CreatureView"))
local HerdNet=require(Shared:WaitForChild("HerdNet"))
local remotes=Shared:WaitForChild("Remotes")
local Action=remotes:WaitForChild("Action")
local State=remotes:WaitForChild("State")
local Feedback=remotes:WaitForChild("Feedback")
local HerdFeed=remotes:WaitForChild("HerdNet")
local creatureView=nil -- living-herd renderer (D13), created once the herd folder exists
local palette,make,round,label,button=Ui.palette,Ui.make,Ui.round,Ui.label,Ui.button
local playerGui=player:WaitForChild("PlayerGui")
local gui=Instance.new("ScreenGui")
gui.Name="SparkHUD"; gui.ResetOnSpawn=false; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.Parent=playerGui
-- latest = last server state with the cached profile/boards merged in.
local latest=nil
local cachedProfile,cachedBoards=nil,nil
local results
local replayButton
local menu
local function controllerActive()
	return string.match(UserInputService:GetLastInputType().Name,"^Gamepad")~=nil
end
local cooldownUntil={Capture=0,Dash=0}
local function requestAction(action)
	if (menu and menu.isOpen()) or not latest or (latest.phase~="Playing" and latest.phase~="Warmup") then return end
	if cooldownUntil[action] and os.clock()<cooldownUntil[action] then return end
	if action=="Capture" then cooldownUntil.Capture=os.clock()+(latest.captureCooldown or Config.CaptureCooldown) end
	Action:FireServer(action)
end
local lastFingerprint=""
local defs={}
for _,def in ipairs(Config.Creatures) do defs[def.id]=def end
local function speciesOf(entry)
	if type(entry)~="string" then return nil end
	return if string.sub(entry,1,1)=="*" then string.sub(entry,2) else entry
end

-- HUD top bar ---------------------------------------------------------------
local top=make("Frame",gui,{BackgroundColor3=palette.paper,BackgroundTransparency=0.05,
	Name="HudTop",Size=UDim2.new(1,-24,0,70),Position=UDim2.fromOffset(12,8),BorderSizePixel=0})
round(top)
local brand=label(top,"SPARK\nSTAMPEDE",18,UDim2.fromOffset(14,7),UDim2.fromOffset(130,54))
brand.Name="Brand"
local timer=label(top,"1:50",26,UDim2.new(.5,-40,0,5),UDim2.fromOffset(80,31))
timer.Name="Timer"
timer.TextXAlignment=Enum.TextXAlignment.Center
local eventLabel=label(top,"GET READY",12,UDim2.new(.5,-110,0,40),UDim2.fromOffset(220,18),palette.purple)
eventLabel.Name="Event"
eventLabel.TextXAlignment=Enum.TextXAlignment.Center
local glow=label(top,"0 GLOW",20,UDim2.new(1,-165,0,8),UDim2.fromOffset(150,28))
glow.Name="Glow"
glow.TextXAlignment=Enum.TextXAlignment.Right
local carry=label(top,"PARADE 0 / 8",12,UDim2.new(1,-165,0,40),UDim2.fromOffset(150,20))
carry.Name="Carry"
carry.TextXAlignment=Enum.TextXAlignment.Right
-- Rank chip with a thin XP bar; heat shown as text, not only colour.
local rankChip=make("Frame",top,{Name="RankChip",BackgroundTransparency=1,Position=UDim2.fromOffset(150,10),Size=UDim2.fromOffset(120,50)})
local rankText=label(rankChip,"RANK 1",13,UDim2.new(),UDim2.fromOffset(120,18),palette.purple)
rankText.Name="RankText"
local _xpBar,xpFill=Ui.bar(rankChip,"XpBar",UDim2.fromOffset(0,22),UDim2.fromOffset(110,6),Color3.fromRGB(214,216,240),palette.purple)
local heatText=label(rankChip,"",12,UDim2.fromOffset(0,31),UDim2.fromOffset(120,16),palette.warm)
heatText.Name="HeatChip"
local objective=label(gui,"Connecting your collection…",17,UDim2.new(.5,-290,0,87),UDim2.fromOffset(580,44),palette.ink)
objective.Name="Objective"
objective.TextXAlignment=Enum.TextXAlignment.Center
objective.BackgroundColor3=palette.paper; objective.BackgroundTransparency=.12; round(objective,12)
local menuButton=button(gui,"MENU  ≡",UDim2.fromOffset(12,141),UDim2.fromOffset(158,42),palette.paper,function() end)
menuButton.Name="CollectionButton"
local saveLabel=label(gui,"Loading",11,UDim2.new(0,14,1,-24),UDim2.fromOffset(230,18),palette.ink)
saveLabel.Name="SaveStatus"
local bankGuide=label(gui,"",16,UDim2.new(.5,-120,1,-74),UDim2.fromOffset(240,40),palette.ink)
bankGuide.Name="BankGuide"
bankGuide.TextXAlignment=Enum.TextXAlignment.Center
bankGuide.BackgroundColor3=palette.gold; bankGuide.BackgroundTransparency=.08; round(bankGuide)
bankGuide.Visible=false
local controls=make("Frame",gui,{Name="Controls",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Visible=false})
local captureButton=button(controls,"CATCH\n[E / X]",UDim2.new(1,-122,1,-182),UDim2.fromOffset(108,70),palette.mint,function() requestAction("Capture") end)
captureButton.Name="CaptureButton"
local dashButton=button(controls,"DASH\n[Shift / B]",UDim2.new(1,-232,1,-165),UDim2.fromOffset(100,58),palette.gold,function() requestAction("Dash") end)
dashButton.Name="DashButton"
-- Combo meter: chain count, text tier badge and a draining chain timer.
local combo=make("Frame",gui,{Name="ComboMeter",BackgroundColor3=palette.paper,BackgroundTransparency=.08,BorderSizePixel=0,
	Position=UDim2.new(.5,-110,0,139),Size=UDim2.fromOffset(220,44),Visible=false})
round(combo,12)
local comboChain=label(combo,"NO CHAIN",13,UDim2.fromOffset(10,3),UDim2.new(.55,-10,0,22),palette.ink)
comboChain.Name="ChainText"; comboChain.TextScaled=true
make("UITextSizeConstraint",comboChain,{MinTextSize=9,MaxTextSize=14})
local comboBadge=label(combo,"x1",13,UDim2.new(.55,0,0,4),UDim2.new(.45,-8,0,20),palette.ink)
comboBadge.Name="TierBadge"; comboBadge.TextXAlignment=Enum.TextXAlignment.Center; comboBadge.BackgroundTransparency=0
comboBadge.BackgroundColor3=Ui.tiers[1].color; comboBadge.TextScaled=true; round(comboBadge,8)
make("UITextSizeConstraint",comboBadge,{MinTextSize=8,MaxTextSize=13})
local _,comboFill=Ui.bar(combo,"ChainBar",UDim2.new(0,10,1,-14),UDim2.new(1,-20,0,7),Color3.fromRGB(214,216,240),palette.mint)
local toast=label(gui,"",20,UDim2.new(.5,-250,.58,-28),UDim2.fromOffset(500,56),palette.ink)
toast.Name="FeedbackToast"
toast.TextXAlignment=Enum.TextXAlignment.Center; toast.BackgroundColor3=palette.gold; toast.BackgroundTransparency=.05; round(toast)
toast.Visible=false
local toastSerial=0
local function showToast(text,kind)
	toastSerial+=1; local serial=toastSerial
	toast.Text=text or ""; toast.Visible=true
	toast.BackgroundColor3=if kind=="Hint" or kind=="Error" then palette.paper elseif kind=="Zap" then Color3.fromRGB(255,214,214) else palette.gold
	task.delay(if kind=="Error" then 8 else 2.1,function() if toastSerial==serial then toast.Visible=false end end)
end

local function syncOverlays()
	local playing=latest~=nil and (latest.phase=="Playing" or latest.phase=="Warmup")
	local open=menu~=nil and menu.isOpen()
	controls.Visible=playing and not open
	bankGuide.Visible=playing and latest.carry>0 and not open
	if results then results.Visible=latest~=nil and (latest.phase=="Results" or latest.phase=="SitOut") and not open end
end

-- BEGIN STARTER VISIBILITY: exercised with event doubles by SparkStarterVisibilitySmoke.ps1.
-- Private first catches occupy the same welcoming positions for each new player.
-- Mask other owners locally; capture eligibility remains entirely server-owned.
local function watchStarter(model,viewerId)
	local masked={}
	local function apply(item)
		local owner=model:GetAttribute("StarterOwnerId")
		local hidden=owner~=nil and owner~=viewerId
		local property=if item:IsA("BasePart") then "LocalTransparencyModifier" elseif item:IsA("BillboardGui") then "Enabled" else nil
		if not property then return end
		if hidden then
			if masked[item]==nil then masked[item]={property=property,value=item[property]} end
			item[property]=if property=="Enabled" then false else 1
		elseif masked[item] then
			item[property]=masked[item].value
			masked[item]=nil
		end
	end
	local function refresh()
		for _,item in ipairs(model:GetDescendants()) do apply(item) end
	end
	local ownerChanged=model:GetAttributeChangedSignal("StarterOwnerId"):Connect(refresh)
	local added=model.DescendantAdded:Connect(apply)
	local removed=model.DescendantRemoving:Connect(function(item)
		local original=masked[item]
		if original then item[original.property]=original.value; masked[item]=nil end
	end)
	refresh()
	return function()
		ownerChanged:Disconnect(); added:Disconnect(); removed:Disconnect()
		for item,original in pairs(masked) do item[original.property]=original.value end
		table.clear(masked)
	end
end
-- END STARTER VISIBILITY

local templates={}
local function miniature(id,parent)
	id=speciesOf(id) or id
	if templates[id] then local clone=templates[id]:Clone(); clone.Parent=parent; return clone end
	local world=workspace:FindFirstChild("SparkWorld")
	local herd=world and world:FindFirstChild("Creatures")
	if herd then
		for _,model in ipairs(herd:GetChildren()) do
			if model:GetAttribute("Species")==id and not model:GetAttribute("Golden") then
				local clone=model:Clone()
				for _,item in ipairs(clone:GetDescendants()) do
					if item:IsA("BasePart") then item.Anchored=true; item.CanCollide=false; item.CanQuery=false; item.CanTouch=false; item.LocalTransparencyModifier=0
					elseif item:IsA("BillboardGui") or item:IsA("ParticleEmitter") or item:IsA("Light") then item:Destroy() end
				end
				templates[id]=clone:Clone()
				clone.Parent=parent; return clone
			end
		end
	end
	local model=make("Model",parent)
	local def=defs[id] or Config.Creatures[1]
	local part=make("Part",model,{Shape=Enum.PartType.Ball,Size=Vector3.new(2,2,2),Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,Color=Color3.fromRGB(table.unpack(def.color))})
	model.PrimaryPart=part
	return model
end

menu=Menu.new({gui=gui,data=function() return latest end,
	fire=function(action,payload) Action:FireServer(action,payload) end,
	miniature=miniature,controllerActive=controllerActive,toast=function(text) showToast(text,"Hint") end,
	boards=function() return cachedBoards end,
	onChanged=function()
		syncOverlays()
		if not menu.isOpen() and controllerActive() and results and results.Visible then GuiService.SelectedObject=replayButton end
	end})
local function togglePanel(name) menu.open(name) end
menuButton.Activated:Connect(function() togglePanel(if menu.isOpen() then nil else "Play") end)

-- Results ---------------------------------------------------------------------
results=make("Frame",gui,{Name="Results",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(420,512),
	BackgroundColor3=palette.paper,BorderSizePixel=0,Visible=false,ZIndex=3}); round(results,20)
local resultScale=make("UIScale",results,{Scale=1})
local resultTitle=label(results,"WHAT A PARADE!",25,UDim2.fromOffset(20,12),UDim2.new(1,-40,0,36)); resultTitle.TextXAlignment=Enum.TextXAlignment.Center
resultTitle.Name="Title"; resultTitle.Font=Enum.Font.GothamBlack
local resultMedal=label(results,"",15,UDim2.new(.5,-100,0,52),UDim2.fromOffset(200,28),palette.ink)
resultMedal.Name="Medal"; resultMedal.TextXAlignment=Enum.TextXAlignment.Center; resultMedal.BackgroundTransparency=0
resultMedal.BackgroundColor3=palette.row; round(resultMedal,14)
local resultScore=label(results,"",18,UDim2.fromOffset(20,86),UDim2.new(1,-40,0,48)); resultScore.TextXAlignment=Enum.TextXAlignment.Center
resultScore.Name="Score"
local resultBreakdown=label(results,"",13,UDim2.fromOffset(24,138),UDim2.new(1,-48,0,96),palette.purple)
resultBreakdown.Name="Breakdown"; resultBreakdown.TextXAlignment=Enum.TextXAlignment.Center; resultBreakdown.TextYAlignment=Enum.TextYAlignment.Top
local resultRank=label(results,"",14,UDim2.fromOffset(24,238),UDim2.new(1,-48,0,20),palette.ink)
resultRank.Name="RankLine"; resultRank.TextXAlignment=Enum.TextXAlignment.Center
local _resultXp,resultXpFill=Ui.bar(results,"XpBar",UDim2.fromOffset(40,262),UDim2.new(1,-80,0,10),Color3.fromRGB(214,216,240),palette.purple)
local resultCallouts=label(results,"",13,UDim2.fromOffset(24,276),UDim2.new(1,-48,0,54),palette.purple)
resultCallouts.Name="Callouts"; resultCallouts.TextXAlignment=Enum.TextXAlignment.Center; resultCallouts.TextYAlignment=Enum.TextYAlignment.Top
-- Rounds auto-start each shared cycle; this button toggles Sit out / Play.
replayButton=button(results,"SIT OUT NEXT ROUND",UDim2.fromOffset(20,416),UDim2.new(1,-40,0,44),palette.gold,function()
	togglePanel(nil)
	if latest and (latest.sitOut or latest.phase=="SitOut") then Action:FireServer("Play") else Action:FireServer("SitOut") end
end)
replayButton.Name="ReplayButton"
local resultCountdown=label(results,"",16,UDim2.fromOffset(20,334),UDim2.new(1,-40,0,22),palette.ink)
resultCountdown.Name="NextRound"; resultCountdown.TextXAlignment=Enum.TextXAlignment.Center; resultCountdown.Font=Enum.Font.GothamBlack
local podiumHolder=make("Frame",results,{Name="PodiumHolder",BackgroundTransparency=1,Position=UDim2.fromOffset(0,350),Size=UDim2.new(1,0,0,64)})
local updatePodium=Podium.mount(podiumHolder,make,round,palette)
local resultUpgrade=button(results,"UPGRADES",UDim2.fromOffset(20,466),UDim2.new(.5,-26,0,36),palette.mint,function() togglePanel("Upgrades") end)
resultUpgrade.Name="UpgradeButton"
local resultSetup=button(results,"PLAY SETUP",UDim2.new(.5,6,0,466),UDim2.new(.5,-26,0,36),palette.mint,function() togglePanel("Play") end)
resultSetup.Name="PlaySetupButton"
replayButton.NextSelectionDown=resultUpgrade
resultUpgrade.NextSelectionUp=replayButton; resultSetup.NextSelectionUp=replayButton
resultUpgrade.NextSelectionRight=resultSetup; resultSetup.NextSelectionLeft=resultUpgrade
for _,child in ipairs(results:GetDescendants()) do if child:IsA("GuiObject") then child.ZIndex=4 end end
local function renderResults(d)
	local m=d.mastery
	local r=d.lastResult
	local medalName=(m and m.medal) or "Unranked"
	local medal=Ui.medals[medalName] or Ui.medals.Unranked
	resultTitle.Text=if d.phase=="SitOut" and not r then "TAKING A BREAK"
		elseif r and r.incomplete then "CATCH 3+ FOR ROUND CREDIT"
		elseif d.personalBest or (r and r.newRecord and (r.previousRecord or 0)>0) then "NEW PERSONAL BEST!" else "WHAT A PARADE!"
	resultMedal.Text=medal.label..(if r and (r.heat or 0)>0 then "  •  HEAT "..r.heat else "")
	resultMedal.BackgroundColor3=medal.color
	if m then
		resultScore.Text=string.format("%d skill • Best %d\n+%d glow • %d / 12 Sparks",m.score,d.profile.mastery.bestScore,d.score or 0,Profile.speciesCount(d.profile))
		resultBreakdown.Text=string.format("Precise %d • Dash %d • Multi %d\nHerded %d • Assists %d • Pops %d\nGolden %d • Best chain %d • Best haul %d%s",
			m.precision or 0,m.dashCatches or 0,m.multiCatches or 0,m.herded or 0,m.assists or 0,m.pops or 0,
			m.golden or 0,m.bestChain or 0,m.bestHaul or 0,
			if (m.buzzerLost or 0)>0 then string.format("\nBuzzer forfeited %d style • bank sooner!",m.buzzerLost) else "")
	else
		resultScore.Text=string.format("+%d glow this round\n%d / 12 Sparks discovered",d.score or 0,Profile.speciesCount(d.profile))
		resultBreakdown.Text=""
	end
	local rank=d.rank
	if rank then
		resultRank.Text=string.format("RANK %d%s",rank.rank,if r then string.format("  •  +%d XP",r.xp or 0) else "")
		resultXpFill.Size=UDim2.fromScale(math.clamp(rank.fraction or 0,0,1),1)
	end
	local callouts={}
	if r then
		if (r.rankAfter or 0)>(r.rankBefore or 0) then table.insert(callouts,"RANK UP! → "..r.rankAfter) end
		for _,unlock in ipairs(r.unlocks or {}) do table.insert(callouts,unlock) end
		for _,name in ipairs(r.titles or {}) do table.insert(callouts,"★ "..name) end
		if r.newRecord and (r.previousRecord or 0)>0 then table.insert(callouts,string.format("Arena record +%d",(r.score or 0)-(r.previousRecord or 0))) end
	end
	if r and r.full==false and not r.incomplete then table.insert(callouts,"Joined mid-round • records count from full rounds") end
	resultCallouts.Text=table.concat(callouts,"  •  ")
	local sitting=d.sitOut or d.phase=="SitOut"
	replayButton.Text=if sitting then "PLAY • JOIN THE STAMPEDE" else "SIT OUT NEXT ROUND"
	resultCountdown.Text=if d.phase=="SitOut" then "Sitting out • join any time"
		elseif d.nextRoundIn then (if sitting then string.format("Sitting out • next stampede in %ds",d.nextRoundIn) else string.format("NEXT STAMPEDE IN %d",d.nextRoundIn))
		else ""
	updatePodium(d.podium,player.UserId)
end

-- BEGIN PURE LAYOUT: extracted by tests/SparkClientLayoutSmoke.ps1 and tests/test_spark_client_blocks.py.
local function layoutFor(width,height,touch)
	local panelWidth=math.min(640,math.max(240,width-24))
	local panelHeight=math.min(560,math.max(200,height-64))
	local touchWide=touch and width>=560
	local stacked=touch and not touchWide
	local compact=touchWide and height<330
	local bankWidth=if compact then 140 elseif touchWide then math.min(240,width-320) else math.min(240,width-24)
	local objectiveWidth=if compact then width-142 else math.min(580,width-24)
	local objectiveRect={x=if compact then 130 else (width-objectiveWidth)/2,y=if compact then 80 else 87,w=objectiveWidth,h=if compact then 40 else 44}
	local bankRect={x=if touchWide then 180 else (width-bankWidth)/2,y=if compact then 128 elseif touchWide then 133 elseif touch then 187 else height-74,w=bankWidth,h=if touchWide then 36 else 40}
	-- Combo meter sits under the objective, clear of the menu button, bank guide and action buttons.
	local comboRect=nil
	if touchWide then
		-- Landscape touch: under the bank guide, right of the thumbstick zone, left of the action buttons.
		comboRect={x=bankRect.x,y=bankRect.y+bankRect.h+8,w=math.min(220,width-232-8-bankRect.x),h=40}
	end
	local captureRect={x=width-122,y=if compact then 126 else height-(if stacked then 244 else 182),w=108,h=if compact then 44 else 70}
	local dashRect={x=width-(if stacked then 122 else 232),y=if compact then 126 else height-165,w=if stacked then 108 else 100,h=if compact then 44 else 58}
	if not comboRect then
		local y=objectiveRect.y+objectiveRect.h+8
		if not touch and width>=700 then
			comboRect={x=(width-220)/2,y=y,w=220,h=44}
		else
			local w=math.min(220,width-24-170)
			comboRect={x=width-12-w,y=y,w=w,h=44}
		end
		local function hits(a,b) return a.x<b.x+b.w and b.x<a.x+a.w and a.y<b.y+b.h and b.y<a.y+a.h end
		-- Short windows bring the action buttons up: slide left of them, right of the menu button.
		if hits(comboRect,captureRect) or hits(comboRect,dashRect) then
			comboRect={x=178,y=y,w=math.min(220,dashRect.x-8-178),h=44}
		end
	end
	return {
		panel={x=(width-panelWidth)/2,y=(height-panelHeight)/2,w=panelWidth,h=panelHeight},
		capture=captureRect,
		dash=dashRect,
		bank=bankRect,
		objective=objectiveRect,
		collection={x=12,y=if compact then 80 else 141,w=if compact then 110 else 158,h=if compact then 40 else 42},
		combo=comboRect,
	}
end
-- END PURE LAYOUT
local function resize()
	local camera=workspace.CurrentCamera; if not camera then return end
	local size=gui.AbsoluteSize
	if size.X<=0 or size.Y<=0 then size=camera.ViewportSize end
	local layout=layoutFor(size.X,size.Y,UserInputService.TouchEnabled)
	menu.resize(size.X,size.Y)
	for key,b in pairs({capture=captureButton,dash=dashButton,bank=bankGuide,objective=objective,collection=menuButton,combo=combo}) do
		local rect=layout[key]
		b.Position=UDim2.fromOffset(rect.x,rect.y); b.Size=UDim2.fromOffset(rect.w,rect.h)
	end
	objective.TextScaled=true
	menuButton.TextSize=if layout.collection.w<158 then 12 else 17
	toast.Size=UDim2.fromOffset(math.min(500,size.X-24),56); toast.Position=UDim2.new(.5,-math.min(500,size.X-24)/2,.58,-28)
	resultScale.Scale=math.clamp(math.min((size.X-24)/420,(size.Y-24)/512),0.45,1)
	local narrow=size.X<500
	brand.TextSize=if narrow then 13 else 18
	glow.TextSize=if narrow then 14 else 20
	glow.Position=UDim2.new(1,if narrow then -100 else -165,0,8)
	glow.Size=UDim2.fromOffset(if narrow then 90 else 150,28)
	eventLabel.Position=if narrow then UDim2.fromOffset(10,51) else UDim2.new(.5,-110,0,40)
	eventLabel.Size=if narrow then UDim2.new(.5,-12,0,18) else UDim2.fromOffset(220,18)
	eventLabel.TextXAlignment=if narrow then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
	carry.Position=UDim2.new(1,if narrow then -125 else -165,0,if narrow then 51 else 40)
	carry.Size=UDim2.fromOffset(if narrow then 115 else 150,18)
	brand.Size=UDim2.fromOffset(if narrow then 82 else 130,if narrow then 40 else 54)
	-- Rank chip needs clear space between brand and the centered timer.
	rankChip.Visible=size.X>=640
end
local viewportConnection
local function bindViewport()
	if viewportConnection then viewportConnection:Disconnect() end
	if workspace.CurrentCamera then viewportConnection=workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
	resize()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindViewport)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
bindViewport()
make("UITextSizeConstraint",objective,{MinTextSize=12,MaxTextSize=17})
UserInputService.LastInputTypeChanged:Connect(function()
	if controllerActive() then
		if menu.isOpen() then GuiService.SelectedObject=menu.tabButtons[menu.selected]
		elseif results.Visible then GuiService.SelectedObject=replayButton end
	end
end)

local function bind(name,action,...)
	ContextActionService:BindAction(name,function(_,state)
		if state~=Enum.UserInputState.Begin or UserInputService:GetFocusedTextBox() or menu.isOpen() then return Enum.ContextActionResult.Pass end
		requestAction(action); return Enum.ContextActionResult.Sink
	end,false,...)
end
bind("SparkCapture","Capture",Enum.KeyCode.E,Enum.KeyCode.ButtonX)
bind("SparkDash","Dash",Enum.KeyCode.LeftShift,Enum.KeyCode.ButtonB)
bind("SparkBank","Bank",Enum.KeyCode.R,Enum.KeyCode.ButtonY)
ContextActionService:BindAction("SparkMenu",function(_,state)
	if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
	if state==Enum.UserInputState.Begin then togglePanel(if menu.isOpen() then nil else "Play") end
	return Enum.ContextActionResult.Sink
end,false,Enum.KeyCode.M,Enum.KeyCode.ButtonSelect)

local catalogModule=Shared:FindFirstChild("AudioCatalog")
local audioCatalog=if catalogModule then require(catalogModule) else nil
local music=make("Sound",SoundService,{Name="SparkMusic",Volume=.16,Looped=true})
local effectsFolder=make("Folder",workspace,{Name="SparkLocalEffects"})
local function reduced() return latest~=nil and latest.profile~=nil and latest.profile.settings.reducedMotion==true end
local effects=Effects.new({playerGui=playerGui,gui=gui,folder=effectsFolder,reduced=reduced,
	sfx=function() return not (latest and latest.profile and latest.profile.settings.sfx==false) end,
	catalog=audioCatalog,musicPlaying=function() return music.IsPlaying end,viewerId=player.UserId})

task.spawn(function()
	local world=workspace:WaitForChild("SparkWorld")
	local herd=world:WaitForChild("Creatures")
	creatureView=CreatureView.new({folder=herd,camera=function() return workspace.CurrentCamera end,
		reducedMotion=reduced,localUserId=player.UserId,guiParent=playerGui,
		quality=function()
			local ok,level=pcall(function() return UserSettings().GameSettings.SavedQualityLevel.Value end)
			return if ok and type(level)=="number" and level>0 then level else 10
		end})
	-- Server snapshots (10 Hz, unreliable): each packet is a full arena snapshot.
	HerdFeed.OnClientEvent:Connect(function(packet)
		local decoded=HerdNet.unpack(packet)
		if decoded and creatureView then
			creatureView.ingest({arena=decoded.arena,origin=Vector3.new((decoded.arena-1)*300,0,0),clock=decoded.clock,
				receivedAt=os.clock(),entries=decoded.entries})
		end
	end)
	local watches={}
	local function watch(model)
		if model:IsA("Model") and not watches[model] then
			watches[model]=watchStarter(model,player.UserId)
			effects.trackCreature(model)
			creatureView.track(model)
		end
	end
	herd.ChildAdded:Connect(watch)
	herd.ChildRemoved:Connect(function(model)
		if watches[model] then watches[model](); watches[model]=nil end
		effects.untrackCreature(model)
		creatureView.untrack(model)
	end)
	for _,model in ipairs(herd:GetChildren()) do watch(model) end
	local statics=world:WaitForChild("Statics",60)
	if statics then
		statics.ChildAdded:Connect(function(model) if model:IsA("Model") then effects.trackStatic(model) end end)
		statics.ChildRemoved:Connect(effects.untrackStatic)
		for _,model in ipairs(statics:GetChildren()) do if model:IsA("Model") then effects.trackStatic(model) end end
	end
end)

-- One local telegraph, no flashing or screen shake. Server decides every hit.
local sweep=make("Part",effectsFolder,{Name="SweepWarning",Shape=Enum.PartType.Cylinder,
	Size=Vector3.new(.15,7,7),Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,
	Material=Enum.Material.SmoothPlastic,Color=Color3.fromRGB(255,157,65),Transparency=1})
local sweepCue=make("BillboardGui",sweep,{Size=UDim2.fromOffset(150,28),StudsOffset=Vector3.new(0,2,0),MaxDistance=50,Enabled=false})
local sweepText=label(sweepCue,"",13,UDim2.new(),UDim2.fromScale(1,1),palette.ink)
sweepText.TextXAlignment=Enum.TextXAlignment.Center
-- One advisory aim outline, updated at 10Hz. Never sends a target or score to the server.
-- Occluded geometry stays occluded; shape/text accompany the color change.
local aimOutline=make("Highlight",effectsFolder,{Name="CatchAim",Enabled=false,FillTransparency=1,
	OutlineTransparency=.15,DepthMode=Enum.HighlightDepthMode.Occluded})
local aimCue=make("BillboardGui",playerGui,{Name="CatchAimCue",Size=UDim2.fromOffset(132,24),StudsOffset=Vector3.new(0,3.3,0),
	MaxDistance=22,AlwaysOnTop=false,Enabled=false,ResetOnSpawn=false})
local aimText=label(aimCue,"",12,UDim2.new(),UDim2.fromScale(1,1),palette.ink)
aimText.TextXAlignment=Enum.TextXAlignment.Center; aimText.BackgroundColor3=palette.paper; aimText.BackgroundTransparency=.1; round(aimText,8)
local aimAt=0
local stateAt=0
local function aimPreview(now)
	if now-aimAt<.1 then return end
	aimAt=now
	local target,best=nil,nil
	local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local world=workspace:FindFirstChild("SparkWorld")
	local herd=world and world:FindFirstChild("Creatures")
	if root and humanoid and humanoid.Health>0 and herd and latest and (latest.phase=="Playing" or latest.phase=="Warmup") and not menu.isOpen() and latest.carry<latest.capacity then
		local function xyz(v) return {x=v.X,y=v.Y,z=v.Z} end
		local radius=Ui.get(latest,"stats","captureRadius") or (Config.CaptureRadius+(latest.profile.upgrades.magnet or 0)*1.5)
		for _,model in ipairs(herd:GetChildren()) do
			local id,owner=model:GetAttribute("CreatureId"),model:GetAttribute("StarterOwnerId")
			local def=defs[model:GetAttribute("Species")]
			-- Any species can be golden or a runner now; other arenas are far beyond reach.
			if id and model.PrimaryPart and def and (not owner or (owner==player.UserId and latest.profile.totalBanked<3)) then
				local aim=Targeting.measure(xyz(root.Position),xyz(root.CFrame.LookVector),xyz(model.PrimaryPart.Position),radius)
				if Targeting.better(aim,id,best,target and target:GetAttribute("CreatureId")) then target=model; best=aim end
			end
		end
	end
	aimOutline.Adornee=target; aimOutline.Enabled=target~=nil
	aimCue.Adornee=target and target.PrimaryPart; aimCue.Enabled=target~=nil
	if target then
		local precise=best.precision and target:GetAttribute("StarterOwnerId")==nil
		aimOutline.OutlineColor=if target:GetAttribute("Golden") then palette.gold elseif precise then palette.gold else palette.mint
		aimText.Text=if target:GetAttribute("Golden") then "★ GOLDEN SPARK" elseif precise then "◆ PRECISE CATCH" else "○ CATCH"
	end
end

local cueKeys={Catch="catch",Bank="bank",Dash="dash",Upgrade="upgrade",Quest="upgrade",Results="round_reward",Zap="zap",Pop="pop",Assist="catch",Event="ui"}
-- Catch flight (§6.2): the caught Spark arcs from where it was rendered into
-- the player's parade. Bounded pool; skipped entirely in reduced motion.
local flights={}
local function startFlight(species,creatureId,position)
	if reduced() or #flights>=8 or not defs[species] then return end
	local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local from=(creatureView and creatureId and creatureView.lastPose(creatureId)) or CFrame.new(position)
	local mini=miniature(species,effectsFolder)
	mini:ScaleTo(0.6)
	mini:PivotTo(from)
	table.insert(flights,{model=mini,from=from.Position,started=os.clock(),duration=0.38})
end
local function updateFlights(now)
	local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	for index=#flights,1,-1 do
		local flight=flights[index]
		local alpha=math.clamp((now-flight.started)/flight.duration,0,1)
		if alpha>=1 or not root or not flight.model.Parent then
			flight.model:Destroy(); table.remove(flights,index)
		else
			local target=root.Position+Vector3.new(0,1.5,0)
			local eased=1-(1-alpha)*(1-alpha)
			local position=flight.from:Lerp(target,eased)+Vector3.new(0,math.sin(alpha*math.pi)*4,0)
			-- Squash on launch, shrink into the parade near the end.
			flight.model:PivotTo(CFrame.new(position)*CFrame.Angles(0,alpha*math.pi*2,0))
			if alpha>0.75 then flight.model:ScaleTo(math.max(0.2,0.6*(1-(alpha-0.75)*3))) end
		end
	end
end
Feedback.OnClientEvent:Connect(function(data)
	if type(data)~="table" then return end
	local extra=if type(data.extra)=="table" then data.extra else {}
	if data.kind=="Catch" and typeof(data.position)=="Vector3" then startFlight(extra.species or data.creature,extra.creatureId,data.position) end
	if data.kind=="Dash" then cooldownUntil.Dash=os.clock()+(latest and latest.dashCooldown or Config.DashCooldown) end
	local hasTags=type(extra.tags)=="table" and #extra.tags>0
	-- Scored catches speak through floating tags; toasts stay for onboarding and events.
	local quietCatch=(data.kind=="Catch" or data.kind=="Pop" or data.kind=="Assist") and hasTags and typeof(data.position)=="Vector3"
	if not quietCatch then showToast(data.text,data.kind) end
	if data.kind~="Hint" and data.kind~="Error" and data.kind~="Round" then
		local key=cueKeys[data.kind]
		if key then effects.sound(key,if data.kind=="Catch" then 1+math.min(tonumber(extra.chain) or 0,10)*0.04 else 1) end
	end
	if typeof(data.position)=="Vector3" then
		local lines={}
		if (tonumber(extra.points) or 0)>0 then table.insert(lines,"+"..math.floor(extra.points)) end
		if hasTags then for _,tag in ipairs(extra.tags) do if #lines<3 then table.insert(lines,tostring(tag)) end end end
		if #lines>0 then effects.tags(data.position,lines) end
		effects.burst(data.position,if extra.golden then palette.gold elseif data.kind=="Zap" then palette.zap elseif data.kind=="Pop" then Color3.fromRGB(200,170,255) else palette.gold)
	end
end)

local function eventText(d)
	if d.phase=="Warmup" then return string.format("WARM-UP • STAMPEDE IN %ds",d.remaining or 0) end
	if d.phase=="Results" then return string.format("INTERMISSION • NEXT IN %ds",d.nextRoundIn or 0) end
	if d.phase=="SitOut" then return "SITTING OUT" end
	if d.phase~="Playing" then return d.event or "CHASE TIME" end
	if (d.startersRemaining or 0)>0 or d.profile.totalBanked<3 then return d.event or "WARM UP" end
	local prefix=if d.finale then "FINALE x1.25 • " else ""
	if Ui.get(d,"gate","active") then return prefix.."SPARK GATE OPEN" end
	if Ui.get(d,"stampede","visible") then return prefix.."STAMPEDE RUN" end
	if type(d.goldens)=="table" and #d.goldens>0 then return prefix.."GOLDEN SPARK LOOSE!" end
	local enc=d.encounter
	if type(enc)=="table" and enc.next and tonumber(enc.nextIn) and enc.nextIn<=20 then
		return prefix..enc.next.." IN "..math.ceil(enc.nextIn).."s"
	end
	if d.rally then
		return prefix..(if d.rally.complete then "RALLY COMPLETE" else string.format("RALLY %d/%d • %ds",d.rally.total,d.rally.target,d.rally.remaining))
	end
	return prefix..((type(enc)=="table" and enc.phase) or d.event or "CHASE TIME")
end

local lastReduced=nil
-- Per-arena colour grade (local only, subtle, never flashing): each arena keeps
-- its own mood while targets stay readable. Instant in reduced motion.
local grade=Instance.new("ColorCorrectionEffect")
grade.Name="SparkArenaGrade"; grade.Parent=game:GetService("Lighting")
local grades={
	{tint=Color3.fromRGB(255,252,240),saturation=0.08,contrast=0.03},
	{tint=Color3.fromRGB(255,240,228),saturation=0.1,contrast=0.05},
	{tint=Color3.fromRGB(238,236,255),saturation=0.12,contrast=0.06},
}
local gradedBiome=nil
local function applyGrade(biome,reduced)
	local target=grades[biome]
	if not target or gradedBiome==biome then return end
	gradedBiome=biome
	local goal={TintColor=target.tint,Saturation=target.saturation,Contrast=target.contrast}
	if reduced then
		for key,value in pairs(goal) do (grade :: any)[key]=value end
	else
		game:GetService("TweenService"):Create(grade,TweenInfo.new(1.2,Enum.EasingStyle.Sine),goal):Play()
	end
end
State.OnClientEvent:Connect(function(data)
	if type(data)~="table" then return end
	if type(data.profile)=="table" then cachedProfile=data.profile end
	if type(data.boards)=="table" then cachedBoards=data.boards end
	data.profile=cachedProfile
	if not data.profile then return end -- the first state of a session always carries the profile
	local previousPhase=latest and latest.phase
	applyGrade(data.biome,data.profile.settings and data.profile.settings.reducedMotion)
	latest=data
	stateAt=os.clock()
	local seconds=if data.phase=="Results" then (data.nextRoundIn or 0) else (data.remaining or 0)
	timer.Text=Ui.clock(seconds)
	timer.TextColor3=if data.phase=="Playing" and seconds<=15 then palette.warm else palette.ink
	eventLabel.Text=eventText(data)
	glow.Text=data.profile.coins.." GLOW"
	carry.Text=string.format("PARADE %d / %d",data.carry,data.capacity)
	local objectiveText=data.objective or ""
	if data.mastery and data.phase=="Playing" and (data.startersRemaining or 0)==0 then
		local m=data.mastery
		local goal=m.challenge
		if goal then objectiveText=objectiveText..string.format("\nGoal: %s %d/%d • %d skill carried",goal.name,goal.progress,goal.target,m.pending or 0) end
	end
	objective.Text=objectiveText
	if data.mastery then
		brand.Text=string.format("SCORE %d\nBEST %d",data.mastery.score,data.profile.mastery.bestScore)
	end
	if data.rank then
		rankText.Text="RANK "..data.rank.rank
		xpFill.Size=UDim2.fromScale(math.clamp(data.rank.fraction or 0,0,1),1)
	end
	local heat=Ui.get(data,"stats","heat") or data.profile.heat or 0
	local multiplier=tonumber(Ui.get(data,"stats","scoreMultiplier")) or 1
	heatText.Text=if heat>0 then "HEAT "..heat..string.format(" • x%.1f",multiplier) else ""
	saveLabel.Text=data.saveStatus
	if data.phase=="Results" or data.phase=="SitOut" then renderResults(data) end
	local h=data.hazard
	sweep.Transparency=if h and h.visible then (if h.active then .25 else .65) else 1
	sweepCue.Enabled=h~=nil and h.visible==true
	if h and h.visible and typeof(h.position)=="Vector3" then
		sweep.CFrame=CFrame.new(h.position)*CFrame.Angles(0,0,math.pi/2)
		local name=h.name or "SWEEP"
		sweepText.Text=if h.active then (h.cue or "DODGE").." • "..name else name.." IN "..math.ceil(h.seconds or 0)
	end
	effects.encounters(data)
	syncOverlays()
	if previousPhase~=data.phase and controllerActive() and not menu.isOpen() then
		GuiService.SelectedObject=if data.phase=="Results" then replayButton else nil
	end
	if data.cooldowns then
		for action,key in pairs({Capture="capture",Dash="dash"}) do
			if type(data.cooldowns[key])=="number" then cooldownUntil[action]=os.clock()+math.max(0,data.cooldowns[key]) end
		end
	end
	local entry=audioCatalog and audioCatalog.music
	if type(entry)=="table" and type(entry.id)=="string" and entry.id~="" and data.profile.settings.music then
		if music.SoundId~=entry.id then music.SoundId=entry.id end
		music.Volume=math.clamp(entry.volume or .16,0,.4)
		if not music.IsPlaying then music:Play() end
	else music:Stop() end
	if not data.profile.settings.sfx then effects.clearSounds() end
	local reducedNow=data.profile.settings.reducedMotion==true
	if reducedNow~=lastReduced then lastReduced=reducedNow; effects.setReduced() end
	local rankSignature={}
	for _,item in ipairs(data.ranking or {}) do table.insert(rankSignature,tostring(item.userId).."="..item.score) end
	local fingerprint=table.concat({tostring(data.profileRevision),data.profile.coins,data.phase,data.biome,tostring(data.heatUnlocked),
		tostring(data.perkSlots),tostring(data.boardsVersion),data.mastery and data.mastery.challenge and data.mastery.challenge.progress or 0,
		tostring(data.mastery and data.mastery.challenge and data.mastery.challenge.complete),table.concat(rankSignature,","),
		data.rally and data.rally.total or 0,data.rally and data.rally.cycle or 0},":")
	if menu.isOpen() and fingerprint~=lastFingerprint then menu.render() end
	-- Keep the countdown current without rebuilding menu controls or stealing gamepad selection.
	menu.live(data)
	lastFingerprint=fingerprint
end)

local followers={}
local function updateParade(other)
	local previous=followers[other]
	if previous then for _,mini in ipairs(previous.models) do mini:Destroy() end end
	local models={}
	local encoded=other:GetAttribute("SparkParade") or ""
	for _,entry in ipairs(string.split(encoded,",")) do
		local id=speciesOf(entry)
		if id and defs[id] and #models<8 then
			local mini=miniature(id,effectsFolder); mini:ScaleTo(.35); table.insert(models,mini)
		end
	end
	followers[other]={models=models}
end
local function track(other)
	other:GetAttributeChangedSignal("SparkParade"):Connect(function() updateParade(other) end)
	updateParade(other)
end
for _,other in ipairs(Players:GetPlayers()) do track(other) end
Players.PlayerAdded:Connect(track)
Players.PlayerRemoving:Connect(function(other)
	local f=followers[other]; if f then for _,mini in ipairs(f.models) do mini:Destroy() end end
	followers[other]=nil
end)
local guideAt=0
RunService.RenderStepped:Connect(function(dt)
	updateFlights(os.clock())
	if creatureView then creatureView.render(os.clock()) end
	local now=os.clock()
	aimPreview(now)
	local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	effects.render(dt,latest,root,workspace.CurrentCamera)
	if latest and latest.mastery and latest.phase=="Playing" and (latest.startersRemaining or 0)==0 and not menu.isOpen() then
		local m=latest.mastery
		local window=math.max(1,tonumber(m.chainWindow) or 6)
		local chainTime=math.max(0,(tonumber(m.chainSeconds) or 0)-(now-stateAt))
		local chain=if chainTime>0 then (m.chain or 0) else 0
		local tier=Ui.tier(if chainTime>0 then m.multiplier else 1)
		comboChain.Text=if chain>0 then string.format("CHAIN %d • %.1fs",chain,chainTime) else "CATCH TO CHAIN"
		comboBadge.Text=tier.label; comboBadge.BackgroundColor3=tier.color
		comboFill.Size=UDim2.fromScale(math.clamp(chainTime/window,0,1),1)
		comboFill.BackgroundColor3=if chainTime<1.5 and chain>0 then palette.warm else palette.mint
		combo.Visible=true
	else
		combo.Visible=false
	end
	for action,b in pairs({Capture=captureButton,Dash=dashButton}) do
		local remaining=math.max(0,cooldownUntil[action]-now)
		local name=if action=="Capture" then "CATCH" else "DASH"
		local hint=if UserInputService.TouchEnabled then "" elseif action=="Capture" then "\n[E / X]" else "\n[Shift / B]"
		b.Text=if remaining>.05 then string.format("%s\n%.1fs",name,remaining) else name..hint
		b.BackgroundTransparency=if remaining>.05 then .35 else 0
	end
	local still=reduced()
	for other,f in pairs(followers) do
		local otherRoot=other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if otherRoot then
			for index,mini in ipairs(f.models) do
				local offset=Vector3.new((index%2*2-1)*1.7,-1+(if still then 0 else math.sin(now*4-index)*.2),2+index*1.15)
				mini:PivotTo(otherRoot.CFrame*CFrame.new(offset))
			end
		else
			for _,mini in ipairs(f.models) do mini:PivotTo(CFrame.new(0,-1000,0)) end
		end
	end
	if latest and bankGuide.Visible and now-guideAt>.1 then
		guideAt=now
		local camera=workspace.CurrentCamera
		if root and camera and typeof(latest.bankPosition)=="Vector3" then
			local relative=camera.CFrame:PointToObjectSpace(latest.bankPosition)
			local direction=if relative.Z>0 then "TURN BACK" elseif relative.X>8 then "BANK →" elseif relative.X < -8 then "← BANK" else "BANK ↑"
			bankGuide.Text=direction.."  "..math.floor((root.Position-latest.bankPosition).Magnitude).." studs"
		end
	end
end)
Action:FireServer("Ready")
-- Ready is idempotent; retries cover a slow server-world build without a dead HUD.
task.spawn(function() for _=1,10 do task.wait(2); if latest and latest.phase~="Loading" then return end; Action:FireServer("Ready") end end)
