-- Fault-injection against the exact runtime embedded in the Studio installer.
-- Instance behavior is mocked: this is not a Studio rollback rehearsal.
local install = require("../tools/StudioInstaller")
local assertions = 0
local function check(value, message)
	assertions += 1
	assert(value, message)
end
local function environment()
	local all, fault = {}, nil
	local methods = {}
	local function new(class)
		local object = {_props={ClassName=class,Name=class,Enabled=true,Source="",RunContext="Legacy"},_attrs={}}
		setmetatable(object, {
			__index=function(self,key) return methods[key] or self._props[key] end,
			__newindex=function(self,key,value)
				if fault then fault(self,key,value) end
				self._props[key]=value
			end,
		})
		table.insert(all, object)
		return object
	end
	function methods:IsA(class)
		return self.ClassName==class or (class=="BaseScript" and (self.ClassName=="Script" or self.ClassName=="LocalScript"))
			or (class=="LuaSourceContainer" and (self.ClassName=="Script" or self.ClassName=="LocalScript" or self.ClassName=="ModuleScript"))
	end
	function methods:GetChildren()
		local children={}
		for _, item in ipairs(all) do if not item._props.destroyed and item.Parent==self then table.insert(children,item) end end
		return children
	end
	function methods:FindFirstChild(name)
		for _, item in ipairs(self:GetChildren()) do if item.Name==name then return item end end
	end
	function methods:GetDescendants()
		local result={}
		for _, child in ipairs(self:GetChildren()) do
			table.insert(result,child)
			for _, item in ipairs(child:GetDescendants()) do table.insert(result,item) end
		end
		return result
	end
	function methods:GetFullName() return (if self.Parent then self.Parent:GetFullName().."." else "")..self.Name end
	function methods:GetAttribute(key) return self._attrs[key] end
	function methods:SetAttribute(key,value)
		if fault then fault(self,"@"..key,value) end
		self._attrs[key]=value
	end
	function methods:Destroy()
		for _, child in ipairs(self:GetChildren()) do child:Destroy() end
		self.Parent=nil; self._props.destroyed=true
	end
	local game=new("DataModel"); game.Name="game"; game.PlaceId=123
	function methods:GetService(name) return assert(self:FindFirstChild(name), name) end
	local function child(parent,class,name)
		local item=new(class); item.Name=name; item.Parent=parent; return item
	end
	for _, name in ipairs({"RunService","InstanceFileSyncService","ServerStorage","Workspace","ServerScriptService","StarterPlayer","ReplicatedStorage","HttpService"}) do child(game,name,name) end
	function methods:IsRunning() return self.running==true end
	function methods:GetStatus(item) return item.sync or "NotSynced" end
	function methods:JSONEncode(value) return value end
	child(game:GetService("StarterPlayer"),"StarterPlayerScripts","StarterPlayerScripts")
	local spark=child(game:GetService("ServerScriptService"),"Folder","Spark")
	local main=child(spark,"Script","Main"); main.Source="previous main"; main.Enabled=false; main:SetAttribute("SourceSHA256","previous hash")
	local cascade=child(game:GetService("ServerScriptService"),"Folder","Cascade")
	local old=child(cascade,"Script","Old"); old.Source="preserved cascade"
	local base=child(game:GetService("Workspace"),"Part","Baseplate")
	local hello=child(game:GetService("Workspace"),"Script","Script")
	local context={game=game,Instance={new=new},Enum={InstanceFileSyncStatus={NotSynced="NotSynced"},RunContext={Server="Server"}},task={wait=function() end}}
	local entries={
		{parts={"ServerScriptService","Spark","Main"},class="Script",source="new main",sha256="new hash"},
		{parts={"ReplicatedStorage","Spark","Config"},class="ModuleScript",source="new config",sha256="config hash"},
	}
	local function snapshot()
		local values={}
		for _, item in ipairs(game:GetDescendants()) do
			local attrs={}
			for key,value in pairs(item._attrs) do table.insert(attrs,key.."="..tostring(value)) end
			table.sort(attrs)
			table.insert(values,table.concat({item:GetFullName(),item.ClassName,item.Source,tostring(item.Enabled),item.RunContext,table.concat(attrs,",")},"|"))
		end
		table.sort(values)
		return table.concat(values,"\n").."\nmode="..tostring(game:GetAttribute("SparkSourceMode"))
	end
	return {context=context,entries=entries,game=game,main=main,old=old,base=base,hello=hello,child=child,snapshot=snapshot,
		setFault=function(value) fault=value end}
