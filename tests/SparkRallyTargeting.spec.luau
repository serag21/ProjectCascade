local Rally=require("../game/ReplicatedStorage/Spark/ArenaRally")
local Targeting=require("../game/ReplicatedStorage/Spark/Targeting")
local n=0
local function check(ok,message) n+=1; assert(ok,message) end
local origin={x=0,y=0,z=0}
local look={x=0,y=0,z=-1}
local function aim(x,y,z,r) return Targeting.measure(origin,look,{x=x,y=y,z=z},r or 10) end
check(aim(0,0,-4).precision,"Precision includes exact four-stud boundary")
check(not aim(0,0,-4.001).precision,"Reach does not grant precision")
check(aim(0,0,-10)~=nil and aim(0,0,-10.001)==nil,"Capture range exact boundary")
check(aim(0,0,3.999)~=nil and aim(0,0,4)==nil,"Touch-friendly close range, forward arc beyond")
check(aim(0,0,0).precision,"Coincident positions are finite")
check(not aim(0/0,0,0) and not aim(0,0,0,math.huge),"Bad inputs rejected")
check(not Targeting.measure(origin,origin,origin,10),"Invalid look rejected")
local a,b=aim(1,0,0),aim(-1,0,0)
check(Targeting.better(a,2,b,3) and not Targeting.better(b,3,a,2),"Tie order is stable by ID")
for tenth=-150,150 do
	for axis=-10,10 do
		local x,z=axis,tenth/10
		local result=aim(x,0,z)
		local distance=math.sqrt(x*x+z*z)
		local facing=if distance>.001 then -z/distance else 1
		local expected=distance<=10 and (distance<4 or facing>-.2)
		check((result~=nil)==expected,"Preview/server arc equivalence")
		if result then check(result.precision==(distance<=4 and facing>=.7),"Precision rule equivalence") end
	end
end

local solo=Rally.new(100)
check(#Rally.deposit(solo,101,1,3)==0,"Partial haul builds sprint")
local winners=Rally.deposit(solo,104,1,3)
check(#winners==1 and winners[1]==1,"Solo completion uses same fixed target")
check(#Rally.deposit(solo,105,1,6)==0,"No repeat awards")
check(Rally.snapshot(solo,144.99,1).complete,"Completion retained until boundary")
local reset=Rally.snapshot(solo,145,1)
check(reset.total==0 and not reset.complete and reset.contribution==0 and reset.remaining==45,"Exact boundary resets shared cycle")
check(#Rally.deposit(solo,144,1,6)==0,"Stale time never reopens previous cycle")
check(#Rally.deposit(solo,145,1,6)==1,"New cycle completion")
for players=1,4 do
	local state=Rally.new(0)
	local awards=0
	for i=1,6 do awards+=#Rally.deposit(state,i,1+(i-1)%players,1) end
	check(awards==players,"Every contributor paid once")
	for i=7,44 do check(#Rally.deposit(state,i,1,14)==0,"Completed rally cannot pay again") end
	check(Rally.snapshot(state,45,999).contribution==0,"Spectator cannot acquire credit")
end
local state=Rally.new(0)
Rally.deposit(state,1,1,2); Rally.leave(state,1)
Rally.deposit(state,2,2,2)
winners=Rally.deposit(state,3,3,2)
check(#winners==2 and winners[1]==2 and winners[2]==3,"Disconnect preserves team haul but removes award eligibility")
check(#Rally.deposit(state,4,1,1)==0,"Rejoin cannot reclaim completion award")
local invalid=Rally.new(0)
for _,value in ipairs({0,-1,1.5,15,math.huge,0/0}) do check(#Rally.deposit(invalid,1,1,value)==0,"Invalid haul rejected") end
check(Rally.snapshot(invalid,2,1).total==0,"Bad deposits never mutate totals")
print("PASS SparkRallyTargeting: "..n.." assertions (pure authority/preview geometry and shared banking sprint)")
