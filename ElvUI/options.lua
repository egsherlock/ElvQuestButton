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
                        desc = "Fade button with action bars",
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
                    distanceYd = {
                        order = 3,
                        type = 'range',
                        name = "Tracking Distance",
                        desc = "Maximum distance in yards to show quest items",
                        min = 5, max = 10000, step = 5,
                        get = function() return self:GetDB().distanceYd end,
                        set = function(_, value)
                            self:GetDB().distanceYd = value
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
