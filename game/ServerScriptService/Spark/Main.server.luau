-- Spark Stampede authoritative session orchestrator. Activate only after G0.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Shared = ReplicatedStorage:WaitForChild("Spark")
local Config = require(Shared.Config)
local Profile = require(Shared.Profile)
local Rules = require(Shared.Rules)
local Challenge = require(Shared.Challenge)
local Loop = require(Shared.Loop)
local GroundMap = require(Shared.GroundMap)
local ArenaRally = require(Shared.ArenaRally)
local ArenaEvents = require(Shared.ArenaEvents)
local Loadout = require(Shared.Loadout)
local Encounters = require(Shared.Encounters)
local Progression = require(Shared.Progression)
local Cycle = require(Shared.Cycle)
local HerdNet = require(Shared.HerdNet)
local Herd = require(Shared.Herd)
local DesignEvents = require(Shared.Design.Events)
local Cosmetics = require(Shared.Cosmetics)
local Trial = require(Shared.Trial)
local Remix = require(Shared.Remix)
local Design = Shared:WaitForChild("Design")
local DesignTuning = require(Design.Tuning)
local Slice = require(Design.Slice)
local DesignCreatures = require(Design.Creatures)
local DesignArenas = require(Design.Arenas)
local LoopService = require(script.Parent.LoopService)
local Habitat = require(script.Parent.Habitat)
local LOOP_T = Loop.tuning(DesignTuning)
local loops = LoopService.new(Loop, LOOP_T, {rate = DesignTuning.ribbon.claimRateLimitPerSecond})
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
if RunService:IsStudio() then
	-- WP-05 evidence: compare GroundMap with real raycasts once, after Terrain settles.
	task.delay(3,function()
		for _,entry in ipairs(world.arenas) do
			if entry.dataDriven then pcall(World.verifyGround,entry,workspace:FindFirstChildOfClass("Terrain")) end
		end
	end)
end
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
-- BEGIN DASH BUCKET (server charge accounting for the client-predicted dash; WP-03)
local DashBucket={}
function DashBucket.new(charges,recharge) return {charges=charges,max=charges,recharge=recharge,nextAt=nil} end
function DashBucket.refill(b,now)
	while b.charges<b.max and b.nextAt and now>=b.nextAt do
		b.charges+=1; b.nextAt=if b.charges<b.max then b.nextAt+b.recharge else nil
	end
end
-- Small slack (0.15 s) so latency jitter never refuses an honest client's charge.
function DashBucket.take(b,now)
	DashBucket.refill(b,now+0.15)
	if b.charges<=0 then return false end
	b.charges-=1
	if not b.nextAt then b.nextAt=now+b.recharge end
	return true
end
-- END DASH BUCKET
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
-- Stampede Run species: the arena's own bolting ("flee") Spark, so a Remix run in
-- Meadow or Aurora never hands out another arena's species early (canyon: Zip Tail).
local runnerSpecies={}
for index,biome in ipairs(Config.Biomes) do
	for _,def in ipairs(Config.Creatures) do
		if (def.biome==index or def.biome==biome.id) and def.behavior=="flee" and not runnerSpecies[index] then runnerSpecies[index]=def end
	end
end
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
-- Checkpoint 1 slice (Design.Slice): upgrades, perks, Heat and the weekly remix are
-- off, so the feel under test is identical for everyone: fixed tuning values.
local SLICE_FIXED=not Slice.on("upgrades")
local function statsFor(s)
	if SLICE_FIXED then
		local st=Loadout.stats({},{},0)
		st.capacity=DesignTuning.parade.capacity
		st.medals=DesignTuning.scoring.medalsProvisional
		return st
	end
	return Remix.apply(Loadout.stats(s.profile.upgrades,s.profile.loadout,s.profile.heat),currentRemix)
end
local function stats(s)
	if not s.stats then s.stats=statsFor(s) end
	return s.stats
end
local function capacity(s) return stats(s).capacity end
local function speed(s) return s.walkOverride or DesignTuning.movement.walkSpeed end
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
		if c.starterOwner==userId then c.gone=true; c.claimed=true; herd[id]=nil end
	end
	for owner,s in pairs(sessions) do if owner.UserId==userId then s.starterRemaining=0 end end
end
local function clearTrial(userId)
	for id,c in pairs(herd) do
		if c.trialOwner==userId then c.claimed=true; c.gone=true; herd[id]=nil end
	end
end
local issueStarters,spawnCreature,stepHerd,broadcastHerd,stepEvents
local bloomSets={} -- [biome] = set of Bloom Burst creature ids this cycle (FULL BLOOM +40)
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
	-- Sweeps are cut (events.json "cut"); the slice never shows them.
	if not Slice.on("sweeps") then return {visible=false,active=false} end
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
-- State budget (plan §6.14: <= 2 KB per tick). While a round runs, the client needs
-- only these mastery fields; the full snapshot (splits, counters) goes at results.
local LEAN_MASTERY={"score","pending","chain","multiplier","chainSeconds","chainWindow","medal","precision","dashCatches",
	"bestLoop","loops","links",
	"multiCatches","herded","assists","pops","golden","bestChain","bestHaul","buzzerLost"}
local function leanMastery(m)
	local out={}
	for _,key in ipairs(LEAN_MASTERY) do out[key]=m[key] end
	local goal=m.challenge
	if goal then out.challenge={id=goal.id,name=goal.name,target=goal.target,progress=goal.progress,complete=goal.complete} end
	if m.personalBest and m.personalBest.delta then out.personalBest={delta=m.personalBest.delta,checkpoint=m.personalBest.checkpoint} end
	return out
end
-- Rarely-changing blocks travel only when they change (or every 10 s to self-heal).
local function changed(s,key,fingerprint,now)
	s.sentKeys=s.sentKeys or {}
	local entry=s.sentKeys[key]
	if entry and entry.print==fingerprint and now-entry.at<10 then return false end
	s.sentKeys[key]={print=fingerprint,at=now}
	return true
end
-- Round beat speed scale (events.json roundBeats) at a shared-cycle time.
local function beatAt(clock)
	local c=Cycle.at(clock)
	local beat=DesignEvents.roundBeats[1]
	if c.phase=="Play" then
		for _,b in ipairs(DesignEvents.roundBeats) do if c.t>=b.start then beat=b end end
	end
	return beat,c
