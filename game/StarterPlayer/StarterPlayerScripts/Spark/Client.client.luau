-- Responsive input, UI and bounded local effects. All rewards originate on server.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
local ContextActionService=game:GetService("ContextActionService")
local TweenService=game:GetService("TweenService")
local RunService=game:GetService("RunService")
local Debris=game:GetService("Debris")
local SoundService=game:GetService("SoundService")
local player=Players.LocalPlayer
local Shared=ReplicatedStorage:WaitForChild("Spark")
local Config=require(Shared:WaitForChild("Config"))
local Profile=require(Shared:WaitForChild("Profile"))
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
	Size=UDim2.new(1,-24,0,70),Position=UDim2.fromOffset(12,8),BorderSizePixel=0})
round(top)
local brand=label(top,"SPARK\nSTAMPEDE",18,UDim2.fromOffset(14,7),UDim2.fromOffset(130,54))
local timer=label(top,"1:50",26,UDim2.new(.5,-40,0,5),UDim2.fromOffset(80,31))
timer.TextXAlignment=Enum.TextXAlignment.Center
local eventLabel=label(top,"GET READY",12,UDim2.new(.5,-100,0,40),UDim2.fromOffset(200,18),palette.purple)
eventLabel.TextXAlignment=Enum.TextXAlignment.Center
local glow=label(top,"0 GLOW",20,UDim2.new(1,-165,0,8),UDim2.fromOffset(150,28))
glow.TextXAlignment=Enum.TextXAlignment.Right
local carry=label(top,"PARADE 0 / 8",12,UDim2.new(1,-165,0,40),UDim2.fromOffset(150,20))
carry.TextXAlignment=Enum.TextXAlignment.Right
local objective=label(gui,"Connecting your collection…",17,UDim2.new(.5,-290,0,87),UDim2.fromOffset(580,44),palette.ink)
objective.TextXAlignment=Enum.TextXAlignment.Center
objective.BackgroundColor3=palette.paper; objective.BackgroundTransparency=.12; round(objective,12)
local menu=button(gui,"COLLECTION  ≡",UDim2.fromOffset(12,141),UDim2.fromOffset(158,42),palette.paper,function() end)
local saveLabel=label(gui,"Loading",11,UDim2.new(0,14,1,-24),UDim2.fromOffset(230,18),palette.ink)
local bankGuide=label(gui,"",16,UDim2.new(.5,-120,1,-74),UDim2.fromOffset(240,40),palette.ink)
bankGuide.TextXAlignment=Enum.TextXAlignment.Center
bankGuide.BackgroundColor3=palette.gold; bankGuide.BackgroundTransparency=.08; round(bankGuide)
bankGuide.Visible=false
local controls=make("Frame",gui,{BackgroundTransparency=1,Size=UDim2.fromScale(1,1)})
local captureButton=button(controls,"CATCH\n[E / X]",UDim2.new(1,-122,1,-182),UDim2.fromOffset(108,70),palette.mint,function() requestAction("Capture") end)
local dashButton=button(controls,"DASH\n[Shift / B]",UDim2.new(1,-232,1,-165),UDim2.fromOffset(100,58),palette.gold,function() requestAction("Dash") end)
local toast=label(gui,"",20,UDim2.new(.5,-250,.58,-28),UDim2.fromOffset(500,56),palette.ink)
toast.TextXAlignment=Enum.TextXAlignment.Center; toast.BackgroundColor3=palette.gold; toast.BackgroundTransparency=.05; round(toast)
toast.Visible=false
local toastSerial=0
local shade=make("Frame",gui,{Size=UDim2.fromScale(1,1),BackgroundColor3=palette.ink,BackgroundTransparency=.3,Visible=false,ZIndex=5})
local panel=make("Frame",shade,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(640,500),BackgroundColor3=palette.paper,BorderSizePixel=0,ZIndex=6})
round(panel,20)
local panelTitle=label(panel,"YOUR SPARKS",24,UDim2.fromOffset(22,14),UDim2.new(1,-80,0,38)); panelTitle.ZIndex=7
local content=make("ScrollingFrame",panel,{Position=UDim2.fromOffset(16,108),Size=UDim2.new(1,-32,1,-124),BackgroundTransparency=1,BorderSizePixel=0,
	ScrollBarThickness=5,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ZIndex=7})
