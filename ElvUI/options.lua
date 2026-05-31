--[[
    ElvQuestButton - ElvUI Options (launcher)

    All settings now live in the bespoke panel (ElvUI/panel.lua), which is the
    single source of truth. This /ec entry is just a launcher into that panel, so
    there are no duplicate control sets to drift or conflict.
]]

local addonName, addon = ...

if not _G.ElvUI then return end

local E, L, V, P, G = unpack(_G.ElvUI)
local EQB = addon.ElvUIModule

function EQB:InsertOptions()
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
                fontSize = 'medium',
                name = 'Automatically detects and displays quest items based on proximity to objectives. The closest quest item is shown on the button — click it to use.\n\n'
                    .. 'All settings live in a dedicated, ElvUI-skinned panel.\n',
            },
            open = {
                order = 3,
                type = 'execute',
                name = 'Open ElvQuestButton Settings',
                desc = 'Open the dedicated ElvQuestButton configuration panel.',
                func = function()
                    if EQB.Panel then
                        EQB.Panel:Show()
                    end
                    -- Close the ElvUI config so the panel is visible underneath.
                    E:ToggleOptions()
                end,
            },
            test = {
                order = 4,
                type = 'execute',
                name = function()
                    return EQB:IsTestMode() and 'Hide Test Button' or 'Show Test Button'
                end,
                desc = 'Show/hide a preview of the button with sample icons.',
                func = function()
                    EQB:ToggleTestMode()
                    LibStub('AceConfigRegistry-3.0'):NotifyChange('ElvUI')
                end,
            },
            tips = {
                order = 5,
                type = 'description',
                name = '\n|cff00ff00/eqb|r open settings   •   |cff00ff00/moveui|r move the button   •   |cff00ff00/kb|r keybind',
            },
        },
    }

    EQB.Debug("Options inserted (launcher)")
end