end
local STARTER_HOME={x=-12,z=48} -- private starter trio home (south lawn)
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
	local clockNow=arenaClock()
	local gate,run
	if trialMode then
		gate=trialGate(s,now); run=trialRun(s,now)
	else
		-- Spark Gate and the legacy Stampede Run lane are cut (WP-08 adds Bloom Burst and
		-- the route Stampede); nothing legacy is drawn in the slice.
		gate={visible=false}; run={visible=false}
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
	local trialState=trialInfo(s,dailyChanged)
	local trialPrint=table.concat({tostring(trialState.available),tostring(trialState.reason),trialState.day,trialState.best,
		trialState.runsToday,tostring(trialState.rewardedToday),tostring(trialState.active),tostring(dailyChanged)},"|")
	local remixPrint=currentRemix.id..":"..math.floor(Remix.endsIn(os.time())/3600)
	local statsPrint=tostring(st)
	local boardsChanged=s.boardsSent~=leaderboard.version
	State:FireClient(player,{
		phase=s.phase,remaining=if s.endsAt and roundPlaying(s,now) then math.max(0,math.ceil(s.endsAt-now)) else 0,
		cycle=if trialMode then nil else (function() local c=Cycle.at(clockNow); return {index=c.index,t=c.t,phase=c.phase} end)(),
		fullRound=s.fullRound==true,sitOut=s.sitOut==true,
		mode=if trialMode then "trial" else "cycle",
		trial=if changed(s,"trial",trialPrint,now) or trialState.board then trialState else nil,
		nextRoundIn=if s.phase=="Results" and s.resultsUntil then math.max(0,math.ceil(s.resultsUntil-now)) else nil,
		podium=if (s.phase=="Results" or s.phase=="SitOut") and podiums[s.biome] and podiums[s.biome].cycle==s.settledCycle then podiums[s.biome].awards else nil,
		biome=s.biome,carry=#s.carry,capacity=capacity(s),score=s.score,
		profile=if includeProfile then s.profile else nil,profileRevision=s.revision,
		saveStatus=s.saveStatus,event=event.name,objective=objective(s),
		encounter=if trialMode then trialDescribe(s,now) else Encounters.describe(clockNow,s.biome),gate=gate,stampede=run,goldens=goldens,
		starfall=if not scoredRound(s,now) and s.phase~="Warmup" then nil
			elseif trialMode then starfallDescriptor(s.trial and s.trial.starfall,now,TRIAL_ARENA)
			else starfallDescriptor(starfalls[s.biome],now,s.biome),
		stats=if changed(s,"stats",statsPrint,now) then {captureRadius=st.captureRadius,capacity=st.capacity,chainSeconds=st.chainSeconds,heat=st.heat,
			scoreMultiplier=st.scoreMultiplier,perks=st.perks,goldenCompass=st.goldenCompass,maxMultiplier=st.maxMultiplier,
			staticCap=st.staticCap} else nil,
		rank=Progression.rankProgress(s.profile.xp),heatUnlocked=Loadout.heatUnlocked(s.profile.records),
		perkSlots=Loadout.slots(Progression.rank(s.profile.xp)),lastResult=s.lastResult,
		finale=scoredRound(s,now) and s.endsAt-now<=Cycle.FinaleSeconds,
		statics=s.statics and s.staticCount or 0,
		boards=if boardsChanged then leaderboard.boards else nil,boardsVersion=leaderboard.version,
		mastery=if mastery and roundPlaying(s,now) then leanMastery(mastery) else mastery,personalBest=s.newPersonalBest or false,arenaBest=s.newArenaBest or false,ranking=ranking,
		startersRemaining=s.starterRemaining or 0,
		hazard=hazard,
		rally=if trialMode then nil else ArenaRally.snapshot(rallies[s.biome],now,player.UserId),
		remix=if changed(s,"remix",remixPrint,now) then Remix.describe(currentRemix,os.time()) else nil,
		bankPosition=world.arenas[s.biome].bank,ready=s.ready,
		dashCharges=(function() DashBucket.refill(s.dash,now); return s.dash.charges end)(),
		-- Slice HUD: round beat name (events.json), claim deviation p99 (F8), starter ghost ring.
		phaseName=if roundPlaying(s,now) then (beatAt(clockNow)).name else nil,
		claimP99=if s.loop then LoopService.p99(s.loop.deviations) else 0,
		starterCenter=if (s.starterRemaining or 0)>0 then STARTER_HOME else nil,
		dashNextIn=if s.dash.nextAt then math.max(0,s.dash.nextAt-now) else 0,
		captureCooldown=st.captureCooldown,dashCooldown=dashCooldown(s),
		cooldowns={capture=math.max(0,st.captureCooldown-(now-(s.buckets.capture or -math.huge))),
			dash=math.max(0,dashCooldown(s)-(now-(s.buckets.dash or -math.huge)))},
	})
	s.boardsSent=leaderboard.version
	s.dailySent=leaderboard.version
