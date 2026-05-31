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

    -- Movement state: gates the distance-polling ticker below
    self.isMoving = false

    -- Register events for updating displayed data
    self:RegisterEvent('UPDATE_BINDINGS', self.UpdateBinding)
    self:RegisterEvent('BAG_UPDATE_DELAYED', self.UpdateCount)
    self:RegisterEvent('BAG_UPDATE_COOLDOWN', self.UpdateCooldown)

    -- Track movement so the ticker only runs the (relatively expensive) full
    -- quest scan while the player is actually moving.
    self:RegisterEvent('PLAYER_STARTED_MOVING', self.PLAYER_STARTED_MOVING)
    self:RegisterEvent('PLAYER_STOPPED_MOVING', self.PLAYER_STOPPED_MOVING)

    -- Distance polling. The only thing this catches that events don't is the
    -- player-to-objective distance changing as they move; everything else is
    -- handled by the event-driven ScheduleUpdate path. So while stationary we
    -- skip the scan entirely (the stop-moving settle update already refreshed
    -- the final position).
    C_Timer.NewTicker(2, function()
        if button.isMoving then
            button:UpdateState()
        end
    end)
    
    -- Throttled update: coalesces multiple same-frame events into one UpdateState
    -- This prevents redundant quest log iterations when e.g. QUEST_LOG_UPDATE,
    -- BAG_UPDATE_DELAYED, and ZONE_CHANGED all fire in the same frame.
    function self:ScheduleUpdate()
        if not self._updateScheduled then
            self._updateScheduled = true
            C_Timer.After(0, function()
                self._updateScheduled = nil
                self:UpdateState()
            end)
        end
    end
    
    -- Quest and tracking related events (throttled via ScheduleUpdate)
    self:RegisterEvent('QUEST_LOG_UPDATE', self.ScheduleUpdate)
    self:RegisterEvent('QUEST_TURNED_IN', self.ScheduleUpdate)
    self:RegisterEvent('QUEST_POI_UPDATE', self.ScheduleUpdate)
    self:RegisterEvent('QUEST_WATCH_LIST_CHANGED', self.ScheduleUpdate)
    self:RegisterEvent('ZONE_CHANGED', self.ScheduleUpdate)
    self:RegisterEvent('ZONE_CHANGED_NEW_AREA', self.ScheduleUpdate)
    self:RegisterEvent('PLAYER_INSIDE_QUEST_BLOB_STATE_CHANGED', self.ScheduleUpdate)
    self:RegisterEvent('WAYPOINT_UPDATE', self.ScheduleUpdate)
    -- BAG_UPDATE_DELAYED is NOT re-registered here for ScheduleUpdate.
    -- UpdateCount (line 42) already handles bag changes and calls UpdateState
    -- when the item count drops to 0, so a duplicate registration is unnecessary.
    self:RegisterUnitEvent('UNIT_AURA', 'player', self.ScheduleUpdate)
    
    -- Some items are used directly on targets
    self:RegisterEvent('PLAYER_TARGET_CHANGED', self.UpdateTarget)

    -- Auto-lock when the displayed quest item's spell is cast by ANY means
    -- (bag click, keybind, hover/right-click world interaction), not just our
    -- button's PostClick. Gated by the autoLockOnUse setting inside the handler.
    self:RegisterUnitEvent('UNIT_SPELLCAST_SUCCEEDED', 'player', self.UNIT_SPELLCAST_SUCCEEDED)
    
    -- Update checked status
    self:RegisterEvent('CURRENT_SPELL_CAST_CHANGED', self.UpdateChecked)
    self:RegisterEvent('ACTIONBAR_UPDATE_STATE', self.UpdateChecked)

    -- Combat Events for Lock/Switch visuals
    self:RegisterEvent('PLAYER_REGEN_DISABLED', self.PLAYER_REGEN_DISABLED)
    self:RegisterEvent('PLAYER_REGEN_ENABLED', self.PLAYER_REGEN_ENABLED)
end

-- Initialize button
button:OnLoad()

-- Auto-lock quest item after use (PostClick fires after secure action completes)
button:HookScript('PostClick', function(self)
    -- Guard: only auto-lock if the setting is explicitly enabled
    local settings = addon:GetCurrentSettings()
    if not settings then return end
    if settings.autoLockOnUse ~= true then return end

    -- Only auto-lock if we have multiple items (locking is meaningless with only 1 item)
    if not self.lastNearbyItems or #self.lastNearbyItems <= 1 then return end

    local link = self:GetItemLink()
    if link and not self.lockedItemLink then
        self:SetLockedItem(link)
        if self.UpdateFeatures then
            self:UpdateFeatures()
        end
    end
end)

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
    if msg == 'test' then
        -- Toggle test mode (same as the button in the ElvUI options panel)
        if addon.ElvUIModule then
            addon.ElvUIModule:ToggleTestMode()
        end
        return
    end

    -- No argument: open the bespoke ElvQuestButton settings panel (ElvUI mode),
    -- or point standalone users at Edit Mode.
    if button.elvuiManaged then
        if addon.ElvUIModule and addon.ElvUIModule.Panel then
            addon.ElvUIModule.Panel:Toggle()
        end
    else
        addon:Print('Configure in Edit Mode (ESC → Edit Mode)')
    end
end)
