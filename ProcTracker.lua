local ProcTracker = CreateFrame("Frame")

-- Some client versions use different spell IDs for Aura of the Blue Dragon.
-- 23684 is used on Classic clients while retail clients can report 1213422.
local BLUE_DRAGON_AURA_IDS = {
    [23684] = true,
    [1213422] = true,
}

ProcTracker.sessionCasts = 0
ProcTracker.sessionProcs = 0

-- Table storing information for each instance entered during the current session
-- { zone = string, casts = number, procs = number }
ProcTracker.instances = {}

-- Holds the table of the instance the player is currently in, or nil when
-- outside of an instance.
ProcTracker.currentInstance = nil

ProcTracker.inInstance = false
ProcTracker.currentZone = nil

local function StartNewInstance(zone)
    local data = { zone = zone or "Unknown", casts = 0, procs = 0 }
    table.insert(ProcTracker.instances, data)
    ProcTracker.currentInstance = data
end

ProcTracker:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
ProcTracker:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
ProcTracker:RegisterEvent("PLAYER_ENTERING_WORLD")

ProcTracker:SetScript("OnEvent", function(self, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit = ...
        if unit == "player" then
            ProcTracker.sessionCasts = ProcTracker.sessionCasts + 1
            if ProcTracker.currentInstance then
                ProcTracker.currentInstance.casts = ProcTracker.currentInstance.casts + 1
            end
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellId = CombatLogGetCurrentEventInfo()
        if subevent == "SPELL_AURA_APPLIED" and BLUE_DRAGON_AURA_IDS[spellId] and destGUID == UnitGUID("player") then
            ProcTracker.sessionProcs = ProcTracker.sessionProcs + 1
            if ProcTracker.currentInstance then
                ProcTracker.currentInstance.procs = ProcTracker.currentInstance.procs + 1
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        local inInstance = IsInInstance()
        local zone = GetRealZoneText()
        if inInstance then
            if not ProcTracker.inInstance or zone ~= ProcTracker.currentZone then
                StartNewInstance(zone)
            end
            ProcTracker.inInstance = true
        else
            ProcTracker.inInstance = false
            ProcTracker.currentInstance = nil
        end
        ProcTracker.currentZone = zone
    end
end)

SLASH_PROCTRACKER1 = "/proctracker"
SlashCmdList["PROCTRACKER"] = function(msg)
    print(string.format("Session Casts: %d, Session Procs: %d", ProcTracker.sessionCasts, ProcTracker.sessionProcs))
    for i, inst in ipairs(ProcTracker.instances) do
        print(string.format("Instance %d (%s): Casts: %d, Procs: %d", i, inst.zone, inst.casts, inst.procs))
    end
end
