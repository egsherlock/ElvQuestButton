# ElvQuestButton

**ElvUI-First Quest Item Button with WindTools Integration**

`ElvQuestButton` is a replacement for the default ExtraActionButton that automatically detects and displays quest items based on your proximity to relevant objectives. It is designed from the ground up to integrate seamlessly with ElvUI and its plugins (like WindTools).

Inspired by the excellent [ExtraQuestButton](https://github.com/p3lim-wow/ExtraQuestButton) by p3lim.

## ✨ Key Features

### 🔍 Automatic Detection
*   Automatically shows the quest item button when you are near a quest objective or tracking a World Quest.
*   Prioritises the closest quest item, with support for hardcoded priority overrides for important items.
*   Works with quest log items, bag items with fallback data, and target-specific items.

### 🎨 ElvUI Integration
*   Full skinning support (transparent backdrop, shadows, borders).
*   Movable via `/moveui` (Toggle Anchors).
*   Configuration via the ElvUI options panel (`/ec` → ElvQuestButton).
*   Inherits ElvUI's **Global Fade** if enabled.
*   Full `/kb` keybind support — bind directly through ElvUI's keybind system.

### 🌬️ WindTools Support
*   Automatically detects [ElvUI_WindTools](https://github.com/wind-addons/ElvUI_WindTools).
*   Applies the distinct WindTools **Shadow** and **Vignette** styles for a premium look consistent with your UI.

### 🔒 Locking
Lock the current quest item so it doesn't change automatically when you move between objectives.

*   **Manual Lock**: Click the **Lock icon** (bottom-left of button) to toggle the lock on/off.
*   **Auto-Lock After Use** *(on by default)*: Clicking the quest item automatically locks it to prevent it from swapping while you're still working on that quest. Unlocks when the quest completes or you leave the area.
*   **Lock on Switch** *(on by default)*: When switching to a different quest item (via the Switch button or scroll wheel), the new item is automatically locked so it stays put.
*   **Visuals**:
    *   🟡 **Gold Lock**: Item is locked (manually or automatically).
    *   ⚪ **Grey Lock**: Item is unlocked.
    *   ⚔️ **Combat**: Automatically locks (Gold) to prevent taint. Unlock is deferred until combat ends.

### 🔄 Quick Switch
When multiple quest items are detected nearby, switch between them instantly.

*   **Switch Button**: A **Switch icon** (bottom-right of button) appears when multiple items are available. Click to cycle forward through items.
*   **Scroll to Switch** *(on by default)*: Hover over the button and **scroll the mouse wheel** to cycle through items — scroll up for next, scroll down for previous.
*   **Combat Safety**: The Switch button desaturates (Grey) and becomes unclickable during combat to comply with protected action restrictions.

### 🎯 Quest Logic
Fine-tune when and where the button appears.

*   **Only Tracked Quests**: Restrict the button to quests you are actively tracking in your quest log.
*   **Current Zone Only**: Only show items for quests in your current map zone.
*   **Tracking Distance**: Maximum distance (in yards) to show quest items. Default: 1000.

### 🖌️ Button Appearance
*   **Scale**: Resize the button.
*   **Alpha**: Adjust button transparency.
*   **Tools Scale**: Resize the Lock and Switch icons independently.
*   **Hide Cooldown Text**: Hide the countdown numbers on cooldown.

### ✏️ Fonts & Text
Fully customisable **Count** and **Keybind** text:
*   Font family (via LibSharedMedia).
*   Font size.
*   Font outline (None, Outline, Monochrome, Thick).
*   X/Y offset positioning.

### 🖥️ Standalone Mode
If ElvUI is not installed, the addon falls back to **LibEditMode** integration:
*   Positioning via Blizzard's Edit Mode.
*   All quest logic settings available in the Edit Mode settings panel.
*   Artwork style selection from 20+ button styles.
*   QuickKeybind support via Blizzard's keybind system.

## 🚀 Installation & Usage

1.  Make sure you have **ElvUI** installed (recommended) or use standalone mode.
2.  Install `ElvQuestButton` to your `Interface/AddOns` folder.
3.  *(Optional)* Install **ElvUI_WindTools** for enhanced shadow visuals.

### Commands
*   `/eqb` — Open configuration (redirects to ElvUI settings or Edit Mode).
*   `/eqb test` — Toggle test mode to preview the button with a sample icon.
*   `/eqb multi` — Toggle multi-item test mode to preview Quick Switch and Locking features.

## ⚙️ Configuration

### ElvUI Users
Open the ElvUI config: `/ec` → **ElvQuestButton**

Settings are organised into four groups:
1.  **General**: Enable/disable, Global Fade inheritance, Test Mode.
2.  **Quest Logic**: Tracking filters, auto-lock, lock-on-switch, scroll-to-switch, tracking distance.
3.  **Button Appearance**: Scale, alpha, tools scale, cooldown text.
4.  **Fonts & Text**: Full font customisation for count and keybind text.

### Standalone Users
Open Edit Mode: `ESC` → **Edit Mode** → Select the quest button frame.

## 📊 Memory & Performance

### Why Does Memory Keep Climbing?

If you check your addon memory usage (e.g., via `/addons` or an addon manager), you might notice ElvQuestButton's memory slowly increasing over time — even when you're idle. **This is normal and expected.** Here's why:

ElvQuestButton polls your quest log every **2 seconds** to check if any quest items are nearby. It also responds to game events (quest updates, zone changes, bag changes, etc.) to ensure the button stays current. Each of these checks involves Lua creating small, temporary data structures — things like distance calculations and item lists.

These temporary objects accumulate in Lua's memory until WoW's **garbage collector** (GC) runs, which happens automatically on WoW's own schedule. When the GC runs, it cleans up all the unused objects at once, and you'll see the memory drop back down. This sawtooth pattern (gradual climb → sudden drop) is completely normal for any addon that does periodic work.

### What We Do to Stay Lightweight

*   **Table reuse**: The core detection logic pre-allocates its working tables (`uniqueItems`, `prioritizedItemLinks`, `allItems`) once at load time and `wipe()`s them each cycle instead of creating new tables. This means the GC has very little temporary garbage to clean up.
*   **Event coalescing**: When multiple game events fire in the same frame (common during zone transitions or quest completions), we coalesce them into a **single** quest log evaluation on the next frame, rather than running the check once per event.
*   **No forced GC**: We never call `collectgarbage()` ourselves. Forcing a GC cycle mid-gameplay causes frame stutters — WoW's built-in GC scheduling is designed to run during natural idle moments and is always the right choice.

### Typical Resource Usage

| Metric | Value |
|---|---|
| **Static data** | ~9 KB (quest/item lookup tables, loaded once) |
| **Per-cycle allocation** | Negligible (table reuse, no new allocations) |
| **Update frequency** | Every 2 seconds (polling) + on game events (coalesced) |
| **CPU impact** | Minimal — a single quest log scan takes <0.1ms |

### Memory Usage ≠ Performance Impact

**Memory alone is a misleading metric.** An addon using 500 KB of memory but doing heavy work every frame is far worse for your FPS than an addon using 2 MB of memory but only working every 2 seconds. What actually matters is:

1.  **CPU time per frame** — ElvQuestButton does zero work per frame. It uses event-driven updates and a 2-second ticker. It never hooks `OnUpdate` for the main button logic.
2.  **GC pressure** — How much temporary garbage an addon creates. We minimise this through table reuse and event coalescing.
3.  **Secure action taint** — Poorly written addons can cause "taint" errors that break Blizzard UI. ElvQuestButton carefully defers all protected operations and never touches secure attributes during combat.

**Bottom line**: The memory number you see climbing is just Lua's normal GC cycle. The addon's actual performance footprint is near-zero.

## 🤝 Credits

*   **p3lim**: Author of the original [ExtraQuestButton](https://github.com/p3lim-wow/ExtraQuestButton), from which the core quest detection logic is derived.
*   **Sherlockell**: Author of this ElvUI integration and extended feature set.
*   **ElvUI Team**: For the amazing UI framework.
*   **fang2hou**: For the design inspiration and the WindTools addon.

## 📄 License
MIT License. See LICENSE for details.
