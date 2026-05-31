--[[
    ElvQuestButton - Standalone Module
    
    LibEditMode integration for users without ElvUI.
    This file is ONLY active when ElvUI is not managing the button.
    
    Extracted from the original ExtraQuestButton by p3lim.
]]

local addonName, addon = ...

local L = addon.L
local LEM = LibStub('LibEditMode')
local DEFAULTS = addon.DEFAULTS

-- Initialize standalone mode
function addon:InitStandalone()
    local button = _G.ElvQuestButton or _G[addonName]
    if not button then return end
    
    -- Don't initialize if ElvUI is managing
    if button.elvuiManaged then return end
    
    button.standaloneMode = true
    
    -- Position change callback
    local function OnPositionChanged(layoutName, point, x, y)
        ElvQuestButtonDB.profiles[layoutName].position = {
            point = point,
            x = x,
            y = y,
        }
    end
    
    -- Settings change callback
    local function OnSettingsChanged(layoutName)
        local profile = ElvQuestButtonDB.profiles[layoutName]
        button:SetScale(profile.scale)
        button:SetArtworkStyle(profile.artworkStyle)
        button:SetArtworkAlpha(profile.artworkAlpha)
        button:SetArtworkScale(profile.artworkScale or 1)
        button:SetArtworkRotation(profile.artworkRotation or 0)
        button:SetLockIcon(profile.lockIconStyle or 'Padlock')
        button:SetSwitchIcon(profile.switchIconStyle or 'Refresh')
        button:EnableCooldownText(not profile.noCooldownText)
        
        local pos = profile.position
        button:ClearAllPoints()
        button:SetPoint(pos.point, pos.x, pos.y)
    end
    
    -- Edit mode callbacks
    local function OnEditModeEnter()
        addon:DeferMethod(button, 'EnableEditMode', true)
    end
    
    local function OnEditModeExit()
        addon:DeferMethod(button, 'EnableEditMode', false)
    end
    
    local function OnEditModeLayout(layoutName)
        if not ElvQuestButtonDB then
            ElvQuestButtonDB = {profiles = {}}
        end
        
        if not ElvQuestButtonDB.profiles[layoutName] then
            ElvQuestButtonDB.profiles[layoutName] = CopyTable(DEFAULTS)
        end
        
        OnSettingsChanged(layoutName)
    end
    
    local function OnEditModeCreate(layoutName, _, sourceName)
        if sourceName then
            if ElvQuestButtonDB and ElvQuestButtonDB.profiles and ElvQuestButtonDB.profiles[sourceName] then
                ElvQuestButtonDB.profiles[layoutName] = CopyTable(ElvQuestButtonDB.profiles[sourceName])
            end
        end
    end
    
    local function OnEditModeRename(oldLayoutName, newLayoutName)
        if ElvQuestButtonDB and ElvQuestButtonDB.profiles and ElvQuestButtonDB.profiles[oldLayoutName] then
            ElvQuestButtonDB.profiles[newLayoutName] = CopyTable(ElvQuestButtonDB.profiles[oldLayoutName])
            ElvQuestButtonDB.profiles[oldLayoutName] = nil
        end
    end
    
    local function OnEditModeDelete(layoutName)
        if ElvQuestButtonDB and ElvQuestButtonDB.profiles and ElvQuestButtonDB.profiles[layoutName] then
            ElvQuestButtonDB.profiles[layoutName] = nil
        end
    end
    
    -- EnableEditMode for the button
    function button:EnableEditMode(isInEditMode)
        self.editing = isInEditMode
        if self.editing then
            if InCombatLockdown() then
                addon:Print('Can\'t modify in combat')
            end
            
            -- unregister state driver and attribute handler
            UnregisterStateDriver(self, 'visible')
            self:SetAttribute('_onattributechanged', nil)
            
            -- set custom texture, clear cooldowns and show
            self:SetIcon([[Interface\Icons\INV_Misc_Wrench_01]])
            self:ClearCooldown()
            self:Show()
        else
            if not InCombatLockdown() and self:IsItemEmpty() then
                -- hide right away
                self:Hide()
            else
                self:SetItem(self:GetItemLink())
            end
            
            -- let state enable itself
            addon:DeferMethod(self, 'UpdateBinding')
        end
    end
    
    -- Register with LibEditMode
    LEM:AddFrame(button, OnPositionChanged, DEFAULTS.position)
    LEM:RegisterCallback('enter', OnEditModeEnter)
    LEM:RegisterCallback('exit', OnEditModeExit)
    LEM:RegisterCallback('layout', OnEditModeLayout)
    LEM:RegisterCallback('create', OnEditModeCreate)
    LEM:RegisterCallback('rename', OnEditModeRename)
    LEM:RegisterCallback('delete', OnEditModeDelete)
    
    -- Build artwork style options
    local ART_STYLE_OPTIONS = {}
    for name in next, button:GetArtworkStyles() do
        table.insert(ART_STYLE_OPTIONS, {
            text = name,
            isRadio = true,
        })
    end
    
    local function sortByText(a, b)
        return a.text < b.text
    end
    table.sort(ART_STYLE_OPTIONS, sortByText)

    -- Build lock / switch icon options
    local function buildIconOptions(iconTable)
        local options = {}
        for name in next, iconTable do
            table.insert(options, { text = name, isRadio = true })
        end
        table.sort(options, sortByText)
        return options
    end
    local LOCK_ICON_OPTIONS = buildIconOptions(button:GetLockIcons())
    local SWITCH_ICON_OPTIONS = buildIconOptions(button:GetSwitchIcons())
    
    -- Add Edit Mode settings
    LEM:AddFrameSettings(button, {
        {
            name = L['Button scale'],
            kind = LEM.SettingType.Slider,
            default = DEFAULTS.scale,
            get = function(layoutName)
                return ElvQuestButtonDB.profiles[layoutName].scale
            end,
            set = function(layoutName, value)
                ElvQuestButtonDB.profiles[layoutName].scale = value
                button:SetScale(value)
            end,
            minValue = 0.1,
            maxValue = 5,
            valueStep = 0.1,
            formatter = function(value)
                return FormatPercentage(value, true)
            end,
        },
        {
            name = L['Artwork opacity'],
            kind = LEM.SettingType.Slider,
            default = DEFAULTS.artworkAlpha,
            get = function(layoutName)
                return ElvQuestButtonDB.profiles[layoutName].artworkAlpha
            end,
            set = function(layoutName, value)
                ElvQuestButtonDB.profiles[layoutName].artworkAlpha = value
                button:SetArtworkAlpha(value)
            end,
            minValue = 0,
            maxValue = 1,
            valueStep = 0.05,
            formatter = function(value)
                return FormatPercentage(value, true)
            end,
        },
        {
            name = L['Artwork style'],
            kind = LEM.SettingType.Dropdown,
            default = DEFAULTS.artworkStyle,
            get = function(layoutName)
                return ElvQuestButtonDB.profiles[layoutName].artworkStyle
            end,
            set = function(layoutName, value)
                ElvQuestButtonDB.profiles[layoutName].artworkStyle = value
                button:SetArtworkStyle(value)
            end,
            values = ART_STYLE_OPTIONS,
            height = 200,
        },
        {
            name = L['Artwork size'],
            kind = LEM.SettingType.Slider,
            default = DEFAULTS.artworkScale,
            get = function(layoutName)
                return ElvQuestButtonDB.profiles[layoutName].artworkScale
            end,
            set = function(layoutName, value)
                ElvQuestButtonDB.profiles[layoutName].artworkScale = value
                button:SetArtworkScale(value)
            end,
            minValue = 0.5,
            maxValue = 2,
            valueStep = 0.05,
            formatter = function(value)
                return FormatPercentage(value, true)
            end,
        },
        {
            name = L['Artwork rotation'],
            kind = LEM.SettingType.Slider,
            default = DEFAULTS.artworkRotation,
            get = function(layoutName)
                return ElvQuestButtonDB.profiles[layoutName].artworkRotation
            end,
            set = function(layoutName, value)
                ElvQuestButtonDB.profiles[layoutName].artworkRotation = value
                button:SetArtworkRotation(value)
            end,
            minValue = 0,
            maxValue = 360,
            valueStep = 1,
            formatter = function(value)
                return math.floor(value + 0.5) .. '°'
            end,
        },
        {
            name = L['Lock icon'],
            kind = LEM.SettingType.Dropdown,
            default = DEFAULTS.lockIconStyle,
            get = function(layoutName)
                return ElvQuestButtonDB.profiles[layoutName].lockIconStyle
            end,
            set = function(layoutName, value)
                ElvQuestButtonDB.profiles[layoutName].lockIconStyle = value
                button:SetLockIcon(value)
            end,
            values = LOCK_ICON_OPTIONS,
        },
        {
            name = L['Switch icon'],
            kind = LEM.SettingType.Dropdown,
            default = DEFAULTS.switchIconStyle,
            get = function(layoutName)
                return ElvQuestButtonDB.profiles[layoutName].switchIconStyle
            end,
            set = function(layoutName, value)
                ElvQuestButtonDB.profiles[layoutName].switchIconStyle = value
                button:SetSwitchIcon(value)
            end,
            values = SWITCH_ICON_OPTIONS,
        },
        {
            name = L['Hide cooldown text'],
            kind = LEM.SettingType.Checkbox,
            default = DEFAULTS.noCooldownText,
            get = function(layoutName)
                return ElvQuestButtonDB.profiles[layoutName].noCooldownText
            end,
            set = function(layoutName, value)
                ElvQuestButtonDB.profiles[layoutName].noCooldownText = value
                button:EnableCooldownText(not value)
            end,
        },
        {
            name = L['Only show for tracked quests'],
            kind = LEM.SettingType.Checkbox,
            default = DEFAULTS.trackingOnly,
            get = function(layoutName)
                return ElvQuestButtonDB.profiles[layoutName].trackingOnly
            end,
            set = function(layoutName, value)
                ElvQuestButtonDB.profiles[layoutName].trackingOnly = value
            end,
        },
        {
            name = L['Only show for quests in current zone'],
            kind = LEM.SettingType.Checkbox,
            default = DEFAULTS.zoneOnly,
            get = function(layoutName)
                return ElvQuestButtonDB.profiles[layoutName].zoneOnly
            end,
            set = function(layoutName, value)
                ElvQuestButtonDB.profiles[layoutName].zoneOnly = value
            end,
        },
        {
            name = 'Scroll to Switch',
            kind = LEM.SettingType.Checkbox,
            default = DEFAULTS.scrollToSwitch,
            get = function(layoutName)
                return ElvQuestButtonDB.profiles[layoutName].scrollToSwitch
            end,
            set = function(layoutName, value)
                ElvQuestButtonDB.profiles[layoutName].scrollToSwitch = value
            end,
        },
        {
            name = 'Lock when switching',
            kind = LEM.SettingType.Checkbox,
            default = DEFAULTS.lockOnSwitch,
            get = function(layoutName)
                return ElvQuestButtonDB.profiles[layoutName].lockOnSwitch
            end,
            set = function(layoutName, value)
                ElvQuestButtonDB.profiles[layoutName].lockOnSwitch = value
                button.selectedItemLink = nil
                if button.lockedItemLink and not button.inCombat then
                    button:SetLockedItem(nil)
                end
            end,
        },
        {
            name = L['Tracking distance'],
            kind = LEM.SettingType.Slider,
            default = DEFAULTS.distanceYd,
            get = function(layoutName)
                return ElvQuestButtonDB.profiles[layoutName].distanceYd
            end,
            set = function(layoutName, value)
                ElvQuestButtonDB.profiles[layoutName].distanceYd = value
            end,
            minValue = 5,
            maxValue = 10000,
            valueStep = 1,
            formatter = function(value)
                return math.floor(value + 0.5)
            end,
        },
    })
    
    -- Adjust the EditMode selection to cover the artwork
    if button.Selection and button.Artwork then
        button.Selection:SetAllPoints(button.Artwork)
    end
    
    -- Hook QuickKeyBind
    hooksecurefunc(ActionButtonUtil, 'SetAllQuickKeybindButtonHighlights', function(show)
        if not show and LEM:IsInEditMode() then
            return
        end
        
        addon:DeferMethod(button, 'EnableEditMode', show)
        
        button.commandName = show and addonName:upper()
        if button.QuickKeybindHighlightTexture then
            button.QuickKeybindHighlightTexture:SetShown(show)
        end
        
        if show and InCombatLockdown() then
            addon:Print('Can\'t adjust bindings in combat, you\'ll probably get errors now.')
        end
    end)
    
    -- Override settings accessor for standalone mode
    function addon:GetCurrentSettings()
        local layoutName = LEM:GetActiveLayoutName()
        if ElvQuestButtonDB and ElvQuestButtonDB.profiles and ElvQuestButtonDB.profiles[layoutName] then
            return ElvQuestButtonDB.profiles[layoutName]
        end
        return DEFAULTS
    end
end
