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

## 🤝 Credits

*   **p3lim**: Author of the original [ExtraQuestButton](https://github.com/p3lim-wow/ExtraQuestButton), from which the core quest detection logic is derived.
*   **Sherlockell**: Author of this ElvUI integration and extended feature set.
*   **ElvUI Team**: For the amazing UI framework.
*   **fang2hou**: For the design inspiration and the WindTools addon.

## 📄 License
MIT License. See LICENSE for details.
