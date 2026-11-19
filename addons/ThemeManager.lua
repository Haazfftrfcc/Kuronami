-- ThemeManager for Linoria Left-Tab UI Library
local HttpService = game:GetService("HttpService")

local ThemeManager = {
	Library = nil,
	Folder = "LinoriaLeftUI/themes",
	CurrentTheme = "Classic Red",
	Presets = {
		["Classic Red"] = {
			MainColor = Color3.fromRGB(16, 16, 18),
			SecondaryColor = Color3.fromRGB(24, 24, 27),
			GroupColor = Color3.fromRGB(20, 20, 23),
			OutlineDark = Color3.fromRGB(8, 8, 10),
			OutlineGrey = Color3.fromRGB(58, 58, 64),
			AccentColor = Color3.fromRGB(196, 38, 38),
			FontColor = Color3.fromRGB(235, 235, 240),
			MutedColor = Color3.fromRGB(145, 145, 155),
			Font = Enum.Font.Code
		},
		["Crimson Night"] = {
			MainColor = Color3.fromRGB(12, 11, 13),
			SecondaryColor = Color3.fromRGB(20, 18, 21),
			GroupColor = Color3.fromRGB(17, 15, 18),
			OutlineDark = Color3.fromRGB(6, 6, 7),
			OutlineGrey = Color3.fromRGB(66, 56, 60),
			AccentColor = Color3.fromRGB(215, 45, 55),
			FontColor = Color3.fromRGB(240, 236, 238),
			MutedColor = Color3.fromRGB(150, 140, 145),
			Font = Enum.Font.Code
		},
		["Ash & Steel"] = {
			MainColor = Color3.fromRGB(18, 18, 20),
			SecondaryColor = Color3.fromRGB(28, 28, 32),
			GroupColor = Color3.fromRGB(23, 23, 26),
			OutlineDark = Color3.fromRGB(10, 10, 12),
			OutlineGrey = Color3.fromRGB(72, 72, 80),
			AccentColor = Color3.fromRGB(180, 32, 32),
			FontColor = Color3.fromRGB(230, 230, 235),
			MutedColor = Color3.fromRGB(140, 140, 148),
			Font = Enum.Font.RobotoMono
		}
	}
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
	local root = ThemeManager.Folder:match("^([^/]+)")
	if root and not isfolder(root) then
		pcall(makefolder, root)
	end
	if not isfolder(ThemeManager.Folder) then
		pcall(makefolder, ThemeManager.Folder)
	end
end

local function colorToTable(c)
	return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
end

local function tableToColor(t, fallback)
	if type(t) == "table" and #t >= 3 then
		return Color3.fromRGB(t[1], t[2], t[3])
	end
	return fallback
end

function ThemeManager:SetLibrary(lib)
	self.Library = lib
	ensureFolders()
end

function ThemeManager:ApplyTheme(themeName)
	if not self.Library then return end
	local preset = self.Presets[themeName]
	if preset then
		self.CurrentTheme = themeName
		self.Library:UpdateTheme(preset)
		return
	end

	if hasFS() then
		local path = self.Folder .. "/" .. tostring(themeName) .. ".json"
		if isfile(path) then
			local ok, raw = pcall(readfile, path)
			if ok and raw then
				local decoded = nil
				pcall(function() decoded = HttpService:JSONDecode(raw) end)
				if type(decoded) == "table" then
					local base = self.Library.Theme
					local applied = {
						MainColor = tableToColor(decoded.MainColor, base.MainColor),
						SecondaryColor = tableToColor(decoded.SecondaryColor, base.SecondaryColor),
						GroupColor = tableToColor(decoded.GroupColor, base.GroupColor),
						OutlineDark = tableToColor(decoded.OutlineDark, base.OutlineDark),
						OutlineGrey = tableToColor(decoded.OutlineGrey, base.OutlineGrey),
						AccentColor = tableToColor(decoded.AccentColor, base.AccentColor),
						FontColor = tableToColor(decoded.FontColor, base.FontColor),
						MutedColor = tableToColor(decoded.MutedColor, base.MutedColor),
						Font = Enum.Font[decoded.Font] or base.Font
					}
					self.CurrentTheme = themeName
					self.Library:UpdateTheme(applied)
				end
			end
		end
	end
end

function ThemeManager:SaveCustomTheme(name)
	if not hasFS() or not self.Library or not name or name == "" then return false end
	ensureFolders()
	local t = self.Library.Theme
	local payload = {
		MainColor = colorToTable(t.MainColor),
		SecondaryColor = colorToTable(t.SecondaryColor),
		GroupColor = colorToTable(t.GroupColor),
		OutlineDark = colorToTable(t.OutlineDark),
		OutlineGrey = colorToTable(t.OutlineGrey),
		AccentColor = colorToTable(t.AccentColor),
		FontColor = colorToTable(t.FontColor),
		MutedColor = colorToTable(t.MutedColor),
		Font = t.Font.Name
	}
	local ok = pcall(writefile, self.Folder .. "/" .. name .. ".json", HttpService:JSONEncode(payload))
	return ok
end

function ThemeManager:GetThemeNames()
	local names = {}
	for k in pairs(self.Presets) do
		table.insert(names, k)
	end
	table.sort(names)

	if hasFS() and isfolder(self.Folder) then
		local ok, files = pcall(listfiles, self.Folder)
		if ok and type(files) == "table" then
			for _, filePath in ipairs(files) do
				local fileName = filePath:match("([^/\\]+)%.json$")
				if fileName and not self.Presets[fileName] then
					table.insert(names, fileName)
				end
			end
		end
	end
	return names
end

function ThemeManager:ApplyToTab(tab)
	if not self.Library or not tab then return end
	ensureFolders()

	local group = tab:AddGroupbox("Themes & Accent")
	local themeNames = self:GetThemeNames()
	local customName = ""

	local themeDropdown = group:AddDropdown("ThemeManager_Preset", {
		Text = "Theme Preset",
		Values = themeNames,
		Default = self.CurrentTheme,
		Callback = function(val)
			self:ApplyTheme(val)
		end
	})

	group:AddInput("ThemeManager_CustomName", {
		Text = "Custom Theme Name",
		Placeholder = "e.g. my_red_theme",
		Default = "",
		Callback = function(val)
			customName = val
		end
	})

	group:AddButton("Save Custom Theme", function()
		if customName ~= "" then
			if self:SaveCustomTheme(customName) then
				themeDropdown:Refresh(self:GetThemeNames(), customName)
			end
		end
	end)

	group:AddButton("Refresh Theme List", function()
		themeDropdown:Refresh(self:GetThemeNames(), self.CurrentTheme)
	end)
end

return ThemeManager
