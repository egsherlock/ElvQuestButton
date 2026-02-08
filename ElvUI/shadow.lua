--[[
    ElvQuestButton - WindTools Shadow Integration
    
    Applies WindTools shadow using the same method they use for ExtraActionButton.
    This hooks into their existing system rather than calling methods directly.
]]

local addonName, addon = ...

if not _G.ElvUI then return end

local E, L, V, P, G = unpack(_G.ElvUI)
local EQB = addon.ElvUIModule

local Debug = EQB.Debug

--[[
    WindTools Detection
]]

local function GetWindTools()
    if not _G.WindTools then return nil, nil end
    
    local W = _G.WindTools[1]
    local S = W and W.Modules and W.Modules.Skins
    
    return W, S
end

local function IsWindToolsShadowEnabled()
    if not E.private or not E.private.WT or not E.private.WT.skins then
        return false
    end
    
    return E.private.WT.skins.enable and E.private.WT.skins.shadow
end

--[[
    Shadow Application
    
    WindTools uses S:CreateBackdropShadow(frame, true) for action buttons.
    The second parameter 'true' tells it to create the shadow on the frame's backdrop.
]]

function EQB:ApplyShadow()
    local button = _G.ElvQuestButton or _G[addonName]
    if not button then return end
    
    -- Don't re-apply if already done
    if button.__windShadowApplied then
        -- Just ensure visibility
        if button.shadow then button.shadow:Show() end
        return
    end
    
    local W, S = GetWindTools()
    
    Debug("Checking WindTools - W:", W ~= nil, "S:", S ~= nil)
    
    if not S then
        Debug("WindTools Skins module not available")
        return
    end
    
    if not IsWindToolsShadowEnabled() then
        Debug("WindTools shadow not enabled in settings")
        return
    end
    
    Debug("Applying WindTools shadow...")
    
    -- Clear any previous failed attempts so CreateShadow will work
    button.__windShadow = nil
    if button.shadow then
        button.shadow:Hide()
        button.shadow = nil
    end
    
    if button.backdrop then
        button.backdrop.__windShadow = nil
        if button.backdrop.shadow then
            button.backdrop.shadow:Hide()
            button.backdrop.shadow = nil
        end
    end
    
    -- Use CreateShadow on the appropriate frame
    -- If we have a backdrop (standard ElvUI skinning), shadow the backdrop
    -- If no backdrop (ExtraActionButton style), shadow the button itself
    if S.CreateShadow then
        if button.backdrop then
            S:CreateShadow(button.backdrop)
            Debug("Called S:CreateShadow on button.backdrop")
        else
            S:CreateShadow(button)
            Debug("Called S:CreateShadow on button")
        end
    end
    
    -- Verify shadow was created
    local shadowCreated = button.shadow or (button.backdrop and button.backdrop.shadow)
    
    if shadowCreated then
        button.__windShadowApplied = true
        if button.shadow then button.shadow:Show() end
        if button.backdrop and button.backdrop.shadow then button.backdrop.shadow:Show() end
        
        Debug("WindTools shadow applied and showing")
    else
        Debug("Shadow creation failed")
    end
end

--[[
    WindTools Shadow Integration Strategy
    
    WindTools applies shadows to ExtraActionButton via S:ElvUI_ActionBars() callback.
    Our button is not in the ExtraActionBarFrame, so WindTools never sees it.
    
    Strategy:
    1. Hook into WindTools' ElvUI_ActionBars function to catch when it runs
    2. Apply shadow after WindTools has fully initialized
    3. Re-apply shadow on button show in case initialization order varies
]]

function EQB:HookWindToolsActionBars()
    local W, S = GetWindTools()
    if not S then return end
    
    -- Hook the ElvUI_ActionBars function that WindTools uses
    if S.ElvUI_ActionBars then
        hooksecurefunc(S, "ElvUI_ActionBars", function()
            -- WindTools just processed action bars, now add our button
            C_Timer.After(0.2, function()
                EQB:ApplyShadow()
            end)
        end)
        Debug("Hooked WindTools S:ElvUI_ActionBars")
    end
    
    -- Also try to apply immediately if WindTools already ran
    C_Timer.After(0.5, function()
        EQB:ApplyShadow()
    end)
end

-- Multiple initialization attempts to ensure shadow is applied
local function InitializeShadow()
    local W, S = GetWindTools()
    if not S then 
        Debug("WindTools Skins not available")
        return 
    end
    
    -- Attempt 1: Hook the function
    EQB:HookWindToolsActionBars()
    
    -- Attempt 2: Direct apply after delay
    C_Timer.After(1.5, function()
        EQB:ApplyShadow()
    end)
    
    -- Attempt 3: Apply when button becomes visible
    local button = _G.ElvQuestButton or _G[addonName]
    if button and not button.__shadowHooked then
        button:HookScript("OnShow", function()
            if not button.shadow then
                EQB:ApplyShadow()
            end
        end)
        button.__shadowHooked = true
    end
end

-- Initialize after PLAYER_ENTERING_WORLD to ensure WindTools is loaded
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event)
    C_Timer.After(2, InitializeShadow)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end)

-- Diagnostic command
addon:RegisterSlash('/eqbshadow', function()
    local button = _G.ElvQuestButton or _G[addonName]
    local W, S = GetWindTools()
    
    print("|cff00ff00[ElvQuestButton Shadow Diagnostics]|r")
    print("  Button exists:", button ~= nil)
    print("  Button.backdrop:", button and button.backdrop ~= nil)
    print("  Button.shadow:", button and button.shadow ~= nil)
    print("  Button.backdrop.shadow:", button and button.backdrop and button.backdrop.shadow ~= nil)
    print("  Button.__windShadow:", button and button.__windShadow)
    print("  Button.__windShadowApplied:", button and button.__windShadowApplied)
    print("  WindTools[1]:", W ~= nil)
    print("  WindTools.Modules.Skins:", S ~= nil)
    print("  E.private.WT:", E.private and E.private.WT ~= nil)
    print("  E.private.WT.skins:", E.private and E.private.WT and E.private.WT.skins ~= nil)
    print("  Shadows enabled:", IsWindToolsShadowEnabled())
    
    if S and S.CreateShadow then
        print("  S:CreateShadow function:", "exists")
    else
        print("  S:CreateShadow function:", "MISSING")
    end
    
    -- Try to force apply shadow
    print("|cffff9900Attempting to force apply shadow...|r")
    if button then
        button.__windShadow = nil
        button.__windShadowApplied = nil
        if button.backdrop then
            button.backdrop.__windShadow = nil
        end
    end
    EQB:ApplyShadow()
    
    -- Check result
    print("  After apply - button.shadow:", button and button.shadow ~= nil)
    print("  After apply - backdrop.shadow:", button and button.backdrop and button.backdrop.shadow ~= nil)
    
    -- Compare with ExtraActionButton1
    local eab = _G.ExtraActionButton1
    if eab then
        print("|cff00ffffExtraActionButton1 comparison:|r")
        print("  EAB.shadow:", eab.shadow ~= nil)
        print("  EAB.backdrop:", eab.backdrop ~= nil)
        print("  EAB.backdrop.shadow:", eab.backdrop and eab.backdrop.shadow ~= nil)
        print("  EAB.__windShadow:", eab.__windShadow)
    else
        print("  ExtraActionButton1 not found")
    end
end)
