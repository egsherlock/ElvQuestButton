# Developer Guide: ElvQuestButton

This guide provides technical details for developers interested in contributing to or understanding the codebase of `ElvQuestButton`.

## 🛠️ Tech Stack & Architecture

*   **Language**: Lua 5.1 (WoW API)
*   **Framework**: ElvUI Plugin System
*   **Libraries**:
    *   `HereBeDragons-2.0`: Coordinate and zone data.
    *   `LibStub`: Library versioning.
    *   `LibEditMode`: Fallback for standalone functionality (non-ElvUI).

### File Structure
*   `libs/`: External libraries.
*   `locale/`: Localization files.
*   `ElvUI/`: **ElvUI Integration Modules**
    *   `core.lua`: Main ElvUI module logic, skinning, and button setup.
    *   `shadow.lua`: WindTools shadow integration.
*   `core.lua`: **Core Logic** - Handles quest item detection, distance checks, reasoning about "closest" items, and managing the `lockedItemLink` state.
*   `button.lua`: **UI Logic** - Creates the button frames, textures, cooldowns, and the new `FeaturesFrame` (Lock/Switch buttons).
*   `utils.lua`: Helper functions (`GetNearbyQuestItems`, distance calcs).
*   `addon.lua`: Entry point and slash command handler.

## 💡 Key Learnings & Technical Hurdles

### 1. WoW 12.0 (Midnight) API & Combat Safety
During development (Feb 2026), significant changes to the WoW API were introduced for the Midnight expansion, preventing addons from querying real-time combat data directly ("Black Box" system).

*   **Problem**: Functions like `InCombatLockdown()` and `C_Item.IsItemInRange()` may return obfuscated or delayed data during raid/dungeon encounters.
*   **Solution: Event-Driven State Mirroring**:
    1.  We initialize a local flag `self.inCombat` based on `InCombatLockdown()` at load.
    2.  We listen for `PLAYER_REGEN_DISABLED` (Enter Combat) and `PLAYER_REGEN_ENABLED` (Leave Combat) to update this flag instantly.
    3.  **UI Updates**: All visual logic (e.g., desaturating the switch button, locking the item) checks `self.inCombat` instead of the API.
    4.  **Attribute Updates**: Actual secure attribute changes are deferred until `PLAYER_REGEN_ENABLED` fires.
    5.  **Auto-Lock After Use**: The `PostClick` hook in `addon.lua` sets `self.lockedItemLink` (a plain Lua flag, not a protected attribute), making it safe to execute at any time, including during combat.

This dual approach ensures the UI feels responsive and accurate (using events) while the secure code remains safe (using deferrals).

### 2. "Secret Values"
The 12.0 API introduced "Secret Values" to obfuscate certain data from addons to prevent combat automation. We carefully structured our detection logic (in `core.lua`) to avoid relying on protected values for critical decision-making paths that feed into `SetAttribute`.

### 3. Test Mode Simulation
Testing quest items without being in a specific zone is difficult. We implemented a robust **Test Mode** (`/eqb test` and `/eqb multi`) that:
*   Mocks the `GetNearbyQuestItems` return values.
*   Overrides `GetItemLink` and `SetItem` on the button instance temporarily.
*   Allows UI verification of Locking/Switching logic anywhere in the world.

Integrating with WindTools requires precise frame parenting. The "Shadow" frame must be parented to `button.backdrop` (if it exists) or the button itself, and its frame level must be managed carefully to appear *behind* the button content but *above* the background.

### 5. ElvUI Initialization Timing & Defaults
A critical race condition exists when ElvUI modules initialize. ElvUI loads its database (`E.db`) very early, but modules often initialize slightly later (delayed after `PLAYER_LOGIN`) to ensure other dependencies are ready.

*   **The Trap**: Relying solely on a module's `Initialized` flag in your settings accessor (e.g., `addon:GetCurrentSettings()`) is risky. If an event fires (like a button click) before the module flags itself ready, the accessor might fall back to hardcoded `DEFAULTS`.
*   **The Fix**: In `ElvUI/init.lua`, we modified the accessor to peek directly at `E.db.elvQuestButton` as a priority fallback. If the table exists in ElvUI's DB, we use it immediately, regardless of the module's internal state. This prevents settings from silently reverting to defaults during startup or reload.

### 6. ElvUI `/kb` Keybind Integration

ElvUI uses its **own** keybind system (`Bind.lua`) for the `/kb` command — it is completely separate from both Blizzard's Key Binding UI and `QuickKeybindButtonTemplate`. Understanding this system is critical.

#### How ElvUI's Bind System Works
1.  **`AB.handledbuttons`**: A table of all buttons ElvUI manages. Buttons must be registered here.
2.  **`button.keyBoundTarget`** / **`button.commandName`**: String identifiers telling ElvUI which WoW binding action to modify (e.g., `"ELVQUESTBUTTON"`).
3.  **`AB:BindUpdate(button)`**: Called on hover, positions the invisible `ElvUI_KeyBinder` overlay frame on the button.
4.  **`AB:BindListener(key)`**: Captures key presses and calls `SetBinding(key, button.bindstring)`.
5.  **`AB:DisplayBindings(tt)`**: Shows the final tooltip with binding info.

#### Key Findings

**Binding Command Must Match `Bindings.xml`:** ElvUI's `/kb` calls `SetBinding(key, bindName)`. Our addon's `UpdateBinding()` reads from `GetBindingKey(bindName)`. If these use *different* binding commands, they'll be out of sync. We use `addonName:upper()` (`"ELVQUESTBUTTON"`) for both, matching our `Bindings.xml` definition.

