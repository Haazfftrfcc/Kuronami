-- SaveManager for Linoria Left-Tab UI Library
local HttpService = game:GetService("HttpService")

local SaveManager = {
	Library = nil,
	Folder = "LinoriaLeftUI/configs",
	DefaultConfig = "default",
	IgnoreFlags = {}
}

local function hasFS()
	return typeof(isfolder) == "function"
		and typeof(makefolder) == "function"
		and typeof(writefile) == "function"
		and typeof(readfile) == "function"
		and typeof(isfile) == "function"
		and typeof(listfiles) == "function"
end

local function ensureFolders()
	if not hasFS() then return end
	local root = SaveManager.Folder:match("^([^/]+)")
	if root and not isfolder(root) then
		pcall(makefolder, root)
	end
	if not isfolder(SaveManager.Folder) then
		pcall(makefolder, SaveManager.Folder)
	end
end

function SaveManager:SetLibrary(lib)
	self.Library = lib
	ensureFolders()
end

function SaveManager:SetIgnoreIndexes(list)
	self.IgnoreFlags = {}
	for _, flag in ipairs(list or {}) do
		self.IgnoreFlags[flag] = true
	end
end

function SaveManager:GetConfigs()
	local list = {}
	if hasFS() and isfolder(self.Folder) then
		local ok, files = pcall(listfiles, self.Folder)
		if ok and type(files) == "table" then
			for _, filePath in ipairs(files) do
				local name = filePath:match("([^/\\]+)%.json$")
				if name then
					table.insert(list, name)
				end
			end
		end
	end
	if #list == 0 then
		table.insert(list, self.DefaultConfig)
	end
	table.sort(list)
	return list
end

function SaveManager:Save(configName)
	if not hasFS() or not self.Library then return false end
	ensureFolders()
	configName = (configName and configName ~= "") and configName or self.DefaultConfig

	local data = {}
	for flag, option in pairs(self.Library.Options) do
		if not self.IgnoreFlags[flag] and type(option) == "table" and option.Type then
			data[flag] = option.Value
		end
	end

	local ok = pcall(writefile, self.Folder .. "/" .. configName .. ".json", HttpService:JSONEncode(data))
	return ok
end

function SaveManager:Load(configName)
	if not hasFS() or not self.Library then return false end
	configName = (configName and configName ~= "") and configName or self.DefaultConfig
	local path = self.Folder .. "/" .. configName .. ".json"
	if not isfile(path) then return false end

	local ok, raw = pcall(readfile, path)
	if not ok or not raw then return false end

	local decoded = nil
	pcall(function() decoded = HttpService:JSONDecode(raw) end)
	if type(decoded) ~= "table" then return false end

	for flag, val in pairs(decoded) do
		if not self.IgnoreFlags[flag] then
			local option = self.Library.Options[flag]
			if option and type(option.SetValue) == "function" then
				pcall(function()
					option:SetValue(val)
				end)
			end
		end
	end

	return true
end

function SaveManager:Delete(configName)
	if not hasFS() or not configName or configName == "" then return false end
	if typeof(delfile) ~= "function" then return false end
	local path = self.Folder .. "/" .. configName .. ".json"
	if isfile(path) then
		return pcall(delfile, path)
	end
	return false
end

function SaveManager:ApplyToTab(tab)
	if not self.Library or not tab then return end
	ensureFolders()

	local group = tab:AddGroupbox("Config Manager")
	local selectedConfig = self.DefaultConfig
	local newConfigName = ""

	local configDropdown = group:AddDropdown("SaveManager_ConfigList", {
		Text = "Config List",
		Values = self:GetConfigs(),
		Default = selectedConfig,
		Callback = function(val)
			selectedConfig = val
		end
	})

	group:AddInput("SaveManager_ConfigName", {
		Text = "Config Name",
		Placeholder = "Enter config name...",
		Default = "",
		Callback = function(val)
			newConfigName = val
		end
	})

	group:AddButton("Save Config", function()
		local target = (newConfigName ~= "") and newConfigName or selectedConfig
		if self:Save(target) then
			selectedConfig = target
			configDropdown:Refresh(self:GetConfigs(), target)
		end
	end)

	group:AddButton("Load Config", function()
		local target = (newConfigName ~= "") and newConfigName or selectedConfig
		self:Load(target)
	end)

	group:AddButton("Delete Config", function()
		local target = selectedConfig
		if self:Delete(target) then
			local updated = self:GetConfigs()
			selectedConfig = updated[1] or self.DefaultConfig
			configDropdown:Refresh(updated, selectedConfig)
		end
	end)

	group:AddButton("Refresh List", function()
		configDropdown:Refresh(self:GetConfigs(), selectedConfig)
	end)
end

return SaveManager
