# Spark implementation contract

Offline development is staged under `game/` until G0 Studio identity, backup and two-way sync pass. Existing `src/Cascade` remains untouched. Git is canonical. Do not deploy while G0 is blocked.

Layout: `game/ReplicatedStorage/Spark/Config.luau`, `Profile.luau`, `Rules.luau`; `game/ServerScriptService/Spark/World.luau`, `Persistence.luau`, `Main.server.luau`; `game/StarterPlayer/StarterPlayerScripts/Spark/Client.client.luau`.

Config is pure Luau data: RoundSeconds=110, IntermissionSeconds=8, MaxCarry=8, CaptureRadius=10, CaptureCooldown=0.65, DashCooldown=3, WalkSpeed=22. Creatures array of 12 `{id,name,shape,color={r,g,b},value,speed,behavior,biome}`; Biomes array of 3 `{id,name,color={r,g,b},accent={r,g,b},unlock}`; Upgrades map `boots/magnet/basket` with `{name,costs={...},description}`. No Roblox datatypes in Config/Profile/Rules.

Profile.new() creates version=1, coins=0, totalBanked=0, rounds=0, album={}, upgrades={boots=0,magnet=0,basket=0}, quests={}, settings={reducedMotion=false,music=true,sfx=true}, lastSeen=0. Profile.sanitize(raw); Profile.bank(profile, catches) where catches are array of creature ids returns reward and new species count; Profile.buy(profile,key) returns boolean,message; Profile.claim(profile,questId) returns boolean,message. Config.Quests array `{id,name,target,reward,metric}`. Profile public snapshot must be serializable.

World.build(Config) returns `{root=Model, arenas={{origin=Vector3,spawn=Vector3,bank=Vector3,radius=number}}, hub=Vector3}`. Build generates all three original themed arenas with clear walkable floor, bank landmark, low obstacle islands and boundaries, with yielded batches. World.creature(def,parent) returns anchored noncolliding Model with PrimaryPart; caller positions using PivotTo. No active gameplay loops in World. Shapes visually distinct, no external paid assets.

Persistence.new(store,clock) returns adapter with `:load(userId)` -> profile,status; `:save(userId,profile)` -> success,status; `:release(userId,profile)` -> success,status. Main controls readiness and never permits progression on failed load. Dependency injected store supports GetAsync/UpdateAsync; production needs session lease and retry failure safety. Document signatures if refined.

Runtime creates ReplicatedStorage.Spark.Remotes Action(RemoteEvent), State(RemoteEvent), Feedback(RemoteEvent). Client sends Action(action,payload) strings: Ready,Capture,Dash,Bank,Replay,Upgrade(key),Quest(id),Settings(table),Biome(index). No client balance, capture id or position accepted. Server emits State table `{phase,remaining,biome,carry,capacity,score,profile,saveStatus,event,objective}` at <=2Hz plus meaningful mutations; Feedback `{kind,text,creature?,position?}`. Creature models under Workspace.SparkWorld.Creatures have CreatureId and Species attributes. Client derives nearby targets visually. Server owns distance, rate limits, capture race resolution, banking, rewards and unlocks.

Player rounds are independent 110-second sessions so joins have immediate play; shared moving herds per arena, no required lobby. End auto-banks legitimate carried captures once; replay explicit. Movement server validates bounds and rejects implausible capture approach, dash is server-issued velocity. Actual engine/mobile/multiplayer QA remains required beyond pure tests.
