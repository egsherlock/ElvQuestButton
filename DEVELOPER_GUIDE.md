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
During development (Feb 2026), significant changes to the WoW API were introduced for the Midnight expansion, specifically targeting `SecureActionButtonTemplate`.

### 1. WoW 12.0 (Midnight) API & Combat Safety
During development (Feb 2026), significant changes to the WoW API were introduced for the Midnight expansion, preventing addons from querying real-time combat data directly ("Black Box" system).

*   **Problem**: Functions like `InCombatLockdown()` and `C_Item.IsItemInRange()` may return obfuscated or delayed data during raid/dungeon encounters.
*   **Solution: Event-Driven State Mirroring**:
    1.  We initialize a local flag `self.inCombat` based on `InCombatLockdown()` at load.
    2.  We listen for `PLAYER_REGEN_DISABLED` (Enter Combat) and `PLAYER_REGEN_ENABLED` (Leave Combat) to update this flag instantly.
    3.  **UI Updates**: All visual logic (e.g., desaturating the switch button, locking the item) checks `self.inCombat` instead of the API.
    4.  **Attribute Updates**: Actual secure attribute changes are deferred until `PLAYER_REGEN_ENABLED` fires.

This dual approach ensures the UI feels responsive and accurate (using events) while the secure code remains safe (using deferrals).

### 2. "Secret Values"
The 12.0 API introduced "Secret Values" to obfuscate certain data from addons to prevent combat automation. We carefully structured our detection logic (in `core.lua`) to avoid relying on protected values for critical decision-making paths that feed into `SetAttribute`.

### 3. Test Mode Simulation
Testing quest items without being in a specific zone is difficult. We implemented a robust **Test Mode** (`/eqb test` and `/eqb multi`) that:
*   Mocks the `GetNearbyQuestItems` return values.
*   Overrides `GetItemLink` and `SetItem` on the button instance temporarily.
*   Allows UI verification of Locking/Switching logic anywhere in the world.

### 4. ElvUI Skinning & WindTools
Integrating with WindTools requires precise frame parenting. The "Shadow" frame must be parented to `button.backdrop` (if it exists) or the button itself, and its frame level must be managed carefully to appear *behind* the button content but *above* the background.

## 🤝 Contributing
1.  Fork the repo.
2.  Make your changes.
3.  Ensure `/eqb multi` works without errors.
4.  Submit a Pull Request.