local tabs=make("Frame",panel,{Position=UDim2.fromOffset(16,62),Size=UDim2.new(1,-32,0,36),BackgroundTransparency=1,ZIndex=7})
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
end
local close=button(panel,"×",UDim2.new(1,-54,0,14),UDim2.fromOffset(38,38),palette.gold,function() togglePanel(nil) end); close.ZIndex=8
for i,name in ipairs({"Album","Upgrades","Quests","Arenas","Settings"}) do
	local b=button(tabs,name,UDim2.new((i-1)/5,2,0,0),UDim2.new(1/5,-4,1,0),palette.mint,function() togglePanel(name) end)
	b.TextSize=13; b.ZIndex=8
end
menu.Activated:Connect(function() togglePanel(if selectedPanel then nil else "Album") end)

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
					if item:IsA("BasePart") then item.Anchored=true; item.CanCollide=false; item.CanQuery=false; item.CanTouch=false
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
local function row(height)
	local r=make("Frame",content,{Size=UDim2.new(1,-6,0,height),BackgroundColor3=Color3.fromRGB(234,234,249),BorderSizePixel=0,ZIndex=8})
	round(r,12)
	return r
end
local function rowText(r,text,size,y)
	local t=label(r,text,size,UDim2.fromOffset(14,y),UDim2.new(1,-28,0,size+14)); t.ZIndex=9; return t
end
renderPanel=function()
	for _,child in ipairs(content:GetChildren()) do child:Destroy() end
	make("UIListLayout",content,{Padding=UDim.new(0,9),SortOrder=Enum.SortOrder.LayoutOrder})
	if not latest or not latest.profile then return end
	local p=latest.profile
	panelTitle.Text=string.upper(selectedPanel or "Album").."  •  "..p.coins.." GLOW"
	if selectedPanel=="Album" then
		local intro=row(80); rowText(intro,Profile.speciesCount(p).." / 12 discovered • Your collection stays with you",15,4)
		rowText(intro,"5 of a species → Glow   •   15 → Prism",13,44)
		for _,def in ipairs(Config.Creatures) do
			local count=p.album[def.id] or 0
			local r=row(108)
			local view=make("ViewportFrame",r,{Position=UDim2.fromOffset(8,8),Size=UDim2.fromOffset(92,92),BackgroundTransparency=1,ZIndex=9,
				Ambient=Color3.fromRGB(200,200,200),LightColor=Color3.new(1,1,1),LightDirection=Vector3.new(-1,-1,-1)})
			local mini=miniature(def.id,view); mini:PivotTo(CFrame.new())
			local bounds,size=mini:GetBoundingBox()
			local distance=math.max(6,size.Magnitude*.5/math.sin(math.rad(20)))
			local target=bounds.Position
			local camera=make("Camera",view,{CFrame=CFrame.lookAt(target+Vector3.new(.3,.18,-1).Unit*distance,target),FieldOfView=40}); view.CurrentCamera=camera
			local name=label(r,def.name.."  •  "..def.rarity,17,UDim2.fromOffset(110,10),UDim2.new(1,-122,0,26)); name.ZIndex=9
			name.TextScaled=true; make("UITextSizeConstraint",name,{MinTextSize=11,MaxTextSize=17})
			local description=label(r,def.trait,13,UDim2.fromOffset(110,39),UDim2.new(1,-122,0,30)); description.ZIndex=9
			local mutation=p.mutations[def.id] or 0
			local status=label(r,if count==0 then "Find in "..Config.Biomes[def.biome].name else count.." banked"..(if mutation>0 then "  •  "..Config.Mutations[mutation].name else ""),13,UDim2.fromOffset(110,73),UDim2.new(1,-122,0,24),palette.purple); status.ZIndex=9
		end
	elseif selectedPanel=="Upgrades" then
		for _,key in ipairs({"boots","magnet","basket"}) do
			local upgrade=Config.Upgrades[key]; local level=p.upgrades[key]; local price=upgrade.costs[level+1]
			local r=row(130); rowText(r,upgrade.name.." • Level "..level,18,6); rowText(r,upgrade.description,14,37)
			local b=button(r,if price then "UPGRADE • "..price.." GLOW" else "FULLY UPGRADED",UDim2.fromOffset(14,80),UDim2.new(1,-28,0,38),palette.gold,function() if price then Action:FireServer("Upgrade",key) end end); b.ZIndex=9
		end
	elseif selectedPanel=="Quests" then
		for _,quest in ipairs(Config.Quests) do
			local progress=Profile.questProgress(p,quest)
			local claimed=p.quests[quest.id]
			local r=row(104); rowText(r,quest.name.." • "..math.min(progress,quest.target).." / "..quest.target,17,5)
			local b=button(r,if claimed then "COMPLETE" elseif progress>=quest.target then "CLAIM "..quest.reward.." GLOW" else "Reward: "..quest.reward.." glow",UDim2.fromOffset(14,53),UDim2.new(1,-28,0,38),if progress>=quest.target then palette.gold else palette.mint,function() Action:FireServer("Quest",quest.id) end); b.ZIndex=9
		end
	elseif selectedPanel=="Arenas" then
		for index,biome in ipairs(Config.Biomes) do
			local unlocked=p.totalBanked>=biome.unlock
			local r=row(137); rowText(r,biome.name,19,7); rowText(r,biome.description,13,37)
			local b=button(r,if unlocked then (if latest.biome==index then "YOU ARE HERE" else "TRAVEL") else "Bank "..biome.unlock.." Sparks to unlock",UDim2.fromOffset(14,86),UDim2.new(1,-28,0,38),Color3.fromRGB(table.unpack(biome.accent)),function()
				if unlocked then Action:FireServer("Biome",index); togglePanel(nil) end
			end); b.ZIndex=9
		end
	elseif selectedPanel=="Settings" then
		for _,setting in ipairs({{"reducedMotion","Reduced motion"},{"music","Music"},{"sfx","Sound effects"}}) do
			local r=row(64)
			local b=button(r,setting[2]..": "..(if p.settings[setting[1]] then "ON" else "OFF"),UDim2.fromOffset(12,10),UDim2.new(1,-24,0,44),palette.mint,function() Action:FireServer("Settings",{[setting[1]]=not p.settings[setting[1]]}) end); b.ZIndex=9
		end
		local r=row(96); rowText(r,"Move: WASD / thumbstick • Jump: Space / A",14,7)
		rowText(r,"Catch: E / X • Dash: Shift / B • Bank: R / Y",14,34)
		rowText(r,"Every reward is earned through play. No purchases.",13,61)
	end
