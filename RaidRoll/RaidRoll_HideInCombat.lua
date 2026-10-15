--[[
	RaidRoll_HideInCombat.lua
	Optional "Hide in combat" feature: hides the roll window and the loot window
	while the player is in combat and shows them again afterwards.
	Option: RaidRoll_DBPC[player]["RR_RollCheckBox_HideInCombat"]
]]

local inCombat = false
local wanted = {}      -- frames that should be visible again after combat
local busy = false     -- guards against re-entrancy from our own Hide/Show calls

local function GetFrames()
	return { RR_RollFrame, RR_LOOT_FRAME }
end

local function OptionOn()
	local db = RaidRoll_DBPC and RaidRoll_DBPC[UnitName("player")]
	return db and db["RR_RollCheckBox_HideInCombat"] == true
end

local function HideForCombat(frame)
	if frame and frame:IsShown() then
		wanted[frame] = true
		busy = true
		frame:Hide()
		busy = false
	end
end

local function RestoreFrames()
	for frame in pairs(wanted) do
		wanted[frame] = nil
		busy = true
		frame:Show()
		busy = false
	end
end

-- Called from the options panel when the checkbox changes
function RR_HideInCombat_Update()
	if inCombat then
		if OptionOn() then
			for _, f in ipairs(GetFrames()) do HideForCombat(f) end
		else
			RestoreFrames()
		end
	end
end

local hooked = {}
local function HookShow(frame)
	if frame and not hooked[frame] then
		hooked[frame] = true
		-- Other code calls :Show() at any time (e.g. a new roll arrives in combat).
		-- Hide again right away and remember to show the frame after combat.
		hooksecurefunc(frame, "Show", function(self)
			if not busy and inCombat and OptionOn() then
				wanted[self] = true
				busy = true
				self:Hide()
				busy = false
			end
		end)
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		for _, fr in ipairs(GetFrames()) do HookShow(fr) end
		inCombat = UnitAffectingCombat("player") and true or false
	elseif event == "PLAYER_REGEN_DISABLED" then
		inCombat = true
		if OptionOn() then
			for _, fr in ipairs(GetFrames()) do HideForCombat(fr) end
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		inCombat = false
		RestoreFrames()
	end
end)
