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
        'Quest Button',
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
    
    -- Hide all original textures except Icon and Artwork.
    -- Artwork is kept and re-layered below as an optional background (see below);
    -- its visibility is driven by the artwork settings in UpdateButton.
    local regionsToHide = {
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

    -- Re-layer the ExtraButton artwork as a background that sits BEHIND the
    -- ElvUI square skin. The icon (ARTWORK, -1) and backdrop child-frame render
    -- on top; the 256x128 art extends past the button as decorative framing.
    if button.Artwork then
        button.Artwork:SetDrawLayer('BACKGROUND', -8)
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

    -- Re-anchor the cooldown swirl to the skinned icon. The button.lua default
    -- insets (4px/3px) were tuned for the original Blizzard frame art; once
    -- ElvUI makes the icon fill the button, those insets leave the swirl ~4px
    -- short on every edge. Matching the icon makes it cover edge-to-edge.
    if button.Cooldown and button.Icon then
        button.Cooldown:ClearAllPoints()
        button.Cooldown:SetAllPoints(button.Icon)
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
    
    -- Scale (matches ElvUI Boss Button pattern: scale the holder, button inherits via SetAllPoints)
    local scale = db.scale or 1
    self.holder:SetScale(scale)
    self.holder:SetSize(52 * scale, 52 * scale)
    
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

    -- Artwork (optional background layer behind the ElvUI skin)
    if button.SetArtworkStyle then
        button:SetArtworkStyle(db.artworkStyle or 'Default')
        button:SetArtworkAlpha(db.artworkEnabled and (db.artworkAlpha or 1) or 0)
        if button.SetArtworkScale then button:SetArtworkScale(db.artworkScale or 1) end
        if button.SetArtworkRotation then button:SetArtworkRotation(db.artworkRotation or 0) end
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
        
        -- Item Count Badge Font (uses Count font family but custom size)
        local badgeFont = LSM:Fetch("font", db.countFont) -- Reuse count font family
        if badgeFont then
            local badgeSize = db.itemCountFontSize or 10
            local badgeOutline = db.countFontOutline or "OUTLINE" -- Reuse count outline
            
            if button.ItemIndex then
                button.ItemIndex:SetFont(badgeFont, badgeSize, badgeOutline)
            end
            
            -- Apply inverse scaling if on switch button to prevent distortion
            if button.SwitchButton and button.SwitchButton.Text then
                 -- Calculate inverse scale to keep text size consistent
                local toolsScale = db.lockScale or 1
                local effectiveSize = badgeSize / toolsScale
                
                button.SwitchButton.Text:SetFont(badgeFont, effectiveSize, badgeOutline)
            end
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
    
    -- Re-apply artwork visibility from settings (a re-show must not reset it).
    -- UpdateButton owns the actual style/alpha values; here we just make sure a
    -- freshly shown button reflects the current DB rather than a stale alpha.
    if button.Artwork then
        local db = self:GetDB()
        if db then
            button.Artwork:SetAlpha(db.artworkEnabled and (db.artworkAlpha or 1) or 0)
        end
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
    
    if InCombatLockdown() then
        if EQB.Print then
            EQB:Print("Cannot toggle test mode in combat")
        else
            print("|cff00ff00[ElvQuestButton]|r Cannot toggle test mode in combat")
        end
        return
    end

    if button.testMode then
        -- Disable test mode
        button.testMode = nil
        button.editing = false
        button.lastNearbyItems = nil -- clear test items
        button.lockedItemLink = nil  -- clear any test locks
        button.selectedItemLink = nil -- clear any test soft-selection
        button.targetItem = nil      -- clear test item tracking
        
        -- Restore ALL original methods
        if button._origSetItem then
            button.SetItem = button._origSetItem
            button._origSetItem = nil
        end
        if button._origGetItemLink then
            button.GetItemLink = button._origGetItemLink
            button._origGetItemLink = nil
        end
        if button._origUpdateAttributes then
            button.UpdateAttributes = button._origUpdateAttributes
            button._origUpdateAttributes = nil
        end
        if button._origUpdateCount then
            button.UpdateCount = button._origUpdateCount
            button._origUpdateCount = nil
        end
        if button._origUpdateCooldown then
            button.UpdateCooldown = button._origUpdateCooldown
            button._origUpdateCooldown = nil
        end
        if button._origUpdateChecked then
            button.UpdateChecked = button._origUpdateChecked
            button._origUpdateChecked = nil
        end
        if button._origUpdateState then
            button.UpdateState = button._origUpdateState
            button._origUpdateState = nil
        end
        
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
        print("|cff00ff00[EQB]|r Test mode disabled")
    else
        -- Enable test mode (always with multi-item support)
        button.testMode = true
        button.editing = true  -- Prevents normal state updates from hiding
        
        -- Bypass state driver
        UnregisterStateDriver(button, 'visible')
        button:SetAttribute('item', 'test')  -- Fake item attribute
        
        -- Icon map for test items (using numeric FileDataIDs for reliability)
        -- These are well-known icons guaranteed to exist in every WoW client
        local TEST_ICONS = {
            ['item:1'] = 134414,  -- Hearthstone (INV_Misc_Rune_01)
            ['item:2'] = 134830,  -- Red Potion (INV_Potion_91)
            ['item:3'] = 133710,  -- Bomb (INV_Misc_Bomb_02)
            ['item:4'] = 134938,  -- Scroll (INV_Scroll_03)
            ['item:5'] = 134245,  -- Key (INV_Misc_Key_04)
        }
        
        -- Setup multi-item test data
        button.lastNearbyItems = {
            'item:1',
            'item:2',
            'item:3',
            'item:4',
            'item:5',
        }
        
        -- Track current test item
        button.targetItem = 'item:1'
        
        -- Save ALL original methods
        button._origSetItem = button.SetItem
        button._origGetItemLink = button.GetItemLink
        button._origUpdateAttributes = button.UpdateAttributes
        button._origUpdateCount = button.UpdateCount
        button._origUpdateCooldown = button.UpdateCooldown
        button._origUpdateChecked = button.UpdateChecked
        button._origUpdateState = button.UpdateState
        
        -- Override SetItem: track the current item and update the icon
        button.SetItem = function(self, link)
            if not link or not TEST_ICONS[link] then return end
            self.targetItem = link
            self:SetIcon(TEST_ICONS[link])
            
            -- Add fake stack counts for testing
            if link == 'item:2' then self:SetCount(5) -- Red Potion
            elseif link == 'item:3' then self:SetCount(10) -- Bomb
            else self:SetCount(0) end
            
            self:UpdateFeatures()
        end
        
        -- Override GetItemLink: return the currently selected test item
        button.GetItemLink = function(self)
            return self.targetItem
        end
        
        -- No-op overrides: prevent WoW API calls on our fake items
        button.UpdateAttributes = function() end
        button.UpdateCount = function() end
        button.UpdateCooldown = function() end
        button.UpdateChecked = function() end
        
        -- Override UpdateState: mirror real logic for lock→display chain
        -- This prevents the real UpdateState from wiping test data or calling
        -- WoW APIs, while still handling the lock-switch-display flow correctly.
        button.UpdateState = function(self)
            -- Mirror the real resolution order: hard lock > soft selection >
            -- current display. (e.g. via SwitchItem/SelectItem)
            local displayItem = self.lockedItemLink or self.selectedItemLink or self.targetItem
            if displayItem and displayItem ~= self.targetItem then
                self:SetItem(displayItem)
            end
            if self.UpdateFeatures then
                self:UpdateFeatures()
            end

            if self.UpdateItemBadge then
                local total = self.lastNearbyItems and #self.lastNearbyItems or 0
                local current = 0
                local currentItem = self.lockedItemLink or self.selectedItemLink or self.targetItem
                if currentItem and total > 0 then
                    for i, link in ipairs(self.lastNearbyItems) do
                        if link == currentItem then
                            current = i
                            break
                        end
                    end
                end
                self:UpdateItemBadge(current, total)
            end
        end
        
        -- Show with initial test icon
        button:SetIcon(TEST_ICONS['item:1'])
        button:ClearCooldown()
        button:SetCount(0)
        button:Show()
        
        -- Trigger initial feature update (shows Switch icon for multi-item)
        button:UpdateFeatures()
        
        -- Trigger initial badge update
        if button.UpdateItemBadge then
            button:UpdateItemBadge(1, #button.lastNearbyItems)
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
        
        Debug("Test mode enabled")
        print("|cff00ff00[EQB]|r Test mode enabled")
    end
    
    return button.testMode
end

function EQB:IsTestMode()
    local button = _G.ElvQuestButton or _G[addonName]
    return button and button.testMode
end