end

results=make("Frame",gui,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(400,260),BackgroundColor3=palette.paper,BorderSizePixel=0,Visible=false,ZIndex=3}); round(results,20)
local resultTitle=label(results,"WHAT A PARADE!",25,UDim2.fromOffset(20,18),UDim2.new(1,-40,0,40)); resultTitle.TextXAlignment=Enum.TextXAlignment.Center
local resultScore=label(results,"",19,UDim2.fromOffset(20,72),UDim2.new(1,-40,0,58)); resultScore.TextXAlignment=Enum.TextXAlignment.Center
button(results,"CHASE AGAIN",UDim2.fromOffset(20,148),UDim2.new(1,-40,0,47),palette.gold,function() togglePanel(nil); Action:FireServer("Replay") end)
button(results,"UPGRADE YOUR PARADE",UDim2.fromOffset(20,205),UDim2.new(1,-40,0,36),palette.mint,function() togglePanel("Upgrades") end)
for _,child in ipairs(results:GetChildren()) do if child:IsA("GuiObject") then child.ZIndex=4 end end

local function resize()
	local camera=workspace.CurrentCamera; if not camera then return end
	local size=camera.ViewportSize
	local width=math.max(280,math.min(640,size.X-24))
	panel.Size=UDim2.fromOffset(width,math.max(220,math.min(560,size.Y-64)))
	objective.Size=UDim2.fromOffset(math.min(580,size.X-24),44)
	objective.Position=UDim2.new(.5,-math.min(580,size.X-24)/2,0,87)
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
bindViewport()

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
	if state==Enum.UserInputState.Begin then togglePanel(if selectedPanel then nil else "Album") end
	return Enum.ContextActionResult.Sink
end,false,Enum.KeyCode.Tab,Enum.KeyCode.ButtonSelect)

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
	latest=data
	local seconds=data.remaining or 0
	timer.Text=string.format("%d:%02d",math.floor(seconds/60),seconds%60)
	eventLabel.Text=data.event or "CHASE TIME"
	glow.Text=data.profile.coins.." GLOW"
	carry.Text=string.format("PARADE %d / %d",data.carry,data.capacity)
	objective.Text=data.objective
	saveLabel.Text=data.saveStatus
	resultScore.Text=string.format("+%d glow this round\n%d / 12 Sparks discovered",data.score,Profile.speciesCount(data.profile))
	syncOverlays()
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
	local fingerprint=table.concat({data.profile.coins,data.profile.totalBanked,data.profile.rounds,tostring(data.profile.settings.reducedMotion),tostring(data.profile.settings.music),tostring(data.profile.settings.sfx)},":")
	if selectedPanel and fingerprint~=lastFingerprint then renderPanel() end
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
