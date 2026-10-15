--[[
	RaidRoll_Style.lua
	Appearance options for the Raid Roll window (RR_RollFrame) and the
	Loot Tracker window (RR_LOOT_FRAME): background texture, border texture,
	border thickness, background colour/alpha, border colour/alpha.
	Settings are shared by both windows and stored per character in
	RaidRoll_DBPC[player]["RR_Style"]. With everything on "Default" the
	original look of the addon is used unchanged.
]]

local de = (GetLocale() == "deDE")
local function T(en, ger) if de then return ger end return en end

------------------------------------------------------------------
-- Original looks (what the XML / Lua files set up)
------------------------------------------------------------------
local ORIG = {
	RR_RollFrame = {
		bgFile = "Interface\\Addons\\RaidRoll\\Images\\Teldrassil",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = false, tileSize = 32, edgeSize = 20, inset = 4,
	},
	RR_LOOT_FRAME = {
		bgFile = "Interface\\Addons\\RaidRoll\\Images\\Lich_King",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = false, tileSize = 32, edgeSize = 20, inset = 2,
	},
}

local BG_PRESETS = {
	{ key = "default",    name = T("Default (per window)", "Standard (pro Fenster)") },
	{ key = "teldrassil", name = "Teldrassil",  path = "Interface\\Addons\\RaidRoll\\Images\\Teldrassil" },
	{ key = "lichking",   name = "Lich King",   path = "Interface\\Addons\\RaidRoll\\Images\\Lich_King" },
	{ key = "dialog",     name = T("Dialog", "Dialog"), path = "Interface\\DialogFrame\\UI-DialogBox-Background" },
	{ key = "tooltip",    name = "Tooltip",     path = "Interface\\Tooltips\\UI-Tooltip-Background" },
	{ key = "solid",      name = T("Solid colour", "Einfarbig"), path = "Interface\\Buttons\\WHITE8X8" },
}
local EDGE_PRESETS = {
	{ key = "default", name = T("Default", "Standard") },
	{ key = "tooltip", name = "Tooltip", path = "Interface\\Tooltips\\UI-Tooltip-Border" },
	{ key = "dialog",  name = T("Dialog", "Dialog"), path = "Interface\\DialogFrame\\UI-DialogBox-Border" },
	{ key = "thin",    name = T("Solid line", "Einfache Linie"), path = "Interface\\Buttons\\WHITE8X8" },
	{ key = "none",    name = T("No border", "Kein Rahmen") },
}

------------------------------------------------------------------
-- Settings access
------------------------------------------------------------------
local function GetStyle()
	if not RaidRoll_DBPC then return nil end
	local name = UnitName("player")
	RaidRoll_DBPC[name] = RaidRoll_DBPC[name] or {}
	local s = RaidRoll_DBPC[name]["RR_Style"]
	if not s then
		s = {}
		RaidRoll_DBPC[name]["RR_Style"] = s
	end
	s.bg = s.bg or "default"
	s.edge = s.edge or "default"
	s.bgColor = s.bgColor or {1, 1, 1, 1}
	s.edgeColor = s.edgeColor or {1, 1, 1, 1}
	return s
end

local function GetLSM()
	return LibStub and LibStub("LibSharedMedia-3.0", true)
end

local function Resolve(presets, key, mediaType)
	if type(key) == "string" and key:sub(1, 4) == "lsm:" then
		local lsm = GetLSM()
		if lsm then
			return lsm:Fetch(mediaType, key:sub(5), true), true
		end
		return nil
	end
	for _, p in ipairs(presets) do
		if p.key == key then return p.path, p.key ~= "default" end
	end
end

local function DisplayName(presets, key)
	if type(key) == "string" and key:sub(1, 4) == "lsm:" then return key:sub(5) end
	for _, p in ipairs(presets) do
		if p.key == key then return p.name end
	end
	return key
end

------------------------------------------------------------------
-- Apply to the windows
------------------------------------------------------------------
local styleApplied = false

