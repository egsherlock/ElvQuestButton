--[[
    ExtraQuestButton Skin for ElvUI WindTools
    
    Uses WindTools' actual skin module (S:CreateShadow) directly,
    the same way WindTools skins ExtraActionButton/ZoneAbilityFrame.
]]

local addonName, addon = ...

local DEBUG = true
local function Debug(...)
    if DEBUG then
        print("|cff00ff00[EQB-Skin]|r", ...)
    end
end

--[[
    Apply WindTools skin using their actual skin module
]]
local function ApplyWindToolsSkin(button)
    if not button then return false end
    if button.__windSkinApplied then return true end
    
    -- Get WindTools references
    local W = _G.WindTools and _G.WindTools[1]
    local E = _G.ElvUI and _G.ElvUI[1]
    
    if not E then
        Debug("ElvUI not found")
        return false
    end
    
    -- Check if WindTools skins are enabled
    if not E.private or not E.private.WT or not E.private.WT.skins then
        Debug("WindTools skins not configured")
        return false
    end
    
    if not E.private.WT.skins.enable then
        Debug("WindTools skins disabled")
        return false
    end
    
    if not E.private.WT.skins.shadow then
        Debug("WindTools shadow disabled")
        return false
    end
    
    -- Get the WindTools Skins module
    local S = W and W.Modules and W.Modules.Skins
    if not S then
        Debug("WindTools Skins module not found, trying alternate path")
        -- Try alternate access method
        if W and W.GetModule then
            S = W:GetModule("Skins", true)
        end
    end
    
    if not S or not S.CreateShadow then
        Debug("WindTools S:CreateShadow not available")
        return false
    end
    
    Debug("=== Applying WindTools skin ===")
    
    -- Set flag to prevent re-entry
    button.__windSkinApplied = true
    
    -- =============================================
    -- STEP 1: Hide original button textures
    -- =============================================
    for _, region in ipairs({button:GetRegions()}) do
        local name = region:GetDebugName() or ""
        local objType = region:GetObjectType()
        
        if not name:find("Icon") or name:find("Mask") then
            if objType == "Texture" or objType == "MaskTexture" then
                region:SetAlpha(0)
                region:Hide()
            end
        end
    end
    
    -- =============================================
    -- STEP 2: Remove masks from icon and set texcoords
    -- =============================================
    if button.Icon then
        for i = 1, 10 do
            local m = button.Icon:GetMaskTexture(i)
            if m then
                button.Icon:RemoveMaskTexture(m)
                m:Hide()
            end
        end
        button.Icon:SetTexCoord(0, 1, 0, 1)
        button.Icon:SetAlpha(1)
        button.Icon:Show()
        
        -- Set icon to fill the button
        button.Icon:ClearAllPoints()
        if button.Icon.SetInside then
            button.Icon:SetInside(button, 0, 0)
        else
            button.Icon:SetAllPoints(button)
        end
    end
    
    -- =============================================
    -- STEP 3: Create invisible backdrop for pixel alignment
    -- =============================================
    -- The backdrop provides pixel-perfect anchoring for the shadow.
    -- We create it but make it invisible.
    if button.CreateBackdrop and not button.backdrop then
        button:CreateBackdrop("Transparent")
        Debug("Created backdrop for pixel alignment")
    end
    
    -- Make backdrop invisible (we only need it for pixel-perfect shadow anchor)
    if button.backdrop then
        -- Hide the backdrop's visual elements but keep the frame
        if button.backdrop.SetBackdropColor then
            button.backdrop:SetBackdropColor(0, 0, 0, 0)
        end
        if button.backdrop.SetBackdropBorderColor then
            button.backdrop:SetBackdropBorderColor(0, 0, 0, 0)
        end
        Debug("Made backdrop invisible")
    end
    
    -- =============================================
    -- STEP 4: Use WindTools' CreateBackdropShadow
    -- This applies shadow to the backdrop (like ExtraActionButton)
    -- =============================================
    if S.CreateBackdropShadow then
        S:CreateBackdropShadow(button, true)
        Debug("Applied WindTools S:CreateBackdropShadow")
    else
        -- Fallback to regular CreateShadow
        S:CreateShadow(button)
        Debug("Applied WindTools S:CreateShadow (fallback)")
    end
    
    -- Bind shadow color with border if available
    if button.shadow and button.shadow.__wind and S.BindShadowColorWithBorder then
        S:BindShadowColorWithBorder(button)
    end
    
    if button.shadow then
        Debug("Shadow size:", button.shadow:GetWidth(), "x", button.shadow:GetHeight())
    elseif button.backdrop and button.backdrop.shadow then
        Debug("Backdrop shadow size:", button.backdrop.shadow:GetWidth(), "x", button.backdrop.shadow:GetHeight())
    end
    
    Debug("Skin applied successfully")
    return true
end

--[[
    Maintain skin on show
]]
local function OnButtonShow(button)
    -- Keep textures hidden
    for _, region in ipairs({button:GetRegions()}) do
        local name = region:GetDebugName() or ""
        if not name:find("Icon") or name:find("Mask") then
            region:SetAlpha(0)
            region:Hide()
        end
    end
    
    if button.Icon then
        button.Icon:SetAlpha(1)
        button.Icon:Show()
    end
    
    if not button.__windSkinApplied then
        ApplyWindToolsSkin(button)
    end
    
    if button.shadow then
        button.shadow:Show()
    end
end

--[[
    Initialize
]]
local function Initialize()
    local button = _G.ExtraQuestButton
    if not button then
        Debug("ExtraQuestButton not found")
        return false
    end
    
    button:HookScript("OnShow", OnButtonShow)
    ApplyWindToolsSkin(button)
    
    if button:IsShown() then
        OnButtonShow(button)
    end
    
    return true
end

local eventFrame = CreateFrame("Frame")
local initialized = false

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- Wait for WindTools to fully initialize
        C_Timer.After(3, function()
            if not initialized then
                initialized = Initialize()
            end
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(4, function()
            local button = _G.ExtraQuestButton
            if button and not button.__windSkinApplied then
                ApplyWindToolsSkin(button)
            end
        end)
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)

Debug("Skin file loaded - using WindTools S:CreateShadow")
