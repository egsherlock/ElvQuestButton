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
                        desc = "Scroll the mouse wheel while hovering the button to cycle between available quest items.\n\n|cffaaaaaaSwitching always locks to the selected item.|r\n\n|cffffd100Unlocks when:|r\n• Quest completes or is handed in\n• You leave the area\n• You click the Lock icon manually",
                        get = function() return self:GetDB().scrollToSwitch end,
                        set = function(_, value)
                            self:GetDB().scrollToSwitch = value
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
                },
            },
            
            -- Group 4: Fonts & Text Settings
            fontsGroup = {
                order = 40,
                type = 'group',
                name = "Fonts & Text",
                inline = false,
                args = {
                    countHeader = { order = 1, type = 'header', name = "Count Text" },
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
