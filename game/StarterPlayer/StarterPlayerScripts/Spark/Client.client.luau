-- Responsive input, UI and bounded local effects. All rewards originate on server.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
local ContextActionService=game:GetService("ContextActionService")
local TweenService=game:GetService("TweenService")
local RunService=game:GetService("RunService")
local Debris=game:GetService("Debris")
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
local remotes=Shared:WaitForChild("Remotes")
local Action=remotes:WaitForChild("Action")
local State=remotes:WaitForChild("State")
local Feedback=remotes:WaitForChild("Feedback")
local palette={ink=Color3.fromRGB(28,35,66),paper=Color3.fromRGB(249,249,255),
	gold=Color3.fromRGB(255,219,90),mint=Color3.fromRGB(99,237,194),purple=Color3.fromRGB(120,96,211)}
local gui=Instance.new("ScreenGui")
gui.Name="SparkHUD"; gui.ResetOnSpawn=false; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.Parent=player:WaitForChild("PlayerGui")
local latest=nil
local selectedPanel=nil
local results
local replayButton
local close
local tabButtons={}
local function controllerActive()
	return string.match(UserInputService:GetLastInputType().Name,"^Gamepad")~=nil
end
local cooldownUntil={Capture=0,Dash=0}
local function requestAction(action)
	if selectedPanel or not latest or latest.phase~="Playing" then return end
	if cooldownUntil[action] and os.clock()<cooldownUntil[action] then return end
	if action=="Capture" then cooldownUntil.Capture=os.clock()+(latest.captureCooldown or Config.CaptureCooldown) end
	Action:FireServer(action)
end
local lastFingerprint=""
local defs={}
for _,def in ipairs(Config.Creatures) do defs[def.id]=def end
local function make(class,parent,props)
	local object=Instance.new(class)
	for key,value in pairs(props or {}) do object[key]=value end
	object.Parent=parent
	return object
end
local function round(object,radius)
	make("UICorner",object,{CornerRadius=UDim.new(0,radius or 14)})
end
local function label(parent,text,size,position,dimensions,color)
	return make("TextLabel",parent,{Text=text,TextSize=size,Font=Enum.Font.GothamBold,
		BackgroundTransparency=1,TextColor3=color or palette.ink,Position=position,Size=dimensions,
		TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left})
end
local function button(parent,text,position,dimensions,color,callback)
	local b=make("TextButton",parent,{Text=text,TextSize=17,Font=Enum.Font.GothamBold,
		BackgroundColor3=color or palette.paper,TextColor3=palette.ink,BorderSizePixel=0,
		Position=position,Size=dimensions,AutoButtonColor=true,Selectable=true})
	round(b,12)
	b.Activated:Connect(callback)
	return b
end
local top=make("Frame",gui,{BackgroundColor3=palette.paper,BackgroundTransparency=0.05,
	Name="HudTop",Size=UDim2.new(1,-24,0,70),Position=UDim2.fromOffset(12,8),BorderSizePixel=0})
round(top)
local brand=label(top,"SPARK\nSTAMPEDE",18,UDim2.fromOffset(14,7),UDim2.fromOffset(130,54))
brand.Name="Brand"
local timer=label(top,"1:50",26,UDim2.new(.5,-40,0,5),UDim2.fromOffset(80,31))
timer.Name="Timer"
timer.TextXAlignment=Enum.TextXAlignment.Center
local eventLabel=label(top,"GET READY",12,UDim2.new(.5,-100,0,40),UDim2.fromOffset(200,18),palette.purple)
eventLabel.Name="Event"
eventLabel.TextXAlignment=Enum.TextXAlignment.Center
local glow=label(top,"0 GLOW",20,UDim2.new(1,-165,0,8),UDim2.fromOffset(150,28))
glow.Name="Glow"
glow.TextXAlignment=Enum.TextXAlignment.Right
local carry=label(top,"PARADE 0 / 8",12,UDim2.new(1,-165,0,40),UDim2.fromOffset(150,20))
carry.Name="Carry"
carry.TextXAlignment=Enum.TextXAlignment.Right
local objective=label(gui,"Connecting your collection…",17,UDim2.new(.5,-290,0,87),UDim2.fromOffset(580,44),palette.ink)
objective.Name="Objective"
objective.TextXAlignment=Enum.TextXAlignment.Center
objective.BackgroundColor3=palette.paper; objective.BackgroundTransparency=.12; round(objective,12)
local menu=button(gui,"COLLECTION  ≡",UDim2.fromOffset(12,141),UDim2.fromOffset(158,42),palette.paper,function() end)
menu.Name="CollectionButton"
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
local toast=label(gui,"",20,UDim2.new(.5,-250,.58,-28),UDim2.fromOffset(500,56),palette.ink)
toast.Name="FeedbackToast"
toast.TextXAlignment=Enum.TextXAlignment.Center; toast.BackgroundColor3=palette.gold; toast.BackgroundTransparency=.05; round(toast)
toast.Visible=false
local toastSerial=0
local shade=make("Frame",gui,{Name="Overlay",Size=UDim2.fromScale(1,1),BackgroundColor3=palette.ink,BackgroundTransparency=.3,Visible=false,ZIndex=5})
local panel=make("Frame",shade,{Name="Panel",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(640,500),BackgroundColor3=palette.paper,BorderSizePixel=0,ZIndex=6})
round(panel,20)
local panelTitle=label(panel,"YOUR SPARKS",24,UDim2.fromOffset(22,14),UDim2.new(1,-80,0,38)); panelTitle.ZIndex=7
panelTitle.Name="Title"
panelTitle.TextScaled=true; panelTitle.TextWrapped=false
make("UITextSizeConstraint",panelTitle,{MinTextSize=12,MaxTextSize=24})
local content=make("ScrollingFrame",panel,{Name="Content",Position=UDim2.fromOffset(16,108),Size=UDim2.new(1,-32,1,-124),BackgroundTransparency=1,BorderSizePixel=0,
	ScrollBarThickness=5,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,Selectable=true,ZIndex=7})