end
onRoundRecorded=function(player,s,summary,result)
	analytics.custom(player,"round_heat_"..(result.heat or 0),summary.score)
	analytics.custom(player,"remix_"..currentRemix.id,1)
	if (summary.signatures or 0)>0 then analytics.custom(player,"signature_catch",summary.signatures) end
	if result.rankAfter>result.rankBefore then analytics.progression(player,"Rank",result.rankAfter,"Rank "..result.rankAfter) end
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
local function teleport(player,s)
	local root,humanoid = rootOf(player)
	if root then
		local arena=world.arenas[s.biome]
		root.CFrame=CFrame.lookAt(arena.spawn,arena.spawnLook or arena.origin+Vector3.new(0,3,0))
		root.AssemblyLinearVelocity=Vector3.zero
		s.motion={position=xyz(root.Position),at=os.clock(),credit=10,blockedUntil=0}
		-- A server-authorised teleport is a path discontinuity: nothing before it can be claimed.
		if s.loop then LoopService.reset(loops,s.loop,os.clock()) end
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
	-- Data-driven arenas validate against their bounds ring (bounce caps reach ~22
	-- studs above a 7-stud hill); legacy arenas keep the 78-stud circle.
	local valid,reason=Rules.movement(s.motion,xyz(root.Position),now,{origin=xyz(arena.origin),radius=78,
		bounds=arena.bounds,boundsMargin=4,
		minY=arena.origin.Y-4,maxY=arena.origin.Y+(arena.maxYOffset or 24),speed=speed(s)+2,burst=10,
		dashPeak=DesignTuning.dash.serverBudgetPeakSpeed*math.max(1,s.dashScale or 1)})
	s.suspiciousUntil=s.motion.blockedUntil or 0
	if not valid and s.mode=="trial" and s.trial then s.trial.rejections+=1 end
	if not valid and s.exploit then s.exploit.movement+=1 end
	if not valid then
		if s.challenge then Challenge.miss(s.challenge,now,"recovery") end
		if reason=="Arena bounds" or (reason=="Height bounds" and root.Position.Y<arena.origin.Y-4) then
			-- A last valid point below the floor would trap a fallen player forever.
			-- Rescue to the authored spawn, retaining the action quarantine.
			teleport(player,s)
			s.motion.blockedUntil=now+1.5; s.suspiciousUntil=now+1.5
		else
			local safe=s.motion.position
			root.CFrame=CFrame.new(safe.x,safe.y,safe.z)
			root.AssemblyLinearVelocity=Vector3.zero
		end
	end
	return valid and now>=s.suspiciousUntil