function RR_ApplyStyle()
	local s = GetStyle()
	if not s then return end
	local function IsWhite(c) return c[1] == 1 and c[2] == 1 and c[3] == 1 and c[4] == 1 end
	local isDefault = (s.bg == "default" and s.edge == "default" and s.edgeSize == nil
		and IsWhite(s.bgColor) and IsWhite(s.edgeColor))
	-- nothing to do while the original look is still untouched
	if isDefault and not styleApplied then return end
	styleApplied = not isDefault
	for frameName, o in pairs(ORIG) do
		local frame = _G[frameName]
		if frame and frame.SetBackdrop then
			local bd = {
				bgFile = o.bgFile, edgeFile = o.edgeFile,
				tile = o.tile, tileSize = o.tileSize, edgeSize = o.edgeSize,
				insets = { left = o.inset, right = o.inset, top = o.inset, bottom = o.inset },
			}
			-- colours always apply (white = original look)
			local bgColor, edgeColor = s.bgColor, s.edgeColor

			if s.bg ~= "default" then
				local path = Resolve(BG_PRESETS, s.bg, "background")
				if path then bd.bgFile = path end
			end

			if s.edge == "none" then
				bd.edgeFile = nil
				bd.insets = { left = 0, right = 0, top = 0, bottom = 0 }
			else
				if s.edge ~= "default" then
					local path = Resolve(EDGE_PRESETS, s.edge, "border")
					if path then bd.edgeFile = path end
				end
				if s.edgeSize then
					bd.edgeSize = s.edgeSize
					local inset = math.max(1, math.floor(s.edgeSize / 5))
					bd.insets = { left = inset, right = inset, top = inset, bottom = inset }
				end
			end

			frame:SetBackdrop(bd)
			frame:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
			if bd.edgeFile then
				frame:SetBackdropBorderColor(edgeColor[1], edgeColor[2], edgeColor[3], edgeColor[4])
			end
		end
	end
end

------------------------------------------------------------------
-- Options panel (Interface Options > Raid Roll > Appearance)
------------------------------------------------------------------
local panel = CreateFrame("Frame", "RaidRoll_StylePanel", UIParent)
panel.name = T("Appearance", "Aussehen")
panel.parent = "Raid Roll"
InterfaceOptions_AddCategory(panel)

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText(T("Window appearance", "Fensteraussehen"))

local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
sub:SetText(T("Applies to the Raid Roll window and the Loot window.",
              "Gilt für das Wurf-Fenster und das Beute-Fenster."))

local function SetDDWidth(dd, w)
	-- the argument order of this helper differs between client versions
	if not pcall(UIDropDownMenu_SetWidth, dd, w) then
		pcall(UIDropDownMenu_SetWidth, w, dd)
	end
end

local function MakeDropDown(name, label, y, presets, mediaType, field)
	local lbl = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	lbl:SetPoint("TOPLEFT", 16, y)
	lbl:SetText(label)

	local dd = CreateFrame("Frame", name, panel, "UIDropDownMenuTemplate")
	dd:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", -16, -2)
	SetDDWidth(dd, 190)
	local text = _G[name .. "Text"]

	local function Pick(key)
		local s = GetStyle()
		if not s then return end
		s[field] = key
		text:SetText(DisplayName(presets, key))
		RR_ApplyStyle()
	end

	UIDropDownMenu_Initialize(dd, function()
		local s = GetStyle()
		local current = s and s[field]
		local function Add(key, nameText)
			local info = {}
			info.text = nameText
			info.checked = (current == key)
			info.func = function() Pick(key); CloseDropDownMenus() end
			UIDropDownMenu_AddButton(info)
		end
		for _, p in ipairs(presets) do Add(p.key, p.name) end
		local lsm = GetLSM()
		if lsm then
			for _, n in ipairs(lsm:List(mediaType)) do Add("lsm:" .. n, n) end
		end
	end)

	dd.Refresh = function()
		local s = GetStyle()
		if s then text:SetText(DisplayName(presets, s[field])) end
	end
	return dd
end

local ddBG   = MakeDropDown("RR_Style_BGDropDown",   T("Background texture", "Hintergrund-Textur"), -70,  BG_PRESETS,   "background", "bg")
local ddEdge = MakeDropDown("RR_Style_EdgeDropDown", T("Border texture", "Rahmen-Textur"),          -130, EDGE_PRESETS, "border",     "edge")

-- Border thickness
local slider = CreateFrame("Slider", "RR_Style_EdgeSize", panel, "OptionsSliderTemplate")
slider:SetPoint("TOPLEFT", 20, -215)
slider:SetWidth(200)
slider:SetMinMaxValues(1, 32)
slider:SetValueStep(1)
_G["RR_Style_EdgeSizeLow"]:SetText("1")
_G["RR_Style_EdgeSizeHigh"]:SetText("32")
local sliderLoading = false
slider:SetScript("OnValueChanged", function(self, value)
	value = math.floor(value + 0.5)
	_G["RR_Style_EdgeSizeText"]:SetText(T("Border thickness: ", "Rahmendicke: ") .. value)
	if sliderLoading then return end
	local s = GetStyle()
	if s then
		s.edgeSize = value
		RR_ApplyStyle()
	end
end)

