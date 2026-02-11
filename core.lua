--[[
    ElvQuestButton - Core Quest Logic
    
    This file contains all the quest item detection and management logic,
    completely separated from UI concerns (positioning, skinning, etc.)
    
    Extracted from the original ExtraQuestButton by p3lim.
]]

local addonName, addon = ...

local L = addon.L
local data = addon.data

-- Default settings (shared between ElvUI and standalone modes)
addon.DEFAULTS = {
    position = {
        point = 'CENTER',
        x = 0,
        y = 0,
    },
    scale = 1,
    artworkAlpha = 1,
    artworkStyle = 'Default',
    noCooldownText = false,
    trackingOnly = false,
    zoneOnly = false,
    distanceYd = 1000,
    autoLockOnUse = true,
    lockOnSwitch = true,
}

-- Attribute handler for secure button behavior
addon.ATTRIBUTE_HANDLER = [[
    local bindingParent = '%s'

    if name == 'item' then
        -- update when the item attribute changes
        if value and not self:IsShown() and not (bindingParent == 'EXTRAACTIONBUTTON1' and HasExtraActionBar()) then
            self:Show()
        elseif not value then
            self:Hide()
            self:ClearBindings()
        end
    elseif name == 'state-visible' then
        -- there is (or was) a pet battle
        if value == 'show' and self:GetAttribute('item') ~= nil then
            -- trigger an update to check if we should show an item
            self:Show()
            self:CallMethod('UpdateState')
        else
            self:Hide()
            self:ClearBindings()
            self:SetAttribute('item', nil) -- avoid ghost clicks
        end
    end

    if self:IsShown() then
        self:ClearBindings()

        local key1, key2 = GetBindingKey(bindingParent)
        if key1 then
            self:SetBindingClick(1, key1, self, 'LeftButton')
        end
        if key2 then
            self:SetBindingClick(2, key2, self, 'LeftButton')
        end
    end
]]

--[[
    Core Quest Logic Methods
    These are mixed into the button frame in addon.lua
]]

local coreMixin = {}

function coreMixin:UpdateBinding()
    if self.editing then
        return
    end

    if not InCombatLockdown() then
        local keyButton = addonName:upper()
        local key1 = GetBindingKey(keyButton)
        if not key1 then
            keyButton = 'EXTRAACTIONBUTTON1'
            key1 = GetBindingKey(keyButton)
        end

        -- update hotkey text
        self:SetHotKey(key1 and GetBindingText(key1, 1))

        -- reset state driver
        UnregisterStateDriver(self, 'visible')

        -- update state driver
        if keyButton == addonName:upper() then
            RegisterStateDriver(self, 'visible', '[petbattle] hide; show')
        else
            RegisterStateDriver(self, 'visible', '[extrabar][petbattle] hide; show')
        end

        -- update attribute handler
        self:SetAttribute('_onattributechanged', addon.ATTRIBUTE_HANDLER:format(keyButton))

        -- trigger a state update for the binding
        self:SetAttribute('binding', GetTime())
        
        -- Always listen for entering combat to update visuals (Switch/Lock icons)
        self:RegisterEvent('PLAYER_REGEN_DISABLED')
    else
        addon:DeferMethod(self, 'UpdateBinding')
    end
end

function coreMixin:UpdateCount()
    if self.editing then
        return
    end

    if not self:IsItemEmpty() then
        -- update count
        local count = C_Item.GetItemCount(self:GetItemLink())
        self:SetCount(count)

        if count == 0 then
            -- player ran out of items, update the state
            self:UpdateState()
        end
    end
end

function coreMixin:UpdateCooldown()
    if self.editing then
        return
    end

    if not self:IsItemEmpty() then
        local start, duration = C_Item.GetItemCooldown(self:GetItemID())
        if duration > 0 then
            self:SetCooldown(start, duration)
        else
            self:ClearCooldown()
        end
    end
end

function coreMixin:UpdateState()
    if self.editing and not (self.testMode and self.lastNearbyItems) then
        return
    end

    -- Strict Combat Safety: Do not update state during combat
    if InCombatLockdown() then
        if not self.needsAttributeUpdate then
            self.needsAttributeUpdate = true
        end
        return
    end
    
    -- If locked item is effectively gone (quest complete, left area), we should unlock
    -- But we need to check if it's still "nearby" to decide
    
    local itemLink = self:GetTargetItem()
    local nearbyItems
    
    if not itemLink then
        -- Get settings from wherever they're stored (ElvUI or standalone)
        local settings = addon:GetCurrentSettings()
        if settings then
             -- Get ALL nearby items
             if self.testMode and self.lastNearbyItems then
                 nearbyItems = self.lastNearbyItems
             else
                 nearbyItems = addon:GetNearbyQuestItems(settings.distanceYd, settings.zoneOnly, settings.trackingOnly)
             end
            
            if nearbyItems and #nearbyItems > 0 then
                -- Check if we have a locked item
                if self.lockedItemLink then
                    local found = false
                    for _, link in ipairs(nearbyItems) do
                        if link == self.lockedItemLink then
                            found = true
                            break
                        end
                    end
                    
                    if found then
                        itemLink = self.lockedItemLink
                    else
                        -- Locked item is no longer valid, unlock and take closest
                        self:SetLockedItem(nil)
                        itemLink = nearbyItems[1]
                    end
                else
                    -- No lock (or just unlocked), take closest
                    itemLink = nearbyItems[1]
                end
            elseif self.lockedItemLink then
                -- No items found at all, but we had a lock.
                -- This implies the locked item is gone too.
                self:SetLockedItem(nil)
            end
        end
    end
    
    -- Cache the nearby items list for the Switch feature to use
    self.lastNearbyItems = nearbyItems

    if itemLink then
        if itemLink ~= self:GetItemLink() then
            self:SetItem(itemLink)
        end
    elseif self:IsShown() then
        self:Reset()
    end
    
    -- Update UI bits (Lock/Switch buttons)
    if self.UpdateFeatures then
        self:UpdateFeatures()
    end
