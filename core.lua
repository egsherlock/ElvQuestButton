--[[
    ElvQuestButton - Core Quest Logic
    
    This file contains all the quest item detection and management logic,
    completely separated from UI concerns (positioning, skinning, etc.)
    
    Extracted from the original ExtraQuestButton by p3lim.
]]

local addonName, addon = ...

local L = addon.L
local data = addon.data

-- Returns true if `value` is present in the array-like table `list`.
function addon:ListContains(list, value)
    if not list then return false end
    for _, v in ipairs(list) do
        if v == value then
            return true
        end
    end
    return false
end

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
    artworkScale = 1,
    artworkRotation = 0,
    noCooldownText = false,
    trackingOnly = false,
    zoneOnly = false,
    distanceYd = 1000,
    autoLockOnUse = false,
    scrollToSwitch = true,
    lockOnSwitch = false,  -- false = soft-select (no persistent lock); true = hard-lock on switch
    lockIconStyle = 'Padlock',
    switchIconStyle = 'Refresh',
    itemCountBadge = 'SWITCH',
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
                -- With only 1 item, neither a hard lock nor a soft selection is
                -- meaningful, so clear both.
                if #nearbyItems <= 1 then
                    if self.lockedItemLink then self:SetLockedItem(nil) end
                    self.selectedItemLink = nil
                end

                -- Resolution order: hard lock > soft selection > closest.
                -- Each preference is honoured only while it's still in range;
                -- otherwise it's cleared and we fall through to the next.

                -- 1) Hard lock (manual Lock button, autoLockOnUse, or scroll
                --    when lockOnSwitch is enabled). Shows the gold lock state.
                if self.lockedItemLink then
                    if addon:ListContains(nearbyItems, self.lockedItemLink) then
                        itemLink = self.lockedItemLink
                    else
                        self:SetLockedItem(nil)
                    end
                end

                -- 2) Soft selection (scroll/Switch when lockOnSwitch is off).
                --    Sticks while in range, no lock visual, auto-clears when gone.
                if not itemLink and self.selectedItemLink then
                    if addon:ListContains(nearbyItems, self.selectedItemLink) then
                        itemLink = self.selectedItemLink
                    else
                        self.selectedItemLink = nil
                    end
                end

                -- 3) Closest item.
                if not itemLink then
                    itemLink = nearbyItems[1]
                end
            else
                -- No items found at all; any lock/selection is stale.
                if self.lockedItemLink then self:SetLockedItem(nil) end
                self.selectedItemLink = nil
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
    
    -- Calculate index and count for badge
    local total = self.lastNearbyItems and #self.lastNearbyItems or 0
    local current = 0
    if itemLink and total > 0 then
        for i, link in ipairs(self.lastNearbyItems) do
            if link == itemLink then
                current = i
                break
            end
        end
    end
    
    -- Update UI bits (Lock/Switch buttons)
    if self.UpdateFeatures then
        self:UpdateFeatures()
    end
    
    if self.UpdateItemBadge then
        self:UpdateItemBadge(current, total)
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
    -- A hard lock supersedes any soft selection.
    if itemLink then
        self.selectedItemLink = nil
    end
    -- Visual update handled by UpdateFeatures calls
end

-- Apply a switch target chosen by the Switch button / scroll wheel. Honours the
-- lockOnSwitch setting: when enabled it pins the item (hard lock, gold state);
-- when disabled it sets a soft selection that sticks while in range but shows no
-- lock visual. Either way UpdateState's resolution order keeps it displayed.
function coreMixin:SelectItem(itemLink)
    if not itemLink then return end

    local settings = addon:GetCurrentSettings()
    if settings and settings.lockOnSwitch then
        self:SetLockedItem(itemLink)
    else
        self:SetLockedItem(nil)
        self.selectedItemLink = itemLink
    end
    self:UpdateState()
end

function coreMixin:SwitchItem()
    -- Switching is NOT safe in combat
    if InCombatLockdown() then return end

    if not self.lastNearbyItems or #self.lastNearbyItems < 2 then return end

    local current = self.lockedItemLink or self.selectedItemLink or self:GetItemLink()
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

    self:SelectItem(nextItem)
end

function coreMixin:SwitchItemPrevious()
    -- Switching is NOT safe in combat
    if InCombatLockdown() then return end

    if not self.lastNearbyItems or #self.lastNearbyItems < 2 then return end

    local current = self.lockedItemLink or self.selectedItemLink or self:GetItemLink()
    if not current then return end

    local prevItem
    for i, link in ipairs(self.lastNearbyItems) do
        if link == current then
            prevItem = self.lastNearbyItems[i-1]
            break
        end
    end

    -- Wrap around to end
    if not prevItem then
        prevItem = self.lastNearbyItems[#self.lastNearbyItems]
    end

    self:SelectItem(prevItem)
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

-- Movement tracking drives the distance-polling ticker (see addon.lua). The
-- only thing that ticker catches which events don't is the player-to-objective
-- distance changing as they move, so we only need to poll while actually moving.
function coreMixin:PLAYER_STARTED_MOVING()
    self.isMoving = true
end

function coreMixin:PLAYER_STOPPED_MOVING()
    self.isMoving = false
    -- One settle update so the final resting distance registers promptly
    -- instead of waiting for the next ticker cycle.
    if self.ScheduleUpdate then
        self:ScheduleUpdate()
    end
end

-- Auto-lock by detecting the quest item's spell being cast, regardless of HOW
-- it was used: our button, a bag click, a keybind, or the hover/right-click
-- world interaction (e.g. lassoing a flying mob). Using an item casts its spell,
-- so we match the cast spellID against the nearby quest items and lock the match.
-- (Registered for the 'player' unit, so the first arg is always 'player'.)
function coreMixin:UNIT_SPELLCAST_SUCCEEDED(_, _, spellID)
    if self.editing or not spellID then
        return
    end

    local settings = addon:GetCurrentSettings()
    if not settings or settings.autoLockOnUse ~= true then
        return
    end

    -- Locking is only meaningful with multiple items, and we never override an
    -- existing lock.
    if self.lockedItemLink then return end
    if not self.lastNearbyItems or #self.lastNearbyItems <= 1 then return end

    for _, link in ipairs(self.lastNearbyItems) do
        local _, itemSpellID = C_Item.GetItemSpell(link)
        if itemSpellID and itemSpellID == spellID then
            self:SetLockedItem(link)
            -- Immediate visual (UpdateState early-returns in combat).
            if self.UpdateFeatures then
                self:UpdateFeatures()
            end
            self:UpdateState()
            return
        end
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
