-- Spark Stampede authoritative session orchestrator. Activate only after G0.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")
local Shared = ReplicatedStorage:WaitForChild("Spark")
local Config = require(Shared.Config)
local Profile = require(Shared.Profile)
local Rules = require(Shared.Rules)
local World = require(script.Parent.World)
local Persistence = require(script.Parent.Persistence)

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = Shared
local function remote(name)
	local value = Instance.new("RemoteEvent")
	value.Name = name; value.Parent = remotes
	return value
end
local Action, State, Feedback = remote("Action"), remote("State"), remote("Feedback")
local world = World.build(Config)
local creaturesFolder = world.root:FindFirstChild("Creatures") or Instance.new("Folder")
creaturesFolder.Name = "Creatures"; creaturesFolder.Parent = world.root
local memory = {}
local store
if RunService:IsStudio() then
	-- Isolated test data: never writes a production profile from Studio.
	store = {
		GetAsync = function(_,key) return memory[key] end,
		UpdateAsync = function(_,key,callback)
			local value = callback(memory[key]); if value ~= nil then memory[key] = value end
			return value
		end,
	}
	print("[Spark] Studio memory persistence; real cross-server durability NOT being tested")
else
	store = DataStoreService:GetDataStore("SparkStampedeProfiles_v1")
end
local persistence = Persistence.new(store, os.time, {
	sessionId = game.JobId..":"..HttpService:GenerateGUID(false), wait = task.wait,
})
local sessions, herd = {}, {}
-- BEGIN PURE LIFECYCLE
-- This exact block is exercised by tests/test_spark_lifecycle.py using the Luau runtime.
local Lifecycle={}
function Lifecycle.new() return {closing=false,loads={},finalizers={}} end
function Lifecycle.beginLoad(work,s)
	if work.closing then return false end
	work.loads[s]=true
	return true
end
function Lifecycle.finishLoad(work,s,hasProfile)
	-- Transfer ownership without a gap in the work tracked by BindToClose.
	local detached=work.closing or s.detached
	if detached and hasProfile then work.finalizers[s]=true end
	work.loads[s]=nil
	return if detached then (if hasProfile then "finalize" else "discard") else "active"
end
function Lifecycle.beginFinalize(work,s)
	if s.finalizing then return false end
	s.finalizing=true; work.finalizers[s]=true
	return true
end
function Lifecycle.finishFinalize(work,s)
	s.finalized=true; work.finalizers[s]=nil
end
function Lifecycle.pending(work)
	local count=0
	for _ in pairs(work.loads) do count+=1 end
	for _ in pairs(work.finalizers) do count+=1 end
	return count
end
function Lifecycle.markDirty(s)
	s.revision=(s.revision or 0)+1; s.dirty=true
	s.saveStatus=if s.saving then "Saving earlier progress" else "Save pending"
end
function Lifecycle.saveResult(s,ok,snapshotRevision,studio)
	if ok then
		s.persistedRevision=math.max(s.persistedRevision or 0,snapshotRevision)
		s.dirty=(s.revision or 0)>s.persistedRevision
		s.saveStatus=if s.dirty then "Save pending" elseif studio then "Studio test save" else "Saved"
	else
		s.saveStatus="Save retry pending"
	end
end
function Lifecycle.leaseValid(deadline, now)
	return type(deadline)=="number" and deadline<math.huge and deadline>now
end
-- END PURE LIFECYCLE
local lifecycle=Lifecycle.new()
local arenaEpoch=os.clock()
local random = Random.new(90210)
local nextCreatureId = 0
local species = {}
for _,def in ipairs(Config.Creatures) do species[def.id] = def end

local function xyz(v) return {x=v.X,y=v.Y,z=v.Z} end
local function feedback(player,kind,text,def,position)
	if player.Parent~=Players then return end
	Feedback:FireClient(player,{kind=kind,text=text,creature=def and def.id,position=position})
end
local function metric(player,s,name)
	if s.metrics[name] then return end
	s.metrics[name] = os.clock()-s.joined
	-- Deliberately no invented retention analytics or private profile content.
	print(string.format("[SparkMetric] user=%d event=%s elapsed=%.3f",player.UserId,name,s.metrics[name]))
