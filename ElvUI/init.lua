--[[
    ElvQuestButton - ElvUI Module Initialization
    
    Registers as an ElvUI plugin and sets up the module.
    This file MUST load before addon.lua finishes to set elvuiManaged flag.
]]

local addonName, addon = ...

-- Early exit if ElvUI is not loaded
if not _G.ElvUI then return end

local E, L, V, P, G = unpack(_G.ElvUI)
local EP = E.Libs.EP

-- Create module
local EQB = E:NewModule('ElvQuestButton', 'AceEvent-3.0')
addon.ElvUIModule = EQB

-- Module defaults (stored in ElvUI GLOBAL DB now, so settings persist across profiles)
local moduleDefaults = {
    enable = true,
    scale = 1,
    alpha = 1,
    artworkAlpha = 0,  -- Hidden when using ElvUI skinning
    noCooldownText = false,
    trackingOnly = false,
    zoneOnly = false,
    distanceYd = 1000,
    inheritGlobalFade = false,
    autoLockOnUse = true,
    scrollToSwitch = true,
    
    -- Fonts & Text
    countFont = 'Expressway',
    countFontSize = 12,
    countFontOutline = 'OUTLINE',
    countXOffset = 0,
    countYOffset = 0,
    
    hotkeyFont = 'Expressway',
    hotkeyFontSize = 14,
    hotkeyFontOutline = 'OUTLINE',
    hotkeyXOffset = 0,
    hotkeyYOffset = 0,
    
    -- Features
    lockScale = 1,
    
    -- Item Count Badge
    itemCountFontSize = 12,
    itemCountBadge = 'NONE',
    
    -- Migration Flag
    migratedFromProfile = false,
}

-- Add to ElvUI GLOBAL defaults (shared across all profiles)
G.elvQuestButton = CopyTable(moduleDefaults)

-- Module state
EQB.initialized = false
EQB.holder = nil

-- Debug helper
local DEBUG = false
local function Debug(...)
    if DEBUG then
        print("|cff00ff00[ElvQuestButton]|r", ...)
    end
end
EQB.Debug = Debug

-- Database accessor (Switch to GLOBAL)
function EQB:GetDB()
    if E.global and E.global.elvQuestButton then
        return E.global.elvQuestButton
    end
    return E.db.elvQuestButton or moduleDefaults -- Fallback during init
end

-- Mark button as ElvUI-managed IMMEDIATELY
-- This runs before addon.lua's delayed initialization check
local function MarkButtonManaged()
    local button = _G.ElvQuestButton or _G[addonName]
    if button then
        button.elvuiManaged = true
        Debug("Marked button as ElvUI-managed")
    else
        -- Button doesn't exist yet, try again soon
        C_Timer.After(0.1, MarkButtonManaged)
    end
end

-- Start trying to mark immediately
MarkButtonManaged()

-- Migration Logic: Restore settings from best available profile if Global is fresh
function EQB:AttemptMigration()
    local globalDB = E.global.elvQuestButton
    if not globalDB or globalDB.migratedFromProfile then return end
    
    Debug("Attempting migration to Global DB...")
    
    local bestProfile = nil
    local maxDiffCount = -1
    
    -- Helper to count non-default settings
    local function CountDifferences(profileSettings)
        if not profileSettings then return -1 end
        local count = 0
        for k, v in pairs(moduleDefaults) do
            -- Check if setting exists in profile and differs from default
            if profileSettings[k] ~= nil and profileSettings[k] ~= v then
                count = count + 1
            end
        end
        return count
    end
    
    -- Scan all profiles in ElvUI DB to find the most customized one
    if E.data and E.data.profiles then
        for key, profile in pairs(E.data.profiles) do
            if profile.elvQuestButton then
                local diffs = CountDifferences(profile.elvQuestButton)
                if diffs > maxDiffCount then
                    maxDiffCount = diffs
                    bestProfile = profile.elvQuestButton
                    Debug("Found candidate profile: " .. key .. " (Changes: " .. diffs .. ")")
                end
            end
        end
    end
    
    -- If no profile found in raw data (fresh install?), try current E.db as fallback
    if not bestProfile and E.db.elvQuestButton then
         bestProfile = E.db.elvQuestButton
    end

    if bestProfile then
        for k, v in pairs(bestProfile) do
            -- Copy only valid keys defined in defaults to avoid garbage
            if moduleDefaults[k] ~= nil then
                globalDB[k] = v
            end
        end
        
        if maxDiffCount > 0 then
             print("|cff00ff00[ElvQuestButton]|r Settings migrated to Global Profile.")
        end
    else
        Debug("No profile settings found, using defaults")
    end
    
    -- Mark as migrated so we don't overwrite user's Global changes later
    globalDB.migratedFromProfile = true
end

-- Module initialization (called by ElvUI)
function EQB:Initialize()
    if self.initialized then return end
    
    local button = _G.ElvQuestButton or _G[addonName]
    if not button then
        Debug("Button not found, retrying...")
        C_Timer.After(0.5, function() self:Initialize() end)
        return
    end
    
    -- Ensure button is marked
    button.elvuiManaged = true
    
    -- Initialize global database if missing (should be handled by ElvUI G table, but safe to ensure)
    if not E.global.elvQuestButton then
        E.global.elvQuestButton = CopyTable(moduleDefaults)
    end
    
    -- Attempt migration from Profile -> Global
    self:AttemptMigration()
    
    Debug("Initializing ElvUI module")
    
    -- Create holder and mover
    self:CreateHolder()
    
    -- Reparent and skin button
    self:SetupButton()
    
    -- Register with ElvUI /kb keybind system (separate from skinning)
    self:SetupKeybind()
    
    -- Apply updates
    self:UpdateButton()
    
    -- Apply WindTools shadow (delayed)
    C_Timer.After(1, function()
        self:ApplyShadow()
    end)
    
    -- Register for profile changes
    -- Even though settings are global, we still update on profile change 
    -- because the MOVER (position) is profile-specific and changes.
    self:RegisterMessage('ElvUI_ProfileChanged', 'OnProfileChanged')
    self:RegisterMessage('ElvUI_PrivateProfileChanged', 'OnProfileChanged')
    
    self.initialized = true
    Debug("ElvUI module initialized")
end

-- Profile change handler
function EQB:OnProfileChanged()
    -- Mover position changed, but settings are now Global.
    -- We just need to ensure the button draws correctly.
    self:UpdateButton()
end

-- Override addon's settings accessor
function addon:GetCurrentSettings()
    if EQB.initialized then
        return EQB:GetDB()
    end
    
    -- Fallback: Use Global DB
    if E and E.global and E.global.elvQuestButton then
        return E.global.elvQuestButton
    end
    
    return addon.DEFAULTS
end

-- ElvUI Plugin registration
local function OptionsCallback()
    -- Options are inserted in options.lua
    addon.ElvUIModule:InsertOptions()
end

EP:RegisterPlugin(addonName, OptionsCallback)

-- Initialize after PLAYER_LOGIN
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- Initialize after a short delay to ensure everything is ready
        C_Timer.After(0.5, function()
            if InCombatLockdown() then
                -- Defend against combat lockout by waiting for RegenEnabled
                EQB:RegisterEvent("PLAYER_REGEN_ENABLED", function(event)
                    EQB:UnregisterEvent(event)
                    EQB:Initialize()
                end)
            else
                EQB:Initialize()
            end
        end)
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

Debug("ElvUI init module loaded")
