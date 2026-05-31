--[[
    ElvQuestButton - ElvUI Options Panel
    
    Adds configuration options under /ec (ElvUI config)
]]

local addonName, addon = ...

if not _G.ElvUI then return end

local E, L, V, P, G = unpack(_G.ElvUI)
local EQB = addon.ElvUIModule

function EQB:InsertOptions()
    local button = _G.ElvQuestButton or _G[addonName]

    -- Build the artwork style dropdown from the button's ART_STYLES table.
    -- values: key -> display name; sorting: alphabetical key list (Ace3 'sorting'
    -- as a key array is safe; sorting = "key" crashes Ace3, see itemCountBadge).
    local artworkValues, artworkSorting = {}, {}
    if button and button.GetArtworkStyles then
        for name in pairs(button:GetArtworkStyles()) do
            artworkValues[name] = name
            table.insert(artworkSorting, name)
        end
        table.sort(artworkSorting)
    end

    -- Lock / Switch icon dropdowns (same pattern as the artwork dropdown).
    local lockIconValues, lockIconSorting = {}, {}
    if button and button.GetLockIcons then
        for name in pairs(button:GetLockIcons()) do
            lockIconValues[name] = name
            table.insert(lockIconSorting, name)
        end
        table.sort(lockIconSorting)
    end

    local switchIconValues, switchIconSorting = {}, {}
    if button and button.GetSwitchIcons then
        for name in pairs(button:GetSwitchIcons()) do
            switchIconValues[name] = name
            table.insert(switchIconSorting, name)
        end
        table.sort(switchIconSorting)
    end

    E.Options.args.elvQuestButton = {
        order = 6,
        type = 'group',
        name = E:TextGradient('ElvQuestButton', 0.2, 0.7, 1, 0.2, 1, 0.6),
        icon = [[Interface\Icons\INV_Misc_Map02]],
        args = {
            header = {
                order = 1,
                type = 'header',
                name = 'ElvQuestButton',
            },
            description = {
                order = 2,
                type = 'description',
                name = 'Automatically detects and displays quest items based on proximity to objectives. The closest quest item is shown on the button — click it to use.\n\n'
                    .. '|cff00ff00Position|r: |cffffffffUse |cff00ff00/moveui|r |cffffffffto drag the button.|r\n'
                    .. '|cff00ff00Keybind|r: |cffffffffUse |cff00ff00/kb|r |cffffffffthen hover over the button to bind a key.|r\n\n',
            },
            
            -- Group 1: General (Core Toggles)
            generalGroup = {
                order = 10,
                type = 'group',
                name = "General",
                inline = true,
                args = {
                    enable = {
                        order = 1,
                        type = 'toggle',
                        name = L["Enable"],
                        desc = "Enable ElvUI integration for the quest button",
                        get = function() return self:GetDB().enable end,
                        set = function(_, value)
                            self:GetDB().enable = value
                            if value then self:UpdateButton() end
                        end,
                    },
                    inheritGlobalFade = {
                        order = 2,
                        type = 'toggle',
                        name = L["Inherit Global Fade"],
                        desc = "Fade this button along with your action bars when using ElvUI's Global Fade",
                        get = function() return self:GetDB().inheritGlobalFade end,
                        set = function(_, value)
                            self:GetDB().inheritGlobalFade = value
                            self:UpdateButton()
                        end,
                    },
                    testMode = {
                        order = 3,
                        type = 'execute',
                        name = function()
                            return self:IsTestMode() and "Hide Test Button" or "Show Test Button"
                        end,
                        desc = "Show/hide a preview of the button with sample icons to verify styling, Lock and Switch features",
                         func = function()
                            self:ToggleTestMode()
                            -- Force options refresh to update button label
                            LibStub('AceConfigRegistry-3.0'):NotifyChange('ElvUI')
                        end,
                    },
                },
            },
            
            -- Group 2: Quest Logic (The "Centrefold" - Main Behavior)
            logicGroup = {
                order = 20,
                type = 'group',
                name = "Quest Logic",
                inline = true,
                args = {
                    -- Section A: Visibility
                    visHeader = {
                        order = 1,
                        type = 'header',
                        name = "Visibility & Filters",
                    },
                    trackingOnly = {
                        order = 2,
                        type = 'toggle',
                        name = "Only Tracked Quests",
                        desc = "Only show button for quests you are actively tracking",
                        get = function() return self:GetDB().trackingOnly end,
                        set = function(_, value)
                            self:GetDB().trackingOnly = value
                        end,
                    },
                    zoneOnly = {
                        order = 3,
                        type = 'toggle',
                        name = "Current Zone Only",
                        desc = "Only show button for quests in your current zone",
                        get = function() return self:GetDB().zoneOnly end,
                        set = function(_, value)
                            self:GetDB().zoneOnly = value
                        end,
                    },
                    distanceYd = {
                        order = 4,
                        type = 'range',
                        name = "Tracking Distance",
                        desc = "Maximum distance in yards to show quest items",
                        min = 5, max = 10000, step = 5,
                        get = function() return self:GetDB().distanceYd end,
                        set = function(_, value)
                            self:GetDB().distanceYd = value
                        end,
                    },

                    -- Section B: Interaction
                    behaviorHeader = {
                        order = 10,
                        type = 'header',
                        name = "Interaction & Locking",
                    },

                    autoLockOnUse = {
                        order = 12,
                        type = 'toggle',
                        name = "Auto-Lock After Use",
                        desc = "Automatically lock the quest item after clicking it.\n\n|cffffd100Unlocks when:|r\n• Quest completes or is handed in\n• You leave the area\n• You click the Lock icon manually",
                        get = function() return self:GetDB().autoLockOnUse == true end,
                        set = function(_, value)
                            self:GetDB().autoLockOnUse = value and true or false
                            -- If turning off, also unlock any currently locked item
                            if not value then
                                local btn = _G.ElvQuestButton or _G[addonName]
                                if btn and btn.lockedItemLink and not btn.inCombat then
                                    btn:SetLockedItem(nil)
                                    btn:UpdateState()
                                end
                            end
                        end,
                    },
                    scrollToSwitch = {
                        order = 13,
                        type = 'toggle',
                        name = "Scroll to Switch",
                        desc = "Scroll the mouse wheel while hovering the button to cycle between available quest items.",
                        get = function() return self:GetDB().scrollToSwitch end,
                        set = function(_, value)
                            self:GetDB().scrollToSwitch = value
                        end,
                    },
                    lockOnSwitch = {
                        order = 14,
                        type = 'toggle',
                        name = "Lock When Switching",
                        desc = "Controls what happens after you switch items (by scrolling or the Switch button).\n\n|cff33ff99On:|r the chosen item is locked (gold) and stays until you unlock it.\n\n|cffffd100Off (default):|r the chosen item is simply displayed and sticks while it's nearby, with no lock — it clears on its own when you leave the area.",
                        get = function() return self:GetDB().lockOnSwitch end,
                        set = function(_, value)
                            self:GetDB().lockOnSwitch = value
                            -- Switching the mode: drop any stale soft selection / hard lock
                            -- so the change takes effect cleanly on the next update.
                            local btn = _G.ElvQuestButton or _G[addonName]
                            if btn and not btn.inCombat then
                                btn.selectedItemLink = nil
                                if btn.lockedItemLink then btn:SetLockedItem(nil) end
                                if btn.UpdateState then btn:UpdateState() end
                            end
                        end,
                    },
                },
            },

            -- Group 3: Button Appearance (Visuals)
            appearanceGroup = {
                order = 30,
                type = 'group',
                name = "Button Appearance",
                inline = true,
                args = {
                    scale = {
                        order = 1,
                        type = 'range',
                        name = L["Scale"],
                        desc = "Button scale",
                        min = 0.1, max = 3, step = 0.01,
                        isPercent = true,
                        get = function() return self:GetDB().scale end,
                        set = function(_, value)
                            self:GetDB().scale = value
                            self:UpdateButton()
                        end,
                    },
                    alpha = {
                        order = 2,
                        type = 'range',
                        name = L["Alpha"],
                        desc = "Button transparency",
                        min = 0, max = 1, step = 0.01,
                        isPercent = true,
                        get = function() return self:GetDB().alpha end,
                        set = function(_, value)
                            self:GetDB().alpha = value
                            self:UpdateButton()
                        end,
                    },
                    toolsScale = {
                        order = 3,
                        type = 'range',
                        name = "Tools Scale",
                        desc = "Scale of the Lock and Switch buttons",
                        min = 0.5, max = 2, step = 0.1,
                        get = function() return self:GetDB().lockScale end,
                        set = function(_, value)
                            self:GetDB().lockScale = value
                            self:UpdateButton()
                        end,
                    },
                    noCooldownText = {
                        order = 4,
                        type = 'toggle',
                        name = "Hide Cooldown Text",
                        desc = "Hide the countdown numbers on cooldown",
                        get = function() return self:GetDB().noCooldownText end,
                        set = function(_, value)
                            self:GetDB().noCooldownText = value
                            if button and button.EnableCooldownText then
                                button:EnableCooldownText(not value)
                            end
                        end,
                    },
                    itemCountBadge = {
                        order = 5,
                        type = 'select',
                        name = "Item Count Badge",
                        desc = "Show which item you're on out of how many are available (e.g. '2/5').",
                        -- sorting = "key", -- CAUSES CRASH: Ace3 doesn't support this
                        values = {
                            ['0_NONE'] = "None",
                            ['1_SWITCH'] = "On Switch Button",
                            ['2_BUTTON'] = "On Quest Button",
                        },
                        get = function() 
                            -- Map stored value back to prefixed key
                            local val = self:GetDB().itemCountBadge or 'NONE'
                            if val == 'NONE' then return '0_NONE' end
                            if val == 'SWITCH' then return '1_SWITCH' end
                            if val == 'BUTTON' then return '2_BUTTON' end
                            return '0_NONE'
                        end,
                        set = function(_, value)
                            -- Strip prefix before storing
                            local actualValue = 'NONE'
                            if value == '0_NONE' then actualValue = 'NONE' end
                            if value == '1_SWITCH' then actualValue = 'SWITCH' end
                            if value == '2_BUTTON' then actualValue = 'BUTTON' end
                            
                            self:GetDB().itemCountBadge = actualValue
                            -- Force update button state to refresh badge visibility
                            if button and button.UpdateState then button:UpdateState() end
                        end,
                    },
                    itemCountFontSize = {
                        order = 6,
                        type = 'range',
                        name = "Item Count Font Size",
                        desc = "Font size for the item count badge",
                        min = 6, max = 32, step = 1,
                        get = function() return self:GetDB().itemCountFontSize end,
                        set = function(_, value)
                            self:GetDB().itemCountFontSize = value
                            self:UpdateButton()
                        end,
                        disabled = function() return (self:GetDB().itemCountBadge or 'NONE') == 'NONE' end,
                    },
                    toolsHeader = {
                        order = 7,
                        type = 'header',
                        name = "Lock & Switch Buttons",
                    },
                    lockIconStyle = {
                        order = 8,
                        type = 'select',
                        name = "Lock Icon",
                        desc = "Which icon to use for the Lock button.",
                        values = lockIconValues,
                        sorting = lockIconSorting,
                        get = function() return self:GetDB().lockIconStyle or 'Padlock' end,
                        set = function(_, value)
                            self:GetDB().lockIconStyle = value
                            self:UpdateButton()
                        end,
                    },
                    switchIconStyle = {
                        order = 9,
                        type = 'select',
                        name = "Switch Icon",
                        desc = "Which icon to use for the Switch button.",
                        values = switchIconValues,
                        sorting = switchIconSorting,
                        get = function() return self:GetDB().switchIconStyle or 'Refresh' end,
                        set = function(_, value)
                            self:GetDB().switchIconStyle = value
                            self:UpdateButton()
                        end,
                    },
                    artworkHeader = {
                        order = 10,
                        type = 'header',
                        name = "Artwork Background",
                    },
                    artworkEnabled = {
                        order = 11,
                        type = 'toggle',
                        name = "Show Artwork Background",
                        desc = "Draw the classic ExtraButton artwork frame behind the button. The ElvUI skin stays on top; the artwork extends past the button as decorative framing.",
                        get = function() return self:GetDB().artworkEnabled end,
                        set = function(_, value)
                            self:GetDB().artworkEnabled = value
                            self:UpdateButton()
                        end,
                    },
                    artworkStyle = {
                        order = 12,
                        type = 'select',
                        name = "Artwork Style",
                        desc = "Which ExtraButton artwork frame to show behind the button.",
                        values = artworkValues,
                        sorting = artworkSorting,
                        get = function() return self:GetDB().artworkStyle or 'Default' end,
                        set = function(_, value)
                            self:GetDB().artworkStyle = value
                            self:UpdateButton()
                        end,
                        disabled = function() return not self:GetDB().artworkEnabled end,
                    },
                    artworkAlpha = {
                        order = 13,
                        type = 'range',
                        name = "Artwork Opacity",
                        desc = "Opacity of the artwork background.",
                        min = 0, max = 1, step = 0.05,
                        isPercent = true,
                        get = function() return self:GetDB().artworkAlpha end,
                        set = function(_, value)
                            self:GetDB().artworkAlpha = value
                            self:UpdateButton()
                        end,
                        disabled = function() return not self:GetDB().artworkEnabled end,
                    },
                    artworkScale = {
                        order = 14,
                        type = 'range',
                        name = "Artwork Size",
                        desc = "Size of the artwork relative to its native dimensions.",
                        min = 0.5, max = 2, step = 0.05,
                        isPercent = true,
                        get = function() return self:GetDB().artworkScale or 1 end,
                        set = function(_, value)
                            self:GetDB().artworkScale = value
                            self:UpdateButton()
                        end,
                        disabled = function() return not self:GetDB().artworkEnabled end,
                    },
                    artworkRotation = {
                        order = 15,
                        type = 'range',
                        name = "Artwork Rotation",
                        desc = "Rotate the artwork (degrees).",
                        min = 0, max = 360, step = 1,
                        get = function() return self:GetDB().artworkRotation or 0 end,
                        set = function(_, value)
                            self:GetDB().artworkRotation = value
                            self:UpdateButton()
                        end,
                        disabled = function() return not self:GetDB().artworkEnabled end,
                    },
                },
            },
            
            -- Group 4: Fonts & Text Settings
            fontsGroup = {
                order = 40,
                type = 'group',
                name = "Fonts & Text",
                inline = false,
                args = {
                    countHeader = { order = 1, type = 'header', name = "Stack Count" },
                    countFont = {
                        order = 2, type = 'select', dialogControl = 'LSM30_Font',
                        name = L["Font"],
                        values = AceGUIWidgetLSMlists and AceGUIWidgetLSMlists.font or {},
                        get = function() return self:GetDB().countFont end,
                        set = function(_, value) self:GetDB().countFont = value; self:UpdateButton() end,
                    },
                    countFontSize = {
                        order = 3, type = 'range', name = L["Font Size"],
                        min = 6, max = 32, step = 1,
                        get = function() return self:GetDB().countFontSize end,
                        set = function(_, value) self:GetDB().countFontSize = value; self:UpdateButton() end,
                    },
                    countFontOutline = {
                        order = 4, type = 'select', name = L["Font Outline"],
                        values = { ['NONE'] = L["None"], ['OUTLINE'] = 'OUTLINE', ['MONOCHROMEOUTLINE'] = 'MONOCROMEOUTLINE', ['THICKOUTLINE'] = 'THICKOUTLINE' },
                        get = function() return self:GetDB().countFontOutline end,
                        set = function(_, value) self:GetDB().countFontOutline = value; self:UpdateButton() end,
                    },
                    countXOffset = {
                        order = 5, type = 'range', name = L["X-Offset"], min = -50, max = 50, step = 1,
                        get = function() return self:GetDB().countXOffset end,
                        set = function(_, value) self:GetDB().countXOffset = value; self:UpdateButton() end,
                    },
                    countYOffset = {
                        order = 6, type = 'range', name = L["Y-Offset"], min = -50, max = 50, step = 1,
                        get = function() return self:GetDB().countYOffset end,
                        set = function(_, value) self:GetDB().countYOffset = value; self:UpdateButton() end,
                    },
                    
                    hotkeyHeader = { order = 10, type = 'header', name = "Keybind Text" },
                    hotkeyFont = {
                        order = 11, type = 'select', dialogControl = 'LSM30_Font',
                        name = L["Font"],
                        values = AceGUIWidgetLSMlists and AceGUIWidgetLSMlists.font or {},
                        get = function() return self:GetDB().hotkeyFont end,
                        set = function(_, value) self:GetDB().hotkeyFont = value; self:UpdateButton() end,
                    },
                    hotkeyFontSize = {
                        order = 12, type = 'range', name = L["Font Size"],
                        min = 6, max = 32, step = 1,
                        get = function() return self:GetDB().hotkeyFontSize end,
                        set = function(_, value) self:GetDB().hotkeyFontSize = value; self:UpdateButton() end,
                    },
                    hotkeyFontOutline = {
                        order = 13, type = 'select', name = L["Font Outline"],
                        values = { ['NONE'] = L["None"], ['OUTLINE'] = 'OUTLINE', ['MONOCHROMEOUTLINE'] = 'MONOCROMEOUTLINE', ['THICKOUTLINE'] = 'THICKOUTLINE' },
                        get = function() return self:GetDB().hotkeyFontOutline end,
                        set = function(_, value) self:GetDB().hotkeyFontOutline = value; self:UpdateButton() end,
                    },
                    hotkeyXOffset = {
                        order = 14, type = 'range', name = L["X-Offset"], min = -50, max = 50, step = 1,
                        get = function() return self:GetDB().hotkeyXOffset end,
                        set = function(_, value) self:GetDB().hotkeyXOffset = value; self:UpdateButton() end,
                    },
                    hotkeyYOffset = {
                        order = 15, type = 'range', name = L["Y-Offset"], min = -50, max = 50, step = 1,
                        get = function() return self:GetDB().hotkeyYOffset end,
                        set = function(_, value) self:GetDB().hotkeyYOffset = value; self:UpdateButton() end,
                    },
                },
            },
        },
    }
    
    EQB.Debug("Options inserted")
end