end
local function capacity(s) return Config.MaxCarry + (s.profile.upgrades.basket or 0)*2 end
local function speed(_s) return Config.WalkSpeed end
local function dashCooldown(s) return math.max(1,Config.DashCooldown-(s.profile.upgrades.boots or 0)*Config.Upgrades.boots.cooldownReduction) end
local function parade(player,s) player:SetAttribute("SparkParade",table.concat(s.carry,",")) end
local function arenaEvent() return Rules.event((os.clock()-arenaEpoch)%Config.RoundSeconds) end
local function rootOf(player)
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart"), char and char:FindFirstChildOfClass("Humanoid")
end
local function clearStarters(userId)
	for id,c in pairs(herd) do
		if c.starterOwner==userId then c.model:Destroy(); herd[id]=nil end
	end
	for owner,s in pairs(sessions) do if owner.UserId==userId then s.starterRemaining=0 end end
end
local issueStarters
local function objective(s)
	if not s.ready then return "Connecting your collection…" end
	if s.phase == "Results" then return "Round banked! Upgrade or chase again • "..s.saveStatus end
	if #s.carry > 0 then return "Bring your parade to the glowing BANK gate" end
	if (s.starterRemaining or 0)>0 then return "CATCH your named first Sparks • then chase into the arena" end
	return "Chase Sparks • Dash to flank • Bank a group for a bonus"
end
local function send(player,s)
	if not s.profile or player.Parent~=Players then return end
	local elapsed = if s.started then os.clock()-s.started else 0
	local now=os.clock()
	-- Public, nonsensitive server summaries make live assertions reproducible.
	player:SetAttribute("SparkPhase",s.phase)
	player:SetAttribute("SparkGlow",s.profile.coins)
	player:SetAttribute("SparkTotalBanked",s.profile.totalBanked)
	player:SetAttribute("SparkSpecies",Profile.speciesCount(s.profile))
	player:SetAttribute("SparkRounds",s.profile.rounds)
	player:SetAttribute("SparkSaveStatus",s.saveStatus)
	player:SetAttribute("SparkStartersRemaining",s.starterRemaining or 0)
	State:FireClient(player,{
		phase=s.phase,remaining=math.max(0,math.ceil(Config.RoundSeconds-elapsed)),
		biome=s.biome,carry=#s.carry,capacity=capacity(s),score=s.score,
		profile=s.profile,saveStatus=s.saveStatus,event=arenaEvent(),objective=objective(s),
		bankPosition=world.arenas[s.biome].bank,ready=s.ready,
		captureCooldown=Config.CaptureCooldown,dashCooldown=dashCooldown(s),
		cooldowns={capture=math.max(0,Config.CaptureCooldown-(now-(s.buckets.capture or -math.huge))),
			dash=math.max(0,dashCooldown(s)-(now-(s.buckets.dash or -math.huge)))},
	})
end
local function stopDash(root)
	for _,name in ipairs({"SparkDashVelocity","SparkDashAttachment"}) do
		local item=root:FindFirstChild(name)
		if item then item:Destroy() end
	end
end
local function teleport(player,s)
	local root,humanoid = rootOf(player)
	if root then
		stopDash(root)
		local arena=world.arenas[s.biome]
		root.CFrame=CFrame.lookAt(arena.spawn,arena.origin+Vector3.new(0,3,0))
		root.AssemblyLinearVelocity=Vector3.zero
		s.motion={position=xyz(root.Position),at=os.clock(),credit=10,blockedUntil=0}
		s.suspiciousUntil=0
	end
	if humanoid then humanoid.WalkSpeed=speed(s); humanoid.JumpPower=42 end
end
local function validApproach(player,s)
	local root,humanoid=rootOf(player)
	if not root or not humanoid or humanoid.Health<=0 or not s.motion then return false end
	local arena=world.arenas[s.biome]
	local now=os.clock()
	local valid,reason=Rules.movement(s.motion,xyz(root.Position),now,{origin=xyz(arena.origin),radius=78,
		minY=arena.origin.Y-4,maxY=arena.origin.Y+24,speed=speed(s)+2,burst=10})
	s.suspiciousUntil=s.motion.blockedUntil or 0
	if not valid then
		if reason=="Arena bounds" or (reason=="Height bounds" and root.Position.Y<arena.origin.Y-4) then
			-- A last valid point below the floor would trap a fallen player forever.
			-- Rescue to the authored spawn, retaining the action quarantine.
			teleport(player,s)
			s.motion.blockedUntil=now+1.5; s.suspiciousUntil=now+1.5
		else
			stopDash(root)
			local safe=s.motion.position
			root.CFrame=CFrame.new(safe.x,safe.y,safe.z)
			root.AssemblyLinearVelocity=Vector3.zero
		end
	end
	return valid and now>=s.suspiciousUntil
