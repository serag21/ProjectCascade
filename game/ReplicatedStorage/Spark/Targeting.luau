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
-- Dash-through geometry: horizontal distance from a spark to the segment the
-- server observed the player sweep during a dash. Vertical tolerance prevents
-- catching sparks far above/below (jumps, ledges). Never trusts client data.
function Targeting.sweep(a,b,position,radius,height)
	if not vector(a) or not vector(b) or not vector(position) or not finite(radius) or radius<=0 then return nil end
	local tolerance=if finite(height) and height>0 then height else 6
	local minY=math.min(a.y,b.y)-tolerance; local maxY=math.max(a.y,b.y)+tolerance
	if position.y<minY or position.y>maxY then return nil end
	local dx,dz=b.x-a.x,b.z-a.z
	local length2=dx*dx+dz*dz
	local t=0
	if length2>1e-9 then t=math.clamp(((position.x-a.x)*dx+(position.z-a.z)*dz)/length2,0,1) end
	local cx,cz=a.x+dx*t,a.z+dz*t
	local ox,oz=position.x-cx,position.z-cz
	local distance=math.sqrt(ox*ox+oz*oz)
	if not finite(distance) or distance>radius then return nil end
	return {distance=distance,t=t}
end
return Targeting
