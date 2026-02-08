--[[
    ElvQuestButton - ElvUI Core Integration
    
    Creates the holder frame, ElvUI mover, and applies skinning.
    Follows the same pattern as ElvUI's ExtraAB.lua for ExtraActionButton.
]]

local addonName, addon = ...

if not _G.ElvUI then return end

local E, L, V, P, G = unpack(_G.ElvUI)
local EQB = addon.ElvUIModule
local AB = E:GetModule('ActionBars', true)

local Debug = EQB.Debug

--[[
    Holder Frame & Mover
]]

function EQB:CreateHolder()
    if self.holder then return self.holder end
    
    local button = _G.ElvQuestButton or _G[addonName]
    if not button then return nil end
    
    -- Create holder frame (like ElvUI_ExtraActionBarHolder)
    local holder = CreateFrame('Frame', 'ElvUI_ElvQuestButtonHolder', E.UIParent)
    holder:Size(52, 52)
    holder:Point('BOTTOM', E.UIParent, 'BOTTOM', 0, 350)
    
    -- Prevent accidental hiding
    E.FrameLocks[holder] = true
    
    -- Create ElvUI mover
    E:CreateMover(
        holder,
        'ElvQuestButtonMover',
        'Quest Item Button',
        nil,
        nil,
        nil,
        'ALL,ACTIONBARS',
        nil,
        'elvQuestButton'
    )
    
    self.holder = holder
    Debug("Created holder and mover")
    
    return holder
end

--[[
    Button Setup & Skinning
]]

function EQB:SetupButton()
    local button = _G.ElvQuestButton or _G[addonName]
    if not button or not self.holder then return end
    
    if button.__elvuiSetup then return end
    
    Debug("Setting up button")
    
    -- Reparent to holder
    button:SetParent(self.holder)
    button:ClearAllPoints()
    button:SetAllPoints(self.holder)
    
    -- Apply ElvUI skinning
    self:SkinButton(button)
    
    -- Hide from Blizzard Edit Mode
    self:DisableEditMode(button)
    
    -- Hook OnShow to maintain skin
    button:HookScript('OnShow', function(self)
        EQB:OnButtonShow(self)
    end)
    
    button.__elvuiSetup = true
end

function EQB:SkinButton(button)
    if button.__elvuiSkinned then return end
    
    Debug("Skinning button")
    
    -- Hide all original textures except Icon
    local regionsToHide = {
        button.Artwork,
        button:GetNormalTexture(),
        button:GetPushedTexture(),
        button:GetHighlightTexture(),
    }
    
    for _, region in ipairs(regionsToHide) do
        if region then
            region:SetAlpha(0)
            region:Hide()
        end
    end
    
    -- Remove masks from icon
    if button.Icon then
        local mask = button.Icon:GetMaskTexture(1)
        if mask then
            button.Icon:RemoveMaskTexture(mask)
            mask:Hide()
        end
    end
    
    -- Create ElvUI backdrop
    button:CreateBackdrop('Transparent')
    
    if button.backdrop then
        button.backdrop:SetAllPoints(button)
        button.backdrop:SetFrameLevel(button:GetFrameLevel())
    end
    
    -- Style button using ActionBars module if available
    if AB and AB.StyleButton then
        AB:StyleButton(button, true)
    end
    
    -- Setup icon properly
    if button.Icon then
        button.Icon:SetDrawLayer('ARTWORK', -1)
        
        -- Apply ElvUI texture coordinates (trimmed edges)
        if E.TexCoords then
            button.Icon:SetTexCoord(unpack(E.TexCoords))
        end
        
        -- Position inside backdrop
        if button.Icon.SetInside then
            button.Icon:SetInside(button.backdrop or button)
        else
            button.Icon:ClearAllPoints()
            button.Icon:SetPoint('TOPLEFT', button, 'TOPLEFT', 2, -2)
            button.Icon:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', -2, 2)
        end
        
        button.Icon:SetAlpha(1)
        button.Icon:Show()
    end
    
    -- Register cooldown with ElvUI
    if button.Cooldown and E.RegisterCooldown then
        E:RegisterCooldown(button.Cooldown, 'actionbar')
    end
    
    button.__elvuiSkinned = true
    Debug("Button skinned")
end

--[[
    Edit Mode Handling
]]