end
local function bank(player,s,automatic)
	if not s.ready or #s.carry==0 then return end
	local root = rootOf(player)
	if not automatic and (not validApproach(player,s) or not root or (root.Position-world.arenas[s.biome].bank).Magnitude>12) then
		feedback(player,"Hint","Follow BANK to save your parade"); return
	end
	-- Clear ownership before any callback; no yields in reward transaction.
	local catches=s.carry; s.carry={}
	parade(player,s)
	local reward,newSpecies=Profile.bank(s.profile,catches)
	if s.profile.totalBanked>=3 then clearStarters(player.UserId) end
	s.score+=reward
	metric(player,s,"first_bank")
	feedback(player,"Bank",string.format("+%d glow • %d Sparks banked%s",reward,#catches,if newSpecies>0 then " • NEW ALBUM ENTRY!" else ""))
	Lifecycle.markDirty(s)
	send(player,s)
end
local function beginRound(player,s)
	if not s.ready then return end
	if s.started then metric(player,s,"replay") end
	s.phase="Playing"; s.started=os.clock(); s.carry={}; s.score=0; s.buckets={}
	parade(player,s)
	teleport(player,s)
	issueStarters(player,s)
	feedback(player,"Round","CHASE • CATCH • BANK   |   110 seconds!")
	send(player,s)
end
local function spawnCreature(biome,index,starterPlayer)
	local defs={}
	for _,def in ipairs(Config.Creatures) do
		if def.biome==Config.Biomes[biome].id or def.biome==biome then table.insert(defs,def) end
	end
	if #defs==0 then defs=Config.Creatures end
	local def=defs[(index-1)%#defs+1]
	local arena=world.arenas[biome]
	local angle=random:NextNumber(0,math.pi*2)
	local radius=random:NextNumber(10,43)
	local offset=Rules.herdSpawn(angle,radius)
	local position=arena.origin+Vector3.new(offset.x,offset.y,offset.z)
	-- Finite owner-specific starters are separate from the 54 normal herd slots.
	if starterPlayer then position=arena.origin+Vector3.new((index-2)*4,2.2,30) end
	local model=World.creature(def,creaturesFolder)
	nextCreatureId+=1
	model.Name="Spark_"..nextCreatureId
	model:SetAttribute("CreatureId",nextCreatureId); model:SetAttribute("Species",def.id)
	if starterPlayer then
		model:SetAttribute("StarterOwnerId",starterPlayer.UserId)
		-- One compact cue introduces the group without covering all three silhouettes.
		-- Index 1 also exists for returning players with only one starter remaining.
		if index==1 then
			local cue=Instance.new("BillboardGui")
			cue.Name="FirstCatchCue"; cue.Size=UDim2.fromOffset(100,26); cue.StudsOffset=Vector3.new(0,3.3,0)
			cue.MaxDistance=38; cue.LightInfluence=0; cue.Parent=model.PrimaryPart
			local title=Instance.new("TextLabel")
			title.Size=UDim2.fromScale(1,1); title.BackgroundColor3=Color3.fromRGB(28,35,66)
			title.BackgroundTransparency=.12; title.TextColor3=Color3.fromRGB(255,219,90)
			title.BorderSizePixel=0; title.TextSize=12; title.Font=Enum.Font.GothamBold
			title.Text="FIRST CATCH"; title.Parent=cue
			local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,8); corner.Parent=title
		end
	end
	model:PivotTo(CFrame.new(position))
	herd[nextCreatureId]={id=nextCreatureId,def=def,model=model,biome=biome,
		position=position,home=position,beginner=starterPlayer~=nil,starterOwner=starterPlayer and starterPlayer.UserId,
		heading=angle,seed=random:NextNumber(0,20),claimed=false,index=index}
end
issueStarters=function(player,s)
	local allowance=Rules.issueStarters(s,s.profile.totalBanked)
	s.starterRemaining=allowance
	for index=1,allowance do spawnCreature(s.biome,index,player) end
end
for biome=1,#world.arenas do
	for index=1,18 do spawnCreature(biome,index) end
	task.wait()
end

local function capture(player,s)
	if not Rules.allow(s.buckets,"capture",os.clock(),Config.CaptureCooldown) then return end
	if not validApproach(player,s) then return end
	local root,humanoid=rootOf(player)
	if not root or not humanoid or humanoid.Health<=0 then return end
	metric(player,s,"first_action")
	local radius=Config.CaptureRadius+(s.profile.upgrades.magnet or 0)*1.5
	local nearest,best=nil,math.huge
	for _,creature in pairs(herd) do
		local allowed=Rules.canCapture({phase=s.phase,ready=s.ready,carry=#s.carry,biome=s.biome,userId=player.UserId,totalBanked=s.profile.totalBanked,
			position=xyz(root.Position),suspiciousUntil=s.suspiciousUntil},
			{claimed=creature.claimed,biome=creature.biome,starterOwner=creature.starterOwner,position=xyz(creature.position)},os.clock(),radius,capacity(s))
		local offset=creature.position-root.Position
		-- Wide forward arc rewards steering; close targets remain touch-friendly.
		if allowed and (offset.Magnitude<4 or root.CFrame.LookVector:Dot(offset.Unit)>-0.2) and offset.Magnitude<best then
			nearest=creature; best=offset.Magnitude
		end
	end
	if not nearest then
		feedback(player,"Hint",if #s.carry>=capacity(s) then "Parade full! Follow BANK" else "Get closer and face a Spark")
		return
	end
	nearest.claimed=true -- atomic claim before effects and respawn scheduling
	if nearest.starterOwner then s.starterRemaining=math.max(0,(s.starterRemaining or 0)-1) end
	table.insert(s.carry,nearest.def.id)
	parade(player,s)
	nearest.model:Destroy(); herd[nearest.id]=nil
	metric(player,s,"first_catch")
	feedback(player,"Catch","Caught "..nearest.def.name.."!",nearest.def,nearest.position)
	send(player,s)
	if not nearest.starterOwner then
		task.delay(2,function() if not lifecycle.closing then spawnCreature(nearest.biome,nearest.index) end end)
	end
end

local function haltForLease(player,s,status)
	s.ready=false; s.leaseLost=true; s.saveStatus="Reconnect to protect your collection"
	warn("[Spark] progression halted: "..tostring(status))
	feedback(player,"Error","Collection connection lost. Rejoin to continue safely.")
	if player.Parent==Players then player:Kick("Your collection connection expired. Please rejoin; this server will not overwrite another session.") end
end

Action.OnServerEvent:Connect(function(player,action,payload)
	if lifecycle.closing then return end
	local s=sessions[player]
	if not s or type(action)~="string" or #action>24 then return end
	if not Rules.allow(s.transport,"request",os.clock(),0.08) then return end
	if action=="Ready" then
		s.clientReady=true
		if s.ready and s.phase=="Loading" then beginRound(player,s) else send(player,s) end
		return
	end
	if not s.ready then return end
	if not Lifecycle.leaseValid(persistence:leaseDeadline(player.UserId),os.time()) then
		haltForLease(player,s,"acknowledged lease expired"); return
	end
	if action=="Replay" then
		if s.phase=="Results" then beginRound(player,s) end
	elseif action=="Capture" then
		capture(player,s)
	elseif action=="Dash" and s.phase=="Playing" then
		local root,humanoid=rootOf(player)
		if validApproach(player,s) and root and humanoid and humanoid.Health>0 and Rules.allow(s.buckets,"dash",os.clock(),dashCooldown(s)) then
			local direction=humanoid.MoveDirection
			if not Rules.validPosition(xyz(direction)) then return end
			if direction.Magnitude<0.1 then direction=root.CFrame.LookVector end
			direction=Vector3.new(direction.X,0,direction.Z)
			if direction.Magnitude<0.01 then return end
			s.motion.dashStarted=os.clock(); s.motion.dashUntil=s.motion.dashStarted+0.35
			-- A one-frame server velocity write is overwritten by client-owned
			-- character simulation. Replicate a short planar actuator instead;
			-- gravity/jumping stay free and collisions remain physical.
			local attachment=Instance.new("Attachment")
			attachment.Name="SparkDashAttachment"; attachment.Parent=root
			local dash=Instance.new("LinearVelocity")
			dash.Name="SparkDashVelocity"; dash.Attachment0=attachment
			dash.RelativeTo=Enum.ActuatorRelativeTo.World
			dash.VelocityConstraintMode=Enum.VelocityConstraintMode.Plane
			dash.PrimaryTangentAxis=Vector3.xAxis; dash.SecondaryTangentAxis=Vector3.zAxis
			dash.PlaneVelocity=Vector2.new(direction.Unit.X,direction.Unit.Z)*65
			dash.ForceLimitsEnabled=true; dash.ForceLimitMode=Enum.ForceLimitMode.Magnitude
			dash.MaxForce=root.AssemblyMass*2500; dash.Parent=root
			Debris:AddItem(dash,0.28); Debris:AddItem(attachment,0.28)
			metric(player,s,"first_action"); feedback(player,"Dash","WHOOSH!")
		end
	elseif action=="Bank" and s.phase=="Playing" and os.clock()>s.suspiciousUntil then
		bank(player,s,false)
	elseif action=="Upgrade" and type(payload)=="string" and #payload<=20 then
		local ok,message=Profile.buy(s.profile,payload)
		if ok then Lifecycle.markDirty(s); metric(player,s,"first_upgrade"); local _,h=rootOf(player); if h then h.WalkSpeed=speed(s) end end
		feedback(player,if ok then "Upgrade" else "Hint",message); send(player,s)
	elseif action=="Quest" and type(payload)=="string" and #payload<=40 then
		local ok,message=Profile.claim(s.profile,payload)
		if ok then Lifecycle.markDirty(s) end
		feedback(player,if ok then "Quest" else "Hint",message); send(player,s)
	elseif action=="Settings" and type(payload)=="table" then
		local changed=false
		for _,key in ipairs({"reducedMotion","music","sfx"}) do
			if type(payload[key])=="boolean" and payload[key]~=s.profile.settings[key] then s.profile.settings[key]=payload[key]; changed=true end
		end
		if changed then Lifecycle.markDirty(s) end
		send(player,s)
	elseif action=="Biome" and type(payload)=="number" and payload%1==0 and Config.Biomes[payload] then
		if #s.carry>0 then feedback(player,"Hint","Bank your parade before travelling"); return end
		if s.profile.totalBanked < Config.Biomes[payload].unlock then feedback(player,"Hint","Bank more Sparks to unlock this arena"); return end
		s.biome=payload; teleport(player,s); send(player,s)
	end
end)

local finalize
local function join(player)
	local s={profile=nil,ready=false,clientReady=false,phase="Loading",carry={},biome=1,score=0,
		buckets={},transport={},metrics={},joined=os.clock(),saveStatus="Loading",suspiciousUntil=0,dirty=false,revision=0,persistedRevision=0}
	if not Lifecycle.beginLoad(lifecycle,s) then
		player:Kick("This server is closing. Please rejoin.")
		return
	end
	sessions[player]=s
	player.CameraMinZoomDistance=9; player.CameraMaxZoomDistance=27
	player.CharacterAdded:Connect(function()
		task.wait(0.25)
		if sessions[player]==s and s.ready then teleport(player,s) end
	end)
	local ran,profile,status=pcall(function() return persistence:load(player.UserId) end)
	if not ran then warn("[Spark] unexpected load error: "..tostring(profile)); profile=nil; status="unavailable" end
	s.profile=profile
	s.detached=s.detached or sessions[player]~=s
	local disposition=Lifecycle.finishLoad(lifecycle,s,profile~=nil)
	if disposition=="finalize" then
		finalize(player,s)
		return
	elseif disposition=="discard" then
		return
	end
	if not profile then
		feedback(player,"Error","Collection unavailable. Rejoin to protect your save.")
		player:Kick("Your collection could not load safely ("..tostring(status).."). Please rejoin. No progress was overwritten.")
		return
	end
	s.profile=profile; s.ready=true; s.saveStatus=if RunService:IsStudio() then "Studio test save" else "Saved"
	metric(player,s,"join")
	if profile.lastSeen and profile.lastSeen>0 then metric(player,s,"return") end
	if s.clientReady then beginRound(player,s) end
end


finalize=function(player,s)
	clearStarters(player.UserId)
	local deadline=math.min(os.clock()+22,lifecycle.deadline or math.huge)
	if not s.profile or s.leaseLost then return end
	if not Lifecycle.beginFinalize(lifecycle,s) then
		while not s.finalized and os.clock()<deadline do task.wait(.05) end
		return
	end
	local ran,failure=pcall(function()
		-- Freeze the final snapshot only after banking legitimate carry once.
		if s.ready then bank(player,s,true) end
		s.ready=false; s.phase="Closing"; s.profile.lastSeen=os.time()
		while s.saving and os.clock()<deadline do task.wait(.05) end
		local ok,status=false,"busy"
		while os.clock()<deadline and not s.leaseLost do
			ok,status=persistence:release(player.UserId,s.profile)
			if ok or (status~="busy" and status~="unavailable") then break end
			task.wait(.2)
		end
		if ok then Lifecycle.saveResult(s,true,s.revision,RunService:IsStudio())
		else warn("[Spark] final save unconfirmed: "..tostring(status)) end
	end)
	s.ready=false
	Lifecycle.finishFinalize(lifecycle,s)
	if not ran then warn("[Spark] final save errored: "..tostring(failure)) end
end
Players.PlayerRemoving:Connect(function(player)
	local s=sessions[player]; sessions[player]=nil
	if s then s.detached=true; finalize(player,s) end
end)
Players.PlayerAdded:Connect(join)
for _,player in ipairs(Players:GetPlayers()) do task.spawn(join,player) end

local accumulator,networkAt=0,0
RunService.Heartbeat:Connect(function(dt)
	if lifecycle.closing then return end
	accumulator+=dt
	if accumulator<0.1 then return end
	local step=math.min(accumulator,0.25); accumulator=0
	local now=os.clock()
	for player,s in pairs(sessions) do
		if not s.ready then continue end
		if not Lifecycle.leaseValid(persistence:leaseDeadline(player.UserId),os.time()) then haltForLease(player,s,"acknowledged lease expired"); continue end
		local root,humanoid=rootOf(player)
		if root and humanoid then
			local arena=world.arenas[s.biome]
			local accepted=validApproach(player,s)
			if accepted and s.phase=="Playing" and (root.Position-arena.bank).Magnitude<10 then bank(player,s,false) end
		end
		if s.phase=="Playing" then
			local phase=Rules.roundPhase(s.started,now,Config.RoundSeconds)
			if phase=="Results" then
				clearStarters(player.UserId)
				bank(player,s,true); s.phase="Results"; s.profile.rounds+=1; Lifecycle.markDirty(s)
				metric(player,s,"first_round"); feedback(player,"Results","Round complete! Your parade earned "..s.score.." glow")
				send(player,s)
			end
		end
	end
	local centroids={}
	for _,c in pairs(herd) do
		if c.starterOwner then continue end
		local center=centroids[c.biome] or {sum=Vector3.zero,count=0}
		center.sum+=c.position; center.count+=1; centroids[c.biome]=center
	end
	local _,sharedScale=arenaEvent()
	for _,c in pairs(herd) do
		local arena=world.arenas[c.biome]
		local time=now+c.seed
		local direction=Vector3.new(math.cos(c.heading),0,math.sin(c.heading))
		local nearest,dist=nil,26
		local eventScale=if c.beginner then .55 else sharedScale
		for player,s in pairs(sessions) do
			if s.ready and s.phase=="Playing" and s.biome==c.biome and (not c.starterOwner or c.starterOwner==player.UserId) then
				local root=rootOf(player)
				if root and Rules.validPosition(xyz(root.Position)) then local d=(root.Position-c.position).Magnitude; if d<dist then nearest=root.Position; dist=d end end
			end
		end
		local center=centroids[c.biome]
		if c.def.behavior=="herd" and center then
			local toHerd=center.sum/center.count-c.position; toHerd=Vector3.new(toHerd.X,0,toHerd.Z)
			if toHerd.Magnitude>7 then direction=direction:Lerp(toHerd.Unit,math.min(1,step*1.5)) end
		elseif c.def.behavior=="wander" then
			c.heading+=math.sin(time*.55)*step*.9
			direction=Vector3.new(math.cos(c.heading),0,math.sin(c.heading))
			eventScale*=.75+.15*math.sin(time*.8)
		end
		local awareness=if c.def.behavior=="wander" then 8 elseif c.def.behavior=="herd" then 15 else 26
		if nearest and dist>0.1 and dist<awareness then
			local away=Vector3.new(c.position.X-nearest.X,0,c.position.Z-nearest.Z)
			if away.Magnitude>0.1 then
				local flee=away.Unit
				if c.def.behavior=="zigzag" then flee=(flee+Vector3.new(math.sin(time*3)*0.6,0,math.cos(time*3)*0.6)).Unit end
				direction=direction:Lerp(flee,math.min(1,step*3))
			end
		else c.heading+=math.sin(time*0.6)*step*0.7 end
		local delta=c.position-arena.origin
		local flat=Vector3.new(delta.X,0,delta.Z)
		if flat.Magnitude>48 then direction=-flat.Unit end
		if not c.starterOwner and (c.position-arena.bank).Magnitude<32 then
			direction=direction+Vector3.new(0,0,-2)
		end
		if c.beginner then
			local toHome=c.home-c.position; toHome=Vector3.new(toHome.X,0,toHome.Z)
			if toHome.Magnitude>.65 then direction=toHome.Unit end
		end
		-- Authored steering islands have 4.5-stud collision radius. Keep a 2.5-stud body margin.
		for _,x in ipairs({-26.163,26.163}) do
			for _,z in ipairs({-26.163,26.163}) do
				local island=arena.origin+Vector3.new(x,0,z)
				local away=Vector3.new(c.position.X-island.X,0,c.position.Z-island.Z)
				if away.Magnitude<10 and away.Magnitude>.01 then direction=direction+away.Unit*(10-away.Magnitude) end
			end
		end
		if direction.Magnitude<0.01 then direction=Vector3.new(0,0,1) else direction=direction.Unit end
		c.heading=math.atan2(direction.Z,direction.X)
		local pace=c.def.speed*eventScale
		c.position+=direction*pace*step
		if c.beginner then
			local fromHome=Vector3.new(c.position.X-c.home.X,0,c.position.Z-c.home.Z)
			if fromHome.Magnitude>.75 then c.position=c.home+fromHome.Unit*.75 end
		end
		for _,x in ipairs({-26.163,26.163}) do
			for _,z in ipairs({-26.163,26.163}) do
				local island=arena.origin+Vector3.new(x,0,z)
				local away=Vector3.new(c.position.X-island.X,0,c.position.Z-island.Z)
				if away.Magnitude<7 then
					local push=if away.Magnitude>.01 then away.Unit else Vector3.new(1,0,0)
					c.position=island+push*7
				end
			end
		end
		if not c.starterOwner then
			local safe=Rules.outsideBank(xyz(c.position),xyz(arena.bank))
			c.position=Vector3.new(safe.x,safe.y,safe.z)
		end
		c.position=Vector3.new(c.position.X,2.2+math.sin(time*4)*0.35,c.position.Z)
		c.model:PivotTo(CFrame.lookAt(c.position,c.position+direction)*CFrame.Angles(0,0,math.sin(time*4)*0.08))
	end
	if now-networkAt>=0.5 then
		networkAt=now
		for player,s in pairs(sessions) do send(player,s) end
	end
end)

task.spawn(function()
	while task.wait(30) and not lifecycle.closing do
		for player,s in pairs(sessions) do
			if not s.ready or s.saving then continue end
			s.saving=true; s.saveStatus="Saving"
			task.spawn(function()
				-- Save even clean profiles to renew the cross-server lease.
				local snapshotRevision=s.revision
				local ran,ok,status=pcall(function() return persistence:save(player.UserId,s.profile) end)
				if not ran then warn("[Spark] unexpected save error: "..tostring(ok)); ok=false; status="unavailable" end
				s.saving=false
				Lifecycle.saveResult(s,ok,snapshotRevision,RunService:IsStudio())
				if not ok then
					if status=="lease-lost" or status=="not-loaded" then haltForLease(player,s,status)
					else warn("[Spark] save failed "..tostring(status)) end
				end
				if sessions[player]==s then send(player,s) end
			end)
		end
	end
end)
game:BindToClose(function()
	lifecycle.closing=true
	lifecycle.deadline=os.clock()+25
	for player,s in pairs(sessions) do
		if not s.profile or s.leaseLost then continue end
		task.spawn(finalize,player,s)
	end
	-- Includes detached PlayerRemoving saves and loads that may acquire a lease late.
	while Lifecycle.pending(lifecycle)>0 and os.clock()<lifecycle.deadline do task.wait(0.1) end
	local pending=Lifecycle.pending(lifecycle)
	if pending>0 then warn("[Spark] shutdown deadline: "..pending.." load/final-save operations remain unconfirmed") end
end)
print("[Spark] Staged build booted; 3 arenas, 54 moving Sparks; publishing remains unauthorized")