end

function coreMixin:ToggleLock()
    -- Locking is safe in combat (just a flag)
    if not self:GetItemLink() then return end
    
    if self.lockedItemLink then
        self:SetLockedItem(nil)
    else
        self:SetLockedItem(self:GetItemLink())
    end
    -- Force update immediately to revert to closest if unlocking, or confirm lock
    self:UpdateState()
end

function coreMixin:SetLockedItem(itemLink)
    self.lockedItemLink = itemLink
    -- Visual update handled by UpdateFeatures calls
end

function coreMixin:SwitchItem()
    -- Switching is NOT safe in combat
    if InCombatLockdown() then return end
    
    if not self.lastNearbyItems or #self.lastNearbyItems < 2 then return end
    
    local current = self.lockedItemLink or self:GetItemLink()
    if not current then return end
    
    local nextItem
    for i, link in ipairs(self.lastNearbyItems) do
        if link == current then
            nextItem = self.lastNearbyItems[i+1]
            break
        end
    end
    
    -- Wrap around
    if not nextItem then
        nextItem = self.lastNearbyItems[1]
    end
    
    if nextItem then
        local settings = addon:GetCurrentSettings()
        if settings and settings.lockOnSwitch then
            self:SetLockedItem(nextItem)
            self:UpdateState()
        else
            -- Just set the item directly without locking
            -- Don't call UpdateState here as it would immediately revert
            -- to the closest item since there's no lock
            self:SetItem(nextItem)
            if self.UpdateFeatures then
                self:UpdateFeatures()
            end
        end
    end
end

function coreMixin:UpdateTarget()
    if self.editing then
        return
    end

    local npcID
    if UnitCreatureID then
        npcID = UnitCreatureID('target')
        if npcID ~= nil and issecretvalue(npcID) then
            npcID = nil
        end
    else
        npcID = addon:GetUnitID('target')
    end

    if npcID then
        local targetItemID = data.targetItems[npcID]
        if targetItemID then
            if C_Item.GetItemCount(targetItemID) > 0 then
                self:SetTargetItem(targetItemID)
                self:UpdateState()
                return
            end
        end
    end

    if self:GetTargetItem() then
        -- there's no npc ID or valid target item, time to reset
        self:SetTargetItem()
        self:UpdateState()
    end
end

function coreMixin:SetTargetItem(itemID)
    if self.editing then
        return
    end

    if itemID then
        -- need to turn this into an item link
        local _, itemLink = C_Item.GetItemInfo(itemID)
        itemID = itemLink
    end

    self.targetItem = itemID
end

function coreMixin:GetTargetItem()
    return self.targetItem
end

function coreMixin:UpdateAttributes()
    if self.editing then
        return
    end

    -- Safety check: SetAttribute is protected
    if InCombatLockdown() then return end
    
    if self:IsItemEmpty() then
        self:SetAttribute('item', nil)
        self:ClearCooldown()
    else
        self:SetAttribute('item', 'item:' .. self:GetItemID())
        self:UpdateCooldown()
    end
end

-- Adding Combat Regen handler to the mixin to catch the retry
function coreMixin:PLAYER_REGEN_ENABLED()
    self.needsAttributeUpdate = nil
    self.inCombat = false
    -- Full state update to catch up on everything (logic, visuals, attributes)
    self:UpdateState()
end

function coreMixin:PLAYER_REGEN_DISABLED()
    -- Entered combat: Update visual features to show locked/disabled states
    self.inCombat = true
    if self.UpdateFeatures then
        self:UpdateFeatures()
    end
end

function coreMixin:SetItem(itemLink)
    if InCombatLockdown() then return end
    
    if not itemLink then
        return
    end

    self:SetItemLink(itemLink)
    self:SetIcon(self:GetItemIcon()) -- we're going to assume it's already loaded since it's a link
    self:EnableUpdateRange(C_Item.ItemHasRange(itemLink))

    addon:DeferMethod(self, 'UpdateAttributes')
    self:UpdateCount()
end

function coreMixin:Reset()
    if self.editing then
        return
    end

    self:Clear()
    self:EnableUpdateRange(false)

    addon:DeferMethod(self, 'UpdateAttributes')
end

function coreMixin:OnEnter()
    if KeybindFrames_InQuickKeybindMode() then
        QuickKeybindButtonTemplateMixin.QuickKeybindButtonOnEnter(self)
    else
        local itemLink = self:GetItemLink()
        if itemLink then
            GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
            GameTooltip:SetHyperlink(itemLink)
        end
    end
end

function coreMixin:OnLeave()
    QuickKeybindButtonTemplateMixin.QuickKeybindButtonOnLeave(self)
    GameTooltip_Hide(self)
end

-- Export the mixin
addon.coreMixin = coreMixin

-- Settings accessor (overridden by ElvUI or standalone modules)
function addon:GetCurrentSettings()
    -- Default implementation - will be overridden
    return addon.DEFAULTS
end