local tabs=make("Frame",panel,{Name="Tabs",Position=UDim2.fromOffset(16,62),Size=UDim2.new(1,-32,0,36),BackgroundTransparency=1,ZIndex=7})
local renderPanel
local function syncOverlays()
	local playing=latest~=nil and latest.phase=="Playing"
	shade.Visible=selectedPanel~=nil
	controls.Visible=playing and selectedPanel==nil
	bankGuide.Visible=playing and latest.carry>0 and selectedPanel==nil
	if results then results.Visible=latest~=nil and latest.phase=="Results" and selectedPanel==nil end
end
local function togglePanel(name)
	selectedPanel=name
	syncOverlays()
	if name then renderPanel() end
	if controllerActive() then
		GuiService.SelectedObject=if name then tabButtons[name] elseif results and results.Visible then replayButton else nil
	elseif not name and GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(panel) then
		GuiService.SelectedObject=nil
	end
end
close=button(panel,"×",UDim2.new(1,-54,0,14),UDim2.fromOffset(38,38),palette.gold,function() togglePanel(nil) end); close.ZIndex=8
close.Name="CloseButton"
for i,name in ipairs({"Album","Upgrades","Quests","Arenas","Settings"}) do
	local b=button(tabs,name,UDim2.new((i-1)/5,2,0,0),UDim2.new(1/5,-4,1,0),palette.mint,function() togglePanel(name) end)
	b.Name=name; b.TextSize=13; b.ZIndex=8
	b.TextScaled=true; make("UITextSizeConstraint",b,{MinTextSize=10,MaxTextSize=13})
	tabButtons[name]=b
