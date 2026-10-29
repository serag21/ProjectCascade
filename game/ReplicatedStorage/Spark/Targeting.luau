-- Same geometry for server selection and advisory client aim. Never authorizes a reward.
local Targeting={}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function vector(v) return type(v)=="table" and finite(v.x) and finite(v.y) and finite(v.z) end
function Targeting.measure(origin,look,position,radius)
	if not vector(origin) or not vector(look) or not vector(position) or not finite(radius) or radius<=0 then return nil end
	local x,y,z=position.x-origin.x,position.y-origin.y,position.z-origin.z
	local distance=math.sqrt(x*x+y*y+z*z)
	if not finite(distance) or distance>radius then return nil end
	local length=math.sqrt(look.x*look.x+look.y*look.y+look.z*look.z)
	if not finite(length) or length<.001 then return nil end
	local facing=if distance>.001 then math.clamp((look.x*x+look.y*y+look.z*z)/(distance*length),-1,1) else 1
	if distance>=4 and facing<=-.2 then return nil end
	return {distance=distance,facing=facing,precision=distance<=4 and facing>=.7}
end
-- Equal distances use stable server creature IDs, independent of table iteration order.
function Targeting.better(candidate,id,best,bestId)
	return candidate~=nil and (best==nil or candidate.distance<best.distance
		or (candidate.distance==best.distance and id<bestId))
end
return Targeting
