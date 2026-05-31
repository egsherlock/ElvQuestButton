--[[
    ElvQuestButton - Bespoke Settings Panel (ElvUI mode only)

    A self-contained, ElvUI-skinned configuration window opened by /eqb (and from
    the /ec launcher). This is the SINGLE settings surface in ElvUI mode; the Ace3
    page is just a launcher button (see options.lua). Every control binds to the
    same global DB (EQB:GetDB) and mirrors the behaviour of the old Ace3 setters,
    so nothing drifts or conflicts.
]]

local addonName, addon = ...

if not _G.ElvUI then return end

local E, L, V, P, G = unpack(_G.ElvUI)
local S = E:GetModule('Skins')
local LSM = E.Libs.LSM
local EQB = addon.ElvUIModule

local floor = math.floor
local tinsert, tsort = table.insert, table.sort

-- Layout constants
local PANEL_W, PANEL_H = 640, 600
local RAIL_W = 150
local PAD = 16
local HEADER_H = 40

local CATEGORIES = { 'General', 'Filtering', 'Behaviour', 'Appearance', 'Artwork', 'Fonts' }

local function GetBtn() return _G.ElvQuestButton or _G[addonName] end
local function DB() return EQB:GetDB() end

local Panel = { pages = {}, railButtons = {} }
EQB.Panel = Panel

--------------------------------------------------------------------------------
-- Shared dropdown menu (single pooled popup)
--------------------------------------------------------------------------------
local Menu
local openOwner

local function CloseMenu()
    if Menu then
        Menu:Hide()
        Menu.closer:Hide()
    end
    openOwner = nil
end

local function EnsureMenu()
    if Menu then return Menu end

    local closer = CreateFrame('Button', nil, E.UIParent)
    closer:SetAllPoints(E.UIParent)
    closer:SetFrameStrata('FULLSCREEN_DIALOG')
    closer:SetFrameLevel(40)
    closer:Hide()
    closer:SetScript('OnClick', CloseMenu)

    Menu = CreateFrame('Frame', nil, E.UIParent)
    Menu:SetFrameStrata('FULLSCREEN_DIALOG')
    Menu:SetFrameLevel(50)
    Menu:SetTemplate('Transparent')
    Menu:SetClampedToScreen(true)
    Menu:Hide()
    Menu.closer = closer

    Menu.scroll = CreateFrame('ScrollFrame', nil, Menu)
    Menu.scroll:SetPoint('TOPLEFT', 4, -4)
    Menu.scroll:SetPoint('BOTTOMRIGHT', -4, 4)
    Menu.scroll:EnableMouseWheel(true)
    Menu.scroll:SetScript('OnMouseWheel', function(self, delta)
        local maxScroll = self:GetVerticalScrollRange()
        local new = math.min(math.max(self:GetVerticalScroll() - delta * 30, 0), maxScroll)
        self:SetVerticalScroll(new)
    end)

    Menu.child = CreateFrame('Frame', nil, Menu.scroll)
    Menu.child:SetSize(10, 10)
    Menu.scroll:SetScrollChild(Menu.child)

    Menu.rows = {}
    return Menu
end

local ROW_H = 18

