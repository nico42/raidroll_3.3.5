--[[
	RaidRoll_Profiles.lua
	Profiles for the per-character options.

	Everything the addon stores per character lives in RaidRoll_DBPC[player].
	A profile is such a table. Profiles are stored account-wide in
	RaidRoll_DB["Profiles"][name]; RaidRoll_DB["ProfileKeys"][player] says which one
	a character uses. RR_Profiles_Init() makes RaidRoll_DBPC[player] point to the
	active profile table, so all existing code keeps working unchanged.

	Existing settings are migrated automatically: every character gets a profile
	named like itself, containing its current settings.

	Because the options panels read their values only while they are built,
	every change of the active profile asks for a UI reload.
]]

local de = (GetLocale() == "deDE")
local function T(en, ger) if de then return ger end return en end

------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------
local function DeepCopy(v, depth)
	depth = depth or 0
	if type(v) ~= "table" or depth > 20 then return v end
	local c = {}
	for k, val in pairs(v) do c[k] = DeepCopy(val, depth + 1) end
	return c
end

local function Wipe(t)
	for k in pairs(t) do t[k] = nil end
end

local function Profiles()  return RaidRoll_DB["Profiles"] end
local function PlayerName() return UnitName("player") end

------------------------------------------------------------------
-- Core
------------------------------------------------------------------
function RR_Profiles_Init()
	RaidRoll_DB = RaidRoll_DB or {}
	RaidRoll_DBPC = RaidRoll_DBPC or {}
	RaidRoll_DB["Profiles"] = RaidRoll_DB["Profiles"] or {}
	RaidRoll_DB["ProfileKeys"] = RaidRoll_DB["ProfileKeys"] or {}

	local char = PlayerName()
	local key = RaidRoll_DB["ProfileKeys"][char]
	if not key or not RaidRoll_DB["Profiles"][key] then
		-- first start (or the profile was deleted): adopt this character's existing settings
		key = char
		if not RaidRoll_DB["Profiles"][key] then
			RaidRoll_DB["Profiles"][key] = RaidRoll_DBPC[char] or {}
		end
		RaidRoll_DB["ProfileKeys"][char] = key
	end
	RaidRoll_DBPC[char] = RaidRoll_DB["Profiles"][key]
end

function RR_Profiles_GetCurrent()
	return RaidRoll_DB and RaidRoll_DB["ProfileKeys"] and RaidRoll_DB["ProfileKeys"][PlayerName()]
end