-- Colour buttons
local function MakeColorButton(label, x, y, field)
	local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	btn:SetWidth(160)
	btn:SetHeight(22)
	btn:SetPoint("TOPLEFT", x, y)
	btn:SetText(label)

	local sw = btn:CreateTexture(nil, "OVERLAY")
	sw:SetWidth(14)
	sw:SetHeight(14)
	sw:SetPoint("LEFT", btn, "RIGHT", 6, 0)
	sw:SetTexture("Interface\\Buttons\\WHITE8X8")

	btn.Refresh = function()
		local s = GetStyle()
		if s then
			local c = s[field]
			sw:SetVertexColor(c[1], c[2], c[3])
		end
	end

	btn:SetScript("OnClick", function()
		local s = GetStyle()
		if not s then return end
		local c = s[field]
		local prev = { r = c[1], g = c[2], b = c[3], a = c[4] }
		ColorPickerFrame:Hide()
		ColorPickerFrame.hasOpacity = true
		ColorPickerFrame.opacity = 1 - c[4]
		ColorPickerFrame.previousValues = prev
		ColorPickerFrame.func = function()
			local r, g, b = ColorPickerFrame:GetColorRGB()
			c[1], c[2], c[3] = r, g, b
			btn.Refresh()
			RR_ApplyStyle()
		end
		ColorPickerFrame.opacityFunc = function()
			c[4] = 1 - OpacitySliderFrame:GetValue()
			RR_ApplyStyle()
		end
		ColorPickerFrame.cancelFunc = function(p)
			p = p or prev
			c[1], c[2], c[3], c[4] = p.r, p.g, p.b, p.a
			btn.Refresh()
			RR_ApplyStyle()
		end
		ColorPickerFrame:SetColorRGB(c[1], c[2], c[3])
		ColorPickerFrame:Show()
	end)
	return btn
end

local btnBG   = MakeColorButton(T("Background colour…", "Hintergrundfarbe…"), 20, -265, "bgColor")
local btnEdge = MakeColorButton(T("Border colour…", "Rahmenfarbe…"),           20, -295, "edgeColor")

-- Tooltip at cursor (Raid Roll / Loot Tracker tooltips only)
local ttCheck = CreateFrame("CheckButton", "RR_RollCheckBox_TooltipAtCursor", panel, "UICheckButtonTemplate")
ttCheck:SetWidth(22)
ttCheck:SetHeight(22)
ttCheck:SetPoint("TOPLEFT", 16, -345)
_G["RR_RollCheckBox_TooltipAtCursorText"]:SetText(T("Tooltips at the mouse cursor", "Tooltips an der Maus"))
ttCheck:SetScript("OnClick", function(self)
	local name = UnitName("player")
	if RaidRoll_DBPC then
		RaidRoll_DBPC[name] = RaidRoll_DBPC[name] or {}
		RaidRoll_DBPC[name]["RR_RollCheckBox_TooltipAtCursor"] = self:GetChecked() and true or false
	end
end)
ttCheck:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText(T("Shows the tooltips of Raid Roll and Loot Tracker at the mouse cursor. Other addons are not affected.",
	                      "Zeigt die Tooltips von Raid Roll und Loot Tracker am Mauszeiger. Andere Addons sind nicht betroffen."), 1, 1, 1, 1, true)
end)
ttCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Reset
local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
reset:SetWidth(160)
reset:SetHeight(22)
reset:SetPoint("TOPLEFT", 20, -385)
reset:SetText(T("Reset to default", "Auf Standard zurücksetzen"))
reset:SetScript("OnClick", function()
	local s = GetStyle()
	if not s then return end
	s.bg, s.edge, s.edgeSize = "default", "default", nil
	s.bgColor, s.edgeColor = {1, 1, 1, 1}, {1, 1, 1, 1}
	panel.Refresh()
	RR_ApplyStyle()
end)

function panel.Refresh()
	local s = GetStyle()
	if not s then return end
	ddBG.Refresh()
	ddEdge.Refresh()
	sliderLoading = true
	slider:SetValue(s.edgeSize or ORIG.RR_RollFrame.edgeSize)
	sliderLoading = false
	_G["RR_Style_EdgeSizeText"]:SetText(T("Border thickness: ", "Rahmendicke: ") .. (s.edgeSize or ORIG.RR_RollFrame.edgeSize))
	btnBG.Refresh()
	btnEdge.Refresh()
	local db = RaidRoll_DBPC and RaidRoll_DBPC[UnitName("player")]
	ttCheck:SetChecked(db and db["RR_RollCheckBox_TooltipAtCursor"] == true)
end
panel.refresh = panel.Refresh
panel:SetScript("OnShow", panel.Refresh)

-- Apply the saved style once all addons (incl. the Loot Tracker) have built their frames
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
	RR_ApplyStyle()
end)
