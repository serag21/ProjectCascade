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
local Challenge = require(Shared.Challenge)
local Targeting = require(Shared.Targeting)
local ArenaRally = require(Shared.ArenaRally)
local ArenaEvents = require(Shared.ArenaEvents)
local Loadout = require(Shared.Loadout)
local Encounters = require(Shared.Encounters)
local Progression = require(Shared.Progression)
local Cycle = require(Shared.Cycle)
local HerdNet = require(Shared.HerdNet)
local Cosmetics = require(Shared.Cosmetics)
local Trial = require(Shared.Trial)
local Remix = require(Shared.Remix)
local World = require(script.Parent.World)
local Persistence = require(script.Parent.Persistence)
local Services = require(script.Parent.Services)

-- Players never collide with each other: nobody can body-block the bank or gate.
local PhysicsService = game:GetService("PhysicsService")
local PLAYER_GROUP = "SparkPlayers"
pcall(function()
	if not PhysicsService:IsCollisionGroupRegistered(PLAYER_GROUP) then PhysicsService:RegisterCollisionGroup(PLAYER_GROUP) end
	PhysicsService:CollisionGroupSetCollidable(PLAYER_GROUP,PLAYER_GROUP,false)
end)
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = Shared
local function remote(name)
	local value = Instance.new("RemoteEvent")
	value.Name = name; value.Parent = remotes
	return value
end
local Action, State, Feedback = remote("Action"), remote("State"), remote("Feedback")
-- Living herd (D13): compact creature snapshots at 10 Hz; clients interpolate and
-- animate. Unreliable delivery is fine: every packet is a full arena snapshot.
local HerdFeed = Instance.new("UnreliableRemoteEvent")
HerdFeed.Name = "HerdNet"; HerdFeed.Parent = remotes
local world = World.build(Config)
-- Daily Stampede (D16, plan §6.4): a private Trial Grounds arena beyond the shared
-- ones. Its look follows the boot day's biome; the course itself always follows
-- the current UTC day (Trial.plan), so gameplay never goes stale on long servers.
local SHARED_ARENAS = #Config.Biomes
World.buildTrials(world, Config, Trial.plan(Trial.day(os.time())).biome)
local TRIAL_ARENA = world.trialIndex
local creaturesFolder = world.root:FindFirstChild("Creatures") or Instance.new("Folder")
creaturesFolder.Name = "Creatures"; creaturesFolder.Parent = world.root
local staticsFolder = Instance.new("Folder")
staticsFolder.Name = "Statics"; staticsFolder.Parent = world.root
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
-- Optional platform services. Studio uses memory doubles: no production writes.
local analytics = Services.analytics(game:GetService("AnalyticsService"), Enum, not RunService:IsStudio())
local orderedProvider = if RunService:IsStudio() then Services.memoryOrderedStore()
	else function(name) return DataStoreService:GetOrderedDataStore(name) end
local biomeIds = {}
for _, biome in ipairs(Config.Biomes) do table.insert(biomeIds, biome.id) end
local leaderboard = Services.leaderboard(orderedProvider, biomeIds, function(now) return Progression.week(now) end)
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
local podiums={} -- [biome]={cycle=index,awards={...}} computed at each shared buzzer
local arenaEpoch=os.clock()
local rallies={}
for index in ipairs(Config.Biomes) do rallies[index]=ArenaRally.new(arenaEpoch) end
local random = Random.new(90210)
local nextCreatureId = 0
local species = {}
for _,def in ipairs(Config.Creatures) do species[def.id] = def end

local function xyz(v) return {x=v.X,y=v.Y,z=v.Z} end
local function feedback(player,kind,text,def,position,extra)
	if player.Parent~=Players then return end
	Feedback:FireClient(player,{kind=kind,text=text,creature=def and def.id,position=position,extra=extra})
end
local function metric(player,s,name)
	if s.metrics[name] then return end
	s.metrics[name] = os.clock()-s.joined
	-- Deliberately no invented retention analytics or private profile content.
	print(string.format("[SparkMetric] user=%d event=%s elapsed=%.3f",player.UserId,name,s.metrics[name]))
	analytics.funnel(player,name)
end
local function economy(player,s,flow,amount,sku)
	if s.profile then analytics.economy(player,flow,amount,s.profile.coins,sku) end
end
-- Earned cosmetics replicate to everyone: a trail behind the root and a title tag.
local function applyStyle(player,s)
	local character=player.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	if not root or not s.profile then return end
	for _,name in ipairs({"SparkTrail","SparkTrailA","SparkTrailB"}) do
		local old=root:FindFirstChild(name); if old then old:Destroy() end
	end
	local head=character:FindFirstChild("Head")
	local oldTitle=head and head:FindFirstChild("SparkTitle"); if oldTitle then oldTitle:Destroy() end
	local trailDef=Progression.TrailById[s.profile.style.trail]
	if trailDef and trailDef.id~="none" then
		local a=Instance.new("Attachment"); a.Name="SparkTrailA"; a.Position=Vector3.new(0,0.9,0); a.Parent=root
		local b=Instance.new("Attachment"); b.Name="SparkTrailB"; b.Position=Vector3.new(0,-0.9,0); b.Parent=root
		local trail=Instance.new("Trail"); trail.Name="SparkTrail"; trail.Attachment0=a; trail.Attachment1=b
		trail.Color=ColorSequence.new(Color3.fromRGB(table.unpack(trailDef.colors[1])),Color3.fromRGB(table.unpack(trailDef.colors[2])))
		trail.Transparency=NumberSequence.new(0.25,1); trail.Lifetime=0.4; trail.LightEmission=0.5
		trail.FaceCamera=true; trail.Parent=root
	end
	-- Visible social flex (D20): formation and burst replicate as attributes;
	-- the name tag style frames the equipped title (rank title or achievement title).
	local cos=s.profile.cosmetics
	player:SetAttribute("SparkFormation",Cosmetics.resolve("formation",cos.formation).id)
	player:SetAttribute("SparkBurst",Cosmetics.resolve("burst",cos.burst).id)
	local title=Progression.titleText(s.profile)
	if title=="" then title=Cosmetics.titleText(s.profile) end
	local tag=Cosmetics.resolve("tag",cos.tag)
	if head and (title~="" or tag.id~="default") then
		local function rgb(c,fallback) return if type(c)=="table" then Color3.fromRGB(c[1],c[2],c[3]) else fallback end
		local gui=Instance.new("BillboardGui"); gui.Name="SparkTitle"; gui.Size=UDim2.fromOffset(170,24)
		gui.StudsOffset=Vector3.new(0,2.4,0); gui.MaxDistance=55; gui.LightInfluence=0; gui.Parent=head
		local text=Instance.new("TextLabel"); text.Size=UDim2.fromScale(1,1)
		text.BackgroundTransparency=if tag.frame then (tag.frameTransparency or 0.3) else 1
		text.BackgroundColor3=rgb(tag.frame,Color3.new(0,0,0))
		text.Font=Enum.Font.GothamBold; text.TextSize=14; text.TextColor3=rgb(tag.text,Color3.fromRGB(255,219,90))
		text.TextStrokeColor3=rgb(tag.stroke,Color3.new(0,0,0)); text.TextStrokeTransparency=0.3
		text.Text=if title~="" then title else player.DisplayName; text.Parent=gui
		local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,8); corner.Parent=text
	end
end
-- Every gameplay stat derives from the saved upgrades, perk loadout and heat.
-- Loadout/heat change only between rounds, so a round's Challenge rules are fixed.
-- Weekly Remix (plan §6.9.3): looked up once per Stampede Cycle so one round never
-- mixes two remixes; it never applies to the normalized Daily Stampede.
local currentRemix=Remix.current(os.time())
local remixCycle=-1
local function statsFor(s) return Remix.apply(Loadout.stats(s.profile.upgrades,s.profile.loadout,s.profile.heat),currentRemix) end
local function stats(s)
	if not s.stats then s.stats=statsFor(s) end
	return s.stats
end
local function capacity(s) return stats(s).capacity end
local function speed(_s) return Config.WalkSpeed end
local function dashCooldown(s) return stats(s).dashCooldown end
local function parade(player,s) player:SetAttribute("SparkParade",table.concat(s.carry,",")) end
local function arenaClock() return os.clock()-arenaEpoch end
local function arenaEvent(biome) return ArenaEvents.herd(arenaClock(),biome) end
local function creatureBase(entry)
	local id=if string.sub(entry,1,1)=="*" then string.sub(entry,2) else entry
	local def=species[id]
	return 10+(if def then def.value else 0)*2
end
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
local function clearTrial(userId)
	for id,c in pairs(herd) do
		if c.trialOwner==userId then c.claimed=true; c.model:Destroy(); herd[id]=nil end
	end
end
local issueStarters,spawnCreature
local clearPersonal,onRoundRecorded
local settleTrial,startTrial,leaveTrial
-- The trial arena has one constant rhythm: no shared phase shifts, no intermission.
local TRIAL_EVENT={name="DAILY STAMPEDE",speedScale=1,turnScale=1,remaining=0,phase=0}
local TRIAL_REJECTION_LIMIT=6 -- movement corrections above this keep a run off the public board
local trialPlans={day=-1}
local function trialPlanFor(day)
	if trialPlans.day~=day then trialPlans={day=day,plan=Trial.plan(day)} end
	return trialPlans.plan
end
local dailyDirty=false
-- Synchronized cycles (Cycle.luau): "Playing" is a scored round ending at the
-- shared buzzer; "Warmup" is free catching until the next cycle starts.
local function roundPlaying(s,now)
	return (s.phase=="Playing" or s.phase=="Warmup") and s.endsAt~=nil and now<s.endsAt
end
local function scoredRound(s,now)
	return s.phase=="Playing" and s.endsAt~=nil and now<s.endsAt
end
-- Staged threats (D18): sweeps from a player's 2nd round, statics from the 3rd.
local function sweepsAllowed(s) return (s.roundsAtStart or 0)>=1 end
local function staticsAllowed(s) return (s.roundsAtStart or 0)>=2 end
local function hazardFor(s,now)
	return if s.mode~="trial" and scoredRound(s,now) and sweepsAllowed(s) and s.hazardStarted and s.challenge
		then ArenaEvents.hazard(now-s.hazardStarted,s.challenge.difficulty,s.biome,stats(s).sweepWarning) else {visible=false,active=false}
end
local function trialElapsed(s,now) return math.clamp(now-(s.started or now),0,Trial.RunSeconds) end
local NO_ENCOUNTER={visible=false,active=false}
-- Meadow/Aurora trial: the shared gate path, shifted so it opens 25 s into the run.
local function trialGate(s,now)
	local tr=s.trial
	if s.mode~="trial" or not tr or tr.plan.encounter~="gate" or not scoredRound(s,now) then return NO_ENCOUNTER end
	local gate=Encounters.gate(trialElapsed(s,now)+30,1)
	if gate.visible then gate.position=world.arenas[TRIAL_ARENA].origin+Vector3.new(gate.x,0.3,gate.z) end
	return gate
end
-- Canyon trial: exactly one telegraphed Stampede Run at plan.runAt.
local function trialRun(s,now)
	local tr=s.trial
	if s.mode~="trial" or not tr or tr.plan.encounter~="stampede" or not scoredRound(s,now) then return NO_ENCOUNTER end
	local sch=Trial.schedule(trialElapsed(s,now),tr.plan)
	if not sch.runWarning and not sch.runActive then return NO_ENCOUNTER end
	local lane=Encounters.Runs[1]
	local origin=world.arenas[TRIAL_ARENA].origin
	return {visible=true,active=sch.runActive,warning=sch.runWarning,run=1,
		from={x=lane.from.x,z=lane.from.z},to={x=lane.to.x,z=lane.to.z},
		fromPosition=origin+Vector3.new(lane.from.x,0.3,lane.from.z),toPosition=origin+Vector3.new(lane.to.x,0.3,lane.to.z),
		progress=sch.runProgress,seconds=if sch.runActive then tr.plan.runAt+Trial.RunLength-sch.elapsed else tr.plan.runAt-sch.elapsed,
		name="STAMPEDE RUN",cue="DASH THROUGH THE LANE"}