**`SetupButton` Can Block Keybind Registration:** If `SkinButton()` (which calls `AB:StyleButton()`) throws an error, it can prevent subsequent code from running. We wrap it in `pcall` and register keybinds in a separate `SetupKeybind()` function called independently from `init.lua`.

**Tooltip Event Cascade ("The `handlingBinds` Problem"):** ElvUI's tooltip for bind mode uses a two-phase approach:
1.  `BindTooltip(true)` adds temporary "Trigger" text and sets `GameTooltip.handlingBinds = true`.
2.  When `GameTooltip:Hide()` fires later, a `ShowBinds` hook checks `handlingBinds` and calls `DisplayBindings()` to show the real tooltip. `ShowBinds` then sets `handlingBinds = nil`.

**The problem:** Any approach that calls `GameTooltip:SetOwner()`, `GameTooltip:Hide()`, or `AB:DisplayBindings()` during the same frame as `BindUpdate` triggers cascading hide/show events that consume `handlingBinds`, breaking the tooltip for subsequent interactions.

**The solution:** Use `C_Timer.After(0, ShowBindTooltip)` in a `hooksecurefunc(AB, 'BindUpdate')` post-hook. This defers tooltip display to the **next frame**, after all event handlers have completed and the call stack has fully unwound. Nothing can overwrite the tooltip because we run last.

```lua
-- Pattern: Deferred tooltip for ElvUI bind mode
hooksecurefunc(AB, 'BindUpdate', function(_, btn)
    if btn ~= myButton then return end
    C_Timer.After(0, function()
        local tt = _G.GameTooltip
        local bind = AB.KeyBinder
        if not bind or not bind.active or bind.button ~= myButton then return end
        tt:SetOwner(bind, 'ANCHOR_TOP')
        tt:SetPoint('BOTTOM', bind, 'TOP', 0, 1)
        -- Add custom lines here
        tt:Show()
    end)
end)
```

**Why NOT `LibKeyBound`:** ElvUI does *not* use `LibKeyBound` for its `/kb` system. Attempting to integrate via `LibKeyBound` will silently fail. Always use `AB.handledbuttons`, `button.keyBoundTarget`, and `AB:BindUpdate()` directly.

### 7. Scroll to Switch (Mouse Wheel on Secure Buttons)

Allowing mouse-wheel scrolling to cycle quest items on a `SecureActionButtonTemplate` button requires careful consideration.

*   **`EnableMouseWheel(true)`**: Called during button creation (out of combat) in `button.lua`. This lets the frame receive `OnMouseWheel` events.
*   **`OnMouseWheel` is non-protected**: The scroll handler is a standard Lua script, not a secure action. It doesn't trigger `SetAttribute` directly — it calls `SwitchItem()` / `SwitchItemPrevious()`, both of which already have `InCombatLockdown()` guards at the top. This means scroll events are silently ignored during combat.
*   **`HookScript` vs `SetScript`**: We use `HookScript('OnMouseWheel', ...)` rather than `SetScript` to avoid overriding any existing handlers (present or future) on the secure template.
*   **Direction mapping**: `delta > 0` = scroll up = next item, `delta < 0` = scroll down = previous item.
*   **Setting check**: The handler reads `scrollToSwitch` from `addon:GetCurrentSettings()` at call time, so toggling the setting takes effect immediately without a `/reload`.

### 8. Lock on Switch Behaviour

The `SwitchItem()` and `SwitchItemPrevious()` functions support two modes controlled by `settings.lockOnSwitch`:

*   **Lock ON (default)**: Calls `SetLockedItem(nextItem)` then `UpdateState()`. The lock ensures the item persists across update cycles.
*   **Lock OFF**: Calls `SetItem(nextItem)` directly, then `UpdateFeatures()` (NOT `UpdateState`). This is intentional — calling `UpdateState()` without a lock would immediately re-evaluate the closest item and revert the switch, causing a visual flicker. `SetItem()` handles all the display updates (icon, count, attributes) without triggering a proximity re-check.

### 9. The `trackingOnly` Inversion Bug

The original `GetNearbyQuestItems()` in `utils.lua` had an inverted condition for the `trackingOnly` parameter. The function collects quest items from three loops:

1.  **World Quest Watches** (`GetNumWorldQuestWatches`): Always included.
2.  **Quest Watches** (`GetNumQuestWatches`): Always included — these are the *tracked* quests.
3.  **All Quest Log Entries** (`GetNumQuestLogEntries`): Conditionally included.

The third loop had:
```lua
-- WRONG: includes untracked quests only when trackingOnly is TRUE
(trackingOnly and not info.isHidden)
```

This meant when `trackingOnly` was `false` (default), **no** regular quest log entries were included from loop 3 — effectively making "tracking only" the default behaviour. The fix:

```lua
-- CORRECT: includes untracked quests only when trackingOnly is FALSE
(not trackingOnly and not info.isHidden)
```

Now loop 3 correctly adds all visible quest log entries when `trackingOnly` is off, and skips them (relying on loops 1 & 2 for tracked-only items) when `trackingOnly` is on.

## 🤝 Contributing
1.  Fork the repo.
2.  Make your changes.
3.  Ensure `/eqb multi` works without errors.
4.  Submit a Pull Request.
