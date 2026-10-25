-- All authored content is original. Colors are RGB bytes; this module is engine-independent.
local Config = {
	RoundSeconds = 110,
	IntermissionSeconds = 8,
	MaxCarry = 8,
	CaptureRadius = 10,
	CaptureCooldown = 0.65,
	DashCooldown = 3,
	WalkSpeed = 22,
	Creatures = {
		{id="pip", name="Pip Pop", shape="orb", color={255,210,65}, value=3, speed=8, behavior="wander", biome=1, rarity="Common", trait="Wobbles toward the herd"},
		{id="bunvolt", name="Bunvolt", shape="ears", color={255,132,177}, value=4, speed=11, behavior="flee", biome=1, rarity="Common", trait="Bounds away when approached"},
		{id="cubloom", name="Cubloom", shape="cube", color={114,232,164}, value=5, speed=7, behavior="herd", biome=1, rarity="Uncommon", trait="Sticks close to friends"},
		{id="flutter", name="Flutterwink", shape="moth", color={179,146,255}, value=7, speed=13, behavior="zigzag", biome=1, rarity="Rare", trait="Zigzags around the chase"},
		{id="sunshell", name="Sunshell", shape="shell", color={255,185,88}, value=6, speed=7, behavior="herd", biome=2, rarity="Common", trait="Patient turns reward flanking"},
		{id="ziptail", name="Zip Tail", shape="comet", color={255,110,93}, value=8, speed=15, behavior="flee", biome=2, rarity="Uncommon", trait="Quick in a straight line"},
		{id="prickle", name="Prism Prickle", shape="prism", color={98,223,224}, value=9, speed=10, behavior="zigzag", biome=2, rarity="Uncommon", trait="Makes sharp playful turns"},
		{id="dunefin", name="Dune Fin", shape="fin", color={126,172,255}, value=12, speed=14, behavior="wander", biome=2, rarity="Rare", trait="Cruises the canyon lanes"},
		{id="crownlet", name="Crownlet", shape="crown", color={255,224,131}, value=9, speed=10, behavior="herd", biome=3, rarity="Common", trait="Leads a luminous parade"},
		{id="ribbubble", name="Ribbubble", shape="ribbon", color={242,137,238}, value=11, speed=13, behavior="zigzag", biome=3, rarity="Uncommon", trait="Loops through the aurora"},
		{id="starwhirl", name="Starwhirl", shape="star", color={155,243,255}, value=14, speed=16, behavior="flee", biome=3, rarity="Rare", trait="A fast dash-timing challenge"},
		{id="antlume", name="Antlume", shape="antler", color={193,176,255}, value=16, speed=12, behavior="wander", biome=3, rarity="Rare", trait="Wide turns reveal an opening"},
	},
	Biomes = {
		{id="meadow", name="Pop Meadow", color={89,211,156}, accent={255,214,72}, unlock=0, description="Soft hills, friendly herds, golden goal."},
		{id="canyon", name="Fizz Canyon", color={242,155,109}, accent={94,234,239}, unlock=30, description="Flank faster sparks between candy mesas."},
		{id="aurora", name="Aurora Arcade", color={126,118,220}, accent={244,146,226}, unlock=90, description="Read the turns of the brightest stampede."},
	},
	Upgrades = {
		boots={name="Dash Boots", costs={20,70,180}, description="Recover your dash sooner.", cooldownReduction=0.35},
		magnet={name="Herd Halo", costs={25,80,200}, description="Reach sparks from farther away.", radiusPerLevel=1.5},
		basket={name="Parade Pack", costs={20,65,160}, description="Bring two more sparks to every bank.", capacityPerLevel=2},
	},
	Quests = {
		{id="first_haul", name="A parade begins", metric="totalBanked", target=3, reward=10},
		{id="first_round", name="Take a victory lap", metric="rounds", target=1, reward=15},
		{id="meadow_album", name="Meet the meadow", metric="species", target=4, reward=30},
		{id="herd_helper", name="Herd helper", metric="totalBanked", target=30, reward=40},
		{id="three_laps", name="Encore explorer", metric="rounds", target=3, reward=45},
		{id="spark_scout", name="Spark scout", metric="species", target=8, reward=65},
		{id="parade_master", name="Parade master", metric="totalBanked", target=100, reward=90},
		{id="complete_album", name="The whole bright bunch", metric="species", target=12, reward=150},
	},
	-- Earned from repeat catches. No random roll, purchase, or consumed creature.
	Mutations = {
		{id="glow", name="Glow", threshold=5, description="Bank five of a species to unlock its glow."},
		{id="prism", name="Prism", threshold=15, description="Bank fifteen of a species to unlock its prism trail."},
	},
}
return Config