local function ShowMenu(owner, options, current, onSelect)
    if openOwner == owner then CloseMenu() return end
    local m = EnsureMenu()
    openOwner = owner

    local n = #options
    local visible = math.min(n, 12)
    local width = owner:GetWidth()

    m:SetWidth(width)
    m:SetHeight(visible * ROW_H + 8)
    m:ClearAllPoints()
    m:SetPoint('TOPLEFT', owner, 'BOTTOMLEFT', 0, -2)
    m.child:SetSize(width - 8, n * ROW_H)

    for i, opt in ipairs(options) do
        local r = m.rows[i]
        if not r then
            r = CreateFrame('Button', nil, m.child)
            r:SetHeight(ROW_H)
            r:SetPoint('LEFT', 0, 0)
            r:SetPoint('RIGHT', 0, 0)
            r.text = r:CreateFontString(nil, 'OVERLAY')
            r.text:FontTemplate()
            r.text:SetPoint('LEFT', 6, 0)
            r.text:SetPoint('RIGHT', -6, 0)
            r.text:SetJustifyH('LEFT')
            r.text:SetWordWrap(false)
            r.hl = r:CreateTexture(nil, 'HIGHLIGHT')
            r.hl:SetAllPoints()
            r.hl:SetColorTexture(1, 1, 1, 0.12)
            m.rows[i] = r
        end
        r:SetPoint('TOPLEFT', 0, -(i - 1) * ROW_H)
        r.text:SetText(opt.text)
        if opt.value == current then
            r.text:SetTextColor(1, 0.82, 0)
        else
            r.text:SetTextColor(1, 1, 1)
        end
        r:SetScript('OnClick', function()
            onSelect(opt.value)
            CloseMenu()
        end)
        r:Show()
    end
    for i = n + 1, #m.rows do m.rows[i]:Hide() end

    m.scroll:SetVerticalScroll(0)
    m.closer:Show()
    m:Show()
end

--------------------------------------------------------------------------------
-- Widget factories (create Blizzard widgets, reskin with ElvUI, bind to DB)
--------------------------------------------------------------------------------
local function NextRow(page, h)
    local y = page.y
    page.y = page.y - h
    return y
end

local function AddSectionHeader(page, text)
    page.y = page.y - 8
    local fs = page:CreateFontString(nil, 'OVERLAY')
    fs:FontTemplate(nil, 13, 'OUTLINE')
    fs:SetText(text)
    fs:SetTextColor(1, 0.82, 0)
    fs:SetPoint('TOPLEFT', PAD, page.y)

    local line = page:CreateTexture(nil, 'ARTWORK')
    line:SetColorTexture(1, 1, 1, 0.10)
    line:SetHeight(1)
    line:SetPoint('TOPLEFT', PAD, page.y - 16)
    line:SetPoint('RIGHT', page, 'RIGHT', -PAD, 0)

    page.y = page.y - 26
end

