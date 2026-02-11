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
    
    Debug("Setting up button: " .. tostring(button:GetName()))
    
    -- Reparent to holder
    button:SetParent(self.holder)
    button:ClearAllPoints()
    button:SetAllPoints(self.holder)
    
    -- Apply ElvUI skinning (protected so errors don't block keybind setup)
    local skinOk, skinErr = pcall(function() self:SkinButton(button) end)
    if not skinOk then
        Debug("SkinButton error: " .. tostring(skinErr))
    end
    
    -- Hide from Blizzard Edit Mode
    pcall(function() self:DisableEditMode(button) end)
    
    -- Hook OnShow to maintain skin
    button:HookScript('OnShow', function(self)
        EQB:OnButtonShow(self)
    end)
    
    button.__elvuiSetup = true
    Debug("SetupButton complete")
end

-- Separate keybind registration - must run AFTER SetupButton
function EQB:SetupKeybind()
    local button = _G.ElvQuestButton or _G[addonName]
    if not button then return end
    if not AB then return end
    
    -- Use the SAME binding command as our Bindings.xml defines
    -- This way ElvUI /kb and our own UpdateBinding() stay in sync
    local bindName = addonName:upper() -- "ELVQUESTBUTTON" - matches Bindings.xml
    button.keyBoundTarget = bindName
    button.commandName = bindName
    
    -- Register in ElvUI's handled buttons table
    AB.handledbuttons = AB.handledbuttons or {}
    AB.handledbuttons[button] = true
    
    -- Hook OnEnter to trigger BindUpdate when hovered in /kb mode
    button:HookScript('OnEnter', function(btn)
        local bind = AB.KeyBinder
        if bind and bind.active then
            AB:BindUpdate(btn)
        end
    end)
    
    -- Show our custom tooltip after ALL event cascading has completed.
    -- We defer to the next frame with C_Timer.After(0) so nothing overwrites us.
    -- This fires on initial hover AND after every key press (bind/clear/escape).
    local function ShowBindTooltip()
        local tt = _G.GameTooltip
        if tt:IsForbidden() then return end
        
        local bind = AB.KeyBinder
        if not bind or not bind.active or bind.button ~= button then return end
        
        tt:SetOwner(bind, 'ANCHOR_TOP')
        tt:SetPoint('BOTTOM', bind, 'TOP', 0, 1)
        tt:AddLine('Quest Item Button', 1, 1, 1)
        
        local bindings = { GetBindingKey(bindName) }
        if #bindings > 0 then
            tt:AddDoubleLine('Binding', 'Key', 0.6, 0.6, 0.6, 0.6, 0.6, 0.6)
            for i, key in ipairs(bindings) do
                tt:AddDoubleLine('Binding ' .. i, GetBindingText(key, 1), 1, 1, 1)
            end
        else
            local fallbackKey = GetBindingKey('EXTRAACTIONBUTTON1')
            if fallbackKey then
                tt:AddLine('Using ExtraActionButton default: ' .. GetBindingText(fallbackKey, 1), 1, 0.82, 0)
                tt:AddLine('Set a new bind for a dedicated key', 0.4, 0.8, 1)
            else
                tt:AddLine('No bindings set.', 0.6, 0.6, 0.6)
                tt:AddLine('Press a key to bind', 0.4, 0.8, 1)
            end
        end
        
        tt:Show()
    end
    
    hooksecurefunc(AB, 'BindUpdate', function(_, btn)
        if btn ~= button then return end
        C_Timer.After(0, ShowBindTooltip)
    end)
    
    Debug("Registered with ElvUI keybind system: " .. bindName)
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
    
    -- Skin Features Frame Buttons
    if button.LockButton then
        -- Desaturate and colorize for clean look
        local lockTex = button.LockButton:GetNormalTexture()
        if lockTex then
            lockTex:SetDesaturated(true)
            lockTex:SetVertexColor(0.6, 0.6, 0.6)
        end
        
        -- Hook update to maintain styling
        hooksecurefunc(button, 'UpdateFeatures', function()
             -- Re-apply ElvUI specific colors if needed, 
             -- though button.lua already handles basic coloring.
             -- We can make it cleaner here if desired.
        end)
    end
    
    if button.SwitchButton then
        -- Cleaner look for switch button
         local switchTex = button.SwitchButton:GetNormalTexture()
         if switchTex then
             switchTex:SetDesaturated(true)
         end
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
    
    -- Fonts & Text
    local LSM = E.Libs.LSM
    if LSM then
        -- Count
        local countFont = LSM:Fetch("font", db.countFont)
        if countFont then
            button.Count:SetFont(countFont, db.countFontSize or 16, db.countFontOutline or "OUTLINE")
            button.Count:ClearAllPoints()
            button.Count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -6 + (db.countXOffset or 0), 6 + (db.countYOffset or 0))
        end
        
        -- HotKey
        local hotkeyFont = LSM:Fetch("font", db.hotkeyFont)
        if hotkeyFont then
            button.HotKey:SetFont(hotkeyFont, db.hotkeyFontSize or 16, db.hotkeyFontOutline or "OUTLINE")
            button.HotKey:ClearAllPoints()
            button.HotKey:SetPoint("TOPRIGHT", button, "TOPRIGHT", -6 + (db.hotkeyXOffset or 0), -6 + (db.hotkeyYOffset or 0))
        end
    end
    
    -- Features Scale
    if button.FeaturesFrame then
        button.FeaturesFrame:SetScale(db.lockScale or 1)
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

function EQB:ToggleTestMode(mode)
    local button = _G.ElvQuestButton or _G[addonName]
    if not button then return end
    
    if button.testMode and not mode then
        -- Disable test mode
        button.testMode = nil
        button.editing = false
        button.lastNearbyItems = nil -- clear test items
        
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
        
        -- Mock Multi-Item Mode
        if mode == 'multi' then
             button.lastNearbyItems = {
                 'item:1', -- Fake links
                 'item:2',
                 'item:3'
             }
             -- Override SetItem to just change the icon for visual feeback
             button.SetItem = function(self, link)
                 if link == 'item:1' then self:SetIcon([[Interface\Icons\INV_Misc_QuestionMark]])
                 elseif link == 'item:2' then self:SetIcon([[Interface\Icons\INV_ChooseExclamation]])
                 elseif link == 'item:3' then self:SetIcon([[Interface\Icons\INV_Misc_Coin_17]]) end
                 -- self.targetItem = link -- Removed to prevent breaking UpdateState logic
                 self:UpdateFeatures()
             end
             -- Override GetItemLink to return our fake link
             button.GetItemLink = function(self)
                 return self.targetItem
             end
             
             -- Trigger initial item
             button:SetItem('item:1')
             Debug("Test mode enabled (Multi-Item)")
        else
            Debug("Test mode enabled")
        end
        
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
    end
    
    return button.testMode
end

function EQB:IsTestMode()
    local button = _G.ElvQuestButton or _G[addonName]
    return button and button.testMode
end
