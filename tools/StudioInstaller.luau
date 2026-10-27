-- Shared by the generated Edit-mode installer and its fault-injection tests.
-- A preflight failure never touches source. A write failure restores prior state.
return function(context, entries, expectedPlace)
	local game, Instance, Enum, task = context.game, context.Instance, context.Enum, context.task
	assert(game.PlaceId == expectedPlace, "Unexpected place; refusing to install")
	local function requireEdit()
		assert(not game:GetService("RunService"):IsRunning(), "Stop Play before installation")
	end
	requireEdit()
	assert(#entries > 0, "Empty source manifest; refusing to install")
	local sync = game:GetService("InstanceFileSyncService")
	local function unique(parent, name)
		local found
		for _, child in ipairs(parent:GetChildren()) do
			if child.Name == name then
				assert(not found, "Ambiguous instance at " .. parent:GetFullName() .. "." .. name)
				found = child
			end
		end
		return found
	end
	local seen, recognized, roots = {}, {}, {}
	for _, entry in ipairs(entries) do
		local path = table.concat(entry.parts, ".")
		assert(not seen[path], "Duplicate source path: " .. path); seen[path] = true
		local parent = game:GetService(entry.parts[1])
		for index = 2, #entry.parts - 1 do
			parent = parent and unique(parent, entry.parts[index])
			if parent then
				assert(parent:IsA("Folder") or parent:IsA("StarterPlayerScripts"), "Unexpected source container: " .. parent:GetFullName())
				assert(sync:GetStatus(parent) == Enum.InstanceFileSyncStatus.NotSynced, "Spark source container has a second sync writer: " .. parent:GetFullName())
				if entry.parts[index] == "Spark" then roots[parent] = true end
			end
		end
		local existing = parent and unique(parent, entry.parts[#entry.parts])
		if existing then
			assert(existing.ClassName == entry.class, "Unexpected script class at " .. path)
			assert(sync:GetStatus(existing) == Enum.InstanceFileSyncStatus.NotSynced, "Spark must not have a second sync writer: " .. path)
			recognized[existing] = true
		end
	end
	for root in pairs(roots) do
		for _, item in ipairs(root:GetDescendants()) do
			assert(not item:IsA("LuaSourceContainer") or recognized[item], "Unmanifested Spark source; export and reconcile before installing: " .. item:GetFullName())
		end
	end
	local serverStorage, workspace = game:GetService("ServerStorage"), game:GetService("Workspace")
	local recovery = unique(serverStorage, "CascadeRecovery")
	assert(not recovery or recovery:IsA("Folder"), "Invalid CascadeRecovery container")
	local legacy = {}
	for _, parent in ipairs({game:GetService("ServerScriptService"), game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")}) do
		local container = unique(parent, "Cascade")
		if container then
			for _, item in ipairs(container:GetDescendants()) do
				if item:IsA("BaseScript") then table.insert(legacy, item) end
			end
		end
	end
	local moved = {}
	for _, name in ipairs({"Baseplate", "SpawnLocation", "Script"}) do
		local item = unique(workspace, name)
		if item then
			assert(not recovery or not unique(recovery, name), "Recovery name conflict: " .. name)
			table.insert(moved, item)
		end
	end
	local undo, installed = {}, {}
	local function remember(callback) table.insert(undo, callback) end
	local function create(class, name, parent)
		local item = Instance.new(class)
		remember(function() item:Destroy() end)
		item.Name = name; item.Parent = parent
		return item
	end
	local function suspend(item)
		local enabled, original = item.Enabled, item:GetAttribute("CascadeOriginalEnabled")
		remember(function() item.Enabled = enabled; item:SetAttribute("CascadeOriginalEnabled", original) end)
		if original == nil then item:SetAttribute("CascadeOriginalEnabled", enabled) end
		item.Enabled = false
	end
	local ok, failure = pcall(function()
		for _, entry in ipairs(entries) do
			requireEdit()
			local parent = game:GetService(entry.parts[1])
			for index = 2, #entry.parts - 1 do
				parent = unique(parent, entry.parts[index]) or create("Folder", entry.parts[index], parent)
			end
			local item = unique(parent, entry.parts[#entry.parts])
			if item then
				local source, hash = item.Source, item:GetAttribute("SourceSHA256")
				local enabled = item:IsA("BaseScript") and item.Enabled
				local runContext = item:IsA("Script") and item.RunContext
				remember(function()
					item.Source = source; item:SetAttribute("SourceSHA256", hash)
					if item:IsA("Script") then item.RunContext = runContext end
					if item:IsA("BaseScript") then item.Enabled = enabled end
				end)
			else item = create(entry.class, entry.parts[#entry.parts], parent) end
			if item:IsA("BaseScript") then item.Enabled = false end
			item.Source = entry.source
			assert(item.Source == entry.source, "Source readback mismatch: " .. item:GetFullName())
			if item:IsA("Script") then item.RunContext = Enum.RunContext.Server end
			item:SetAttribute("SourceSHA256", entry.sha256)
			table.insert(installed, item)
			task.wait()
		end
		requireEdit()
		recovery = recovery or create("Folder", "CascadeRecovery", serverStorage)
		for _, item in ipairs(legacy) do suspend(item) end
		for _, item in ipairs(moved) do
			local oldParent = item.Parent
			remember(function() item.Parent = oldParent end)
			if item:IsA("BaseScript") then suspend(item) end
			item.Parent = recovery
		end
		for _, item in ipairs(installed) do if item:IsA("BaseScript") then item.Enabled = true end end
		local oldMode = game:GetAttribute("SparkSourceMode")
		remember(function() game:SetAttribute("SparkSourceMode", oldMode) end)
		game:SetAttribute("SparkSourceMode", "GitExplicitInstall")
	end)
	if not ok then
		local failures = {}
		for index = #undo, 1, -1 do
			local restored, detail = pcall(undo[index])
			if not restored then table.insert(failures, tostring(detail)) end
		end
		error("Install failed: " .. tostring(failure) .. "; rollback failures=" .. #failures .. (if #failures > 0 then ": " .. table.concat(failures, "; ") else ""))
	end
	local result = {}
	for _, item in ipairs(installed) do
		table.insert(result, {path=item:GetFullName(), bytes=#item.Source, sha256=item:GetAttribute("SourceSHA256")})
	end
	return game:GetService("HttpService"):JSONEncode(result)
end
