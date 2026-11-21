-- WP-03: dash state machine (charges, recharge, 0.12 s buffer, speed curve,
-- steering), camera maths and ribbon claim bookkeeping, on a fake clock.
-- These are the pure halves of client modules (no Roblox globals needed).
local V3={}
function V3.new(x,y,z) return {X=x,Y=y,Z=z} end
local Movement=require("../game/StarterPlayer/StarterPlayerScripts/Spark/Movement")
local SparkCamera=require("../game/StarterPlayer/StarterPlayerScripts/Spark/SparkCamera")
local Ribbon=require("../game/StarterPlayer/StarterPlayerScripts/Spark/Ribbon")
local Loop=require("../game/ReplicatedStorage/Spark/Loop")
local Tuning=require("../game/ReplicatedStorage/Spark/Design/Tuning")
local assertions=0
local function check(c,m) assertions+=1; assert(c,m) end
local function equal(a,b,m) check(a==b,(m or "Mismatch")..": "..tostring(a).." ~= "..tostring(b)) end
local function near(a,b,tol,m) check(a~=nil and math.abs(a-b)<=tol,(m or "Mismatch")..": "..tostring(a).." vs "..tostring(b)) end
local north=V3.new(0,0,-1)

-- Charges and recharge (2 charges, 2.4 s each, one at a time).
do
	local d=Movement.newDash(Tuning.dash,Tuning.movement.walkSpeed)
	equal(d.charges,2); equal(d.maxCharges,Tuning.dash.charges)
	equal(Movement.press(d,0,north),"start","first dash starts on the input frame")
	near(Movement.speedAt(d,0),Tuning.dash.speedCurve[1][2],1e-9,"motion at t=0 (same frame)")
	equal(d.charges,1)
	equal(Movement.press(d,0.1,north),"buffered","a press during the motion phase is buffered")
	equal(Movement.update(d,0.2),nil,"buffer expired after 0.12 s while still dashing")
	equal(Movement.press(d,0.3,north),"start","second charge after the first dash")
	equal(d.charges,0)
	equal(Movement.press(d,0.7,north),"empty","no charge, recharge far away -> empty")
	equal(Movement.update(d,2.39),nil)
	Movement.refill(d,2.4)
	equal(d.charges,1,"one charge back 2.4 s after the first use")
	Movement.refill(d,4.79); equal(d.charges,1)
	Movement.refill(d,4.8); equal(d.charges,2,"second charge 2.4 s later (one at a time)")
	near(Movement.nextChargeIn(d,4.8),0,1e-9)
end

-- Buffer: a press up to 0.12 s before the charge returns fires when it does.
do
	local d=Movement.newDash(Tuning.dash,24)
	Movement.press(d,0,north); Movement.press(d,0.5,north)
	equal(d.charges,0)
	equal(Movement.press(d,2.3,north),"buffered","0.10 s early is inside the buffer")
	equal(Movement.update(d,2.35),nil)
	equal(Movement.update(d,2.4),"start","buffered press fires at the recharge")
	local d2=Movement.newDash(Tuning.dash,24)
	Movement.press(d2,0,north); Movement.press(d2,0.5,north)
	equal(Movement.press(d2,2.2,north),"empty","0.20 s early is outside the buffer")
	equal(Movement.update(d2,2.4),nil,"an expired buffer never fires")
	equal(d2.dashes,2)
end

-- Speed curve sampling, exit blend to walk, and the distance it covers.
do
	local d=Movement.newDash(Tuning.dash,24)
	Movement.press(d,10,north)
	local curve=Tuning.dash.speedCurve
	for _,k in ipairs(curve) do near(Movement.speedAt(d,10+k[1]),k[2],1e-9,"curve key "..k[1]) end
	near(Movement.speedAt(d,10.02),(curve[1][2]+curve[2][2])/2,1e-9,"linear between keys")
	near(Movement.speedAt(d,10+Tuning.dash.duration+0.05),(curve[#curve][2]+24)/2,1e-9,"blend halfway to walk")
	equal(Movement.speedAt(d,10+Tuning.dash.duration+0.11),nil,"dash over after the blend")
	local distance=0
	for i=0,399 do distance+=(Movement.speedAt(d,10+i/1000) or 0)/1000 end
	check(distance>12 and distance<17,"dash covers ~15 studs ("..distance..")")
	local reference=Movement.curveDistance(curve)
	local scaled=Movement.newDash(Tuning.dash,24,{distance=18})
	Movement.press(scaled,0,north)
	near(Movement.speedAt(scaled,0.04),curve[2][2]*18/reference,1e-9,"F9 dash distance scales the curve")
end

-- Steering: 40 % of live input bends the direction.
do
	local d=Movement.newDash(Tuning.dash,24)
	Movement.press(d,0,north)
	local east=V3.new(1,0,0)
	local dir=Movement.steerDirection(d,east)
	local s=Tuning.dash.steerFraction
	local m=math.sqrt(s*s+(1-s)^2)
	near(dir.X,s/m,1e-9,"steer x"); near(dir.Z,-(1-s)/m,1e-9,"steer z")
	equal(Movement.steerDirection(d,nil),north,"no input keeps the direction")
end

-- Camera maths: preset stepping, offsets, smoothing.
do
	equal(SparkCamera.step(2,-1,3),1); equal(SparkCamera.step(1,-1,3),1); equal(SparkCamera.step(3,1,3),3)
	local presets=Tuning.camera.pitchPresets
	equal(presets[2],Tuning.camera.pitchDegrees,"default is the middle preset")
	local x,y,z=SparkCamera.offset(0,math.rad(46),38)
	near(x,0,1e-9); near(y,38*math.sin(math.rad(46)),1e-9); near(z,38*math.cos(math.rad(46)),1e-9,"camera sits behind (+z) at yaw 0")
	near(SparkCamera.alpha(0.12,0.12),1-math.exp(-1),1e-12)
	equal(SparkCamera.alpha(1,0),1)
end

-- Ribbon claim bookkeeping: rate limit 3/s, slip after resultTimeout, in-order results.
do
	local T=Loop.tuning(Tuning)
	local c=Ribbon.newClaims(T,Tuning.ribbon.claimRateLimitPerSecond)
	local ids={}
	for i=1,4 do ids[i]=Ribbon.openClaim(c,10+i*0.01,{},"snap") end
	check(ids[1] and ids[2] and ids[3],"three claims in a second")
	equal(ids[4],nil,"the fourth claim inside a second is not sent")
	equal(Ribbon.resolveClaim(c,nil).id,ids[1],"oldest pending resolves first")
	local slipped=Ribbon.expireClaims(c,10.03+T.resultTimeout)
	equal(#slipped,2,"unanswered claims slip at resultTimeout")
	equal(#Ribbon.expireClaims(c,20),0,"slips are reported once")
	check(Ribbon.openClaim(c,11.5,{},"cross")~=nil,"rate window rolls")
end
print("SparkMovement: "..assertions.." assertions passed")