end
local tabOrder={"Album","Upgrades","Quests","Arenas","Settings"}
for i,name in ipairs(tabOrder) do
	local b=tabButtons[name]
	b.NextSelectionLeft=tabButtons[tabOrder[(i-2)%#tabOrder+1]]
	b.NextSelectionRight=tabButtons[tabOrder[i%#tabOrder+1]]
	b.NextSelectionUp=close
	b.NextSelectionDown=content
end
close.NextSelectionDown=tabButtons.Album
content.NextSelectionUp=tabButtons.Album
menu.Activated:Connect(function() togglePanel(if selectedPanel then nil else "Album") end)

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
task.spawn(function()
	local herd=workspace:WaitForChild("SparkWorld"):WaitForChild("Creatures")
	local watches={}
	local function watch(model)
		if model:IsA("Model") and not watches[model] then watches[model]=watchStarter(model,player.UserId) end
	end
	herd.ChildAdded:Connect(watch)
	herd.ChildRemoved:Connect(function(model)
		if watches[model] then watches[model](); watches[model]=nil end
	end)
	for _,model in ipairs(herd:GetChildren()) do watch(model) end
end)

local templates={}
local function miniature(id,parent)
	if templates[id] then local clone=templates[id]:Clone(); clone.Parent=parent; return clone end
	local world=workspace:FindFirstChild("SparkWorld")
	local herd=world and world:FindFirstChild("Creatures")
	if herd then
		for _,model in ipairs(herd:GetChildren()) do
			if model:GetAttribute("Species")==id then
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
local function row(height,name)
	local r=make("Frame",content,{Name=name or "Row",Size=UDim2.new(1,-6,0,height),BackgroundColor3=Color3.fromRGB(234,234,249),BorderSizePixel=0,ZIndex=8})
	round(r,12)
	return r
end
local function rowText(r,text,size,y)
	local t=label(r,text,size,UDim2.fromOffset(14,y),UDim2.new(1,-28,0,size+14)); t.Name="Line_"..y; t.ZIndex=9; return t
end
renderPanel=function()
	local focused=GuiService.SelectedObject
	local focusedRow=if focused and focused.Parent and focused:IsDescendantOf(content) then focused.Parent.Name else nil
	local focusedName=if focusedRow then focused.Name else nil
	for _,child in ipairs(content:GetChildren()) do child:Destroy() end
	make("UIListLayout",content,{Padding=UDim.new(0,9),SortOrder=Enum.SortOrder.LayoutOrder})
	if not latest or not latest.profile then return end
	local p=latest.profile
	panelTitle.Text=string.upper(selectedPanel or "Album").."  •  "..p.coins.." GLOW"
	if selectedPanel=="Album" then
		local intro=row(80,"CollectionSummary"); rowText(intro,Profile.speciesCount(p).." / 12 discovered • Your collection stays with you",15,4)
		rowText(intro,"5 of a species → Glow   •   15 → Prism",13,44)
		for _,def in ipairs(Config.Creatures) do
			local count=p.album[def.id] or 0
			local r=row(108,"Album_"..def.id)
			local view=make("ViewportFrame",r,{Name="Preview",Position=UDim2.fromOffset(8,8),Size=UDim2.fromOffset(92,92),BackgroundTransparency=1,ZIndex=9,
				Ambient=Color3.fromRGB(200,200,200),LightColor=Color3.new(1,1,1),LightDirection=Vector3.new(-1,-1,-1)})
			local mini=miniature(def.id,view); mini:PivotTo(CFrame.new())
			local bounds,size=mini:GetBoundingBox()
			local distance=math.max(6,size.Magnitude*.5/math.sin(math.rad(20)))
			local target=bounds.Position
			local camera=make("Camera",view,{CFrame=CFrame.lookAt(target+Vector3.new(.3,.18,-1).Unit*distance,target),FieldOfView=40}); view.CurrentCamera=camera
			local name=label(r,def.name.."  •  "..def.rarity,17,UDim2.fromOffset(110,10),UDim2.new(1,-122,0,26)); name.ZIndex=9
			name.Name="SpeciesName"
			name.TextScaled=true; make("UITextSizeConstraint",name,{MinTextSize=11,MaxTextSize=17})
			local description=label(r,def.trait,13,UDim2.fromOffset(110,39),UDim2.new(1,-122,0,30)); description.ZIndex=9
			description.Name="Trait"
			local mutation=p.mutations[def.id] or 0
			local status=label(r,if count==0 then "Find in "..Config.Biomes[def.biome].name else count.." banked"..(if mutation>0 then "  •  "..Config.Mutations[mutation].name else ""),13,UDim2.fromOffset(110,73),UDim2.new(1,-122,0,24),palette.purple); status.ZIndex=9
			status.Name="Status"
		end
	elseif selectedPanel=="Upgrades" then
		for _,key in ipairs({"boots","magnet","basket"}) do
			local upgrade=Config.Upgrades[key]; local level=p.upgrades[key]; local price=upgrade.costs[level+1]
			local r=row(130,"Upgrade_"..key); rowText(r,upgrade.name.." • Level "..level,18,6); rowText(r,upgrade.description,14,37)
			local b=button(r,if price then "UPGRADE • "..price.." GLOW" else "FULLY UPGRADED",UDim2.fromOffset(14,80),UDim2.new(1,-28,0,38),palette.gold,function() if price then Action:FireServer("Upgrade",key) end end); b.ZIndex=9
			b.Name="UpgradeButton"
		end
	elseif selectedPanel=="Quests" then
		if latest.rally then
			local rally=latest.rally
			local r=row(112,"ArenaRally")
			rowText(r,"ARENA RALLY • "..rally.total.." / "..rally.target.." banked",17,5)
			rowText(r,"Solo or together: bank ordinary Sparks in 45 seconds",13,34)
			rowText(r,"Each active contributor earns 8 glow • First catches excluded",12,60)
			rowText(r,if rally.complete then "COMPLETE • Next rally in "..rally.remaining.."s" else "Your contribution: "..rally.contribution.." • "..rally.remaining.."s left",12,84)
		end
		if latest.mastery then
			local goal=latest.mastery.challenge
			local r=row(120,"RoundChallenge")
			rowText(r,goal.name.." • "..goal.progress.." / "..goal.target,17,5)
			rowText(r,goal.description,13,34)
			rowText(r,if goal.complete then "COMPLETE • 100 skill secured" else "Bank to secure 100 bonus skill • No glow cost",13,65)
			rowText(r,"Best chain: "..p.mastery.bestChain.." • Goals cleared: "..p.mastery.completed,12,91)
		end
		for _,quest in ipairs(Config.Quests) do
			local progress=Profile.questProgress(p,quest)
			local claimed=p.quests[quest.id]
			local r=row(if quest.description then 136 else 104,"Quest_"..quest.id); rowText(r,quest.name.." • "..math.min(progress,quest.target).." / "..quest.target,17,5)
			if quest.description then rowText(r,quest.description,13,35) end
			local b=button(r,if claimed then "COMPLETE" elseif progress>=quest.target then "CLAIM "..quest.reward.." GLOW" else "Reward: "..quest.reward.." glow",UDim2.fromOffset(14,if quest.description then 85 else 53),UDim2.new(1,-28,0,38),if progress>=quest.target then palette.gold else palette.mint,function() Action:FireServer("Quest",quest.id) end); b.ZIndex=9
			b.Name="ClaimButton"
		end
	elseif selectedPanel=="Arenas" then
		for index,biome in ipairs(Config.Biomes) do
			local unlocked=p.totalBanked>=biome.unlock
			local r=row(137,"Arena_"..biome.id); rowText(r,biome.name,19,7); rowText(r,biome.description,13,37)
			local b=button(r,if unlocked then (if latest.biome==index then "YOU ARE HERE" else "TRAVEL") else "Bank "..biome.unlock.." Sparks to unlock",UDim2.fromOffset(14,86),UDim2.new(1,-28,0,38),Color3.fromRGB(table.unpack(biome.accent)),function()
				if unlocked then Action:FireServer("Biome",index); togglePanel(nil) end
			end); b.ZIndex=9
			b.Name="TravelButton"
		end
	elseif selectedPanel=="Settings" then
		for _,setting in ipairs({{"reducedMotion","Reduced motion"},{"music","Music"},{"sfx","Sound effects"},{"competition","Opt in: session scores"}}) do
			local r=row(64,"Setting_"..setting[1])
			local b=button(r,setting[2]..": "..(if p.settings[setting[1]] then "ON" else "OFF"),UDim2.fromOffset(12,10),UDim2.new(1,-24,0,44),palette.mint,function() Action:FireServer("Settings",{[setting[1]]=not p.settings[setting[1]]}) end); b.ZIndex=9
			b.Name="ToggleButton"
		end
		local r=row(96,"ControlsHelp"); rowText(r,"Move: WASD / thumbstick • Jump: Space / A",14,7)
		rowText(r,"Catch: E / X • Dash: Shift / B • Bank: R / Y",14,34)
		rowText(r,"Collection: M / Select • All rewards earned in play",13,61)
		local help=row(112,"MasteryHelp")
		rowText(help,"Aim close + face your Spark for precision",13,7)
		rowText(help,"Dash then catch • Chain catches within 6 seconds",13,33)
		rowText(help,"Misses / orange sweeps lose carried skill bonus",13,59)
		rowText(help,"Banked score, glow and collection stay safe",13,85)
		if p.settings.competition then
			local scores=row(130,"SessionScores")
			rowText(scores,"Optional session scores • current rounds",14,4)
			for index,entry in ipairs(latest.ranking or {}) do rowText(scores,entry.name.." • "..entry.score,13,8+index*24) end
		end
	end
	local firstAction=nil
	for _,r in ipairs(content:GetChildren()) do
		for _,child in ipairs(r:GetChildren()) do
			if child:IsA("GuiButton") then firstAction=child; break end
		end
		if firstAction then break end
	end
	for _,b in pairs(tabButtons) do b.NextSelectionDown=firstAction or content end
	if focusedRow and controllerActive() then
		local replacementRow=content:FindFirstChild(focusedRow)
		GuiService.SelectedObject=(replacementRow and replacementRow:FindFirstChild(focusedName)) or tabButtons[selectedPanel]
	end
end

results=make("Frame",gui,{Name="Results",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(400,260),BackgroundColor3=palette.paper,BorderSizePixel=0,Visible=false,ZIndex=3}); round(results,20)
local resultTitle=label(results,"WHAT A PARADE!",25,UDim2.fromOffset(20,18),UDim2.new(1,-40,0,40)); resultTitle.TextXAlignment=Enum.TextXAlignment.Center
resultTitle.Name="Title"
local resultScore=label(results,"",19,UDim2.fromOffset(20,72),UDim2.new(1,-40,0,58)); resultScore.TextXAlignment=Enum.TextXAlignment.Center
resultScore.Name="Score"
replayButton=button(results,"CHASE AGAIN",UDim2.fromOffset(20,148),UDim2.new(1,-40,0,47),palette.gold,function() togglePanel(nil); Action:FireServer("Replay") end)
replayButton.Name="ReplayButton"
local resultUpgrade=button(results,"UPGRADE YOUR PARADE",UDim2.fromOffset(20,205),UDim2.new(1,-40,0,36),palette.mint,function() togglePanel("Upgrades") end)
resultUpgrade.Name="UpgradeButton"
replayButton.NextSelectionDown=resultUpgrade
resultUpgrade.NextSelectionUp=replayButton
for _,child in ipairs(results:GetChildren()) do if child:IsA("GuiObject") then child.ZIndex=4 end end

-- BEGIN PURE LAYOUT: extracted by tests/SparkClientLayoutSmoke.ps1.
local function layoutFor(width,height,touch)
	local panelWidth=math.min(640,math.max(240,width-24))
	local panelHeight=math.min(560,math.max(200,height-64))
	local touchWide=touch and width>=560
	local stacked=touch and not touchWide
	local compact=touchWide and height<330
	local bankWidth=if compact then 140 elseif touchWide then math.min(240,width-320) else math.min(240,width-24)
	local objectiveWidth=if compact then width-142 else math.min(580,width-24)
	return {
		panel={x=(width-panelWidth)/2,y=(height-panelHeight)/2,w=panelWidth,h=panelHeight},
		capture={x=width-122,y=if compact then 126 else height-(if stacked then 244 else 182),w=108,h=if compact then 44 else 70},
		dash={x=width-(if stacked then 122 else 232),y=if compact then 126 else height-165,w=if stacked then 108 else 100,h=if compact then 44 else 58},
		bank={x=if touchWide then 180 else (width-bankWidth)/2,y=if compact then 128 elseif touchWide then 133 elseif touch then 187 else height-74,w=bankWidth,h=if touchWide then 36 else 40},
		objective={x=if compact then 130 else (width-objectiveWidth)/2,y=if compact then 80 else 87,w=objectiveWidth,h=if compact then 40 else 44},
		collection={x=12,y=if compact then 80 else 141,w=if compact then 110 else 158,h=if compact then 40 else 42},
	}
end
-- END PURE LAYOUT
local function resize()
	local camera=workspace.CurrentCamera; if not camera then return end
	local size=gui.AbsoluteSize
	if size.X<=0 or size.Y<=0 then size=camera.ViewportSize end
	local layout=layoutFor(size.X,size.Y,UserInputService.TouchEnabled)
	panel.Size=UDim2.fromOffset(layout.panel.w,layout.panel.h)
	for key,b in pairs({capture=captureButton,dash=dashButton,bank=bankGuide,objective=objective,collection=menu}) do
		local rect=layout[key]
		b.Position=UDim2.fromOffset(rect.x,rect.y); b.Size=UDim2.fromOffset(rect.w,rect.h)
	end
	objective.TextScaled=true
	menu.TextSize=if layout.collection.w<158 then 12 else 17
	toast.Size=UDim2.fromOffset(math.min(500,size.X-24),56); toast.Position=UDim2.new(.5,-math.min(500,size.X-24)/2,.58,-28)
	results.Size=UDim2.fromOffset(math.min(400,size.X-24),260)
	brand.TextSize=if size.X<500 then 13 else 18
	brand.Size=UDim2.fromOffset(if size.X<500 then 94 else 130,54)
	glow.TextSize=if size.X<500 then 14 else 20
	glow.Position=UDim2.new(1,if size.X<500 then -100 else -165,0,8)
	glow.Size=UDim2.fromOffset(if size.X<500 then 90 else 150,28)
	eventLabel.Position=if size.X<500 then UDim2.fromOffset(10,51) else UDim2.new(.5,-100,0,40)
	eventLabel.Size=if size.X<500 then UDim2.new(.5,-12,0,18) else UDim2.fromOffset(200,18)
	eventLabel.TextXAlignment=if size.X<500 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
	carry.Position=UDim2.new(1,if size.X<500 then -125 else -165,0,if size.X<500 then 51 else 40)
	carry.Size=UDim2.fromOffset(if size.X<500 then 115 else 150,18)
	brand.Size=UDim2.fromOffset(if size.X<500 then 82 else 130,if size.X<500 then 40 else 54)
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
		if selectedPanel then GuiService.SelectedObject=tabButtons[selectedPanel]
		elseif results.Visible then GuiService.SelectedObject=replayButton end
	end
end)

local function bind(name,action,...)
	ContextActionService:BindAction(name,function(_,state)
		if state~=Enum.UserInputState.Begin or UserInputService:GetFocusedTextBox() or selectedPanel then return Enum.ContextActionResult.Pass end
		requestAction(action); return Enum.ContextActionResult.Sink
	end,false,...)
end
bind("SparkCapture","Capture",Enum.KeyCode.E,Enum.KeyCode.ButtonX)
bind("SparkDash","Dash",Enum.KeyCode.LeftShift,Enum.KeyCode.ButtonB)
bind("SparkBank","Bank",Enum.KeyCode.R,Enum.KeyCode.ButtonY)
ContextActionService:BindAction("SparkMenu",function(_,state)
	if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
	if state==Enum.UserInputState.Begin then togglePanel(if selectedPanel then nil else "Album") end
	return Enum.ContextActionResult.Sink
end,false,Enum.KeyCode.M,Enum.KeyCode.ButtonSelect)

local catalogModule=Shared:FindFirstChild("AudioCatalog")
local audioCatalog=if catalogModule then require(catalogModule) else nil
local music=make("Sound",SoundService,{Name="SparkMusic",Volume=.16,Looped=true})
local voices={}
local cueKeys={Catch="catch",Bank="bank",Dash="dash",Upgrade="upgrade",Quest="upgrade",Results="round_reward"}
local function retire(cue)
	local index=table.find(voices,cue)
	if not index then return end
	table.remove(voices,index)
	cue:Destroy()
end
local function sound(kind)
	if latest and not latest.profile.settings.sfx then return end
	local entry=audioCatalog and audioCatalog[cueKeys[kind]]
	if type(entry)~="table" or type(entry.id)~="string" or entry.id=="" then return end
	local limit=if music.IsPlaying then 5 else 6
	while #voices>=limit do retire(voices[1]) end
	local cue=make("Sound",SoundService,{Name="SparkCue_"..kind,SoundId=entry.id,Volume=math.clamp(entry.volume or .25,0,.6)})
	table.insert(voices,cue)
	cue.Ended:Connect(function() retire(cue) end)
	cue:Play()
	task.delay(math.clamp((entry.duration or 2)+1,1,12),function() retire(cue) end)
end
local effects=make("Folder",workspace,{Name="SparkLocalEffects"})
-- One local telegraph, no flashing or screen shake. Server decides every hit.
local sweep=make("Part",effects,{Name="SweepWarning",Shape=Enum.PartType.Cylinder,
	Size=Vector3.new(.15,7,7),Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,
	Material=Enum.Material.SmoothPlastic,Color=Color3.fromRGB(255,157,65),Transparency=1})
local sweepCue=make("BillboardGui",sweep,{Size=UDim2.fromOffset(120,28),StudsOffset=Vector3.new(0,2,0),MaxDistance=50,Enabled=false})
local sweepText=label(sweepCue,"",13,UDim2.new(),UDim2.fromScale(1,1),palette.ink)
sweepText.TextXAlignment=Enum.TextXAlignment.Center
-- One advisory aim outline, updated at 10Hz. Never sends a target or score to the server.
-- Occluded geometry stays occluded; shape/text accompany the color change.
local aimOutline=make("Highlight",effects,{Name="CatchAim",Enabled=false,FillTransparency=1,
	OutlineTransparency=.15,DepthMode=Enum.HighlightDepthMode.Occluded})
local aimCue=make("BillboardGui",gui,{Name="CatchAimCue",Size=UDim2.fromOffset(132,24),StudsOffset=Vector3.new(0,3.3,0),
	MaxDistance=22,AlwaysOnTop=false,Enabled=false})
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
	if root and humanoid and humanoid.Health>0 and herd and latest and latest.phase=="Playing" and not selectedPanel and latest.carry<latest.capacity then
		local function xyz(v) return {x=v.X,y=v.Y,z=v.Z} end
		local radius=Config.CaptureRadius+(latest.profile.upgrades.magnet or 0)*1.5
		for _,model in ipairs(herd:GetChildren()) do
			local id,owner=model:GetAttribute("CreatureId"),model:GetAttribute("StarterOwnerId")
			local def=defs[model:GetAttribute("Species")]
			if id and model.PrimaryPart and def and def.biome==latest.biome and (not owner or (owner==player.UserId and latest.profile.totalBanked<3)) then
				local aim=Targeting.measure(xyz(root.Position),xyz(root.CFrame.LookVector),xyz(model.PrimaryPart.Position),radius)
				if Targeting.better(aim,id,best,target and target:GetAttribute("CreatureId")) then target=model; best=aim end
			end
		end
	end
	aimOutline.Adornee=target; aimOutline.Enabled=target~=nil
	aimCue.Adornee=target and target.PrimaryPart; aimCue.Enabled=target~=nil
	if target then
		local precise=best.precision and target:GetAttribute("StarterOwnerId")==nil
		aimOutline.OutlineColor=if precise then palette.gold else palette.mint
		aimText.Text=if precise then "◆ PRECISE CATCH" else "○ CATCH"
	end
end
local effectCount=0
local function burst(position)
	if effectCount>=24 or (latest and latest.profile.settings.reducedMotion) then return end
	for i=1,8 do
		effectCount+=1
		local dot=make("Part",effects,{Shape=Enum.PartType.Ball,Size=Vector3.new(.35,.35,.35),Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,Material=Enum.Material.Neon,Color=palette.gold,Position=position})
		local angle=i*math.pi/4
		TweenService:Create(dot,TweenInfo.new(.5,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=position+Vector3.new(math.cos(angle)*4,2,math.sin(angle)*4),Transparency=1,Size=Vector3.new(.05,.05,.05)}):Play()
		Debris:AddItem(dot,.6); task.delay(.6,function() effectCount-=1 end)
	end
end
Feedback.OnClientEvent:Connect(function(data)
	if data.kind=="Dash" then cooldownUntil.Dash=os.clock()+(latest and latest.dashCooldown or Config.DashCooldown) end
	toastSerial+=1; local serial=toastSerial
	toast.Text=data.text or ""; toast.Visible=true
	toast.BackgroundColor3=if data.kind=="Hint" or data.kind=="Error" then palette.paper else palette.gold
	task.delay(if data.kind=="Error" then 8 else 2.1,function() if toastSerial==serial then toast.Visible=false end end)
	if data.kind~="Hint" and data.kind~="Error" then sound(data.kind) end
	if data.position then burst(data.position) end
end)
State.OnClientEvent:Connect(function(data)
	local previousPhase=latest and latest.phase
	latest=data
	stateAt=os.clock()
	local seconds=data.remaining or 0
	timer.Text=string.format("%d:%02d",math.floor(seconds/60),seconds%60)
	eventLabel.Text=data.event or "CHASE TIME"
	if data.rally and data.phase=="Playing" and data.profile.totalBanked>=3 then
		eventLabel.Text=if data.rally.complete then "RALLY COMPLETE" else string.format("RALLY %d/%d • %ds",data.rally.total,data.rally.target,data.rally.remaining)
	end
	glow.Text=data.profile.coins.." GLOW"
	carry.Text=string.format("PARADE %d / %d",data.carry,data.capacity)
	objective.Text=data.objective
	if data.mastery then
		local m=data.mastery
		brand.Text=string.format("SCORE %d\nBEST %d",m.score,data.profile.mastery.bestScore)
		if data.phase=="Playing" and (data.startersRemaining or 0)==0 then
			objective.Text=data.objective..string.format("\nx%d • %d carried skill • %s %d/%d",m.multiplier,m.pending,m.challenge.name,m.challenge.progress,m.challenge.target)
		end
	end
	saveLabel.Text=data.saveStatus
	resultScore.Text=string.format("+%d glow this round\n%d / 12 Sparks discovered",data.score,Profile.speciesCount(data.profile))
	if data.mastery then
		resultTitle.Text=if data.personalBest then "NEW PERSONAL BEST!" else data.mastery.medal.." PARADE"
		resultScore.Text=string.format("%d skill • Best %d\n+%d glow • Chain %d",data.mastery.score,data.profile.mastery.bestScore,data.score,data.mastery.bestChain)
	end
	local h=data.hazard
	sweep.Transparency=if h and h.visible then (if h.active then .25 else .65) else 1
	sweepCue.Enabled=h~=nil and h.visible==true
	if h and h.visible then
		sweep.CFrame=CFrame.new(h.position)*CFrame.Angles(0,0,math.pi/2)
		sweepText.Text=if h.active then "DODGE SWEEP" else "SWEEP IN "..math.ceil(h.seconds)
	end
	syncOverlays()
	if previousPhase~=data.phase and controllerActive() and not selectedPanel then
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
		while #voices>5 do retire(voices[1]) end
		if not music.IsPlaying then music:Play() end
	else music:Stop() end
	if not data.profile.settings.sfx then while #voices>0 do retire(voices[1]) end end
	local rankSignature={}
	for _,entry in ipairs(data.ranking or {}) do table.insert(rankSignature,tostring(entry.userId).."="..entry.score) end
	local fingerprint=table.concat({data.profile.coins,data.profile.totalBanked,data.profile.rounds,tostring(data.profile.settings.reducedMotion),tostring(data.profile.settings.music),tostring(data.profile.settings.sfx),tostring(data.profile.settings.competition),data.mastery and data.mastery.challenge.progress or 0,tostring(data.mastery and data.mastery.challenge.complete),table.concat(rankSignature,","),data.rally and data.rally.total or 0,data.rally and data.rally.cycle or 0},":")
	if selectedPanel and fingerprint~=lastFingerprint then renderPanel() end
	-- Keep the countdown current without rebuilding menu controls or stealing gamepad selection.
	if selectedPanel=="Quests" and data.rally then
		local rallyRow=content:FindFirstChild("ArenaRally")
		local countdown=rallyRow and rallyRow:FindFirstChild("Line_84")
		if countdown then
			countdown.Text=if data.rally.complete then "COMPLETE • Next rally in "..data.rally.remaining.."s"
				else "Your contribution: "..data.rally.contribution.." • "..data.rally.remaining.."s left"
		end
	end
	lastFingerprint=fingerprint
end)

local followers={}
local function updateParade(other)
	local previous=followers[other]
	if previous then for _,mini in ipairs(previous.models) do mini:Destroy() end end
	local models={}
	local encoded=other:GetAttribute("SparkParade") or ""
	for _,id in ipairs(string.split(encoded,",")) do
		if defs[id] and #models<8 then
			local mini=miniature(id,effects); mini:ScaleTo(.35); table.insert(models,mini)
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
RunService.RenderStepped:Connect(function()
	local now=os.clock()
	aimPreview(now)
	if latest and latest.mastery and latest.phase=="Playing" and (latest.startersRemaining or 0)==0 then
		local m=latest.mastery
		local chainTime=math.max(0,m.chainSeconds-(now-stateAt))
		local factor=if chainTime>0 then m.multiplier else 1
		objective.Text=latest.objective..string.format("\nx%d • %d skill carried • %s",factor,m.pending,
			if chainTime>0 then string.format("CHAIN %.1fs",chainTime) else "Close + face for precision")
	end
	for action,b in pairs({Capture=captureButton,Dash=dashButton}) do
		local remaining=math.max(0,cooldownUntil[action]-now)
		local name=if action=="Capture" then "CATCH" else "DASH"
		local hint=if UserInputService.TouchEnabled then "" elseif action=="Capture" then "\n[E / X]" else "\n[Shift / B]"
		b.Text=if remaining>.05 then string.format("%s\n%.1fs",name,remaining) else name..hint
		b.BackgroundTransparency=if remaining>.05 then .35 else 0
	end
	local reduced=latest and latest.profile.settings.reducedMotion
	for other,f in pairs(followers) do
		local root=other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if root then
			for index,mini in ipairs(f.models) do
				local offset=Vector3.new((index%2*2-1)*1.7,-1+(if reduced then 0 else math.sin(now*4-index)*.2),2+index*1.15)
				mini:PivotTo(root.CFrame*CFrame.new(offset))
			end
		else
			for _,mini in ipairs(f.models) do mini:PivotTo(CFrame.new(0,-1000,0)) end
		end
	end
	if latest and bankGuide.Visible and now-guideAt>.1 then
		guideAt=now
		local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local camera=workspace.CurrentCamera
		if root and camera then
			local relative=camera.CFrame:PointToObjectSpace(latest.bankPosition)
			local direction=if relative.Z>0 then "TURN BACK" elseif relative.X>8 then "BANK →" elseif relative.X < -8 then "← BANK" else "BANK ↑"
			bankGuide.Text=direction.."  "..math.floor((root.Position-latest.bankPosition).Magnitude).." studs"
		end
	end
end)
Action:FireServer("Ready")
-- Ready is idempotent; retries cover a slow server-world build without a dead HUD.
task.spawn(function() for _=1,10 do task.wait(2); if latest and latest.phase~="Loading" then return end; Action:FireServer("Ready") end end)