end
local function trialDescribe(s,now)
	local tr=s.trial
	if not tr then return {phase="DAILY STAMPEDE",next=nil,nextIn=0} end
	local e=trialElapsed(s,now)
	local stampede=tr.plan.encounter=="stampede"
	local starfall=tr.plan.encounter=="starfall"
	local name=if stampede then "STAMPEDE RUN" elseif starfall then "AURORA STARFALL" else "SPARK GATE"
	local from=if stampede then tr.plan.runAt-Trial.RunWarning elseif starfall then 23 else 22
	local to=if stampede then tr.plan.runAt+Trial.RunLength elseif starfall then 53 else 55
	if e<from then return {phase="DAILY STAMPEDE",next=name,nextIn=from-e} end
	if e<to then return {phase=name,next="GOLDEN SPARK",nextIn=math.max(0,tr.plan.goldenAt-e)} end
	if e<tr.plan.goldenAt then return {phase="DAILY STAMPEDE",next="GOLDEN SPARK",nextIn=tr.plan.goldenAt-e} end
	return {phase="GOLDEN FINALE",next=nil,nextIn=0}
end
-- AURORA STARFALL (shared arena 3, and the Daily Stampede on aurora days). The
-- schedule is pure (Encounters.starfall); the server picks each landing spot from
-- live Spark clusters at telegraph time and dazes Sparks inside at impact.
local starfalls={} -- [arena]={key,x,z,impactAt,resolved} (shared arenas)
local function starfallCandidates(arenaIndex,ownerId)
	local origin=world.arenas[arenaIndex].origin
	local list={}
	for _,c in pairs(herd) do
		if c.biome==arenaIndex and not c.claimed and not c.starterOwner and not c.runner and c.trialOwner==ownerId and #list<64 then
			table.insert(list,{x=c.position.X-origin.X,z=c.position.Z-origin.Z})
		end
	end
	return list
end
-- Returns the descriptor for State (telegraph) and resolves due impacts.
local function stepStarfall(state,fall,arenaIndex,ownerId,draw,now,notify)
	if fall.warning then
		local key=tostring(fall.cycle)..":"..tostring(fall.impact)
		if not state.current or state.current.key~=key then
			local spot=Encounters.starfallSpot(starfallCandidates(arenaIndex,ownerId),draw:NextNumber(),draw:NextNumber(),
				if ownerId then 1 else arenaIndex)
			state.current={key=key,x=spot.x,z=spot.z,impactAt=now+fall.seconds,resolved=false}
		end
	end
	local cur=state.current
	if cur and not cur.resolved and now>=cur.impactAt then
		cur.resolved=true
		local origin=world.arenas[arenaIndex].origin
		local center=origin+Vector3.new(cur.x,0,cur.z)
		local dazed=0
		for _,c in pairs(herd) do
			if c.biome==arenaIndex and not c.claimed and not c.starterOwner and not c.runner and c.trialOwner==ownerId
				and Vector3.new(c.position.X-center.X,0,c.position.Z-center.Z).Magnitude<=Encounters.StarfallRadius then
				c.dazedUntil=now+Encounters.DazeSeconds; dazed+=1
			end
		end
		notify(center+Vector3.new(0,1,0),dazed)
	end
end
local function starfallDescriptor(state,now,arenaIndex)
	local cur=state and state.current
	if not cur or cur.resolved or now>=cur.impactAt then return {visible=false} end
	return {visible=true,warning=true,position=world.arenas[arenaIndex].origin+Vector3.new(cur.x,0.2,cur.z),
		radius=Encounters.StarfallRadius,seconds=math.max(0,cur.impactAt-now)}
end
local function trialAvailable(s)
	if not s.ready or not s.profile then return false,"Loading your collection" end
	if s.profile.rounds<2 then return false,string.format("Finish %d more round%s to unlock",2-s.profile.rounds,if s.profile.rounds==1 then "" else "s") end
	return true,nil
end
local function trialInfo(s,includeBoard)
	local day=Trial.day(os.time())
	local plan=trialPlanFor(day)
	local t=s.profile.trial
	local runsToday=if t.runsDay==day then t.runsToday else 0
	local available,reason=trialAvailable(s)
	local board=nil
	if includeBoard then
		board={}
		if leaderboard.daily.day==day then
			for index,row in ipairs(leaderboard.daily.rows) do board[index]={rank=row.rank,name=row.name,score=row.score,userId=row.userId} end
		end
	end
	return {available=available,reason=reason,day=day,biome=plan.biome,biomeId=plan.biomeId,encounter=plan.encounter,
		best=if t.day==day then t.best else 0,runsToday=runsToday,xpRunsLeft=math.max(0,Trial.XpRunsPerDay-runsToday),
		rewardedToday=t.rewardedDay==day,medals=Trial.Medals,board=board,active=s.mode=="trial" and s.phase=="Playing",
		seconds=Trial.RunSeconds,firstGlow=Trial.FirstRunGlow,firstXp=Trial.FirstRunXp}
end
local function objective(s)
	if not s.ready then return "Connecting your collection…" end
	local now=os.clock()
	if s.phase=="Results" and s.mode=="trial" then
		return "DAILY STAMPEDE done • RETRY to beat your best • LEAVE to rejoin the stampede"
	end
	if s.phase=="Results" then
		return string.format("Next stampede in %ds • check Goals and Upgrades • %s",math.max(0,math.ceil((s.resultsUntil or now)-now)),s.saveStatus)
	end
	if s.phase=="SitOut" then return "Taking a break • press PLAY to join the stampede" end
	if #s.carry > 0 then return "Bring your parade to the glowing BANK gate" end
	if (s.starterRemaining or 0)>0 then return "CATCH your first Sparks • then chase into the arena" end
	if s.mode=="trial" then return "DAILY STAMPEDE • same course for everyone today • chain, dash, bank!" end
	if s.phase=="Warmup" then
		return string.format("WARM-UP • catch freely • the stampede starts in %ds",math.max(0,math.ceil((s.endsAt or now)-now)))
	end
	if s.endsAt and s.endsAt-now<=15 and s.challenge and s.challenge.pendingBonus>0 then
		return "BUZZER SOON! Bank now to keep your style bonus"
	end
	return "Dash THROUGH Sparks • Chain catches • Bank big hauls"
end
local function send(player,s)
	if not s.profile or player.Parent~=Players then return end
	local now=os.clock()
	-- Public, nonsensitive server summaries make live assertions reproducible.
	player:SetAttribute("SparkPhase",s.phase)
	player:SetAttribute("SparkGlow",s.profile.coins)
	player:SetAttribute("SparkTotalBanked",s.profile.totalBanked)
	player:SetAttribute("SparkSpecies",Profile.speciesCount(s.profile))
	player:SetAttribute("SparkRounds",s.profile.rounds)
	player:SetAttribute("SparkSaveStatus",s.saveStatus)
	player:SetAttribute("SparkStartersRemaining",s.starterRemaining or 0)
	local mastery=s.challenge and Challenge.snapshot(s.challenge,now)
	local trialMode=s.mode=="trial"
	local event=if trialMode then TRIAL_EVENT else arenaEvent(s.biome)
	local hazard=hazardFor(s,now)
	if hazard.visible then hazard.position=world.arenas[s.biome].origin+Vector3.new(hazard.x,0.25,hazard.z) end
	player:SetAttribute("SparkSkillScore",mastery and mastery.score or 0)
	local ranking={}
	if s.profile.settings.competition then
		for other,session in pairs(sessions) do
			if session.ready and session.challenge and session.profile.settings.competition and (session.mode=="trial")==trialMode then
				table.insert(ranking,{name=other.DisplayName,score=Challenge.snapshot(session.challenge,now).score,userId=other.UserId})
			end
		end
		table.sort(ranking,function(a,b) return a.score>b.score or (a.score==b.score and a.userId<b.userId) end)
		while #ranking>4 do table.remove(ranking) end
	end
	-- Encounter descriptors in world space for this player's arena (drawing only).
	local origin=world.arenas[s.biome].origin
	local clockNow=arenaClock()
	local gate,run
	if trialMode then
		gate=trialGate(s,now); run=trialRun(s,now)
	else
		gate=Encounters.gate(clockNow,s.biome)
		if gate.visible then gate.position=origin+Vector3.new(gate.x,0.3,gate.z) end
		run=Encounters.stampede(clockNow,s.biome,currentRemix)
		if run.visible then
			run.fromPosition=origin+Vector3.new(run.from.x,0.3,run.from.z); run.toPosition=origin+Vector3.new(run.to.x,0.3,run.to.z)
		end
	end
	local goldens={}
	for _,c in pairs(herd) do
		if c.golden and c.biome==s.biome and (not c.trialOwner or c.trialOwner==player.UserId) and #goldens<4 then table.insert(goldens,c.position) end
	end
	-- The daily board travels only when it changed (the client keeps the last copy).
	local dailyChanged=s.dailySent~=leaderboard.version
	local st=stats(s)
	-- The full profile is large; resend only after a change (or every 10s as a
	-- self-healing fallback). The client keeps the last copy it received.
	local includeProfile=s.profileSent~=s.revision or now-(s.profileSentAt or -math.huge)>10
	if includeProfile then s.profileSent=s.revision; s.profileSentAt=now end
	local boardsChanged=s.boardsSent~=leaderboard.version
	State:FireClient(player,{
		phase=s.phase,remaining=if s.endsAt and roundPlaying(s,now) then math.max(0,math.ceil(s.endsAt-now)) else 0,
		cycle=if trialMode then nil else Cycle.at(clockNow),fullRound=s.fullRound==true,sitOut=s.sitOut==true,
		mode=if trialMode then "trial" else "cycle",trial=trialInfo(s,dailyChanged),
		nextRoundIn=if s.phase=="Results" and s.resultsUntil then math.max(0,math.ceil(s.resultsUntil-now)) else nil,
		podium=if (s.phase=="Results" or s.phase=="SitOut") and podiums[s.biome] and podiums[s.biome].cycle==s.settledCycle then podiums[s.biome].awards else nil,
		biome=s.biome,carry=#s.carry,capacity=capacity(s),score=s.score,
		profile=if includeProfile then s.profile else nil,profileRevision=s.revision,
		saveStatus=s.saveStatus,event=event.name,arenaEvent=event,objective=objective(s),
		encounter=if trialMode then trialDescribe(s,now) else Encounters.describe(clockNow,s.biome),gate=gate,stampede=run,goldens=goldens,
		starfall=if not scoredRound(s,now) and s.phase~="Warmup" then nil
			elseif trialMode then starfallDescriptor(s.trial and s.trial.starfall,now,TRIAL_ARENA)
			else starfallDescriptor(starfalls[s.biome],now,s.biome),
		stats={captureRadius=st.captureRadius,capacity=st.capacity,chainSeconds=st.chainSeconds,heat=st.heat,
			scoreMultiplier=st.scoreMultiplier,perks=st.perks,goldenCompass=st.goldenCompass,maxMultiplier=st.maxMultiplier,
			staticCap=st.staticCap},
		rank=Progression.rankProgress(s.profile.xp),heatUnlocked=Loadout.heatUnlocked(s.profile.records),
		perkSlots=Loadout.slots(Progression.rank(s.profile.xp)),lastResult=s.lastResult,
		finale=scoredRound(s,now) and s.endsAt-now<=Cycle.FinaleSeconds,
		statics=s.statics and s.staticCount or 0,
		boards=if boardsChanged then leaderboard.boards else nil,boardsVersion=leaderboard.version,
		mastery=mastery,personalBest=s.newPersonalBest or false,arenaBest=s.newArenaBest or false,ranking=ranking,
		startersRemaining=s.starterRemaining or 0,
		hazard=hazard,
		rally=if trialMode then nil else ArenaRally.snapshot(rallies[s.biome],now,player.UserId),
		remix=Remix.describe(currentRemix,os.time()),
		bankPosition=world.arenas[s.biome].bank,ready=s.ready,
		captureCooldown=st.captureCooldown,dashCooldown=dashCooldown(s),
		cooldowns={capture=math.max(0,st.captureCooldown-(now-(s.buckets.capture or -math.huge))),
			dash=math.max(0,dashCooldown(s)-(now-(s.buckets.dash or -math.huge)))},
	})
	s.boardsSent=leaderboard.version
	s.dailySent=leaderboard.version
