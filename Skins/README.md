# ExtraQuestButton WindTools Skin

This folder contains skin modules for integrating ExtraQuestButton with ElvUI WindTools' visual style.

## Files

### `ElvUI_WindTools.lua`
**Main skin file** - This is the active skin that loads when both ExtraQuestButton and WindTools are present.

Features:
- Applies WindTools' characteristic shadow/vignette effect around the button
- Creates a clean backdrop using ElvUI's template system
- Dynamically binds shadow color to border color for theme compatibility
- Respects Masque integration (skips skinning if Masque handles the button)
- Hooks into show/hide events to maintain skin across visibility changes
- Supports MerathilisUI styling if that addon is present

### `WindTools_Native.lua.example`
**Reference implementation** - This file shows how to create a native WindTools addon skin that could be contributed to the WindTools repository.

To use this approach:
1. Copy the file to: `ElvUI_WindTools/Modules/Skins/Addons/ExtraQuestButton.lua`
2. Add a reference in: `ElvUI_WindTools/Modules/Skins/Addons/Load_Addons.xml`
3. Add the setting key `extraQuestButton = true` to WindTools' `Settings/Private.lua` under `V.skins.addons`

## How It Works

### Skin Application Flow

1. **Initialization**: The skin waits for both ElvUI and WindTools to be fully loaded
2. **Backdrop Creation**: A backdrop frame is created around the button's icon region
3. **Shadow Application**: WindTools' `CreateShadow` function applies the characteristic glow effect
4. **Color Binding**: Shadow color is bound to the backdrop border color for dynamic theming
5. **Event Hooks**: OnShow/OnSizeChanged events ensure the skin persists across state changes

### Key WindTools Functions Used

| Function | Purpose |
|----------|---------|
| `S:CreateShadow(frame)` | Creates the characteristic shadow/glow around frames |
| `S:BindShadowColorWithBorder(frame)` | Syncs shadow color with border color changes |
| `S:MerathilisUISkin(frame)` | Applies MerathilisUI styling if available |
| `S:CreateBackdropShadow(frame)` | Alternative that creates backdrop + shadow together |

### WindTools Settings Integration

The skin checks these WindTools settings:
- `E.private.WT.skins.enable` - Master skins toggle
- `E.private.WT.skins.shadow` - Shadow effects toggle
- `E.private.WT.skins.addons.extraQuestButton` - Per-addon toggle (if defined)

Shadow appearance is controlled by:
- `E.private.WT.skins.color` - RGB values for shadow color
- `E.private.WT.skins.increasedSize` - Additional size offset for shadows

## Customization

### Adjusting Shadow Size
Modify the shadow size by changing the size parameter in `CreateShadow`:
```lua
S:CreateShadow(Button.backdrop, 6)  -- Larger shadow (default is 4)
```

### Custom Shadow Color
Override the shadow color:
```lua
S:CreateShadow(Button.backdrop, 4, 0.2, 0.4, 0.8)  -- Blue tint
```

### Hiding Default Artwork
If you prefer no overlay artwork:
```lua
if Button.Artwork then
    Button.Artwork:SetAlpha(0)
end
```

## Troubleshooting

### Skin Not Applying
1. Ensure ElvUI and WindTools are installed and enabled
2. Check that WindTools skins are enabled: `/elvui` → WindTools → Skins → Enable
3. Verify shadows are enabled in WindTools settings
4. If using Masque, ensure its skin allows WindTools shadows

### Shadow Not Visible
- Check `E.private.WT.skins.shadow` is `true`
- Ensure the button has proper frame strata/level
- Verify no other addon is hiding the shadow frame

### Conflicts with Masque
The skin automatically detects Masque usage. If Masque is handling the button with a non-Blizzard skin, our backdrop/shadow skinning is skipped to avoid visual conflicts.

## Version Compatibility

- **WoW Version**: 12.0.0+ (Retail)
- **ElvUI**: Any recent version
- **WindTools**: Any recent version
- **Masque**: Compatible (will defer to Masque if active)

## Contributing

To contribute this skin to the official WindTools addon:
1. Use `WindTools_Native.lua.example` as a template
2. Add the skin to WindTools' Addons folder
3. Register it in their Load_Addons.xml
4. Add the setting default in Private.lua
5. Submit a pull request to the WindTools repository
