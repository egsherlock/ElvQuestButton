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

-- Module defaults (stored in ElvUI profile)
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
    
    -- Fonts & Text
    countFont = 'Expressway',
    countFontSize = 16,
    countFontOutline = 'OUTLINE',
    countXOffset = 0,
    countYOffset = 0,
    
    hotkeyFont = 'Expressway',
    hotkeyFontSize = 16,
    hotkeyFontOutline = 'OUTLINE',
    hotkeyXOffset = 0,
    hotkeyYOffset = 0,
    
    -- Features
    lockScale = 1,
}

-- Add to ElvUI profile defaults
P.elvQuestButton = CopyTable(moduleDefaults)

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

-- Database accessor
function EQB:GetDB()
    return E.db.elvQuestButton
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
    
    -- Initialize database
    if not E.db.elvQuestButton then
        E.db.elvQuestButton = CopyTable(moduleDefaults)
    end
    
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
    self:RegisterMessage('ElvUI_ProfileChanged', 'OnProfileChanged')
    self:RegisterMessage('ElvUI_PrivateProfileChanged', 'OnProfileChanged')
    
    self.initialized = true
    Debug("ElvUI module initialized")
end

-- Profile change handler
function EQB:OnProfileChanged()
    self:UpdateButton()
end

-- Override addon's settings accessor
function addon:GetCurrentSettings()
    if EQB.initialized then
        return EQB:GetDB()
    end
    
    -- Fallback: If ElvUI is loaded and DB exists, use it even if not fully initialized
    if E and E.db and E.db.elvQuestButton then
        return E.db.elvQuestButton
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
            EQB:Initialize()
        end)
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

Debug("ElvUI init module loaded")