end
onRoundRecorded=function(player,s,summary,result)
	analytics.custom(player,"round_heat_"..(result.heat or 0),summary.score)
	if summary.golden and summary.golden>0 then analytics.custom(player,"golden_catch",summary.golden) end
	for _,perk in ipairs(stats(s).perks) do analytics.custom(player,"perk_"..perk,1) end
	-- D16: normal-round scores stay personal (records + podium); only the
	-- normalized Daily Stampede writes a public board.
	if result.rankAfter>result.rankBefore then
		feedback(player,"Quest","RANK UP! Rank "..result.rankAfter..(if #result.unlocks>0 then " • "..result.unlocks[1] else ""))
	end
	for _,name in ipairs(result.titles) do feedback(player,"Quest","ACHIEVEMENT • "..name) end
end
-- Coaching hints persist in the profile (flags.seenHints): never repeated across sessions.
local function hintOnce(player,s,id,text)
	local seen=s.profile.flags.seenHints
	if seen[id] then return false end
	seen[id]=true; Lifecycle.markDirty(s)
	feedback(player,"Hint",text,nil,nil,{coach=id})
	return true
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
		s.startPos=root.Position
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
	if not valid and s.mode=="trial" and s.trial then s.trial.rejections+=1 end
	if not valid then
		if s.challenge then Challenge.miss(s.challenge,now,"recovery") end
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
	if not automatic and not roundPlaying(s,os.clock()) then return end
	local root = rootOf(player)
	if not automatic and (not validApproach(player,s) or not root or (root.Position-world.arenas[s.biome].bank).Magnitude>12) then
		feedback(player,"Hint","Follow BANK to save your parade"); return
	end
	-- Clear ownership before any callback; no yields in reward transaction.
	local catches=s.carry; s.carry={}
	local ordinary=if s.challenge then s.challenge.pendingCount else 0
	parade(player,s)
	if s.mode=="trial" then
		-- Daily Stampede banks secure skill only: no glow, album, rally or bursts,
		-- so unlimited retries can never become a glow farm (rewards: settleTrial).
		local finaleTrial=not automatic and s.endsAt~=nil and s.endsAt-os.clock()<=Cycle.FinaleSeconds
		local secured=if s.challenge then Challenge.bank(s.challenge,os.clock(),{finale=finaleTrial}) else 0
		if not automatic then s.active=true end
		feedback(player,"Bank",string.format("+%d skill secured%s",secured,if finaleTrial and secured>0 then " • FINALE x1.25" else ""),nil,nil,
			{count=#catches,skill=secured,glow=0,newSpecies=0,trial=true,position=world.arenas[s.biome].bank})
		send(player,s)
		return
	end
	local wasNew=s.profile.totalBanked<3
	local reward,newSpecies=Profile.bank(s.profile,catches)
	if s.profile.totalBanked>=3 then clearStarters(player.UserId) end
	if wasNew and s.profile.totalBanked>=3 and not automatic and not s.profile.flags.seenHints.practice then
		-- Dash practice line (§7): three slow Sparks in a row straight out from the
		-- bank, so the first dash-through is guaranteed to be a MULTI catch.
		local pool={}
		for _,def in ipairs(Config.Creatures) do if def.biome==s.biome then table.insert(pool,def) end end
		local origin=world.arenas[s.biome].origin
		for n=1,3 do
			spawnCreature(s.biome,nil,nil,{def=pool[(n-1)%#pool+1],extra=true,beginner=true,expiresAt=os.clock()+25,
				position=origin+Vector3.new(0,2.2,13-(n-1)*4)})
		end
		hintOnce(player,s,"practice","DASH THROUGH THE LINE! Run at the three Sparks and press DASH (Shift / B)")
	end
	if s.profile.totalBanked>=3 and not s.hazardStarted then s.hazardStarted=os.clock() end
	s.score+=reward
	-- Final 25 seconds of the shared round: finale bank bonus (manual banks only).
	local warm=s.phase=="Warmup"
	local finale=not automatic and not warm and s.endsAt~=nil and s.endsAt-os.clock()<=Cycle.FinaleSeconds
	local skillPoints=if s.challenge and not warm then Challenge.bank(s.challenge,os.clock(),{finale=finale}) else 0
	if not automatic then s.active=true end
	metric(player,s,"first_bank")
	economy(player,s,"source",reward,"bank")
	feedback(player,"Bank",if warm then string.format("+%d glow banked%s • warm-up",reward,if newSpecies>0 then " • NEW SPARK!" else "")
		else string.format("+%d glow • %d skill secured%s%s",reward,skillPoints,
		if finale and skillPoints>0 then " • FINALE x1.25" else "",if newSpecies>0 then " • NEW SPARK!" else ""),nil,nil,
		{count=#catches,skill=skillPoints,glow=reward,newSpecies=newSpecies,position=world.arenas[s.biome].bank})
	Lifecycle.markDirty(s)
	if not automatic and #catches>0 then
		-- Everyone in the arena sees this player's Bank Burst celebration.
		local burst=Cosmetics.resolve("burst",s.profile.cosmetics.burst).id
		for other,session in pairs(sessions) do
			if session.ready and session.biome==s.biome and other.Parent==Players then
				Feedback:FireClient(other,{kind="BankBurst",position=world.arenas[s.biome].bank,extra={burst=burst,userId=player.UserId,count=#catches}})
			end
		end
	end
	if not automatic and not warm and ordinary>0 then
		local recipients=ArenaRally.deposit(rallies[s.biome],os.clock(),player.UserId,ordinary)
		for _,userId in ipairs(recipients) do
			for other,session in pairs(sessions) do
				if other.UserId==userId and session.ready and session.biome==s.biome
					and roundPlaying(session,os.clock()) and Lifecycle.leaseValid(persistence:leaseDeadline(userId),os.time()) then
					local bonus=Profile.rewardRally(session.profile)
					economy(other,session,"source",bonus,"rally")
					session.score+=bonus; Lifecycle.markDirty(session)
					feedback(other,"Quest","ARENA RALLY! +"..bonus.." glow • Every contribution helped")
					send(other,session)
				end
			end
		end
	end
	send(player,s)
end
local beginRound
-- Shared buzzer for this session's round. Warm-ups end into the next full round;
-- scored rounds bank, record and move to Results until the next cycle starts.
local function settleRound(player,s,now)
	if s.mode=="trial" then return settleTrial(player,s,now) end
	if (s.phase~="Playing" and s.phase~="Warmup") or roundPlaying(s,now) then return false end
	if s.phase=="Warmup" then
		-- Glow and album from warm-up catches are kept; no score, rounds or records.
		clearPersonal(player,s)
		if #s.carry>0 then bank(player,s,true) end
		beginRound(player,s,Cycle.fullRound(arenaClock()))
		return true
	end
	clearStarters(player.UserId)
	clearPersonal(player,s)
	-- Buzzer: carried style bonus is forfeited; carried Sparks and base points still bank.
	local forfeited=Challenge.buzzer(s.challenge,os.clock())
	bank(player,s,true); s.phase="Results"
	Challenge.finish(s.challenge,os.clock())
	if s.fullRound then Challenge.checkpoint(s.challenge,math.max(Cycle.Play,os.clock()-s.started)) end
	local summary=Challenge.snapshot(s.challenge,os.clock())
	local biomeId=Config.Biomes[s.challengeBiome].id
	local catches=s.roundCatches or 0
	local completed=Cycle.completed(catches)
	local partial=not s.fullRound
	s.settledCycle=s.cycleIndex
	s.resultsUntil=arenaEpoch+(s.cycleIndex+1)*Cycle.Length
	s.lastSummary={userId=player.UserId,name=player.DisplayName,score=summary.score,bestChain=summary.bestChain,
		golden=summary.golden,assists=summary.assists,herded=summary.herded,pops=summary.pops,
		showOnPodium=s.profile.settings.showOnPodium~=false,cycle=s.cycleIndex,biome=s.challengeBiome}
	-- AFK (D17): two idle rounds in a row switch the player to Sit out.
	if s.active then s.idleRounds=0 else s.idleRounds=(s.idleRounds or 0)+1 end
	if (s.idleRounds or 0)>=2 and not s.sitOut then
		s.sitOut=true
		feedback(player,"Hint","Taking a break? You're sitting out • press PLAY to rejoin")
	end
	if completed then
		s.profile.rounds=math.min(1000000,s.profile.rounds+1)
		s.newArenaBest=not partial and summary.score>(s.profile.mastery.bestByBiome[biomeId] or 0)
		s.newPersonalBest=Profile.recordMastery(s.profile,biomeId,summary,s.profile.rounds,partial)
		local result=Progression.applyRound(s.profile,summary,s.challengeBiome,s.roundHeat or 0,s.profile.rounds,os.time(),partial)
		if result then
			result.score=summary.score; result.medal=summary.medal; result.heat=s.roundHeat or 0; result.buzzer=forfeited
			result.full=not partial
			result.titles={}
			for _,id in ipairs(result.achievements) do
				local a=Progression.AchievementById[id]; if a then table.insert(result.titles,a.name) end
			end
			s.lastResult=result
			onRoundRecorded(player,s,summary,result)
		end
		metric(player,s,"first_round")
	else
		s.newArenaBest=false; s.newPersonalBest=false
		s.lastResult={incomplete=true,score=summary.score,medal=summary.medal,heat=s.roundHeat or 0,buzzer=forfeited,
			xp=0,rankBefore=Progression.rank(s.profile.xp),rankAfter=Progression.rank(s.profile.xp),unlocks={},achievements={},titles={},
			full=not partial,catches=catches}
	end
	Lifecycle.markDirty(s)
	feedback(player,"Results",if not completed then string.format("Catch %d+ Sparks in a round to earn round credit",Cycle.CompletionCatches)
		elseif forfeited>0 then string.format("BUZZER! %d style bonus unbanked • Round complete",forfeited)
		else "Round complete! Your parade earned "..s.score.." glow")
	send(player,s)
	return true
end
-- plan: Cycle.joinPlan(...) or Cycle.fullRound(...); times are arena-clock seconds.
beginRound=function(player,s,plan)
	if not s.ready then return end
	local now=os.clock()
	if s.started then metric(player,s,"replay") end
	local warm=plan.mode=="warmup"
	s.phase=if warm then "Warmup" else "Playing"
	s.started=now; s.endsAt=arenaEpoch+plan.endsAt; s.fullRound=plan.full==true; s.cycleIndex=plan.cycle
	s.carry={}; s.score=0; s.buckets={}; s.roundCatches=0; s.active=false
	s.roundsAtStart=s.profile.rounds
	local biomeId=Config.Biomes[s.biome].id
	local previous=s.profile.mastery.bestRuns[biomeId] or {score=s.profile.mastery.bestByBiome[biomeId] or 0}
	-- Heat and loadout lock for the whole round; records are filed under this heat.
	s.profile.heat=math.min(s.profile.heat,Loadout.heatUnlocked(s.profile.records))
	s.profile.loadout=Loadout.sanitize(s.profile.loadout,Progression.rank(s.profile.xp))
	s.stats=statsFor(s); s.roundHeat=s.profile.heat
	if Progression.ensureGoals(s.profile,os.time()) then Lifecycle.markDirty(s) end
	s.lastResult=nil
	clearPersonal(player,s)
	s.challenge=Challenge.new(s.profile.rounds+1,if s.fullRound then previous else nil,s.stats)
	s.newPersonalBest=false; s.newArenaBest=false; s.challengeBiome=s.biome
	s.eventPhase=nil
	s.hazardUntil=0; s.hazardNext=0
	s.hazardStarted=if not warm and s.profile.totalBanked>=3 then now else nil
	parade(player,s)
	teleport(player,s)
	issueStarters(player,s)
	local left=math.max(0,math.ceil(s.endsAt-now))
	feedback(player,"Round",if warm then string.format("WARM-UP • catch freely • stampede starts in %ds",left)
		elseif s.fullRound then "3-2-1 STAMPEDE! • CHASE • CATCH • BANK"
		else string.format("JOIN THE STAMPEDE! • %ds left",left),nil,nil,{cycleStart=s.fullRound,warmup=warm})
	send(player,s)
end
local function startNow(player,s)
	s.sitOut=false; s.idleRounds=0
	beginRound(player,s,Cycle.joinPlan(arenaClock()))
end
-- BEGIN DAILY STAMPEDE
-- Seeded solo run (plan §6.4): same spawns, respawn order, encounter, golden moment
-- and normalized rules for every player on a UTC day. Outside the shared cycle.
local function spawnTrialSpark(player,s,def,spot,options)
	options=options or {}
	return spawnCreature(TRIAL_ARENA,nil,nil,{def=def,extra=true,trialOwner=player.UserId,trialPlan=options.trialPlan,
		golden=options.golden,runner=options.runner,expiresAt=options.expiresAt,
		seed=options.seed,heading=options.heading,
		position=options.position or world.arenas[TRIAL_ARENA].origin+Vector3.new(spot.x,2.2,spot.z)})
end
startTrial=function(player,s)
	local ok,reason=trialAvailable(s)
	if not ok then feedback(player,"Hint","Daily Stampede: "..tostring(reason)); send(player,s); return end
	local now=os.clock()
	if s.mode~="trial" and s.phase=="Playing" then
		feedback(player,"Hint","Finish this round first • the Daily Stampede opens between rounds"); send(player,s); return
	end
	if s.trial and now-s.trial.startedAt<1.5 then return end -- retry spam guard
	if s.mode~="trial" then
		-- Leaving the shared cycle keeps any warm-up glow: bank the parade first.
		clearPersonal(player,s)
		if #s.carry>0 then bank(player,s,true) end
		s.trialReturnBiome=s.biome
	end
	clearTrial(player.UserId); clearStarters(player.UserId); clearPersonal(player,s)
	local day=Trial.day(os.time())
	local plan=trialPlanFor(day)
	local t=s.profile.trial
	s.mode="trial"; s.biome=TRIAL_ARENA; s.challengeBiome=plan.biome
	s.trial={day=day,plan=plan,rng=Random.new(plan.seed),serial=0,rejections=0,startedAt=now,
		goldenSpawned=false,runSpawned=false,runWarned=false,gateWarned=false}
	s.phase="Playing"; s.started=now; s.endsAt=now+Trial.RunSeconds; s.fullRound=false; s.cycleIndex=nil
	s.carry={}; s.score=0; s.buckets={}; s.roundCatches=0; s.active=true; s.lastSummary=nil; s.sitOut=false
	s.stats=Trial.stats(); s.roundHeat=0; s.lastResult=nil; s.newPersonalBest=false; s.newArenaBest=false
	-- Fixed difficulty for everyone; the round goal rotates by day. Ghost splits vs today's best.
	s.challenge=Challenge.new(7+day%12,if t.day==day then t.bestRun else nil,s.stats)
	s.hazardStarted=nil; s.hazardUntil=0; s.hazardNext=0; s.eventPhase=nil; s.starterRemaining=0
	parade(player,s); teleport(player,s)
	for k,spot in ipairs(plan.spawns) do
		if species[spot.species] then
			local spark=spawnTrialSpark(player,s,species[spot.species],spot,{trialPlan=true,seed=(k*3.7)%20,heading=(k*1.31)%(math.pi*2)})
			if spark then spark.model:SetAttribute("TrialSlot",k) end
		end
	end
	feedback(player,"Round",string.format("DAILY STAMPEDE! Same course for everyone today • %ds",Trial.RunSeconds),nil,nil,{trial=true,cycleStart=true})
	hintOnce(player,s,"trial","DAILY STAMPEDE: one fair course for everyone today • upgrades and perks don't count • RETRY anytime")
	analytics.custom(player,"daily_stampede_start",1)
	send(player,s)
end
leaveTrial=function(player,s)
	if s.mode~="trial" then send(player,s); return end
	clearTrial(player.UserId); clearPersonal(player,s)
	-- Trial catches never pay glow, so dropping an unbanked trial parade loses nothing saved.
	s.carry={}; parade(player,s)
	s.mode=nil; s.trial=nil
	s.biome=s.trialReturnBiome or 1; s.challengeBiome=s.biome; s.trialReturnBiome=nil
	s.stats=statsFor(s)
	feedback(player,"Hint","Back to the stampede!")
	startNow(player,s)
end
settleTrial=function(player,s,now)
	if s.phase~="Playing" or roundPlaying(s,now) then return false end
	local tr=s.trial
	if not tr then return false end
	clearTrial(player.UserId); clearPersonal(player,s)
	local forfeited=Challenge.buzzer(s.challenge,now)
	bank(player,s,true)
	Challenge.finish(s.challenge,now)
	local summary=Challenge.snapshot(s.challenge,now)
	local score=math.floor(summary.score)
	local profile=s.profile
	local day=tr.day
	local catches=s.roundCatches or 0
	local rankBefore=Progression.rank(profile.xp)
	-- Shared pure settlement (Trial.settle): once-per-day reward, capped XP, today's best.
	local settled=Trial.settle(profile,day,score,catches,summary.checkpoints,os.time())
	local completed,improved,glow,xp=settled.completed,settled.improved,settled.glow,settled.xp
	if glow>0 then economy(player,s,"source",glow,"daily_stampede") end
	local rankAfter=Progression.rank(profile.xp)
	local eligible=settled.valid and completed and score>0 and tr.rejections<=TRIAL_REJECTION_LIMIT
	if eligible and improved then
		dailyDirty=true
		task.spawn(function() leaderboard.submitDaily(player.UserId,day,score) end)
	end
	s.lastResult={trial=true,score=score,medal=Trial.medal(score),best=settled.best,improved=improved,xp=xp,glow=glow,
		runsToday=settled.runsToday,xpRunsLeft=settled.xpRunsLeft,day=day,catches=catches,
		buzzer=forfeited,rankBefore=rankBefore,rankAfter=rankAfter,unlocks=Progression.unlocksBetween(rankBefore,rankAfter),
		achievements={},titles={},full=true,incomplete=not completed,boardEligible=eligible,bestChain=summary.bestChain,
		reason=if not completed then string.format("Catch %d+ Sparks to finish a run",Cycle.CompletionCatches)
			elseif not eligible then "This run can't go on the board (movement corrections)" else nil}
	s.phase="Results"; s.resultsUntil=nil; s.settledCycle=nil
	s.newPersonalBest=improved; s.newArenaBest=false
	Lifecycle.markDirty(s)
	metric(player,s,"first_daily_stampede")
	analytics.custom(player,"daily_stampede_run",score)
	if rankAfter>rankBefore then feedback(player,"Quest","RANK UP! Rank "..rankAfter) end
	feedback(player,"Results",if not completed then s.lastResult.reason
		else string.format("DAILY STAMPEDE • %d • %s%s",score,Trial.medal(score),if improved then " • NEW BEST TODAY!" else ""),
		nil,nil,{trial=true})
	send(player,s)
	return true
end
-- Personal encounter schedule from trial elapsed time (golden, run, gate warning).
local function updateTrial(player,s,now)
	local tr=s.trial
	if s.mode~="trial" or not tr or not scoredRound(s,now) then return end
	local sch=Trial.schedule(now-s.started,tr.plan)
	if sch.golden and not tr.goldenSpawned then
		tr.goldenSpawned=true
		local spot=Trial.respawn(tr.plan,999)
		if spot and species[spot.species] then
			spawnTrialSpark(player,s,species[spot.species],spot,{golden=true,expiresAt=s.endsAt,seed=7,heading=0})
			feedback(player,"Event","GOLDEN SPARK! Catch it for +250 style")
		end
	end
	if tr.plan.encounter=="stampede" then
		if sch.runWarning and not tr.runWarned then
			tr.runWarned=true; feedback(player,"Event","STAMPEDE RUN in 3s • get beside the lane")
		end
		if sch.runActive and not tr.runSpawned then
			tr.runSpawned=true
			local lane=Encounters.Runs[1]
			local origin=world.arenas[TRIAL_ARENA].origin
			local from=origin+Vector3.new(lane.from.x,2.2,lane.from.z)
			local to=origin+Vector3.new(lane.to.x,2.2,lane.to.z)
			local direction=(to-from).Unit
			local side=Vector3.new(-direction.Z,0,direction.X)
			local speedRun=Encounters.runSpeed()
			for n=1,Encounters.RunCount do
				local lag=(n-1)*2.2
				spawnTrialSpark(player,s,species.ziptail,nil,{position=from-direction*lag+side*((n%3)-1)*2.4,seed=n,
					runner={direction=direction,speed=speedRun,untilT=now+(to-from).Magnitude/speedRun+lag/speedRun+0.2}})
			end
			feedback(player,"Event","STAMPEDE RUN! Dash through the lane")
		end
	elseif tr.plan.encounter=="starfall" then
		-- Personal Starfall: the shared choreography shifted 30 s earlier, own Sparks only.
		local fall=Encounters.starfall(now-s.started+30,3)
		tr.starfall=tr.starfall or {}
		if fall.warning and not tr.starfallWarned then
			tr.starfallWarned=true; feedback(player,"Event","AURORA STARFALL! Stars daze nearby Sparks • catch them for STARSTRUCK")
		end
		stepStarfall(tr.starfall,fall,TRIAL_ARENA,player.UserId,tr.rng,now,function(position,dazed)
			feedback(player,"Starfall",if dazed>0 then string.format("STARFALL! %d Spark%s dazed",dazed,if dazed==1 then "" else "s") else "STARFALL!",nil,position,{dazed=dazed})
		end)
	elseif not tr.gateWarned and trialGate(s,now).visible then
		tr.gateWarned=true; feedback(player,"Event","SPARK GATE! Chase Sparks so they flee THROUGH the ring")
	end
end
-- END DAILY STAMPEDE
-- options (all server-owned): def, position, golden, extra (no respawn on catch),
-- runner={direction,speed,untilT}, expiresAt.
spawnCreature=function(biome,index,starterPlayer,options)
	options=options or {}
	local defs={}
	local biomeDef=Config.Biomes[biome]
	for _,def in ipairs(Config.Creatures) do
		if (biomeDef and def.biome==biomeDef.id) or def.biome==biome then table.insert(defs,def) end
	end
	if #defs==0 then defs=Config.Creatures end
	local def=options.def or defs[((index or 1)-1)%#defs+1]
	local arena=world.arenas[biome]
	local angle=random:NextNumber(0,math.pi*2)
	local radius=random:NextNumber(10,43)
	local offset=Rules.herdSpawn(angle,radius)
	local position=arena.origin+Vector3.new(offset.x,offset.y,offset.z)
	-- Finite owner-specific starters are separate from the 54 normal herd slots.
	if starterPlayer then position=arena.origin+Vector3.new((index-2)*4,2.2,30) end
	if options.position then position=options.position end
	-- Golden models are fully gilded before they replicate, so clients see the
	-- final appearance (and reduced-motion masking) from the first frame.
	local model=World.creature(def,if options.golden then nil else creaturesFolder)
	if options.golden then World.gild(model); model.Parent=creaturesFolder end
	nextCreatureId+=1
	model.Name="Spark_"..nextCreatureId
	model:SetAttribute("CreatureId",nextCreatureId); model:SetAttribute("Species",def.id)
	if options.trialOwner then
		-- Owner-only like starters: other clients mask it (StarterOwnerId), and the
		-- owner's aim preview accepts it (Trial). The server enforces capture.
		model:SetAttribute("StarterOwnerId",options.trialOwner); model:SetAttribute("Trial",true)
	end
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
	if options.golden then model:SetAttribute("Golden",true) end
	herd[nextCreatureId]={id=nextCreatureId,def=def,model=model,biome=biome,
		position=position,home=position,beginner=starterPlayer~=nil or options.beginner==true,starterOwner=starterPlayer and starterPlayer.UserId,
		heading=if options.runner then math.atan2(options.runner.direction.Z,options.runner.direction.X) else (options.heading or angle),
		seed=options.seed or random:NextNumber(0,20),claimed=false,index=index,
		golden=options.golden==true,extra=options.extra==true,runner=options.runner,expiresAt=options.expiresAt,
		trialOwner=options.trialOwner,trialPlan=options.trialPlan==true}
	return herd[nextCreatureId]
end
issueStarters=function(player,s)
	local allowance=Rules.issueStarters(s,s.profile.totalBanked)
	s.starterRemaining=allowance
	for index=1,allowance do spawnCreature(s.biome,index,player) end
end
for biome=1,SHARED_ARENAS do
	for index=1,18 do spawnCreature(biome,index) end
	task.wait()
end

-- BEGIN CATCH TRANSACTIONS (extracted by tests/test_spark_gameplay_integration.py)
local function sessionFor(userId)
	for other,session in pairs(sessions) do if other.UserId==userId then return other,session end end
	return nil,nil
end
-- Flanking credit: the most recent *other* player who spooked this Spark within 4s.
local function creditAssist(creature,catcherId,now)
	for _,pair in ipairs({{creature.spookedBy,creature.spookedAt},{creature.assistBy,creature.assistAt}}) do
		local userId,at=pair[1],pair[2]
		if userId and userId~=catcherId and at and now-at<=4 then
			local other,session=sessionFor(userId)
			-- Credit only spooks from this session's current round (not a pre-rejoin session).
			if other and session.ready and session.challenge and session.biome==creature.biome and roundPlaying(session,now)
				and session.started and at>=session.started then
				local ok,points=Challenge.award(session.challenge,now,"assist")
				if ok then feedback(other,"Assist",string.format("ASSIST! +%d style for the flank",points),nil,creature.position,{tags={"ASSIST"},points=points}) end
			end
			return
		end
	end
end
-- One atomic claim path for button, dash-through, herded and golden catches.
local function claim(player,s,creature,kind,aim,multiIndex)
	local now=os.clock()
	creature.claimed=true -- atomic claim before effects and respawn scheduling
	s.roundCatches=(s.roundCatches or 0)+1; s.active=true
	if creature.starterOwner then s.starterRemaining=math.max(0,(s.starterRemaining or 0)-1) end
	table.insert(s.carry,if creature.golden then "*"..creature.def.id else creature.def.id)
	parade(player,s)
	creature.model:Destroy(); herd[creature.id]=nil
	metric(player,s,"first_catch")
	local scoredKind=if creature.golden then "golden" else kind
	local _,skill=Challenge.capture(s.challenge,now,{
		distance=if aim then aim.distance else 0,facing=if aim and aim.facing then aim.facing else 1,
		dashAge=if s.motion and s.motion.dashStarted then now-s.motion.dashStarted else nil,
		value=creature.def.value,starter=creature.starterOwner~=nil,captureId=creature.id,
		kind=scoredKind,multiIndex=multiIndex,signature=creature.def.signature,
		dazed=creature.dazedUntil~=nil and now<creature.dazedUntil})
	local tags={}
	local message="Caught "..creature.def.name.."!"
	local scored=type(skill)=="table" and not skill.starter
	if scored then
		if skill.kind=="golden" then table.insert(tags,"GOLDEN") end
		if skill.kind=="herd" then table.insert(tags,"HERDED") end
		if skill.multi then table.insert(tags,"MULTI x"..multiIndex) elseif skill.dash then table.insert(tags,"DASH") end
		if skill.precision then table.insert(tags,"PRECISE") end
		if skill.starstruck then table.insert(tags,"STARSTRUCK") end
		if skill.signature then
			table.insert(tags,"SIGNATURE")
			-- Album signature stars (D21) count outside the Daily Stampede (no collection farming there).
			if s.mode~="trial" then
				local star=Progression.recordSignature(s.profile,creature.def.id)
				Lifecycle.markDirty(s)
				if star then
					feedback(player,"Quest",string.format("★ %s SIGNATURE STAR %d!",string.upper(creature.def.name),star),creature.def,creature.position,{signatureStar=star})
					for _,id in ipairs(Progression.evaluateAchievements(s.profile)) do
						local a=Progression.AchievementById[id]
						if a then feedback(player,"Quest","ACHIEVEMENT • "..a.name) end
					end
				end
			end
			hintOnce(player,s,"signature","SIGNATURE CATCH! Each Spark has its own technique • check the ALBUM for stars")
		end
		message=string.format("+%d skill • %sx%d",skill.points,if #tags>0 then table.concat(tags," • ").." • " else "",skill.multiplier)
	end
	feedback(player,"Catch",message,creature.def,creature.position,{tags=tags,points=if scored then skill.points else 0,
		chain=if scored then skill.chain else 0,multiplier=if scored then skill.multiplier else 1,golden=creature.golden,
		creatureId=creature.id,species=creature.def.id,signature=scored and skill.signature or nil,starstruck=scored and skill.starstruck or nil})
	if creature.golden or kind=="herd" then creditAssist(creature,player.UserId,now)
	elseif creature.spookedBy and creature.spookedBy~=player.UserId and creature.spookedAt and now-creature.spookedAt<=1.5 then
		-- Contested catch (D25): the player who was chasing it within 8 studs gets a
		-- small ASSIST, so "stealing" a chased Spark becomes teamwork.
		local other,session=sessionFor(creature.spookedBy)
		local otherRoot=other and rootOf(other)
		if other and session.ready and session.challenge and session.biome==creature.biome and scoredRound(session,now)
			and session.started and creature.spookedAt>=session.started and otherRoot
			and (otherRoot.Position-creature.position).Magnitude<=8 then
			local ok,points=Challenge.award(session.challenge,now,"contest")
			if ok then feedback(other,"Assist",string.format("ASSIST! +%d style • teamwork",points),nil,creature.position,{tags={"ASSIST"},points=points}) end
		end
	end
	if creature.trialPlan and s.trial then
		-- Seeded respawn sequence: the k-th replacement is identical for everyone today.
		local tr=s.trial
		tr.serial+=1
		local k=tr.serial
		task.delay(0.8,function()
			if lifecycle.closing or s.trial~=tr or s.mode~="trial" or not scoredRound(s,os.clock()) then return end
			local spot=Trial.respawn(tr.plan,k)
			if spot and species[spot.species] then
				spawnCreature(TRIAL_ARENA,nil,nil,{def=species[spot.species],extra=true,trialOwner=player.UserId,trialPlan=true,
					seed=(k*7.31)%20,heading=(k*2.17)%(math.pi*2),
					position=world.arenas[TRIAL_ARENA].origin+Vector3.new(spot.x,2.2,spot.z)})
			end
		end)
	end
	if creature.golden and not creature.trialOwner then
		for other,session in pairs(sessions) do
			if other~=player and session.ready and session.biome==creature.biome then
				feedback(other,"Event",player.DisplayName.." caught a GOLDEN SPARK!")
			end
		end
	end
	if not creature.starterOwner and not creature.extra then
		task.delay(2,function() if not lifecycle.closing then spawnCreature(creature.biome,creature.index) end end)
	end
	return skill
end

local function capture(player,s)
	local now=os.clock()
	if not roundPlaying(s,now) then return end
	if now<(s.hazardUntil or 0) then return end
	local st=stats(s)
	if not Rules.allow(s.buckets,"capture",now,st.captureCooldown) then return end
	if not validApproach(player,s) then return end
	local root,humanoid=rootOf(player)
	if not root or not humanoid or humanoid.Health<=0 then return end
	metric(player,s,"first_action")
	local radius=st.captureRadius
	local nearest,best=nil,nil
	for _,creature in pairs(herd) do
		local allowed=Rules.canCapture({phase=if roundPlaying(s,now) then "Playing" else s.phase,ready=s.ready,carry=#s.carry,biome=s.biome,userId=player.UserId,totalBanked=s.profile.totalBanked,
			position=xyz(root.Position),suspiciousUntil=s.suspiciousUntil,mode=s.mode},
			{claimed=creature.claimed,biome=creature.biome,starterOwner=creature.starterOwner,trialOwner=creature.trialOwner,position=xyz(creature.position)},now,radius,capacity(s))
		local aim=if allowed then Targeting.measure(xyz(root.Position),xyz(root.CFrame.LookVector),xyz(creature.position),radius) else nil
		if Targeting.better(aim,creature.id,best,nearest and nearest.id) then
			nearest=creature; best=aim
		end
	end
	if not nearest then
		-- A full pack is a return-to-bank prompt, not a failed aiming attempt.
		if #s.carry<capacity(s) and s.challenge then
			Challenge.miss(s.challenge,now,"miss")
			if st.missLock>0 then s.hazardUntil=now+st.missLock end
		end
		feedback(player,"Hint",if #s.carry>=capacity(s) then "Parade full! Follow BANK" else "Get closer and face a Spark")
		send(player,s)
		return
	end
	claim(player,s,nearest,"normal",best,nil)
	send(player,s)
end

-- Dash-through: sparks within the dash path radius of the server-observed,
-- movement-validated segment are caught in path order, up to the perk limit.
local function dashSweep(player,s,root,now)
	local sweep=s.dashSweep
	if not sweep then return 0 end
	if now>sweep.untilT or not roundPlaying(s,now) then s.dashSweep=nil; return 0 end
	local here=xyz(root.Position)
	local from=sweep.last; sweep.last=here
	if now<(s.hazardUntil or 0) then return 0 end
	local st=stats(s)
	local candidates={}
	for _,creature in pairs(herd) do
		local allowed=Rules.canCapture({phase=if roundPlaying(s,now) then "Playing" else s.phase,ready=s.ready,carry=#s.carry,biome=s.biome,userId=player.UserId,totalBanked=s.profile.totalBanked,
			position=here,suspiciousUntil=s.suspiciousUntil,mode=s.mode},
			{claimed=creature.claimed,biome=creature.biome,starterOwner=creature.starterOwner,trialOwner=creature.trialOwner,position=xyz(creature.position)},now,500,capacity(s))
		local hit=if allowed then Targeting.sweep(from,here,xyz(creature.position),st.dashCatchRadius) else nil
		if hit then table.insert(candidates,{creature=creature,hit=hit}) end
	end
	table.sort(candidates,function(a,b) return a.hit.t<b.hit.t or (a.hit.t==b.hit.t and a.creature.id<b.creature.id) end)
	local caught=0
	for _,candidate in ipairs(candidates) do
		if sweep.caught>=st.dashCatchLimit or #s.carry>=capacity(s) then break end
		if not candidate.creature.claimed then
			sweep.caught+=1; caught+=1
			claim(player,s,candidate.creature,"dash",{distance=candidate.hit.distance,facing=1},sweep.caught)
		end
	end
	if caught>0 then send(player,s) end
	return caught
end

-- A zap or sweep hit: chain and carried bonus end, catching pauses briefly and
-- up to N carried Sparks scatter back into the arena (recatchable by anyone).
-- Saved glow, album and banked score are never touched.
local function scatter(player,s,count,at)
	if #s.carry==0 or count<=0 then return 0 end
	local removed={}
	for _=1,math.min(count,#s.carry) do table.insert(removed,table.remove(s.carry)) end
	local bases={}
	for _,entry in ipairs(removed) do table.insert(bases,creatureBase(entry)) end
	Challenge.scatter(s.challenge,os.clock(),bases)
	parade(player,s)
	local arena=world.arenas[s.biome]
	for _,entry in ipairs(removed) do
		local golden=string.sub(entry,1,1)=="*"
		local def=species[if golden then string.sub(entry,2) else entry]
		if def then
			local angle=random:NextNumber(0,math.pi*2)
			local distance=random:NextNumber(6,10)
			local rel=(at-arena.origin)+Vector3.new(math.cos(angle)*distance,0,math.sin(angle)*distance)
			local flat=Vector3.new(rel.X,0,rel.Z)
			if flat.Magnitude>44 then flat=flat.Unit*44 end
			local safe=Rules.outsideBank({x=flat.X,y=0,z=flat.Z},{x=0,y=0,z=44})
			-- Scattered extras always expire so unattended arenas never accumulate them.
			local spark=spawnCreature(s.biome,nil,nil,{def=def,golden=golden,extra=true,
				trialOwner=if s.mode=="trial" then player.UserId else nil,
				position=arena.origin+Vector3.new(safe.x,2.2,safe.z),expiresAt=os.clock()+(if golden then 20 else 30)})
			if spark then spark.scattered=true end
		end
	end
	return #removed
end
local function hit(player,s,now,position,label)
	local _,lost=Challenge.miss(s.challenge,now,"zap")
	s.hazardUntil=now+.8; s.zapImmuneUntil=now+1.5
	local scattered=scatter(player,s,stats(s).zapScatter,position)
	feedback(player,"Zap",string.format("%s! %d bonus lost%s • Recatch them!",label,lost,
		if scattered>0 then " • "..scattered.." Sparks scattered" else ""),nil,position,{lost=lost,scattered=scattered,tags={label}})
	send(player,s)
end
clearPersonal=function(_player,s)
	if s.statics then for _,static in pairs(s.statics) do if static.model then static.model:Destroy() end end end
	s.statics={}; s.staticCount=0; s.staticNext=0; s.staticSerial=s.staticSerial or 0; s.dashSweep=nil
end
-- Personal statics: only the owner can be zapped by, or pop, their statics.
local function updateStatics(player,s,root,now,step)
	if not s.statics then clearPersonal(player,s) end
	local origin=world.arenas[s.biome].origin
	local st=stats(s)
	local eligible
	if s.mode=="trial" then
		eligible=scoredRound(s,now) and s.trial~=nil and Trial.schedule(now-s.started,s.trial.plan).staticsActive
	else
		eligible=scoredRound(s,now) and staticsAllowed(s) and s.hazardStarted~=nil and s.profile.totalBanked>=3
			and now-s.hazardStarted>=Encounters.staticStart(s.biome)
			-- Weekly Remix "Fizz Festival": statics only for Heat 1+ (and pops pay x2).
			and (currentRemix.staticsMinHeat==nil or (s.roundHeat or 0)>=currentRemix.staticsMinHeat)
	end
	local draw=if s.mode=="trial" and s.trial then s.trial.rng else random
	local rel={x=root.Position.X-origin.X,z=root.Position.Z-origin.Z}
	if eligible and s.staticCount<st.staticCap and now>=s.staticNext then
		for _=1,6 do
			local spot=Encounters.staticSpawn(draw:NextNumber(0,math.pi*2),draw:NextNumber(18,44),rel)
			if spot then
				s.staticSerial+=1
				local model=World.static(staticsFolder,player.UserId)
				model:PivotTo(CFrame.new(origin+Vector3.new(spot.x,3,spot.z)))
				s.statics[s.staticSerial]={id=s.staticSerial,pos=spot,born=now,model=model}
				s.staticCount+=1
				hintOnce(player,s,"static","STATIC PUFF! DASH through it to POP it • touching it zaps your parade")
				break
			end
		end
		s.staticNext=now+st.staticInterval
	end
	local dashing=s.motion~=nil and s.motion.dashUntil~=nil and now<=s.motion.dashUntil+0.05
	for id,static in pairs(s.statics) do
		local remove=not eligible or now-static.born>12
		if not remove then
			static.pos=Encounters.staticStep(static.pos,rel,st.staticSpeed,step)
			local bob=if s.profile.settings.reducedMotion then 0 else math.sin((now-static.born)*3)*0.3
			static.model:PivotTo(CFrame.new(origin+Vector3.new(static.pos.x,3+bob,static.pos.z)))
			local dx,dz=rel.x-static.pos.x,rel.z-static.pos.z
			if dx*dx+dz*dz<=9 and math.abs(root.Position.Y-(origin.Y+3))<6 then
				remove=true
				local position=origin+Vector3.new(static.pos.x,3,static.pos.z)
				if dashing then
					local ok,points=Challenge.award(s.challenge,now,"pop")
					if ok then feedback(player,"Pop",string.format("POP! +%d style • chain refreshed",points),nil,position,{tags={"POP"},points=points}) end
				elseif now>=(s.zapImmuneUntil or 0) then
					hit(player,s,now,position,"ZAP")
				end
			end
		end
		if remove then static.model:Destroy(); s.statics[id]=nil; s.staticCount-=1 end
	end
end
-- END CATCH TRANSACTIONS

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
	-- Ready/Replay are idempotent phase transitions with their own bucket, so a
	-- catch press in the same instant can never swallow a Replay click.
	local phaseAction=action=="Ready" or action=="Replay" or action=="Play" or action=="SitOut" or action=="Trial"
	local bucket=if phaseAction then action else "request"
	if not Rules.allow(s.transport,bucket,os.clock(),if bucket=="request" then 0.08 else 0.25) then return end
	if action=="Ready" then
		s.clientReady=true
		if s.ready and s.phase=="Loading" then startNow(player,s) else send(player,s) end
		return
	end
	if not s.ready then return end
	if not Lifecycle.leaseValid(persistence:leaseDeadline(player.UserId),os.time()) then
		haltForLease(player,s,"acknowledged lease expired"); return
	end
	if action=="Replay" or action=="Play" then
		-- Rounds start automatically each cycle; Play clears Sit out.
		s.sitOut=false; s.idleRounds=0
		if s.phase=="SitOut" then startNow(player,s) else send(player,s) end
	elseif action=="Trial" and type(payload)=="string" and #payload<=8 then
		if payload=="start" or payload=="retry" then startTrial(player,s)
		elseif payload=="leave" then leaveTrial(player,s) end
	elseif action=="SitOut" and s.mode=="trial" then
		send(player,s)
	elseif action=="SitOut" then
		s.sitOut=true
		if s.phase=="Warmup" then
			clearPersonal(player,s); if #s.carry>0 then bank(player,s,true) end
			s.phase="SitOut"
		end
		send(player,s)
	elseif action=="Capture" then
		s.active=true
		capture(player,s)
	elseif action=="Dash" and roundPlaying(s,os.clock()) then
		s.active=true
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
			-- The heartbeat sweeps the validated path for dash-through catches.
			s.dashSweep={last=xyz(root.Position),untilT=s.motion.dashUntil+0.1,caught=0}
			metric(player,s,"first_action"); feedback(player,"Dash","WHOOSH!")
		end
	elseif action=="Bank" and roundPlaying(s,os.clock()) and os.clock()>s.suspiciousUntil then
		bank(player,s,false)
	elseif action=="Upgrade" and type(payload)=="string" and #payload<=20 then
		local ok,message=Profile.buy(s.profile,payload)
		if ok then
			Lifecycle.markDirty(s); if s.mode~="trial" then s.stats=statsFor(s) end; metric(player,s,"first_upgrade")
			local _,h=rootOf(player); if h then h.WalkSpeed=speed(s) end
			economy(player,s,"sink",Config.Upgrades[payload].costs[s.profile.upgrades[payload]],"upgrade_"..payload)
		end
		feedback(player,if ok then "Upgrade" else "Hint",message); send(player,s)
	elseif action=="Quest" and type(payload)=="string" and #payload<=40 then
		local before=s.profile.coins
		local ok,message=Profile.claim(s.profile,payload)
		if ok then Lifecycle.markDirty(s); economy(player,s,"source",s.profile.coins-before,"quest_"..payload) end
		feedback(player,if ok then "Quest" else "Hint",message); send(player,s)
	elseif action=="Settings" and type(payload)=="table" then
		local changed=false
		for _,key in ipairs({"reducedMotion","music","sfx","competition","showOnPodium","holdCatch","highContrast"}) do
			if type(payload[key])=="boolean" and payload[key]~=s.profile.settings[key] then s.profile.settings[key]=payload[key]; changed=true end
		end
		for _,key in ipairs({"musicVolume","sfxVolume"}) do
			local value=payload[key]
			if type(value)=="number" and value==value then
				value=math.clamp(math.floor(value*20+0.5)/20,0,1)
				if value~=s.profile.settings[key] then s.profile.settings[key]=value; changed=true end
			end
		end
		if type(payload.uiScale)=="number" then
			for _,allowed in ipairs(Profile.UiScales) do
				if math.abs(payload.uiScale-allowed)<1e-6 and s.profile.settings.uiScale~=allowed then s.profile.settings.uiScale=allowed; changed=true end
			end
		end
		if changed then Lifecycle.markDirty(s) end
		send(player,s)
	elseif action=="ClaimAll" then
		-- Claim-on-results: every completed quest and goal in one validated request.
		local count,total=0,0
		for _,quest in ipairs(Config.Quests) do
			if not s.profile.quests[quest.id] and Profile.questProgress(s.profile,quest)>=quest.target then
				local before=s.profile.coins
				if Profile.claim(s.profile,quest.id) then
					count+=1; total+=s.profile.coins-before
					economy(player,s,"source",s.profile.coins-before,"quest_"..quest.id)
				end
			end
		end
		for _,id in ipairs(Progression.claimable(s.profile)) do
			local ok,_,glow=Progression.claimGoal(s.profile,id)
			if ok then count+=1; total+=glow; economy(player,s,"source",glow,"goal_"..id) end
		end
		if count>0 then
			Lifecycle.markDirty(s)
			feedback(player,"Quest",string.format("CLAIMED %d reward%s • +%d glow",count,if count==1 then "" else "s",total))
		end
		send(player,s)
	elseif action=="Goal" and type(payload)=="string" and #payload<=24 then
		local ok,message,glow=Progression.claimGoal(s.profile,payload)
		if ok then Lifecycle.markDirty(s); economy(player,s,"source",glow,"goal_"..payload) end
		feedback(player,if ok then "Quest" else "Hint",message); send(player,s)
	elseif action=="Style" and type(payload)=="table" and type(payload.category)=="string" and type(payload.id)=="string"
		and #payload.category<=12 and #payload.id<=24 then
		local ok,message,price=Cosmetics.equip(s.profile,payload.category,payload.id)
		if ok then
			-- Rank titles and achievement titles are exclusive: one tag text at a time.
			-- (equipping a rank title, or "No title", clears an achievement title too)
			if payload.category=="title" then s.profile.style.title="" end
			Lifecycle.markDirty(s); applyStyle(player,s)
			if price and price>0 then economy(player,s,"sink",price,"cosmetic_"..payload.id) end
		end
		feedback(player,if ok then "Upgrade" else "Hint",message); send(player,s)
	elseif action=="Reroll" and type(payload)=="string" and #payload<=24 then
		local ok,message=Progression.rerollGoal(s.profile,payload)
		if ok then Lifecycle.markDirty(s) end
		feedback(player,if ok then "Quest" else "Hint",message); send(player,s)
	elseif action=="Style" and type(payload)=="string" and #payload<=24 then
		local ok,message,price=Progression.style(s.profile,payload)
		if ok then
			Lifecycle.markDirty(s); applyStyle(player,s)
			if price and price>0 then economy(player,s,"sink",price,"style_"..payload) end
		end
		feedback(player,if ok then "Upgrade" else "Hint",message); send(player,s)
	elseif action=="Title" and type(payload)=="string" and #payload<=24 then
		local ok,message=Progression.setTitle(s.profile,payload)
		if ok then
			if payload~="" then s.profile.cosmetics.title="" end
			Lifecycle.markDirty(s); applyStyle(player,s)
		end
		feedback(player,if ok then "Quest" else "Hint",message); send(player,s)
	elseif action=="Loadout" and type(payload)=="table" then
		-- Between rounds only: a round's rules never change mid-round.
		if s.phase=="Playing" then feedback(player,"Hint","Change perks after this round"); return end
		local requested={}
		for index=1,math.min(#payload,3) do if type(payload[index])=="string" and #payload[index]<=16 then table.insert(requested,payload[index]) end end
		s.profile.loadout=Loadout.sanitize(requested,Progression.rank(s.profile.xp))
		if s.mode~="trial" then s.stats=statsFor(s) end; Lifecycle.markDirty(s)
		feedback(player,"Upgrade",#s.profile.loadout>0 and ("Perks set: "..#s.profile.loadout) or "Perks cleared"); send(player,s)
	elseif action=="Heat" and type(payload)=="number" and payload==payload and payload%1==0 and payload>=0 and payload<=Loadout.MaxHeat then
		if s.phase=="Playing" then feedback(player,"Hint","Change Heat after this round"); return end
		if payload>Loadout.heatUnlocked(s.profile.records) then feedback(player,"Hint","Earn Silver at the previous Heat first"); return end
		s.profile.heat=payload; if s.mode~="trial" then s.stats=statsFor(s) end; Lifecycle.markDirty(s)
		feedback(player,"Upgrade","Heat "..payload.." • "..Loadout.Heat[payload].name); send(player,s)
	elseif action=="Biome" and type(payload)=="number" and payload%1==0 and Config.Biomes[payload] then
		if s.phase=="Playing" then feedback(player,"Hint","Choose your next arena after this round"); return end
		if s.mode=="trial" then feedback(player,"Hint","Leave the Daily Stampede first"); return end
		if #s.carry>0 then feedback(player,"Hint","Bank your parade before travelling"); return end
		if s.profile.totalBanked < Config.Biomes[payload].unlock then feedback(player,"Hint","Bank more Sparks to unlock this arena"); return end
		clearPersonal(player,s)
		s.biome=payload; s.challengeBiome=payload; teleport(player,s); send(player,s)
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
	player.CharacterAdded:Connect(function(character)
		local function group(item) if item:IsA("BasePart") then item.CollisionGroup=PLAYER_GROUP end end
		for _,item in ipairs(character:GetDescendants()) do group(item) end
		character.DescendantAdded:Connect(group)
		task.wait(0.25)
		if sessions[player]==s and s.ready then
			if s.challenge then Challenge.miss(s.challenge,os.clock(),"respawn") end
			teleport(player,s)
		end
		if sessions[player]==s and s.profile then applyStyle(player,s) end
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
	applyStyle(player,s)
	if s.clientReady then startNow(player,s) end
end


finalize=function(player,s)
	clearStarters(player.UserId); clearTrial(player.UserId)
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
	for _,rally in ipairs(rallies) do ArenaRally.leave(rally,player.UserId) end
	-- Forget herding credit from this session so a quick rejoin cannot inherit it.
	for _,c in pairs(herd) do
		if c.spookedBy==player.UserId then c.spookedBy=nil; c.spookedAt=nil end
		if c.assistBy==player.UserId then c.assistBy=nil; c.assistAt=nil end
	end
	local s=sessions[player]; sessions[player]=nil
	if s then s.detached=true; clearPersonal(player,s); finalize(player,s) end
end)
Players.PlayerAdded:Connect(join)
for _,player in ipairs(Players:GetPlayers()) do task.spawn(join,player) end

local accumulator,networkAt=0,0
local goldenCycle,runKey,surplusNext={},{},{}
local podiumCycle={}
RunService.Heartbeat:Connect(function(dt)
	if lifecycle.closing then return end
	accumulator+=dt
	if accumulator<0.1 then return end
	local step=math.min(accumulator,0.25); accumulator=0
	local now=os.clock()
	for player,s in pairs(sessions) do
		if not s.ready then continue end
		if not Lifecycle.leaseValid(persistence:leaseDeadline(player.UserId),os.time()) then haltForLease(player,s,"acknowledged lease expired"); continue end
		-- Observe secured score before this tick's banking; missed historical splits stay absent.
		if scoredRound(s,now) and (s.fullRound or s.mode=="trial") then Challenge.checkpoint(s.challenge,now-s.started) end
		-- Settle expired rounds before movement/hazards: no post-deadline captures or penalties.
		settleRound(player,s,now)
		-- Intermission over: everyone in Results starts the next shared round together.
		if s.phase=="Results" and s.resultsUntil and now>=s.resultsUntil then
			if s.sitOut then s.phase="SitOut"; send(player,s)
			else beginRound(player,s,Cycle.fullRound(arenaClock())) end
		end
		if scoredRound(s,now) and s.mode~="trial" then
			local event=arenaEvent(s.biome)
			if s.eventPhase~=nil and s.eventPhase~=event.phase and s.profile.totalBanked>=3 then
				feedback(player,"Round",event.name.." • Read the herd's new rhythm")
			end
			s.eventPhase=event.phase
		end
		local root,humanoid=rootOf(player)
		if root and humanoid then
			local arena=world.arenas[s.biome]
			local accepted=validApproach(player,s)
			if not accepted then s.dashSweep=nil end
			if accepted and not s.active and s.startPos and roundPlaying(s,now) and (root.Position-s.startPos).Magnitude>10 then s.active=true end
			if accepted and roundPlaying(s,now) then
				dashSweep(player,s,root,now)
				updateStatics(player,s,root,now,step)
				updateTrial(player,s,now)
			elseif s.staticCount and s.staticCount>0 and not roundPlaying(s,now) then
				clearPersonal(player,s)
			end
			-- Shared 1.5s immunity: a static zap and a sweep can never stack in one moment.
			if accepted and roundPlaying(s,now) and now>=(s.hazardNext or 0) and now>=(s.zapImmuneUntil or 0) then
				local hazard=hazardFor(s,now)
				if hazard.active then
					local center=arena.origin+Vector3.new(hazard.x,0,hazard.z)
					local delta=root.Position-center
					if Vector3.new(delta.X,0,delta.Z).Magnitude<hazard.radius and math.abs(delta.Y)<5 then
						s.hazardNext=now+2.5
						hit(player,s,now,root.Position,"BUMP")
					end
				end
			end
			if accepted and roundPlaying(s,now) and (root.Position-arena.bank).Magnitude<10 then bank(player,s,false) end
		end
	end
	local centroids={}
	-- Herd centroids per arena; each Daily Stampede course herds around its own owner's Sparks.
	local function centroidKey(c) return if c.trialOwner then "t"..c.trialOwner else c.biome end
	for _,c in pairs(herd) do
		if c.starterOwner then continue end
		local key=centroidKey(c)
		local center=centroids[key] or {sum=Vector3.zero,count=0}
		center.sum+=c.position; center.count+=1; centroids[key]=center
	end
	local events,gates={},{}
	local clockNow=arenaClock()
	for biome=1,SHARED_ARENAS do
		events[biome]=arenaEvent(biome)
		gates[biome]=Encounters.gate(clockNow,biome)
		-- Shared encounters spawn only when someone is actively playing this arena.
		local present=0
		for _,s in pairs(sessions) do if s.ready and s.biome==biome and roundPlaying(s,now) then present+=1 end end
		-- Herd density scales with active players (+5 Sparks each beyond the
		-- first) so co-op never starves anyone. Surplus Sparks are temporary
		-- extras: they never respawn on catch and expire after 45s unless needed.
		-- Weekly Remix "Big Herd": +6 temporary Sparks per arena while anyone plays it.
		local bigHerd=currentRemix.extraSparks or 0
		if (present>1 or (present>0 and bigHerd>0)) and now>=(surplusNext[biome] or 0) then
			local alive=0
			for _,c in pairs(herd) do
				if c.biome==biome and not c.starterOwner and not c.runner and not c.golden and not c.scattered and not c.trialOwner then alive+=1 end
			end
			if alive<18+bigHerd+5*(present-1) then
				surplusNext[biome]=now+0.5
				local offset=Rules.herdSpawn(random:NextNumber(0,math.pi*2),random:NextNumber(12,40))
				local pool={}
				for _,candidate in ipairs(Config.Creatures) do
					if candidate.biome==biome or candidate.biome==Config.Biomes[biome].id then table.insert(pool,candidate) end
				end
				spawnCreature(biome,nil,nil,{def=pool[random:NextInteger(1,#pool)],extra=true,expiresAt=now+45,
					position=world.arenas[biome].origin+Vector3.new(offset.x,offset.y,offset.z)})
			end
		end
		local gold=Encounters.golden(clockNow,biome,present,currentRemix)
		if gold.spawn and present>0 and goldenCycle[biome]~=gold.cycle then
			goldenCycle[biome]=gold.cycle
			-- Earned randomness only: any of this arena's species may appear gilded,
			-- building a 12-species Gilded collection over many rounds.
			local pool={}
			for _,candidate in ipairs(Config.Creatures) do
				if candidate.biome==biome or candidate.biome==Config.Biomes[biome].id then table.insert(pool,candidate) end
			end
			for _=1,gold.count do
				local def=if #pool>0 then pool[random:NextInteger(1,#pool)] else species[Config.GoldenSpecies[biome]]
				local offset=Rules.herdSpawn(random:NextNumber(0,math.pi*2),random:NextNumber(14,36))
				spawnCreature(biome,nil,nil,{def=def,golden=true,extra=true,expiresAt=now+gold.expiresIn,
					position=world.arenas[biome].origin+Vector3.new(offset.x,offset.y,offset.z)})
			end
			for player,s in pairs(sessions) do
				if s.ready and s.biome==biome and roundPlaying(s,now) then
					feedback(player,"Event",if gold.count>1 then "GOLDEN SPARKS! Catch one for +250 style" else "GOLDEN SPARK! Catch it for +250 style")
				end
			end
		end
		local fall=Encounters.starfall(clockNow,biome,nil,currentRemix)
		if fall.visible and present>0 then
			starfalls[biome]=starfalls[biome] or {}
			stepStarfall(starfalls[biome],fall,biome,nil,random,now,function(position,dazed)
				for player,s in pairs(sessions) do
					if s.ready and s.biome==biome and roundPlaying(s,now) then
						feedback(player,"Starfall",if dazed>0 then string.format("STARFALL! %d Spark%s dazed • STARSTRUCK +30",dazed,if dazed==1 then "" else "s") else "STARFALL!",nil,position,{dazed=dazed})
					end
				end
			end)
		end
		local run=Encounters.stampede(clockNow,biome,currentRemix)
		if run.active and present>0 then
			local key=run.cycle..":"..run.run
			if runKey[biome]~=key then
				runKey[biome]=key
				local origin=world.arenas[biome].origin
				local from=origin+Vector3.new(run.from.x,2.2,run.from.z)
				local to=origin+Vector3.new(run.to.x,2.2,run.to.z)
				local direction=(to-from).Unit
				local side=Vector3.new(-direction.Z,0,direction.X)
				local speedRun=Encounters.runSpeed()
				for n=1,Encounters.RunCount do
					local lag=(n-1)*2.2
					local position=from-direction*lag+side*((n%3)-1)*2.4
					spawnCreature(biome,nil,nil,{def=species.ziptail,extra=true,position=position,
						runner={direction=direction,speed=speedRun,untilT=now+(to-from).Magnitude/speedRun+lag/speedRun+0.2}})
				end
				for player,s in pairs(sessions) do
					if s.ready and s.biome==biome and roundPlaying(s,now) then feedback(player,"Event","STAMPEDE RUN! Dash through the lane") end
				end
			end
		end
	end
	-- Shared buzzer passed: build each arena's positive podium from this cycle's rounds.
	local cycleNow=Cycle.at(clockNow)
	if cycleNow.index~=remixCycle and cycleNow.phase=="Intermission" or remixCycle<0 then
		-- The remix may change only in an intermission (Monday 00:00 UTC rollover).
		remixCycle=cycleNow.index; currentRemix=Remix.current(os.time())
	end
	if cycleNow.phase=="Intermission" then
		for biome=1,SHARED_ARENAS do
			if podiumCycle[biome]~=cycleNow.index then
				local entries={}
				for _,s in pairs(sessions) do
					if s.lastSummary and s.lastSummary.cycle==cycleNow.index and s.lastSummary.biome==biome then table.insert(entries,s.lastSummary) end
				end
				if #entries>0 then
					podiumCycle[biome]=cycleNow.index
					podiums[biome]={cycle=cycleNow.index,awards=Cycle.awards(entries)}
					for player,s in pairs(sessions) do
						if s.ready and s.biome==biome and (s.phase=="Results" or s.phase=="SitOut") then send(player,s) end
					end
				end
			end
		end
	end
	local gateCatches={}
	local trialGates={}
	for player,s in pairs(sessions) do
		if s.ready and s.mode=="trial" then trialGates[player.UserId]=trialGate(s,now) end
	end
	for id,c in pairs(herd) do
		local arena=world.arenas[c.biome]
		-- Encounter extras leave cleanly: runners at lane end, goldens at cycle end.
		if (c.expiresAt and now>c.expiresAt) or (c.runner and now>c.runner.untilT) then
			c.claimed=true; c.model:Destroy(); herd[id]=nil
			continue
		end
		if c.runner then
			c.position+=c.runner.direction*c.runner.speed*step
			local bob=Vector3.new(c.position.X,2.2+math.abs(math.sin((now+c.seed)*9))*0.6,c.position.Z)
			c.renderPosition=bob
			continue
		end
		-- Starfall daze: the Spark stops and spins (client pose from the HerdNet flag).
		if c.dazedUntil and now<c.dazedUntil then c.fleeing=false; continue end
		local time=now+c.seed
		local direction=Vector3.new(math.cos(c.heading),0,math.sin(c.heading))
		local nearest,dist,nearestId=nil,26,nil
		local event=events[c.biome] or TRIAL_EVENT
		local eventScale=if c.beginner then .55 else event.speedScale
		local turnScale=if c.beginner then 1 else event.turnScale
		if c.golden then eventScale*=1.35 end
		for player,s in pairs(sessions) do
			if s.ready and s.phase=="Playing" and s.biome==c.biome and (not c.starterOwner or c.starterOwner==player.UserId)
				and (not c.trialOwner or c.trialOwner==player.UserId) then
				local root=rootOf(player)
				if root and Rules.validPosition(xyz(root.Position)) then
					local d=(root.Position-c.position).Magnitude
					if d<dist then nearest=root.Position; dist=d; nearestId=player.UserId end
				end
			end
		end
		local center=centroids[centroidKey(c)]
		if c.def.behavior=="herd" and center then
			local toHerd=center.sum/center.count-c.position; toHerd=Vector3.new(toHerd.X,0,toHerd.Z)
			if toHerd.Magnitude>7 then direction=direction:Lerp(toHerd.Unit,math.min(1,step*1.5)) end
		elseif c.def.behavior=="wander" then
			c.heading+=math.sin(time*.55)*step*.9*turnScale
			direction=Vector3.new(math.cos(c.heading),0,math.sin(c.heading))
			eventScale*=.75+.15*math.sin(time*.8)
		end
		local awareness=if c.golden then 26 elseif c.def.behavior=="wander" then 8 elseif c.def.behavior=="herd" then 15 else 26
		-- Gate herding: a Spark spooked into fleeing remembers who pushed it (4s).
		-- Wander/herd types spook within 14 studs for herding even if they barely flee.
		if nearestId and dist<math.max(awareness,14) and (not c.starterOwner or c.trialOwner) then
			if c.spookedBy~=nearestId then c.assistBy=c.spookedBy; c.assistAt=c.spookedAt end
			c.spookedBy=nearestId; c.spookedAt=now
		end
		local fleeing=nearest~=nil and dist>0.1 and dist<awareness
		if fleeing and not c.fleeing then c.startledUntil=now+0.6 end
		c.fleeing=fleeing
		if nearest and dist>0.1 and dist<awareness then
			local away=Vector3.new(c.position.X-nearest.X,0,c.position.Z-nearest.Z)
			if away.Magnitude>0.1 then
				local flee=away.Unit
				if c.def.behavior=="zigzag" then flee=(flee+Vector3.new(math.sin(time*3*turnScale)*0.6,0,math.cos(time*3*turnScale)*0.6)).Unit end
				direction=direction:Lerp(flee,math.min(1,step*3))
			end
		else c.heading+=math.sin(time*0.6)*step*0.7*turnScale end
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
		-- Per-arena obstacles (World/Encounters.Obstacles): steer early, keep a 2.5-stud body margin.
		for _,o in ipairs(arena.obstacles) do
			local away=Vector3.new(c.position.X-(arena.origin.X+o.x),0,c.position.Z-(arena.origin.Z+o.z))
			local steer=o.r+5.5
			if away.Magnitude<steer and away.Magnitude>.01 then direction=direction+away.Unit*(steer-away.Magnitude) end
		end
		if direction.Magnitude<0.01 then direction=Vector3.new(0,0,1) else direction=direction.Unit end
		c.heading=math.atan2(direction.Z,direction.X)
		local pace=c.def.speed*eventScale
		c.position+=direction*pace*step
		if c.beginner then
			local fromHome=Vector3.new(c.position.X-c.home.X,0,c.position.Z-c.home.Z)
			if fromHome.Magnitude>.75 then c.position=c.home+fromHome.Unit*.75 end
		end
		for _,o in ipairs(arena.obstacles) do
			local obstacleAt=arena.origin+Vector3.new(o.x,0,o.z)
			local away=Vector3.new(c.position.X-obstacleAt.X,0,c.position.Z-obstacleAt.Z)
			local margin=o.r+2.5
			if away.Magnitude<margin then
				local push=if away.Magnitude>.01 then away.Unit else Vector3.new(1,0,0)
				c.position=obstacleAt+push*margin
			end
		end
		if not c.starterOwner then
			local safe=Rules.outsideBank(xyz(c.position),xyz(arena.bank))
			c.position=Vector3.new(safe.x,safe.y,safe.z)
		end
		c.position=Vector3.new(c.position.X,2.2+math.sin(time*4)*0.35,c.position.Z)
		-- Models are no longer moved on the server: HerdNet carries the pose.
		local gate=if c.trialOwner then trialGates[c.trialOwner] else gates[c.biome]
		if gate and gate.active and (not c.starterOwner or c.trialOwner) and not c.golden and not c.claimed and c.spookedBy and now-c.spookedAt<=4 then
			local gateCenter=arena.origin+Vector3.new(gate.x,0,gate.z)
			if Vector3.new(c.position.X-gateCenter.X,0,c.position.Z-gateCenter.Z).Magnitude<=gate.radius then
				table.insert(gateCatches,c)
			end
		end
	end
	-- First-encounter coaching (D18): one line the first time each thing happens,
	-- persisted in the profile so returning players are never lectured again.
	for player,s in pairs(sessions) do
		if s.ready and roundPlaying(s,now) and s.profile.totalBanked>=3 and s.mode~="trial" then
			local gate=gates[s.biome]
			local run=Encounters.stampede(clockNow,s.biome,currentRemix)
			if gate.visible then hintOnce(player,s,"gate","SPARK GATE! Chase Sparks so they flee THROUGH the glowing ring") end
			if run.visible then hintOnce(player,s,"stampede","STAMPEDE RUN! Stand by the lane and DASH through the fast herd") end
			if Encounters.starfall(clockNow,s.biome,nil,currentRemix).visible then hintOnce(player,s,"starfall","AURORA STARFALL! Stars daze Sparks in the glowing circle • catch dazed Sparks for STARSTRUCK") end
			if goldenCycle[s.biome]==Cycle.at(clockNow).index and Cycle.at(clockNow).finale then
				hintOnce(player,s,"golden","GOLDEN SPARK! It's fast and worth triple glow • catch it before the buzzer")
			end
			if scoredRound(s,now) and s.endsAt-now<=15 and s.challenge and s.challenge.pendingBonus>0 then
				hintOnce(player,s,"buzzer","15 SECONDS! Bank before the buzzer or your style bonus is lost")
			end
			local hazard=hazardFor(s,now)
			if hazard.visible then hintOnce(player,s,"sweep","SWEEP INCOMING! Step out of the orange circle • hits scatter your parade") end
			if s.challenge and s.challenge.chain>=2 then hintOnce(player,s,"chain","CHAIN! Keep catching within "..math.floor(stats(s).chainSeconds).."s to build x2, x3, x4") end
		end
	end
	-- Broadcast one snapshot per arena to the players currently in it (10 Hz).
	local packets={}
	for biome,arena in ipairs(world.arenas) do
		local entries={}
		for _,c in pairs(herd) do
			if c.biome==biome and not c.claimed then
				local flags=0
				if c.fleeing then flags+=HerdNet.Flags.fleeing end
				if c.dazedUntil and now<c.dazedUntil then flags+=HerdNet.Flags.dazed end
				if c.golden then flags+=HerdNet.Flags.golden end
				if c.runner then flags+=HerdNet.Flags.runner end
				if c.startledUntil and now<c.startledUntil then flags+=HerdNet.Flags.startled end
				if c.trialOwner then flags+=HerdNet.Flags.trial end
				table.insert(entries,{id=c.id,x=c.position.X-arena.origin.X,z=c.position.Z-arena.origin.Z,heading=c.heading or 0,flags=flags})
			end
		end
		packets[biome]=HerdNet.pack(biome,now-arenaEpoch,entries)
	end
	for player,s in pairs(sessions) do
		local list=s.ready and packets[s.herdArena or s.biome]
		if list and player.Parent==Players then
			for _,packet in ipairs(list) do HerdFeed:FireClient(player,packet) end
		end
	end
	-- Resolve gate herding after movement so herd iteration never mutates mid-step.
	for _,c in ipairs(gateCatches) do
		local herder,hs=sessionFor(c.spookedBy)
		if herder and not c.claimed and hs.ready and hs.challenge and hs.biome==c.biome and roundPlaying(hs,now)
			and hs.started and c.spookedAt>=hs.started
			and #hs.carry<capacity(hs) and Lifecycle.leaseValid(persistence:leaseDeadline(herder.UserId),os.time()) then
			claim(herder,hs,c,"herd",{distance=0,facing=1},nil)
			send(herder,hs)
		end
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
-- Leaderboard refresh: bounded to one read per board every 120s, names cached.
local nameCache={}
local function nameOf(userId)
	if nameCache[userId] then return nameCache[userId] end
	local ok,name=pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
	nameCache[userId]=if ok and type(name)=="string" then name else "Player"
	return nameCache[userId]
end
-- Daily Stampede board (D16): every arena's records board shows today's top 5.
-- One sorted read per refresh: every 120 s, or 15 s after an improved submit.
task.spawn(function()
	task.wait(5)
	local lastRefresh=-math.huge
	while not lifecycle.closing do
		local day=Trial.day(os.time())
		if dailyDirty or os.clock()-lastRefresh>=120 or leaderboard.daily.day~=day then
			dailyDirty=false; lastRefresh=os.clock()
			local rows=leaderboard.refreshDaily(day,nameOf)
			for index=1,#world.arenas do
				World.setRecords(world.arenas[index].records,rows,nil,"DAILY STAMPEDE • TODAY'S TOP 5")
			end
		end
		task.wait(15)
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
print("[Spark] Staged build booted; 3 arenas + Trial Grounds, 54 moving Sparks; publishing remains unauthorized")
