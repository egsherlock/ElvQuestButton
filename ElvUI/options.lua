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
        name = 'Quest Item Button',
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
                name = 'Displays a button for quest items in your bags.\nPosition using: |cff00ff00/moveui|r\n\n',
            },
            
            -- General Settings
            generalGroup = {
                order = 10,
                type = 'group',
                name = L["General"],
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
                    scale = {
                        order = 2,
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
                        order = 3,
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
                    inheritGlobalFade = {
                        order = 4,
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
                        order = 5,
                        type = 'execute',
                        name = function()
                            return self:IsTestMode() and "Hide Test" or "Test Button"
                        end,
                        desc = "Show/hide a preview of the button with a sample icon to verify styling",
                        func = function()
                            local isOn = self:ToggleTestMode()
                            -- Force options refresh to update button label
                            E:UpdateOptions()
                        end,
                    },
                },
            },
            
            -- Fonts & Text Settings
            fontsGroup = {
                order = 15,
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
            
            -- Quest Behavior
            behaviorGroup = {
                order = 20,
                type = 'group',
                name = "Quest Behavior",
                inline = true,
                args = {
                    trackingOnly = {
                        order = 1,
                        type = 'toggle',
                        name = "Only Tracked Quests",
                        desc = "Only show button for quests you are actively tracking",
                        get = function() return self:GetDB().trackingOnly end,
                        set = function(_, value)
                            self:GetDB().trackingOnly = value
                        end,
                    },
                    zoneOnly = {
                        order = 2,
                        type = 'toggle',
                        name = "Current Zone Only",
                        desc = "Only show button for quests in your current zone",
                        get = function() return self:GetDB().zoneOnly end,
                        set = function(_, value)
                            self:GetDB().zoneOnly = value
                        end,
                    },
                    autoLockOnUse = {
                        order = 3,
                        type = 'toggle',
                        name = "Auto-Lock After Use",
                        desc = "Automatically lock the quest item after clicking it, so it won't swap to a different item. Unlocks when the quest completes or you leave the area.",
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
                    lockScale = {
                         order = 5, type = 'range', name = "Tools Scale",
                         desc = "Scale of the Lock and Switch buttons",
                         min = 0.5, max = 2, step = 0.1,
                         get = function() return self:GetDB().lockScale end,
                         set = function(_, value)
                             self:GetDB().lockScale = value
                             self:UpdateButton()
                         end,
                    },
                },
            },
            
            -- Cooldown Settings
            cooldownGroup = {
                order = 30,
                type = 'group',
                name = "Cooldown",
                inline = true,
                args = {
                    noCooldownText = {
                        order = 1,
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
                },
            },
        },
    }
    
    EQB.Debug("Options inserted")
end