function RR_Profiles_List()
	local list = {}
	if RaidRoll_DB and RaidRoll_DB["Profiles"] then
		for name in pairs(RaidRoll_DB["Profiles"]) do list[#list + 1] = name end
	end
	table.sort(list, function(a, b) return a:lower() < b:lower() end)
	return list
end

local function CurrentTable()
	return RaidRoll_DB["Profiles"][RR_Profiles_GetCurrent()]
end

------------------------------------------------------------------
-- Export / import (own tiny text format, parsed without loadstring)
------------------------------------------------------------------
local PREFIX = "RR1:"

local function Ser(v, depth)
	local t = type(v)
	if t == "number" then
		return string.format("%.14g", v)
	elseif t == "boolean" then
		return v and "true" or "false"
	elseif t == "string" then
		return '"' .. v:gsub("[\\\"]", "\\%0"):gsub("\n", "\\n"):gsub("\r", "\\r") .. '"'
	elseif t == "table" and depth < 20 then
		local keys = {}
		for k in pairs(v) do
			if type(k) == "string" or type(k) == "number" then keys[#keys + 1] = k end
		end
		table.sort(keys, function(a, b)
			if type(a) == type(b) then return a < b end
			return type(a) == "number"
		end)
		local out = {}
		for _, k in ipairs(keys) do
			local val = v[k]
			local vt = type(val)
			if vt == "number" or vt == "boolean" or vt == "string" or vt == "table" then
				out[#out + 1] = Ser(k, depth + 1) .. "=" .. Ser(val, depth + 1)
			end
		end
		return "{" .. table.concat(out, ",") .. "}"
	end
	return "false"
end

function RR_Profiles_Export()
	return PREFIX .. Ser(CurrentTable(), 0)
end

-- Parser
local function Parse(s)
	local i, n = 1, #s
	local function ws()
		while i <= n and s:sub(i, i):match("%s") do i = i + 1 end
	end
	local value
	local function str()
		i = i + 1 -- opening quote
		local buf = {}
		while i <= n do
			local c = s:sub(i, i)
			if c == "\\" then
				local nx = s:sub(i + 1, i + 1)
				if nx == "n" then buf[#buf + 1] = "\n"
				elseif nx == "r" then buf[#buf + 1] = "\r"
				else buf[#buf + 1] = nx end
				i = i + 2
			elseif c == '"' then
				i = i + 1
				return table.concat(buf)
			else
				buf[#buf + 1] = c
				i = i + 1
			end
		end
		error("unterminated string")
	end
	function value(depth)
		if depth > 20 then error("too deep") end
		ws()
		local c = s:sub(i, i)
		if c == "{" then
			i = i + 1
			local t = {}
			ws()
			while s:sub(i, i) ~= "}" do
				if i > n then error("unterminated table") end
				local k = value(depth + 1)
				if type(k) ~= "string" and type(k) ~= "number" then error("bad key") end
				ws()
				if s:sub(i, i) ~= "=" then error("expected =") end
				i = i + 1
				t[k] = value(depth + 1)
				ws()
				if s:sub(i, i) == "," then i = i + 1 end
				ws()
			end
			i = i + 1
			return t
		elseif c == '"' then
			return str()
		elseif s:sub(i, i + 3) == "true" then
			i = i + 4
			return true
		elseif s:sub(i, i + 4) == "false" then
			i = i + 5
			return false
		else
			local num = s:match("^-?%d+%.?%d*[eE]?[+-]?%d*", i)
			if not num or num == "" then error("unexpected character at " .. i) end
			i = i + #num
			local v = tonumber(num)
			if not v then error("bad number") end
			return v
		end
	end
	local result = value(0)
	ws()
	if i <= n then error("trailing data") end
	return result
end

-- Returns the parsed table or nil, error
function RR_Profiles_ParseImport(text)
	text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if text:sub(1, #PREFIX) ~= PREFIX then return nil, "no RR1: header" end
	local ok, res = pcall(Parse, text:sub(#PREFIX + 1))
	if not ok then return nil, tostring(res) end
	if type(res) ~= "table" then return nil, "not a table" end
	return res
end

------------------------------------------------------------------
-- Actions (all of them require a UI reload afterwards)
------------------------------------------------------------------
local function ShowReload()
	StaticPopup_Show("RAIDROLL_PROFILE_RELOAD")
end

local function Confirm(text, func)
	StaticPopup_Show("RAIDROLL_PROFILE_CONFIRM", text, nil, { func = func })
end

local function ValidName(name)
	name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" or #name > 40 then return nil end
	return name
end

function RR_Profiles_Switch(name)
	if not RaidRoll_DB["Profiles"][name] or name == RR_Profiles_GetCurrent() then return end
	RaidRoll_DB["ProfileKeys"][PlayerName()] = name
	ShowReload()
end

function RR_Profiles_Create(name)
	name = ValidName(name)
	if not name then return false, T("Please enter a name (max. 40 characters).", "Bitte einen Namen eingeben (max. 40 Zeichen).") end
	if RaidRoll_DB["Profiles"][name] then return false, T("A profile with this name already exists.", "Ein Profil mit diesem Namen existiert bereits.") end
	RaidRoll_DB["Profiles"][name] = {}
	RaidRoll_DB["ProfileKeys"][PlayerName()] = name
	ShowReload()
	return true
end

function RR_Profiles_CopyFrom(name)
	local src = RaidRoll_DB["Profiles"][name]
	local dst = CurrentTable()
	if not src or src == dst then return end
	local copy = DeepCopy(src)
	Wipe(dst)
	for k, v in pairs(copy) do dst[k] = v end
	ShowReload()
end

function RR_Profiles_Delete(name)
	if name == RR_Profiles_GetCurrent() or not RaidRoll_DB["Profiles"][name] then return end
	RaidRoll_DB["Profiles"][name] = nil
end

function RR_Profiles_ResetCurrent()
	Wipe(CurrentTable())
	ShowReload()
end

function RR_Profiles_ImportInto(tbl)
	local dst = CurrentTable()
	Wipe(dst)
	for k, v in pairs(tbl) do dst[k] = v end
	ShowReload()
end

StaticPopupDialogs["RAIDROLL_PROFILE_RELOAD"] = {
	text = T("Raid Roll: the profile has changed. The UI has to be reloaded to apply it.",
	         "Raid Roll: Das Profil wurde geändert. Das UI muss neu geladen werden, um es anzuwenden."),
	button1 = T("Reload UI", "UI neu laden"),
	OnAccept = function() ReloadUI() end,
	timeout = 0,
	whileDead = 1,
	exclusive = 1,
	hideOnEscape = 0,
}

StaticPopupDialogs["RAIDROLL_PROFILE_CONFIRM"] = {
	text = "%s",
	button1 = YES,
	button2 = NO,
	OnAccept = function(self, data)
		if data and data.func then data.func() end
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}

------------------------------------------------------------------
-- Options panel (Interface Options > Raid Roll > Profiles)
------------------------------------------------------------------
local panel = CreateFrame("Frame", "RaidRoll_ProfilePanel", UIParent)
panel.name = T("Profiles", "Profile")
panel.parent = "Raid Roll"

-- the parent category is created later in Setup_RR_Panel(); register right after it
local registered = false
local function Register()
	if not registered then
		registered = true
		InterfaceOptions_AddCategory(panel)
	end
end
if RaidRoll_Panel and RaidRoll_Panel.panel then
	Register()
elseif Setup_RR_Panel then
	hooksecurefunc("Setup_RR_Panel", Register)
else
	Register()
end

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText(T("Profiles", "Profile"))

local current = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
current:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)

local function SetDDWidth(dd, w)
	if not pcall(UIDropDownMenu_SetWidth, dd, w) then
		pcall(UIDropDownMenu_SetWidth, w, dd)
	end
end

-- A dropdown whose entries trigger an action
local function MakeActionDropDown(name, label, y, getList, onPick)
	local lbl = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	lbl:SetPoint("TOPLEFT", 16, y)
	lbl:SetText(label)

	local dd = CreateFrame("Frame", name, panel, "UIDropDownMenuTemplate")
	dd:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", -16, -2)
	SetDDWidth(dd, 200)
	_G[name .. "Text"]:SetText(T("Select…", "Auswählen…"))

	UIDropDownMenu_Initialize(dd, function()
		if not RaidRoll_DB then return end
		for _, p in ipairs(getList()) do
			local info = {}
			info.text = p
			info.notCheckable = true
			info.func = function() CloseDropDownMenus(); onPick(p) end
			UIDropDownMenu_AddButton(info)
		end
	end)
	return dd
end

local function AllProfiles()
	local cur = RR_Profiles_GetCurrent()
	local list = {}
	for _, p in ipairs(RR_Profiles_List()) do
		list[#list + 1] = p
	end
	return list
end
local function OtherProfiles()
	local cur = RR_Profiles_GetCurrent()
	local list = {}
	for _, p in ipairs(RR_Profiles_List()) do
		if p ~= cur then list[#list + 1] = p end
	end
	return list
end

MakeActionDropDown("RR_Profile_SwitchDD", T("Switch profile", "Profil wechseln"), -70, AllProfiles, function(p)
	RR_Profiles_Switch(p)
end)

-- New profile
local newLbl = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
newLbl:SetPoint("TOPLEFT", 16, -130)
newLbl:SetText(T("New profile", "Neues Profil"))

local nameBox = CreateFrame("EditBox", "RR_Profile_NameBox", panel, "InputBoxTemplate")
nameBox:SetWidth(170)
nameBox:SetHeight(20)
nameBox:SetPoint("TOPLEFT", newLbl, "BOTTOMLEFT", 6, -6)
nameBox:SetAutoFocus(false)
nameBox:SetMaxLetters(40)

local createBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
createBtn:SetWidth(100)
createBtn:SetHeight(22)
createBtn:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)
createBtn:SetText(T("Create", "Erstellen"))

local msg = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
msg:SetPoint("TOPLEFT", 22, -178)
msg:SetTextColor(1, 0.3, 0.3)

local function DoCreate()
	local ok, err = RR_Profiles_Create(nameBox:GetText())
	if ok then
		nameBox:SetText("")
		msg:SetText("")
	else
		msg:SetText(err or "")
	end
end
createBtn:SetScript("OnClick", DoCreate)
nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); DoCreate() end)
nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

MakeActionDropDown("RR_Profile_CopyDD", T("Copy settings from…", "Einstellungen kopieren von…"), -195, OtherProfiles, function(p)
	Confirm(string.format(T("Overwrite the settings of the current profile with those of \"%s\"?",
	                        "Die Einstellungen des aktuellen Profils mit denen von \"%s\" überschreiben?"), p),
	        function() RR_Profiles_CopyFrom(p) end)
end)

MakeActionDropDown("RR_Profile_DeleteDD", T("Delete profile", "Profil löschen"), -255, OtherProfiles, function(p)
	Confirm(string.format(T("Delete the profile \"%s\"?", "Das Profil \"%s\" löschen?"), p),
	        function() RR_Profiles_Delete(p) end)
end)

local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
resetBtn:SetWidth(200)
resetBtn:SetHeight(22)
resetBtn:SetPoint("TOPLEFT", 20, -320)
resetBtn:SetText(T("Reset current profile", "Aktuelles Profil zurücksetzen"))
resetBtn:SetScript("OnClick", function()
	Confirm(T("Reset the current profile to the default settings?", "Das aktuelle Profil auf Standardeinstellungen zurücksetzen?"),
	        function() RR_Profiles_ResetCurrent() end)
end)

-- Export / Import
local exLbl = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
exLbl:SetPoint("TOPLEFT", 16, -358)
exLbl:SetText(T("Export / Import (current profile)", "Export / Import (aktuelles Profil)"))

local box = CreateFrame("Frame", nil, panel)
box:SetPoint("TOPLEFT", 16, -378)
box:SetWidth(520)
box:SetHeight(96)
box:SetBackdrop({
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 14,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
box:SetBackdropColor(0, 0, 0, 0.6)

local sf = CreateFrame("ScrollFrame", "RR_Profile_ScrollFrame", box, "UIPanelScrollFrameTemplate")
sf:SetPoint("TOPLEFT", 6, -6)
sf:SetPoint("BOTTOMRIGHT", -28, 6)

local eb = CreateFrame("EditBox", "RR_Profile_ExportBox", sf)
eb:SetMultiLine(true)
eb:SetAutoFocus(false)
eb:SetFontObject(ChatFontNormal)
eb:SetWidth(480)
eb:SetMaxLetters(0)
eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
eb:SetScript("OnTextChanged", function(self) sf:UpdateScrollChildRect() end)
sf:SetScrollChild(eb)

local exportBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
exportBtn:SetWidth(120)
exportBtn:SetHeight(22)
exportBtn:SetPoint("TOPLEFT", 20, -480)
exportBtn:SetText(T("Export", "Exportieren"))
exportBtn:SetScript("OnClick", function()
	eb:SetText(RR_Profiles_Export())
	eb:HighlightText()
	eb:SetFocus()
	msg:SetText("")
end)

local importBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
importBtn:SetWidth(120)
importBtn:SetHeight(22)
importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 8, 0)
importBtn:SetText(T("Import", "Importieren"))
importBtn:SetScript("OnClick", function()
	local tbl, err = RR_Profiles_ParseImport(eb:GetText())
	if not tbl then
		msg:SetText(T("Import failed: ", "Import fehlgeschlagen: ") .. tostring(err))
		return
	end
	msg:SetText("")
	Confirm(T("Overwrite the settings of the current profile with the imported ones?",
	          "Die Einstellungen des aktuellen Profils mit den importierten überschreiben?"),
	        function() RR_Profiles_ImportInto(tbl) end)
end)

panel:SetScript("OnShow", function()
	current:SetText(T("Current profile: ", "Aktuelles Profil: ") .. "|cff00ff00" .. tostring(RR_Profiles_GetCurrent() or "?") .. "|r")
	msg:SetText("")
end)