end
-- Banking (WP-04): run through a bank ring (LoopService.crossesRing on the server
-- path) or the buzzer auto-bank. Bank points = carried base values x the bank
-- tier (x1.0 at the buzzer), added to the round score; glow and album still
-- accrue through Profile.bank (profile stays v3 in the slice).
local function bank(player,s,automatic)
	if not s.ready or #s.carry==0 then return end
	local now=os.clock()
	if not automatic and not roundPlaying(s,now) then return end
	-- Clear ownership before any callback; no yields in reward transaction.
	local catches=s.carry; s.carry={}
	parade(player,s)
	local values={}
	for _,entry in ipairs(catches) do
		local id=if string.sub(entry,1,1)=="*" then string.sub(entry,2) else entry
		local def=species[id]
		table.insert(values,if def then def.value else 0)
	end
	local warm=s.phase=="Warmup"
	local finale=not automatic and not warm and s.endsAt~=nil and s.endsAt-now<=Cycle.FinaleSeconds
	local points,mult=0,1
	if s.challenge and not warm then
		points,mult=Challenge.bank(s.challenge,now,{values=values,automatic=automatic,finale=finale})
	end
	local ring=s.bankRing; s.bankRing=nil
	local ringPosition=world.arenas[s.biome].bank
	for _,r in ipairs(world.arenas[s.biome].bankRings or {}) do if r.id==ring then ringPosition=r.position end end
	if s.mode=="trial" then
		if not automatic then s.active=true end
		feedback(player,"Bank",string.format("+%d banked",points),nil,nil,
			{count=#catches,skill=points,glow=0,newSpecies=0,trial=true,position=ringPosition,ring=ring,multiplier=mult})
		send(player,s)
		return
	end
	local reward,newSpecies=Profile.bank(s.profile,catches)
	if s.profile.totalBanked>=3 then clearStarters(player.UserId) end
	s.score+=reward
	if not automatic then s.active=true end
	metric(player,s,"first_bank")
	economy(player,s,"source",reward,"bank")
	feedback(player,"Bank",if warm then string.format("+%d glow banked%s • warm-up",reward,if newSpecies>0 then " • NEW SPARK!" else "")
		else string.format("+%d • x%s bank%s",points,tostring(mult),if newSpecies>0 then " • NEW SPARK!" else ""),nil,ringPosition,
		{count=#catches,skill=points,points=points,glow=reward,newSpecies=newSpecies,position=ringPosition,ring=ring,multiplier=mult,
			automatic=automatic==true})
	Lifecycle.markDirty(s)
	if not automatic and #catches>0 then
		-- Everyone in the arena sees this player's Bank Burst celebration.
		local burst=Cosmetics.resolve("burst",s.profile.cosmetics.burst).id
		for other,session in pairs(sessions) do
			if session.ready and session.biome==s.biome and other.Parent==Players then
				Feedback:FireClient(other,{kind="BankBurst",position=ringPosition,extra={burst=burst,userId=player.UserId,count=#catches}})
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
		metric(player,s,"first_round_complete")
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
	local warm=plan.mode=="warmup"
	-- Frozen funnel step 6: the player's second scored round begins.
	if not warm and s.profile.rounds>=1 then metric(player,s,"second_round_start") end
	s.phase=if warm then "Warmup" else "Playing"
	s.started=now; s.endsAt=arenaEpoch+plan.endsAt; s.fullRound=plan.full==true; s.cycleIndex=plan.cycle
	s.carry={}; s.score=0; s.buckets={}; s.roundCatches=0; s.active=false
	s.roundsAtStart=s.profile.rounds
	s.loop=s.loop or LoopService.session(); LoopService.reset(loops,s.loop,now)
	s.lastDashAt=nil; s.bestLoopSize=0; s.lastLoopSize=0; s.bloomIds=nil
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
			if spark then spark.trialSlot=k end
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
	-- Score bucket (500s) keeps the event cheap and comparable across days.
	analytics.custom(player,"trial_run",math.floor(score/500)*500)
	if rankAfter>rankBefore then analytics.progression(player,"Rank",rankAfter,"Rank "..rankAfter) end
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
				spawnTrialSpark(player,s,runnerSpecies[tr.plan.biome] or species.ziptail,nil,{position=from-direction*lag+side*((n%3)-1)*2.4,seed=n,
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
-- Creatures are server DATA only (WP-06): no Instances. Clients build models
-- from HerdNet v2 packets (CreatureKit). Data-driven arenas spawn pods through
-- Habitat; Herd steps each species' state machine at the 10 Hz heartbeat.
local herdCtx={} -- [biome]={habitat,blockers,boundary,clampInside,def}
local function makeCreature(biome,def,x,z,extras)
	extras=extras or {}
	nextCreatureId+=1
	local arena=world.arenas[biome]
	local c={id=nextCreatureId,def=def,biome=biome,x=x,z=z,heading=extras.heading or random:NextNumber(0,math.pi*2),
		state=if def.behavior=="percher" then "perched" else "graze",stateAt=arenaClock(),height=0,catchable=true,speed=0,
		home=extras.home or {x=x,z=z,r=6},podId=extras.podId,flock=extras.flock,slot=extras.slot,perches=extras.perches,
		seed=random:NextNumber(0,20),claimed=false,history={},golden=extras.golden==true,extra=extras.extra==true,
		starter=extras.starterOwner~=nil,starterOwner=extras.starterOwner,expiresAt=extras.expiresAt,
		behavior=extras.behavior,feedUntil=extras.feedUntil,behaviorAfter=extras.behaviorAfter,
		route=extras.route,routeSpeed=extras.routeSpeed,lane=extras.lane,lag=extras.lag,event=extras.event}
	c.position=arena.origin+Vector3.new(x,GroundMap.height(arena.ground,x,z),z)
	herd[c.id]=c
	return c
end
-- Legacy entry point (trial, scatter) kept for compatibility: data-only creature.
spawnCreature=function(biome,_index,starterPlayer,options)
	options=options or {}
	local arena=world.arenas[biome]
	local def=DesignCreatures.byId[(options.def and options.def.id) or "pip"] or DesignCreatures.byId.pip
	local position=options.position or arena.origin
	local c=makeCreature(biome,def,position.X-arena.origin.X,position.Z-arena.origin.Z,{
		golden=options.golden,extra=true,expiresAt=options.expiresAt,starterOwner=starterPlayer and starterPlayer.UserId})
	c.trialOwner=options.trialOwner; c.trialPlan=options.trialPlan==true
	return c
end
-- Starter Pips (existing finite allowance): a private trio on the south lawn,
-- owner-only (other clients never receive them), tethered near home.
issueStarters=function(player,s)
	local allowance=Rules.issueStarters(s,s.profile.totalBanked)
	s.starterRemaining=allowance
	local def=DesignCreatures.byId.pip
	for index=1,allowance do
		local a=index*2.1
		makeCreature(s.biome,def,STARTER_HOME.x+math.cos(a)*2.2,STARTER_HOME.z+math.sin(a)*2.2,{starterOwner=player.UserId,
			home={x=STARTER_HOME.x,z=STARTER_HOME.z,r=3},podId="starter:"..player.UserId})
	end
end
for biome,arena in ipairs(world.arenas) do
	if arena.dataDriven and biome<=SHARED_ARENAS then
		local boundary,clampInside=Herd.boundsTools(arena.bounds)
		local ctx={def=arena.def,blockers=arena.obstacles,boundary=boundary,clampInside=clampInside,
			habitat=Habitat.new(arena.def,DesignCreatures,DesignTuning.density,biome*7919)}
		herdCtx[biome]=ctx
		Habitat.seed(ctx.habitat,arenaClock(),function(def,x,z,extras) return makeCreature(biome,def,x,z,extras) end)
	end
end

-- BEGIN CATCH TRANSACTIONS (extracted by tests/test_spark_gameplay_integration.py)
local function sessionFor(userId)
	for other,session in pairs(sessions) do if other.UserId==userId then return other,session end end
	return nil,nil
end
-- Atomic take for one creature inside a validated loop (WP-04). Ownership moves
-- before any effect or callback. Kept creatures join the parade; overflow ones
-- score at half value (Loop.scoreLoop) and are released (respawn as normal).
local function take(player,s,creature,kept)
	creature.claimed=true
	s.roundCatches=(s.roundCatches or 0)+1; s.active=true
	if creature.starterOwner then s.starterRemaining=math.max(0,(s.starterRemaining or 0)-1) end
	if kept then table.insert(s.carry,if creature.golden then "*"..creature.def.id else creature.def.id) end
	creature.gone=true
	herd[creature.id]=nil
	metric(player,s,"first_catch")
	-- Pod creatures respawn through Habitat once their whole pod is gone.
end
-- Recently caught creatures stay resolvable for 1 s so a second, simultaneous loop
-- over the same creature earns its owner an ASSIST instead of nothing.
local recentCatches={}
local function creditContest(otherPlayer,session,now,position)
	if not session.ready or not session.challenge or not scoredRound(session,now) then return end
	local ok,points=Challenge.award(session.challenge,now,"contest")
	if ok then feedback(otherPlayer,"Assist",string.format("ASSIST! +%d style • teamwork",points),nil,position,{tags={"ASSIST"},points=points}) end
end
-- Candidate creatures for a player's loop: same arena, unclaimed, owner rules.
local function loopCandidates(player,s)
	local list,byId={},{}
	for _,c in pairs(herd) do
		if c.history and #c.history>0 and not c.claimed then
			local allowed=Rules.canCapture({phase="Playing",ready=s.ready,carry=0,biome=s.biome,userId=player.UserId,
				totalBanked=s.profile.totalBanked,position={x=0,y=0,z=0},suspiciousUntil=0,mode=s.mode},
				{claimed=c.claimed,biome=c.biome,starterOwner=c.starterOwner,trialOwner=c.trialOwner,position={x=0,y=0,z=0}},
				os.clock(),1,1,"loop")
			if allowed then table.insert(list,{id=c.id,history=c.history}); byId[c.id]=c end
		end
	end
	return list,byId
end
-- A validated loop: resolve, claim atomically in pop order, score once.
local function handleLoop(player,s,claim,now,serverArea)
	local herdNow=arenaClock()
	local candidates,byId=loopCandidates(player,s)
	local caught,escaped=LoopService.resolve(loops,claim,candidates,herdNow)
	local origin=world.arenas[s.biome].origin
	local cx,cz=Loop.centroid(claim.poly)
	local centroid=origin+Vector3.new(cx,GroundMap.height(world.arenas[s.biome].ground,cx,cz)+3,cz)
	-- Contest: a creature another player caught in the last second, inside this ring.
	local contested=LoopService.contested(loops,recentCatches,claim,player.UserId,s.biome,now,herdNow)
	local room=math.max(0,capacity(s)-#s.carry)
	local catches,result,species,info={},{},{},{}
	for _,id in ipairs(caught) do
		local c=byId[id]
		if c and not c.claimed then
			table.insert(info,{creature=c,kept=#info<room})
			table.insert(catches,{captureId=c.id,value=c.def.value,signature=c.def.signature,species=c.def.id,
				golden=c.golden==true,dazed=c.dazedUntil~=nil and now<c.dazedUntil,starter=c.starterOwner~=nil})
			species[c.def.id]=true
		end
	end
	local speciesCount=0; for _ in pairs(species) do speciesCount+=1 end
	local soloTight=if #info==1 then (DesignCreatures.byId[info[1].creature.def.id] or {}).soloTightArea else nil
	local tight=#info>0 and Loop.isTight(#info,serverArea,LOOP_T,soloTight)
	local snap=LoopService.snap(loops,s.lastDashAt,claim)
	local finale=scoredRound(s,now) and s.endsAt-now<=Cycle.FinaleSeconds
	local bloomIds=bloomSets[s.biome]
	local style=if #info==8 and bloomIds and (function()
		for _,entry in ipairs(info) do if not bloomIds[entry.creature.id] then return false end end
		return true end)() then 40 else 0
	local ok
	ok,result=Challenge.loop(s.challenge,now,{catches=catches,snap=snap,tight=tight,pinch=false,
		speciesCount=speciesCount,finale=finale,carried=#s.carry,style=style})
	if not ok then
		s.exploit.loopRejected=(s.exploit.loopRejected or 0)+1
		feedback(player,"Loop","",nil,centroid,{id=claim.id,caught={},escaped={},points=0,techs={},overflow=0,rejected=true})
		return
	end
	local caughtOut={}
	for index,entry in ipairs(info) do
		local c=entry.creature
		recentCatches[c.id]={by=player.UserId,at=now,biome=c.biome,history=c.history}
		table.insert(caughtOut,{creatureId=c.id,species=c.def.id,golden=c.golden==true,kept=entry.kept})
		take(player,s,c,entry.kept)
		local hit=result.perCatch[index] and result.perCatch[index].signatureHit
		if hit and s.mode~="trial" then
			local star=Progression.recordSignature(s.profile,c.def.id)
			Lifecycle.markDirty(s)
			if star then
				feedback(player,"Quest",string.format("★ %s SIGNATURE STAR %d!",string.upper(c.def.name),star),c.def,centroid,{signatureStar=star})
			end
		end
	end
	if #info>0 then
		metric(player,s,"first_loop_catch")
		s.lastLoopSize=#info
		s.bestLoopSize=math.max(s.bestLoopSize or 0,#info)
	end
	-- Two loops over one creature: the first validated claim caught it; this
	-- (second) claimant ringed it too and earns an ASSIST instead of nothing.
	if contested then creditContest(player,s,now,centroid) end
	parade(player,s)
	if #info>0 and #info>=8 then
		for other,session in pairs(sessions) do
			if other~=player and session.ready and session.biome==s.biome then
				feedback(other,"Event",player.DisplayName.." netted a STAMPEDE! ("..#info..")")
			end
		end
	end
	local escapedSpecies={}
	for _,id in ipairs(escaped) do local c=byId[id]; if c then table.insert(escapedSpecies,c.def.id) end end
	feedback(player,"Loop","",nil,centroid,{id=claim.id,caught=caughtOut,escaped=escaped,escapedSpecies=escapedSpecies,wraps={},points=result.points,
		techs=result.techs,chain=result.links,multiplier=result.multiplier,overflow=result.overflow,size=#info,style=result.style})
	send(player,s)
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
	s.statics={}; s.staticCount=0; s.staticNext=0; s.staticSerial=s.staticSerial or 0
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
	if not Rules.allow(s.transport,bucket,os.clock(),if bucket=="request" then 0.08 else 0.25) then
		s.exploit.rateLimited+=1; return
	end
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
	elseif action=="Trial" and not DesignTuning.features.trialEnabled then
		-- Daily Stampede is off until WP-15 (its course and board assume capture scoring).
		feedback(player,"Hint","The Daily Stampede returns in a later build"); send(player,s)
	elseif (action=="Upgrade" and not Slice.on("upgrades")) or ((action=="Loadout" or action=="Heat") and not Slice.on("heat_and_perks"))
		or (action=="Biome" and not Slice.on("arena_travel") and payload~=1) then
		-- Checkpoint 1 slice: fixed tuning for everyone; Meadow only.
		feedback(player,"Hint","Not available in this test build"); send(player,s)
	elseif action=="Trial" and type(payload)=="string" and #payload<=8 then
		if payload=="start" or payload=="retry" then startTrial(player,s)
		elseif payload=="leave" then leaveTrial(player,s) end
	elseif action=="SitOut" and s.mode=="trial" then
		send(player,s)
	elseif action=="SitOut" then
		if not s.sitOut then analytics.custom(player,"sit_out",1) end
		s.sitOut=true
		if s.phase=="Warmup" then
			clearPersonal(player,s); if #s.carry>0 then bank(player,s,true) end
			s.phase="SitOut"
		end
		send(player,s)
	elseif action=="Capture" or action=="Bank" then
		-- Removed actions (WP-04): there is no catch button and banking is a
		-- run-through ring. Ignored, not counted as malformed (old clients).
	elseif action=="Loop" then
		local now=os.clock()
		if not roundPlaying(s,now) or now<(s.suspiciousUntil or 0) or not s.loop then
			s.exploit.loopRejected=(s.exploit.loopRejected or 0)+1; return
		end
		local claim,reason=LoopService.receive(loops,s.loop,payload,now,arenaClock())
		if not claim then
			if reason=="malformed" then s.exploit.malformed+=1 else s.exploit.loopRejected=(s.exploit.loopRejected or 0)+1 end
			return
		end
		s.active=true
		metric(player,s,"first_action")
	elseif action=="Tune" then
		-- F9 tuning panel: Studio only, session only, clamped to Tuning.Ranges.
		if not RunService:IsStudio() or type(payload)~="table" then s.exploit.malformed+=1; return end
		local R=DesignTuning.Ranges
		local function clamp(v,range) return if type(v)=="number" and v==v then math.clamp(v,range[1],range[2]) else nil end
		local lifetime,snap=clamp(payload.lifetime,R.ribbon.lifetime),clamp(payload.snapRadius,R.ribbon.snapRadius)
		if lifetime then LOOP_T.lifetime=lifetime end
		if snap then LOOP_T.snapRadius=snap end
		local walk=clamp(payload.walkSpeed,R.movement.walkSpeed)
		if walk then
			s.walkOverride=walk
			local _,humanoid=rootOf(player); if humanoid then humanoid.WalkSpeed=walk end
		end
		local dashDistance=clamp(payload.dashDistance,R.dash.distance)
		if dashDistance then s.dashScale=dashDistance/DesignTuning.dash.distance end
	elseif action=="Dash" and roundPlaying(s,os.clock()) then
		-- Client-predicted dash (WP-03): the client already moved its own character
		-- on the input frame. The server never moves it; it grants a movement budget
		-- window if its own charge bucket allows, and records the arrival time for
		-- SNAP. A refused dash simply gets no extra budget (Rules.movement rejects
		-- the surplus distance), and the true charge state goes back with send().
		s.active=true
		local root,humanoid=rootOf(player)
		local now=os.clock()
		if root and humanoid and humanoid.Health>0 and s.motion and DashBucket.take(s.dash,now) then
			s.motion.dashStarted=now; s.motion.dashUntil=now+DesignTuning.dash.duration+0.12
			s.lastDashAt=now
			-- Boop (01 section 3): creatures within boopRadius of the dash line are shoved
			-- sideways and startled (a Cubloom flock scatters for 3 s).
			local look=humanoid.MoveDirection
			if look.Magnitude<0.1 then look=root.CFrame.LookVector end
			local dir=Vector3.new(look.X,0,look.Z)
			if dir.Magnitude>0.01 and herdCtx[s.biome] then
				dir=dir.Unit
				local origin=world.arenas[s.biome].origin
				local ox,oz=root.Position.X-origin.X,root.Position.Z-origin.Z
				local reach,radius=DesignTuning.dash.distance+2,DesignTuning.dash.boopRadius
				for _,c in pairs(herd) do
					if c.biome==s.biome and not c.claimed and (not c.starterOwner or c.starterOwner==player.UserId) then
						local rx,rz=c.x-ox,c.z-oz
						local along=rx*dir.X+rz*dir.Z
						local side=rx*(-dir.Z)+rz*dir.X
						if along>-2 and along<reach and math.abs(side)<=radius then
							local sign=if side>=0 then 1 else -1
							Herd.boop(c,arenaClock(),-dir.Z*sign,dir.X*sign)
						end
					end
				end
			end
			metric(player,s,"first_action"); feedback(player,"Dash","WHOOSH!")
		else
			s.exploit.dashRefused=(s.exploit.dashRefused or 0)+1
			send(player,s)
		end
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
			if type(payload[key])=="boolean" and payload[key]~=s.profile.settings[key] then
				s.profile.settings[key]=payload[key]; changed=true
				if payload[key] and (key=="reducedMotion" or key=="holdCatch") then
					analytics.custom(player,if key=="reducedMotion" then "reduced_motion_on" else "hold_catch_on",1)
				end
			end
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
		if #s.profile.loadout>0 then metric(player,s,"first_perk_equipped") end
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
	elseif action~="Dash" then
		-- Unknown action or a known action with an invalid payload shape.
		s.exploit.malformed+=1
	end
end)

local finalize
local function join(player)
	local s={profile=nil,ready=false,clientReady=false,phase="Loading",carry={},biome=1,score=0,
		buckets={},transport={},metrics={},joined=os.clock(),saveStatus="Loading",suspiciousUntil=0,dirty=false,revision=0,persistedRevision=0,
		-- Exploit telemetry (plan §6.12): counted per session, reported once at leave.
		exploit={movement=0,rateLimited=0,malformed=0,dashRefused=0},
		dash=DashBucket.new(DesignTuning.dash.charges,DesignTuning.dash.rechargeSeconds),
		loop=LoopService.session()}
	if not Lifecycle.beginLoad(lifecycle,s) then
		player:Kick("This server is closing. Please rejoin.")
		return
	end
	sessions[player]=s
	-- SparkCamera drives a raised chase camera in rounds; Classic mode keeps 28..55.
	player.CameraMinZoomDistance=28; player.CameraMaxZoomDistance=55
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
	if s and s.exploit then
		-- One aggregated event per counter per session; never per violation.
		for name,count in pairs(s.exploit) do
			if count>0 then analytics.custom(player,"exploit_"..name,math.min(count,100000)) end
		end
	end
	if s then s.detached=true; clearPersonal(player,s); finalize(player,s) end
end)
Players.PlayerAdded:Connect(join)
for _,player in ipairs(Players:GetPlayers()) do task.spawn(join,player) end

local accumulator,networkAt=0,0
local herdTick=0
local CODES=Herd.CODES
local function playersIn(biome)
	local list={}
	for player,s in pairs(sessions) do
		if s.ready and s.biome==biome and (s.phase=="Playing" or s.phase=="Warmup") then
			local root=rootOf(player)
			if root and Rules.validPosition(xyz(root.Position)) then
				local origin=world.arenas[biome].origin
				table.insert(list,{x=root.Position.X-origin.X,z=root.Position.Z-origin.Z,id=player.UserId})
			end
		end
	end
	return list
end
local function removeCreature(c)
	c.claimed=true; c.gone=true
	herd[c.id]=nil
end
-- EVENTS (WP-08): Bloom Burst at 30 s and the route Stampede at 55 s on the
-- shared arena clock (events.json), for data-driven arenas with someone playing.
local eventState={} -- [biome] = {cycle, warned, opened, closed, stampedeWarned, horned, ran}
local EV_BLOOM=DesignEvents.byId.bloom_burst
local EV_STAMPEDE=DesignEvents.byId.stampede
local function arenaPlayers(biome)
	local list={}
	for player,s in pairs(sessions) do
		if s.ready and s.biome==biome and s.phase=="Playing" and player.Parent==Players then table.insert(list,player) end
	end
	return list
end
local function liveCount(biome)
	local n=0
	for _,c in pairs(herd) do if c.biome==biome and not c.claimed and not c.starterOwner then n+=1 end end
	return n
end
-- Pure-ish schedule for a cycle: which bud and which route (rotating per cycle).
local function eventPlan(biome,cycle)
	local def=world.arenas[biome].def
	local anchors,routes={},{}
	for _,a in ipairs(def.eventAnchors or {}) do if a.event=="bloom_burst" then table.insert(anchors,a) end end
	for _,r in ipairs(def.routes or {}) do if r.kind=="stampede" then table.insert(routes,r) end end
	local anchor=anchors[(cycle%math.max(1,#anchors))+1]
	return {bud=anchor and DesignArenas.feature(def,anchor.feature),
		route=routes[(cycle%math.max(1,#routes))+1]}
end
function stepEvents(herdNow)
	local c=Cycle.at(herdNow)
	for biome,ctx in pairs(herdCtx) do
		local players=arenaPlayers(biome)
		local st=eventState[biome]
		if not st or st.cycle~=c.index then
			st={cycle=c.index}; eventState[biome]=st
			bloomSets[biome]=nil
		end
		if #players==0 or c.phase~="Play" then continue end
		local plan=eventPlan(biome,c.index)
		local arena=world.arenas[biome]
		local model=arena.model and plan.bud and arena.model:FindFirstChild(plan.bud.id)
		local function tell(text,extra)
			extra.at=c.t -- shared-cycle time the event fired (evidence for T-E1)
			for _,player in ipairs(players) do feedback(player,"Event",text,nil,nil,extra) end
		end
		-- Bloom Burst: telegraph (swell + chime) from telegraphAt, opens at start.
		if plan.bud and Slice.on("bloom_burst") then
			local budAt=arena.origin+Vector3.new(plan.bud.x,GroundMap.height(arena.ground,plan.bud.x,plan.bud.z),plan.bud.z)
			if c.t>=EV_BLOOM.telegraphAt and not st.warned then
				st.warned=true
				if model then model:SetAttribute("Bloom","swell") end
				tell("BLOOM BURST! Get to the glowing bud",{event="bloom_burst",position=budAt,radius=7,
					seconds=EV_BLOOM.start-EV_BLOOM.telegraphAt})
			end
			if c.t>=EV_BLOOM.start and not st.opened then
				st.opened=true
				if model then model:SetAttribute("Bloom","open") end
				local room=math.max(0,DesignTuning.density.eventLiveCapPerArena-liveCount(biome))
				local cx,cz=plan.bud.x,plan.bud.z+6 -- the 7-stud feeding cluster at the bud's base
				local ids={}
				local spawnList={"pip","pip","pip","pip","pip","cubloom","cubloom","cubloom"}
				for i,id in ipairs(spawnList) do
					if i>room then break end
					local a=i*math.pi*2/#spawnList
					local def=DesignCreatures.byId[id]
					local cr=makeCreature(biome,def,cx+math.cos(a)*2.8,cz+math.sin(a)*2.8,{extra=true,event="bloom_burst",
						home={x=cx,z=cz,r=3.5},behavior="feeder",feedUntil=herdNow+6,
						behaviorAfter=Herd.species[if id=="cubloom" then "clump" else def.behavior],
						expiresAt=herdNow+EV_BLOOM.duration+8})
					ids[cr.id]=true
				end
				bloomSets[biome]=ids
				tell("The bud bursts open! Ring the whole cluster",{event="bloom_burst",open=true,position=budAt})
			end
			if c.t>=EV_BLOOM.start+EV_BLOOM.duration and not st.closed then
				st.closed=true
				if model then model:SetAttribute("Bloom","closed") end
			end
		end
		-- Stampede: route telegraph at telegraphAt, horn 2 s before, the herd charges at start.
		if plan.route and Slice.on("stampede") then
			if c.t>=EV_STAMPEDE.telegraphAt and not st.stampedeWarned then
				st.stampedeWarned=true
				tell("STAMPEDE incoming! Lay a ring across the glowing route",{event="stampede",route=plan.route.points,
					telegraph=true,seconds=EV_STAMPEDE.start-EV_STAMPEDE.telegraphAt,duration=EV_STAMPEDE.duration})
			end
			if c.t>=EV_STAMPEDE.start-2 and not st.horned then
				st.horned=true
				tell("",{event="stampede",horn=true})
			end
			if c.t>=EV_STAMPEDE.start and not st.ran then
				st.ran=true
				local want=math.min(18,12+2*#players)
				local n=math.min(want,math.max(0,DesignTuning.density.eventLiveCapPerArena-liveCount(biome)))
				local kinds={"pip","bunvolt","cubloom"}
				for i=1,n do
					local def=DesignCreatures.byId[kinds[(i-1)%#kinds+1]]
					local first=plan.route.points[1]
					makeCreature(biome,def,first[1],first[2],{extra=true,event="stampede",behavior="runner",
						route=plan.route.points,routeSpeed=26,lane=((i-1)%3-1)*2.5,lag=math.floor((i-1)/3)*2.5,
						expiresAt=herdNow+EV_STAMPEDE.duration+6})
				end
				tell("STAMPEDE!",{event="stampede",run=true})
			end
		end
	end
end
function stepHerd(step,herdNow,_now)
	herdTick+=1
	local beat=beatAt(herdNow)
	for biome,ctx in pairs(herdCtx) do
		local arena=world.arenas[biome]
		local players=playersIn(biome)
		Habitat.step(ctx.habitat,herdNow,players,function(def,x,z,extras) return makeCreature(biome,def,x,z,extras) end)
		local pods=table.clone(ctx.habitat.podMembers)
		local starterPods={}
		for _,c in pairs(herd) do
			if c.biome==biome and c.starterOwner then
				starterPods[c.podId]=starterPods[c.podId] or {}
				table.insert(starterPods[c.podId],c)
			end
		end
		for id,members in pairs(starterPods) do pods[id]=members end
		local shared={players=players,blockers=ctx.blockers,boundary=ctx.boundary,clampInside=ctx.clampInside,
			pods=pods,speedScale=beat.speedScale}
		local owners={}
		for _,p in ipairs(players) do
			owners[p.id]={players={p},blockers=ctx.blockers,boundary=ctx.boundary,clampInside=ctx.clampInside,pods=pods,speedScale=1}
		end
		local glow={}
		for _,c in pairs(herd) do
			if c.biome~=biome or c.claimed then continue end
			if (c.expiresAt and herdNow>c.expiresAt) or c.finished then removeCreature(c); continue end
			local cctx=shared
			if c.starterOwner then cctx=owners[c.starterOwner] or {players={},blockers=ctx.blockers,boundary=ctx.boundary,
				clampInside=ctx.clampInside,pods=pods,speedScale=1} end
			Herd.step(c,cctx,step,herdNow)
			local g=GroundMap.height(arena.ground,c.x,c.z)
			c.g=g
			c.position=arena.origin+Vector3.new(c.x,g+(c.height or 0),c.z)
			-- 0.5 s history at the snapshot ticks for lag-compensated loop resolution.
			LoopService.pushHistory(c.history,herdNow,c.x,c.z,g,c.catchable~=false)
			if c.glowPerch and c.perches then glow[c.perches[c.glowPerch].id]=true end
		end
		-- Flutterwink landing telegraph: the target perch glows 1.5 s early.
		if arena.model then
			for _,perch in ipairs(ctx.habitat.perches) do
				local model=arena.model:FindFirstChild(perch.id)
				if model and (model:GetAttribute("Glow")==true)~=(glow[perch.id]==true) then model:SetAttribute("Glow",glow[perch.id]==true) end
			end
		end
	end
end
-- HerdNet v2 broadcast: one packet list per player (shared creatures plus that
-- player's own private starters). Grazing creatures with nobody within 40 studs
-- go in every third packet.
function broadcastHerd(herdNow)
	for player,s in pairs(sessions) do
		local ctx=s.ready and herdCtx[s.biome]
		if not ctx or player.Parent~=Players then continue end
		local arena=world.arenas[s.biome]
		local players=playersIn(s.biome)
		local entries={}
		for _,c in pairs(herd) do
			if c.biome~=s.biome or c.claimed then continue end
			if c.starterOwner and c.starterOwner~=player.UserId then continue end
			if c.trialOwner and c.trialOwner~=player.UserId then continue end
			if c.state=="graze" and not c.starterOwner then
				local near=false
				for _,p in ipairs(players) do if (p.x-c.x)^2+(p.z-c.z)^2<1600 then near=true; break end end
				if not near and (herdTick+c.id)%3~=0 then continue end
			end
			local flags=0
			if c.state=="flee" or c.state=="scatter" or c.state=="charging" then flags+=HerdNet.Flags.fleeing end
			if c.state=="dazed" then flags+=HerdNet.Flags.dazed end
			if c.golden then flags+=HerdNet.Flags.golden end
			if c.state=="charging" then flags+=HerdNet.Flags.runner end
			if c.state=="alert" or c.state=="crouch" or c.state=="lean" then flags+=HerdNet.Flags.startled end
			if c.trialOwner then flags+=HerdNet.Flags.trial end
			if c.starterOwner then flags+=HerdNet.Flags.private end
			table.insert(entries,{id=c.id,x=c.x,z=c.z,heading=c.heading or 0,flags=flags,species=c.def.id,
				state=CODES[c.state] or 0,height=c.height or 0})
		end
		for _,packet in ipairs(HerdNet.pack(s.biome,herdNow,entries)) do HerdFeed:FireClient(player,packet) end
		if arena then s.herdArena=s.biome end
	end
end
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
			-- Round beats (events.json): GRAZE / GATHER / STAMPEDE / GOLDEN FINALE.
			local beat=beatAt(arenaClock())
			if s.eventPhase~=nil and s.eventPhase~=beat.name then feedback(player,"Round",beat.name) end
			s.eventPhase=beat.name
		end
		local root,humanoid=rootOf(player)
		if root and humanoid then
			local arena=world.arenas[s.biome]
			local accepted=validApproach(player,s)
			if accepted and not s.active and s.startPos and roundPlaying(s,now) and (root.Position-s.startPos).Magnitude>10 then s.active=true end
			if s.loop and accepted and roundPlaying(s,now) then
				-- Server path (WP-04): accepted positions only, arena-relative, with the
				-- ground level of the layer under the player (jumps/bounces keep g).
				local rel=root.Position-arena.origin
				local g=GroundMap.height(arena.ground,rel.X,rel.Z,rel.Y-2.5)
				local previous=LoopService.record(loops,s.loop,rel.X,rel.Z,now,g)
				-- Run-through bank rings: the path segment crossed a ring (radius 5).
				if previous and #s.carry>0 then
					for _,ring in ipairs(arena.bankRings or {}) do
						if LoopService.crossesRing(previous.x,previous.z,rel.X,rel.Z,ring) then
							s.bankRing=ring.id; bank(player,s,false); break
						end
					end
				end
				for _,claim in ipairs(LoopService.due(loops,s.loop,now)) do
					local head={x=rel.X,z=rel.Z,t=now,g=g}
					local ok,reason,serverArea=LoopService.validate(loops,s.loop,claim,now,arena.bounds,head)
					if ok then
						handleLoop(player,s,claim,now,serverArea)
					else
						s.exploit.loopRejected=(s.exploit.loopRejected or 0)+1
						feedback(player,"Loop","",nil,nil,{caught={},escaped={},points=0,techs={},overflow=0,rejected=true,reason=reason})
					end
				end
			end
			if accepted and roundPlaying(s,now) then
				if Slice.on("static_puff") then updateStatics(player,s,root,now,step) end
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
			if not arena.bankRings and accepted and roundPlaying(s,now) and (root.Position-arena.bank).Magnitude<10 then bank(player,s,false) end
		end
	end
	local clockNow=arenaClock()
	local herdNow=clockNow
	-- Herd (WP-06): Habitat respawns, then each creature's species state machine.
	stepEvents(herdNow)
	stepHerd(step,herdNow,now)
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
					for _,award in ipairs(podiums[biome].awards) do
						local winner=sessionFor(award.userId)
						if winner then analytics.custom(winner,"podium_award",1) end
					end
					for player,s in pairs(sessions) do
						if s.ready and s.biome==biome and (s.phase=="Results" or s.phase=="SitOut") then send(player,s) end
					end
				end
			end
		end
	end
	broadcastHerd(herdNow)
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
