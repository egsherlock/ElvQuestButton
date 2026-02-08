# ElvQuestButton

**ElvUI-First Quest Item Button with WindTools Integration**

`ElvQuestButton` is a replacement for the default ExtraActionButton that automatically detects and displays quest items based on your proximity to relevant objectives. It is designed from the ground up to integrate seamlessly with ElvUI and its plugins (like WindTools).

Inspired by the excellent [ExtraQuestButton](https://github.com/p3lim-wow/ExtraQuestButton) by p3lim.

## ✨ Key Features

*   **Automatic Detection**: Automatically shows the quest item button when you are near a quest objective or tracking a World Quest.
*   **ElvUI Integration**:
    *   Full skinning support (transparent, shadows, borders).
    *   Movable via `/ec` -> Toggle Anchors.
    *   Configuration via ElvUI options panel.
*   **WindTools Support**:
    *   Automatically detects [ElvUI_WindTools](https://github.com/wind-addons/ElvUI_WindTools) key functionalities.
    *   Applies the distinct WindTools "Shadow" and "Vignette" styles for a premium look consistent with your UI.
*   **[NEW] Locking**:
    *   Lock the current quest item so it doesn't change automatically when you move around.
    *   **Visuals**:
        *   **Gold Lock**: Active.
        *   **Grey Lock**: Inactive.
        *   **Combat**: Automatically locks (Gold) to prevent taint.
*   **[NEW] Quick Switch**:
    *   When multiple quest items are detected nearby, a **Switch Icon** (bottom-right) appears.
    *   Click to cycle through available items.
    *   **Combat Safety**: Button desaturates (Grey) and becomes unclickable during combat to comply with protected action restrictions.

## 🚀 Installation & Usage

1.  Make sure you have **ElvUI** installed.
2.  Install `ElvQuestButton` to your `Interface/AddOns` folder.
3.  (Optional) Install **ElvUI_WindTools** for enhanced visuals.

### Commands
*   `/eqb`: Open configuration (redirects to ElvUI settings).
*   `/eqb test`: Toggle test mode to preview the button.
*   `/eqb multi`: Toggle "multi-item" test mode to preview Quick Switch and Locking features.

## ⚙️ Configuration

Start by opening the ElvUI config:
`/ec` -> **ActionBars** -> **ElvQuestButton** (if integrated) or check the **General** settings.

You can adjust:
*   **Scale**: Resize the button.
*   **Alpha**: Adjust transparency.
*   **Combat Visibility**: Hide/Show in combat.

## 🤝 Credits

*   **p3lim**: Author of the original [ExtraQuestButton](https://github.com/p3lim-wow/ExtraQuestButton), from which the core quest detection logic is derived.
*   **Sherlockell**: Author of this ElvUI integration and extended feature set.
*   **ElvUI Team**: For the amazing UI framework.
*   **WindTools Team**: For the beautiful aesthetic inspiration.

## 📄 License
MIT License. See LICENSE for details.