function EQB:DisableEditMode(button)
    -- When ElvUI is managing, completely hide from Blizzard Edit Mode
    if _G.EditModeManagerFrame then
        hooksecurefunc(_G.EditModeManagerFrame, 'Show', function()
            if button.elvuiManaged then
                button:Hide()
            end
        end)
        
        hooksecurefunc(_G.EditModeManagerFrame, 'Hide', function()
            if button.elvuiManaged and button:GetAttribute('item') then
                button:Show()
            end
        end)
    end
    
    Debug("Edit Mode handling configured")
end

--[[
    Button Updates
]]

function EQB:UpdateButton()
    local button = _G.ElvQuestButton or _G[addonName]
    if not button or not self.holder then return end
    
    local db = self:GetDB()
    if not db then return end
    
    -- Scale
    local scale = db.scale or 1
    button:SetScale(scale * E.uiscale)
    button:SetIgnoreParentScale(true)
    
    local width, height = button:GetSize()
    self.holder:SetSize(width * scale, height * scale)
    
    -- Alpha
    button:SetAlpha(db.alpha or 1)
    
    -- Parent for global fade
    if AB and AB.fadeParent then
        self.holder:SetParent(db.inheritGlobalFade and AB.fadeParent or E.UIParent)
    end
    
    -- Cooldown text
    if button.EnableCooldownText then
        button:EnableCooldownText(not db.noCooldownText)
    end
    
    Debug("Button updated")
end

function EQB:OnButtonShow(button)
    -- Don't show during Edit Mode
    if _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown() then
        button:Hide()
        return
    end
    
    -- Ensure skin is maintained
    if not button.__elvuiSkinned then
        self:SkinButton(button)
    end
    
    -- Keep textures hidden
    if button.Artwork then
        button.Artwork:SetAlpha(0)
    end
    
    if button.Icon then
        button.Icon:SetAlpha(1)
        button.Icon:Show()
    end
    
    -- Apply shadow if not already done (this is where it actually works - when button is visible)
    if not button.__windShadowApplied then
        self:ApplyShadow()
    end
    
    -- Ensure shadow is visible
    if button.shadow then
        button.shadow:Show()
    end
end

--[[
    Test Mode
    
    Allows previewing the button without needing an actual quest item.
    Useful for verifying skinning, shadows, and positioning.
]]

function EQB:ToggleTestMode()
    local button = _G.ElvQuestButton or _G[addonName]
    if not button then return end
    
    if button.testMode then
        -- Disable test mode
        button.testMode = nil
        button.editing = false
        
        -- Reset icon
        button:SetIcon(nil)
        button:Hide()
        
        -- Let normal quest logic take over
        if button.UpdateBinding then
            addon:DeferMethod(button, 'UpdateBinding')
        end
        if button.UpdateState then
            button:UpdateState()
        end
        
        Debug("Test mode disabled")
    else
        -- Enable test mode
        button.testMode = true
        button.editing = true  -- Prevents normal state updates from hiding
        
        -- Bypass state driver
        UnregisterStateDriver(button, 'visible')
        button:SetAttribute('item', 'test')  -- Fake item to prevent hiding logic
        
        -- Show with test icon
        button:SetIcon([[Interface\Icons\INV_Misc_QuestionMark]])
        button:ClearCooldown()
        button:SetCount(0)
        button:Show()
        
        -- Ensure skinning is applied
        if not button.__elvuiSkinned then
            self:SkinButton(button)
        end
        
        -- Apply shadow - clear ALL flags first
        button.__windShadow = nil
        button.__windShadowApplied = nil
        if button.backdrop then
            button.backdrop.__windShadow = nil
        end
        
        -- Try applying shadow immediately
        self:ApplyShadow()
        
        -- Also try again with delay in case WindTools needs the frame to settle
        C_Timer.After(0.2, function()
            if not button.shadow then
                button.__windShadow = nil
                button.__windShadowApplied = nil
                self:ApplyShadow()
            end
        end)
        
        C_Timer.After(0.5, function()
            if not button.shadow then
                button.__windShadow = nil
                button.__windShadowApplied = nil
                self:ApplyShadow()
            end
        end)
        
        Debug("Test mode enabled")
    end
    
    return button.testMode
end

function EQB:IsTestMode()
    local button = _G.ElvQuestButton or _G[addonName]
    return button and button.testMode
end