local function AddCheckbox(page, label, tooltip, getFn, setFn)
    local y = NextRow(page, 26)
    local cb = CreateFrame('CheckButton', nil, page, 'UICheckButtonTemplate')
    S:HandleCheckBox(cb)
    cb:SetPoint('TOPLEFT', PAD, y)

    local fs = page:CreateFontString(nil, 'OVERLAY')
    fs:FontTemplate()
    fs:SetPoint('LEFT', cb, 'RIGHT', 4, 0)
    fs:SetText(label)

    cb:SetScript('OnClick', function(self)
        setFn(self:GetChecked() and true or false)
    end)
    if tooltip then
        cb:SetScript('OnEnter', function(self)
            GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
            GameTooltip:AddLine(label, 1, 1, 1)
            GameTooltip:AddLine(tooltip, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        cb:SetScript('OnLeave', GameTooltip_Hide)
    end

    local function refresh() cb:SetChecked(getFn() and true or false) end
    tinsert(page.updaters, refresh)
    return cb
end

local function AddSlider(page, label, minV, maxV, step, kind, getFn, setFn)
    local y = NextRow(page, 42)

    local fs = page:CreateFontString(nil, 'OVERLAY')
    fs:FontTemplate()
    fs:SetPoint('TOPLEFT', PAD, y)
    fs:SetText(label)

    local val = page:CreateFontString(nil, 'OVERLAY')
    val:FontTemplate()
    val:SetPoint('TOPRIGHT', -PAD, y)
    val:SetJustifyH('RIGHT')
    val:SetTextColor(1, 0.82, 0)

    local s = CreateFrame('Slider', nil, page)
    s:SetOrientation('HORIZONTAL')
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:SetHeight(12)
    s:SetPoint('TOPLEFT', PAD, y - 18)
    s:SetPoint('RIGHT', page, 'RIGHT', -PAD, 0)
    S:HandleSliderFrame(s)

    local function fmt(v)
        if kind == 'percent' then
            return floor(v * 100 + 0.5) .. '%'
        else
            return tostring(floor(v + 0.5))
        end
    end

    s:SetScript('OnValueChanged', function(self, v, userInput)
        val:SetText(fmt(v))
        if userInput then setFn(v) end
    end)

    local function refresh()
        local v = getFn()
        if v == nil then v = minV end
        s:SetValue(v)
        val:SetText(fmt(v))
    end
    tinsert(page.updaters, refresh)
    return s
end

local function AddDropdown(page, label, getFn, setFn, optionsFn)
    local y = NextRow(page, 44)

    local fs = page:CreateFontString(nil, 'OVERLAY')
    fs:FontTemplate()
    fs:SetPoint('TOPLEFT', PAD, y)
    fs:SetText(label)

    local btn = CreateFrame('Button', nil, page)
    btn:SetHeight(22)
    btn:SetPoint('TOPLEFT', PAD, y - 18)
    btn:SetPoint('RIGHT', page, 'RIGHT', -PAD, 0)
    btn:SetTemplate('Transparent')

    local text = btn:CreateFontString(nil, 'OVERLAY')
    text:FontTemplate()
    text:SetPoint('LEFT', 6, 0)
    text:SetPoint('RIGHT', -22, 0)
    text:SetJustifyH('LEFT')
    text:SetWordWrap(false)

    local arrow = btn:CreateTexture(nil, 'OVERLAY')
    arrow:SetTexture([[Interface\ChatFrame\ChatFrameExpandArrow]])
    arrow:SetSize(16, 16)
    arrow:SetPoint('RIGHT', -3, 0)

    btn:SetScript('OnEnter', function(self) self:SetBackdropBorderColor(1, 0.82, 0) end)
    btn:SetScript('OnLeave', function(self) self:SetBackdropBorderColor(unpack(E.media.bordercolor)) end)

    local function refresh()
        local cur = getFn()
        local shown = cur
        for _, o in ipairs(optionsFn()) do
            if o.value == cur then shown = o.text break end
        end
        text:SetText(shown or '')
    end

    btn:SetScript('OnClick', function(self)
        ShowMenu(self, optionsFn(), getFn(), function(v)
            setFn(v)
            refresh()
        end)
    end)

    tinsert(page.updaters, refresh)
    return btn
end

--------------------------------------------------------------------------------
-- Option list builders
--------------------------------------------------------------------------------
local function SortedKeyOptions(tbl)
    local opts = {}
    for name in pairs(tbl) do tinsert(opts, { value = name, text = name }) end
    tsort(opts, function(a, b) return a.text < b.text end)
    return opts
end

local function ArtworkOptions() return SortedKeyOptions(GetBtn():GetArtworkStyles()) end
local function LockIconOptions() return SortedKeyOptions(GetBtn():GetLockIcons()) end
local function SwitchIconOptions() return SortedKeyOptions(GetBtn():GetSwitchIcons()) end

local function FontOptions()
    local opts = {}
    for _, name in ipairs(LSM:List('font')) do tinsert(opts, { value = name, text = name }) end
    tsort(opts, function(a, b) return a.text < b.text end)
    return opts
end

local OUTLINE_OPTIONS = {
    { value = 'NONE', text = 'None' },
    { value = 'OUTLINE', text = 'Outline' },
    { value = 'MONOCHROMEOUTLINE', text = 'Monochrome Outline' },
    { value = 'THICKOUTLINE', text = 'Thick Outline' },
}
local BADGE_OPTIONS = {
    { value = 'NONE', text = 'None' },
    { value = 'SWITCH', text = 'On Switch Button' },
    { value = 'BUTTON', text = 'On Quest Button' },
}

--------------------------------------------------------------------------------
-- Setter helpers (mirror the old Ace3 setters exactly)
--------------------------------------------------------------------------------
local function SetAndUpdate(key)
    return function(v) DB()[key] = v; EQB:UpdateButton() end
end
local function SetOnly(key)
    return function(v) DB()[key] = v end
end
local function Get(key)
    return function() return DB()[key] end
end

--------------------------------------------------------------------------------
-- Live preview (artwork + sample icon), used on the Artwork page
--------------------------------------------------------------------------------
local function AddArtworkPreview(page)
    local box = CreateFrame('Frame', nil, page)
    box:SetSize(220, 150)
    box:SetPoint('BOTTOM', 0, 18)
    box:SetTemplate('Transparent')

    local caption = box:CreateFontString(nil, 'OVERLAY')
    caption:FontTemplate(nil, 11)
    caption:SetPoint('TOP', 0, -4)
    caption:SetText('|cffaaaaaaPreview|r')

    local art = box:CreateTexture(nil, 'BACKGROUND')
    art:SetPoint('CENTER', 0, -6)

    local icon = box:CreateTexture(nil, 'ARTWORK')
    icon:SetTexture(134414) -- Hearthstone
    icon:SetSize(40, 40)
    icon:SetPoint('CENTER', 0, -6)

    function box:Update()
        local db = DB()
        local path = GetBtn():GetArtworkStyles()[db.artworkStyle or 'Default']
        art:SetTexture(path)
        local scale = (db.artworkScale or 1) * 0.45
        art:SetSize(256 * scale, 128 * scale)
        art:SetAlpha(db.artworkEnabled and (db.artworkAlpha or 1) or 0.15)
        if art.SetRotation then art:SetRotation(math.rad(db.artworkRotation or 0)) end
    end

    tinsert(page.updaters, function() box:Update() end)
    return box
end

--------------------------------------------------------------------------------
-- Pages
--------------------------------------------------------------------------------
local function BuildGeneral(page)
    AddSectionHeader(page, 'General')
    AddCheckbox(page, L["Enable"], "Enable ElvUI integration for the quest button.",
        Get('enable'), function(v) DB().enable = v; if v then EQB:UpdateButton() end end)
    AddCheckbox(page, L["Inherit Global Fade"], "Fade this button along with your action bars when using ElvUI's Global Fade.",
        Get('inheritGlobalFade'), SetAndUpdate('inheritGlobalFade'))

    AddSectionHeader(page, 'Positioning')
    local info = page:CreateFontString(nil, 'OVERLAY')
    info:FontTemplate()
    info:SetPoint('TOPLEFT', PAD, page.y)
    info:SetPoint('RIGHT', page, 'RIGHT', -PAD, 0)
    info:SetJustifyH('LEFT')
    info:SetText("|cff00ff00/moveui|r  drag the button into place\n|cff00ff00/kb|r  then hover the button to bind a key\n|cff00ff00/eqb test|r  toggle a preview button")
    page.y = page.y - 60
end

local function BuildFiltering(page)
    AddSectionHeader(page, 'Visibility & Filters')
    AddCheckbox(page, "Only Tracked Quests", "Only show the button for quests you are actively tracking.",
        Get('trackingOnly'), SetOnly('trackingOnly'))
    AddCheckbox(page, "Current Zone Only", "Only show the button for quests in your current zone.",
        Get('zoneOnly'), SetOnly('zoneOnly'))
    AddSlider(page, "Tracking Distance (yds)", 5, 10000, 5, 'int',
        Get('distanceYd'), SetOnly('distanceYd'))
end

local function BuildBehaviour(page)
    AddSectionHeader(page, 'Interaction & Locking')
    AddCheckbox(page, "Auto-Lock After Use",
        "Automatically lock the quest item after you use it (by any means). Unlocks on quest completion, leaving the area, or clicking the Lock icon.",
        Get('autoLockOnUse'), function(v)
            DB().autoLockOnUse = v
            if not v then
                local b = GetBtn()
                if b and b.lockedItemLink and not b.inCombat then
                    b:SetLockedItem(nil); b:UpdateState()
                end
            end
        end)
    AddCheckbox(page, "Scroll to Switch", "Scroll the mouse wheel over the button to cycle between nearby quest items.",
        Get('scrollToSwitch'), SetOnly('scrollToSwitch'))
    AddCheckbox(page, "Lock When Switching",
        "On: switching locks the chosen item (gold). Off: the chosen item is shown and sticks while nearby, with no lock.",
        Get('lockOnSwitch'), function(v)
            DB().lockOnSwitch = v
            local b = GetBtn()
            if b and not b.inCombat then
                b.selectedItemLink = nil
                if b.lockedItemLink then b:SetLockedItem(nil) end
                if b.UpdateState then b:UpdateState() end
            end
        end)

    AddSectionHeader(page, 'Item Count Badge')
    AddDropdown(page, "Show Badge", Get('itemCountBadge'), function(v)
        DB().itemCountBadge = v
        local b = GetBtn()
        if b and b.UpdateState then b:UpdateState() end
    end, function() return BADGE_OPTIONS end)
    AddSlider(page, "Badge Font Size", 6, 32, 1, 'int',
        Get('itemCountFontSize'), SetAndUpdate('itemCountFontSize'))
end

local function BuildAppearance(page)
    AddSectionHeader(page, 'Button')
    AddSlider(page, L["Scale"], 0.1, 3, 0.01, 'percent', Get('scale'), SetAndUpdate('scale'))
    AddSlider(page, L["Alpha"], 0, 1, 0.01, 'percent', Get('alpha'), SetAndUpdate('alpha'))
    AddSlider(page, "Tools Scale", 0.5, 2, 0.1, 'percent', Get('lockScale'), SetAndUpdate('lockScale'))
    AddCheckbox(page, "Hide Cooldown Text", "Hide the countdown numbers on the cooldown swirl.",
        Get('noCooldownText'), function(v)
            DB().noCooldownText = v
            local b = GetBtn()
            if b and b.EnableCooldownText then b:EnableCooldownText(not v) end
        end)

    AddSectionHeader(page, 'Lock & Switch Icons')
    AddDropdown(page, "Lock Icon", function() return DB().lockIconStyle or 'Padlock' end,
        SetAndUpdate('lockIconStyle'), LockIconOptions)
    AddDropdown(page, "Switch Icon", function() return DB().switchIconStyle or 'Refresh' end,
        SetAndUpdate('switchIconStyle'), SwitchIconOptions)
end

local function BuildArtwork(page)
    AddArtworkPreview(page)
    AddSectionHeader(page, 'Artwork Background')
    AddCheckbox(page, "Show Artwork Background",
        "Draw the classic ExtraButton artwork behind the square ElvUI skin.",
        Get('artworkEnabled'), SetAndUpdate('artworkEnabled'))
    AddDropdown(page, "Style", function() return DB().artworkStyle or 'Default' end,
        SetAndUpdate('artworkStyle'), ArtworkOptions)
    AddSlider(page, "Opacity", 0, 1, 0.05, 'percent', Get('artworkAlpha'), SetAndUpdate('artworkAlpha'))
    AddSlider(page, "Size", 0.5, 2, 0.05, 'percent', function() return DB().artworkScale or 1 end, SetAndUpdate('artworkScale'))
    AddSlider(page, "Rotation", 0, 360, 1, 'int', function() return DB().artworkRotation or 0 end, SetAndUpdate('artworkRotation'))
end

local function BuildFonts(page)
    AddSectionHeader(page, 'Stack Count')
    AddDropdown(page, "Font", Get('countFont'), SetAndUpdate('countFont'), FontOptions)
    AddSlider(page, "Font Size", 6, 32, 1, 'int', Get('countFontSize'), SetAndUpdate('countFontSize'))
    AddDropdown(page, "Outline", Get('countFontOutline'), SetAndUpdate('countFontOutline'), function() return OUTLINE_OPTIONS end)
    AddSlider(page, "X Offset", -50, 50, 1, 'int', Get('countXOffset'), SetAndUpdate('countXOffset'))
    AddSlider(page, "Y Offset", -50, 50, 1, 'int', Get('countYOffset'), SetAndUpdate('countYOffset'))

    AddSectionHeader(page, 'Keybind Text')
    AddDropdown(page, "Font", Get('hotkeyFont'), SetAndUpdate('hotkeyFont'), FontOptions)
    AddSlider(page, "Font Size", 6, 32, 1, 'int', Get('hotkeyFontSize'), SetAndUpdate('hotkeyFontSize'))
    AddDropdown(page, "Outline", Get('hotkeyFontOutline'), SetAndUpdate('hotkeyFontOutline'), function() return OUTLINE_OPTIONS end)
    AddSlider(page, "X Offset", -50, 50, 1, 'int', Get('hotkeyXOffset'), SetAndUpdate('hotkeyXOffset'))
    AddSlider(page, "Y Offset", -50, 50, 1, 'int', Get('hotkeyYOffset'), SetAndUpdate('hotkeyYOffset'))
end

local PAGE_BUILDERS = {
    General = BuildGeneral,
    Filtering = BuildFiltering,
    Behaviour = BuildBehaviour,
    Appearance = BuildAppearance,
    Artwork = BuildArtwork,
    Fonts = BuildFonts,
}

--------------------------------------------------------------------------------
-- Window construction
--------------------------------------------------------------------------------
function Panel:Select(name)
    for n, pg in pairs(self.pages) do pg:SetShown(n == name) end
    for n, b in pairs(self.railButtons) do
        if n == name then
            b.selected = true
            b.bg:SetColorTexture(1, 0.82, 0, 0.18)
            b.text:SetTextColor(1, 0.82, 0)
        else
            b.selected = false
            b.bg:SetColorTexture(1, 1, 1, 0)
            b.text:SetTextColor(0.9, 0.9, 0.9)
        end
    end
    self.selected = name
    self:Refresh()
end

function Panel:Refresh()
    for _, pg in pairs(self.pages) do
        for _, fn in ipairs(pg.updaters) do fn() end
    end
    if self.testBtn then
        self.testBtn:SetText(EQB:IsTestMode() and "Hide Test" or "Test Button")
    end
end

function Panel:Build()
    if self.frame then return end

    local f = CreateFrame('Frame', 'ElvQuestButtonPanel', E.UIParent)
    f:SetSize(PANEL_W, PANEL_H)
    f:SetPoint('CENTER')
    f:SetFrameStrata('HIGH')
    f:SetTemplate('Transparent')
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:Hide()
    self.frame = f

    -- Header (drag handle)
    local header = CreateFrame('Frame', nil, f)
    header:SetPoint('TOPLEFT', 1, -1)
    header:SetPoint('TOPRIGHT', -1, -1)
    header:SetHeight(HEADER_H)
    header:EnableMouse(true)
    header:RegisterForDrag('LeftButton')
    header:SetScript('OnDragStart', function() f:StartMoving() end)
    header:SetScript('OnDragStop', function()
        f:StopMovingOrSizing()
        local point, _, _, x, y = f:GetPoint()
        DB().panelPosition = { point = point, x = x, y = y }
    end)

    local icon = header:CreateTexture(nil, 'ARTWORK')
    icon:SetSize(24, 24)
    icon:SetPoint('LEFT', 10, 0)
    icon:SetTexture([[Interface\Icons\INV_Misc_Map02]])

    local title = header:CreateFontString(nil, 'OVERLAY')
    title:FontTemplate(nil, 16, 'OUTLINE')
    title:SetPoint('LEFT', icon, 'RIGHT', 8, 0)
    title:SetText(E:TextGradient('ElvQuestButton', 0.2, 0.7, 1, 0.2, 1, 0.6))

    local close = CreateFrame('Button', nil, f, 'UIPanelCloseButton')
    close:SetPoint('TOPRIGHT', 2, 2)
    S:HandleCloseButton(close)
    close:SetScript('OnClick', function() Panel:Hide() end)

    -- Header action buttons (Test / Defaults)
    local function headerButton(text, width, anchorTo, onClick)
        local b = CreateFrame('Button', nil, header, 'UIPanelButtonTemplate')
        b:SetSize(width, 22)
        b:SetText(text)
        S:HandleButton(b)
        if anchorTo then
            b:SetPoint('RIGHT', anchorTo, 'LEFT', -6, 0)
        else
            b:SetPoint('RIGHT', close, 'LEFT', -8, 0)
        end
        b:SetScript('OnClick', onClick)
        return b
    end

    self.testBtn = headerButton("Test Button", 90, nil, function()
        EQB:ToggleTestMode()
        Panel:Refresh()
    end)
    headerButton("Defaults", 76, self.testBtn, function()
        Panel:ResetDefaults()
    end)

    -- Left category rail
    local rail = CreateFrame('Frame', nil, f)
    rail:SetPoint('TOPLEFT', 8, -(HEADER_H + 6))
    rail:SetPoint('BOTTOMLEFT', 8, 8)
    rail:SetWidth(RAIL_W)
    rail:SetTemplate('Transparent')

    local ry = -8
    for _, name in ipairs(CATEGORIES) do
        local b = CreateFrame('Button', nil, rail)
        b:SetPoint('TOPLEFT', 6, ry)
        b:SetPoint('TOPRIGHT', -6, ry)
        b:SetHeight(26)
        b.bg = b:CreateTexture(nil, 'BACKGROUND')
        b.bg:SetAllPoints()
        b.bg:SetColorTexture(1, 1, 1, 0)
        b.text = b:CreateFontString(nil, 'OVERLAY')
        b.text:FontTemplate()
        b.text:SetPoint('LEFT', 8, 0)
        b.text:SetText(name)
        b.text:SetTextColor(0.9, 0.9, 0.9)
        local hl = b:CreateTexture(nil, 'HIGHLIGHT')
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        b:SetScript('OnClick', function() Panel:Select(name) end)
        self.railButtons[name] = b
        ry = ry - 28
    end

    -- Content area + pages
    local content = CreateFrame('Frame', nil, f)
    content:SetPoint('TOPLEFT', rail, 'TOPRIGHT', 8, 0)
    content:SetPoint('BOTTOMRIGHT', -8, 8)
    content:SetTemplate('Transparent')
    self.content = content

    for _, name in ipairs(CATEGORIES) do
        local page = CreateFrame('Frame', nil, content)
        page:SetPoint('TOPLEFT', 4, -4)
        page:SetPoint('BOTTOMRIGHT', -4, 4)
        page:Hide()
        page.y = -8
        page.updaters = {}
        self.pages[name] = page
        PAGE_BUILDERS[name](page)
    end

    -- Restore saved position
    local pos = DB().panelPosition
    if pos and pos.point then
        f:ClearAllPoints()
        f:SetPoint(pos.point, E.UIParent, pos.point, pos.x, pos.y)
    end

    self:Select('General')
end

function Panel:ResetDefaults()
    -- Reset to ElvUI's registered global defaults for this module (G.elvQuestButton,
    -- seeded from moduleDefaults in init.lua). Preserve a few non-cosmetic keys.
    local db = DB()
    local keep = { enable = true, panelPosition = true, migratedFromProfile = true }
    local defaults = G and G.elvQuestButton
    if defaults then
        for k, v in pairs(defaults) do
            if not keep[k] then db[k] = v end
        end
    end
    EQB:UpdateButton()
    local b = GetBtn()
    if b and b.UpdateState and not b.inCombat then b:UpdateState() end
    self:Refresh()
end

function Panel:Show()
    self:Build()
    self.frame:Show()
    self:Refresh()
end

function Panel:Hide()
    if self.frame then self.frame:Hide() end
    CloseMenu()
end

function Panel:Toggle()
    self:Build()
    if self.frame:IsShown() then self:Hide() else self:Show() end
end
