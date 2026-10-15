--[[
	RaidRoll_HideInCombat.lua
	Optional "Hide in combat" feature.

	- "Hide in combat" (RR_RollCheckBox_HideInCombat): the roll window and the
	  loot window are hidden ONCE per fight.
	- "Only boss fights" (RR_RollCheckBox_HideBossOnly): the windows are hidden
	  once, as soon as a boss fight is detected (instead of at combat start).
	- If a window is shown again during the fight (e.g. because of a roll),
	  it stays visible until the fight ends.
	- When the fight ends, the windows that were hidden by this feature are
	  shown again.
]]

local inCombat = false
local hiddenThisFight = false   -- hidden once already? (only once per fight)
local wanted = {}               -- frames hidden by us, to be restored after the fight
local CHECK_INTERVAL = 0.5

local function GetFrames()
	return { RR_RollFrame, RR_LOOT_FRAME }
end

local function Opt(key)
	local db = RaidRoll_DBPC and RaidRoll_DBPC[UnitName("player")]
	return db and db[key] == true
end

local function OptionOn()   return Opt("RR_RollCheckBox_HideInCombat") end
local function BossOnly()   return Opt("RR_RollCheckBox_HideBossOnly") end

------------------------------------------------------------------
-- Boss detection
------------------------------------------------------------------
local function IsBossUnit(unit)
	if not UnitExists(unit) or UnitIsDead(unit) or UnitIsPlayer(unit) then return false end
	if not UnitCanAttack("player", unit) then return false end
	local class = UnitClassification(unit)
	if class == "worldboss" then return true end
	local level = UnitLevel(unit)
	if level == -1 then return true end   -- skull / "??"
	-- heroic dungeon bosses: elite, clearly above the player's level
	if (class == "elite" or class == "rareelite") and level and level >= UnitLevel("player") + 2 then
		return true
	end
	return false
end

local function BossFightActive()
	for i = 1, 4 do
		if UnitExists("boss" .. i) then return true end
	end
	if IsBossUnit("target") or IsBossUnit("focus") then return true end
	for i = 1, GetNumRaidMembers() do
		if IsBossUnit("raid" .. i .. "target") then return true end
	end
	for i = 1, GetNumPartyMembers() do
		if IsBossUnit("party" .. i .. "target") then return true end
	end
	return false
end

------------------------------------------------------------------
-- Hide / restore
------------------------------------------------------------------
local function HideAll()
	hiddenThisFight = true
	for _, frame in ipairs(GetFrames()) do
		if frame and frame:IsShown() then
			wanted[frame] = true
			frame:Hide()
		end
	end
end

local function RestoreAll()
	for frame in pairs(wanted) do
		wanted[frame] = nil
		if not frame:IsShown() then frame:Show() end
	end
end

------------------------------------------------------------------
-- Boss check while in combat (only needed in "boss only" mode)
------------------------------------------------------------------
local ticker = CreateFrame("Frame")
ticker:Hide()
local elapsed = 0

local function Evaluate()
	if not inCombat or hiddenThisFight or not OptionOn() then return end
	if not BossOnly() or BossFightActive() then
		HideAll()
	end
end

ticker:SetScript("OnUpdate", function(self, dt)
	elapsed = elapsed + dt
	if elapsed < CHECK_INTERVAL then return end
	elapsed = 0
	if not inCombat or hiddenThisFight or not OptionOn() then
		self:Hide()
		return
	end
	Evaluate()
	if hiddenThisFight then self:Hide() end
end)

local function StartFight()
	inCombat = true
	hiddenThisFight = false
	elapsed = 0
	if OptionOn() then
		Evaluate()
		if not hiddenThisFight then ticker:Show() end
	end
end

-- Called from the options panel when a checkbox changes
function RR_HideInCombat_Update()
	if not inCombat then return end
	if not OptionOn() then
		ticker:Hide()
		RestoreAll()
	elseif not hiddenThisFight then
		Evaluate()
		if not hiddenThisFight then ticker:Show() end
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		if UnitAffectingCombat("player") then StartFight() end
	elseif event == "PLAYER_REGEN_DISABLED" then
		StartFight()
	elseif event == "PLAYER_REGEN_ENABLED" then
		inCombat = false
		hiddenThisFight = false
		ticker:Hide()
		RestoreAll()
	end
end)
