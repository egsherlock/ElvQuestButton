--[[
    ElvQuestButton - Main Entry Point
    
    This file initializes the button and defers to either:
    - ElvUI module (if ElvUI is present)
    - Standalone module (LibEditMode fallback)
    
    The quest item logic is in core.lua.
    Original addon by p3lim, ElvUI integration by Sherlockell.
]]

local addonName, addon = ...

local L = addon.L
local data = addon.data

-- Create the extra button using the template from button.lua
local button = addon:CreateExtraButton('QuickKeybindButtonTemplate, SecureActionButtonTemplate, SecureHandlerStateTemplate, SecureHandlerAttributeTemplate')

-- Store button reference globally for ElvUI/standalone modules to access
_G.ElvQuestButton = button
_G[addonName] = button

-- Mix in core quest logic
Mixin(button, addon.coreMixin)

-- Button initialization
function button:OnLoad()
    self:Hide()
    
    -- Add ItemMixin API
    Mixin(self, ItemMixin)
    
    -- Set action type
    self:SetAttribute('type', 'item')
    
    -- Initialize combat state flag
    self.inCombat = InCombatLockdown()
    
    -- Register events for updating displayed data
    self:RegisterEvent('UPDATE_BINDINGS', self.UpdateBinding)
    self:RegisterEvent('BAG_UPDATE_DELAYED', self.UpdateCount)
    self:RegisterEvent('BAG_UPDATE_COOLDOWN', self.UpdateCooldown)
    
    -- Update every 2 seconds for the distance check (polling for performance)
    C_Timer.NewTicker(2, function() button:UpdateState() end)
    
    -- Quest and tracking related events
    self:RegisterEvent('QUEST_LOG_UPDATE', self.UpdateState)
    self:RegisterEvent('QUEST_POI_UPDATE', self.UpdateState)
    self:RegisterEvent('QUEST_WATCH_LIST_CHANGED', self.UpdateState)
    self:RegisterEvent('ZONE_CHANGED', self.UpdateState)
    self:RegisterEvent('ZONE_CHANGED_NEW_AREA', self.UpdateState)
    self:RegisterEvent('PLAYER_INSIDE_QUEST_BLOB_STATE_CHANGED', self.UpdateState)
    self:RegisterEvent('WAYPOINT_UPDATE', self.UpdateState)
    self:RegisterEvent('BAG_UPDATE_DELAYED', self.UpdateState)
    self:RegisterUnitEvent('UNIT_AURA', 'player', self.UpdateState)
    
    -- Some items are used directly on targets
    self:RegisterEvent('PLAYER_TARGET_CHANGED', self.UpdateTarget)
    
    -- Update checked status
    self:RegisterEvent('CURRENT_SPELL_CAST_CHANGED', self.UpdateChecked)
    self:RegisterEvent('ACTIONBAR_UPDATE_STATE', self.UpdateChecked)

    -- Combat Events for Lock/Switch visuals
    self:RegisterEvent('PLAYER_REGEN_DISABLED', self.PLAYER_REGEN_DISABLED)
    self:RegisterEvent('PLAYER_REGEN_ENABLED', self.PLAYER_REGEN_ENABLED)
end

-- Initialize button
button:OnLoad()

--[[
    Mode Detection
    
    After a short delay, check if ElvUI has claimed the button.
    If not, initialize standalone mode with LibEditMode.
]]

C_Timer.After(1, function()
    if not button.elvuiManaged then
        -- ElvUI didn't claim the button, use standalone mode
        if addon.InitStandalone then
            addon:InitStandalone()
        end
    end
    
    -- Initial binding update regardless of mode
    addon:DeferMethod(button, 'UpdateBinding')
end)

-- Set binding globals
_G['BINDING_HEADER_' .. addonName:upper()] = addonName
_G['BINDING_NAME_' .. addonName:upper()] = addonName

-- Slash command
addon:RegisterSlash('/eqb', function(msg)
    if msg == 'test' or msg == 'multi' then
         if addon.ElvUIModule then
            addon.ElvUIModule:ToggleTestMode(msg)
         end
         return
    end

    if button.elvuiManaged then
        addon:Print('Configure in ElvUI settings: /ec')
    else
        addon:Print('Configure in Edit Mode (ESC → Edit Mode)')
    end
end)