end
local function rejected(setup, fragment)
	local env=environment(); setup(env)
	local before=env.snapshot()
	local ok,message=pcall(install,env.context,env.entries,123)
	check(not ok and string.find(tostring(message),fragment,1,true)~=nil,"expected failure "..fragment..": "..tostring(message))
	check(env.snapshot()==before,"failure changed prior state: "..fragment)
end
rejected(function(e) e.game.PlaceId=456 end,"Unexpected place")
rejected(function(e) e.entries={} end,"Empty source manifest")
rejected(function(e) e.game:GetService("RunService").running=true end,"Stop Play")
rejected(function(e) e.main.sync="SyncedAsRoot" end,"second sync writer")
rejected(function(e) e.main.Parent.sync="SyncedAsRoot" end,"second sync writer")
rejected(function(e) e.entries[2].class="Script"; e.child(e.game:GetService("ReplicatedStorage"),"Part","Spark") end,"Unexpected source container")
rejected(function(e) e.entries[1].class="LocalScript" end,"Unexpected script class")
rejected(function(e) e.child(e.main.Parent,"Script","Main") end,"Ambiguous instance")
rejected(function(e) e.child(e.main.Parent,"Script","ObsoleteMain") end,"Unmanifested Spark source")
rejected(function(e) e.child(e.main.Parent,"ModuleScript","ObsoleteModule") end,"Unmanifested Spark source")
rejected(function(e)
	e.context.task.wait=function() e.game:GetService("RunService").running=true end
end,"Stop Play")
rejected(function(e) table.insert(e.entries,e.entries[1]) end,"Duplicate source path")
rejected(function(e)
	local recovery=e.child(e.game:GetService("ServerStorage"),"Folder","CascadeRecovery")
	e.child(recovery,"Part","Baseplate")
end,"Recovery name conflict")
for _, target in ipairs({"Source","@SourceSHA256","legacy","move","enable","@SparkSourceMode"}) do
	rejected(function(e)
		local fired=false
		e.setFault(function(item,key,value)
			local matches=(target=="Source" and item.Name=="Config" and key=="Source")
				or (target=="@SourceSHA256" and key==target)
				or (target=="legacy" and item==e.old and key=="Enabled")
				or (target=="move" and item==e.hello and key=="Parent")
				or (target=="enable" and item==e.main and key=="Enabled" and value==true)
				or (target=="@SparkSourceMode" and key==target)
			if matches and not fired then fired=true; error("injected "..target) end
		end)
	end,"rollback failures=0")
end
do
	local e=environment()
	local result=install(e.context,e.entries,123)
	check(#result==2,"install result count")
	check(e.main.Source=="new main" and e.main.Enabled and e.main.RunContext=="Server","main activated")
	check(e.old.Source=="preserved cascade" and not e.old.Enabled and e.old:GetAttribute("CascadeOriginalEnabled")==true,"legacy source preserved and suspended")
	check(e.base.Parent.Name=="CascadeRecovery" and e.hello.Parent==e.base.Parent and not e.hello.Enabled,"legacy objects recovered")
	check(e.game:GetAttribute("SparkSourceMode")=="GitExplicitInstall","source mode")
	local after=e.snapshot()
	install(e.context,e.entries,123)
	check(e.snapshot()==after,"repeat install idempotent")
end
do
	local e=environment()
	e.setFault(function(item,key)
		if item==e.main and key=="Source" then error("persistent write failure") end
	end)
	local ok,message=pcall(install,e.context,e.entries,123)
	check(not ok and string.find(tostring(message),"rollback failures=1",1,true)~=nil,"rollback failures must be reported")
end
print("PASS SparkInstaller: "..assertions.." assertions; mocked preflight, write rollback, preservation and repeat install")
