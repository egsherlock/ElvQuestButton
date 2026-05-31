# ElvQuestButton — Improvements Tracker

A list of potential improvements identified during development. Items are marked as they are completed.

---

## 🔴 High Priority (Stability)

### 1. Throttle Event-Driven `UpdateState()` Calls
- [x] **DONE**
- **Problem**: Events like `BAG_UPDATE_DELAYED`, `QUEST_LOG_UPDATE`, `ZONE_CHANGED`, etc. each trigger an immediate `UpdateState()`. When multiple events fire in the same frame (common during zone transitions, quest completions, etc.), this causes redundant `GetNearbyQuestItems()` evaluations — iterating the full quest log multiple times per frame for no benefit.
- **Fix**: Replace direct `UpdateState` event bindings with a `ScheduleUpdate()` method that uses a dirty flag + `C_Timer.After(0)` to coalesce all same-frame events into a single update on the next frame. The 2-second ticker remains for distance polling.

### 2. Guard `BAG_UPDATE_DELAYED` Double-Registration
- [x] **DONE**
- **Problem**: In `addon.lua`, `BAG_UPDATE_DELAYED` is registered twice — once for `UpdateCount` and once for `UpdateState`. The `UpdateCount` handler already calls `UpdateState()` when count hits 0, so the direct `UpdateState` registration causes double work on every bag update.
- **Fix**: Remove the duplicate `BAG_UPDATE_DELAYED` → `UpdateState` registration. `UpdateCount` already handles the edge case.

---

## 🟡 Medium Priority (Performance)

### 3. Reuse the `allItems` Table in `GetNearbyQuestItems()`
- [x] **DONE**
- **Problem**: A new `local allItems = {}` table is created inside `GetNearbyQuestItems()` every call (every 2 seconds + every event-driven update). These short-lived tables put pressure on Lua's garbage collector.
- **Fix**: Move `allItems` to file scope alongside the existing `uniqueItems` and `prioritizedItemLinks` tables, and `table.wipe()` it at the start of each call.

### 4. Pool Inner `{itemLink, distance}` Pairs
- [ ] TODO (micro-optimisation, low ROI)
- **Problem**: `addPrioritizedItem()` creates a new `{itemLink, distance}` table for each nearby quest item every call. These are small but generated every tick.
- **Fix**: Use a table pool to recycle these pairs. Adds complexity for marginal gain — likely not worth it unless profiling shows GC as a bottleneck.

---

## 🟢 Low Priority (Nice to Have)

### 5. Localise Standalone Setting Names
- [ ] TODO
- **Problem**: The standalone Edit Mode settings for `Lock on Switch` and `Scroll to Switch` use hardcoded English strings rather than `L[...]` locale lookups like the other settings.
- **Fix**: Add locale entries and reference them.

### 6. Keep `data.lua` in Sync with Upstream
- [x] **DONE (2026-05-31)** — ongoing; re-check periodically
- **Problem**: p3lim still actively maintains ExtraQuestButton and adds new quest/item entries. Our `data.lua` is a snapshot from the initial fork.
- **Fix**: Periodically diff against [p3lim's data.lua](https://github.com/p3lim-wow/ExtraQuestButton/blob/master/data.lua) and merge new entries.
- **Last sync (2026-05-31)**: merged the only two upstream additions since the fork — `targetItems[36231] = 49202` (Gilneas) and the four Noblegarden `inaccurateQuestAreas` entries (`79331/79578/79330/79577`). All other tables were identical.

### 7. Debounce Scroll-to-Switch
- [x] **DONE**
- **Problem**: Aggressive scrolling can trigger many rapid `SwitchItem()` / `SwitchItemPrevious()` calls in quick succession.
- **Fix**: Added ~0.15s cooldown check in `OnMouseWheel` handler.

---

## ✨ Feature & Polish Pass (2026-05-31)

### 8. Decouple Locking from Scroll-to-Switch
- [x] **DONE (2026-05-31)**
- **Problem**: Switching items (scroll or Switch button) always hard-locked the chosen item (gold), which users don't always want.
- **Fix**: Added a soft-selection concept (`selectedItemLink`) separate from the hard lock (`lockedItemLink`). New `lockOnSwitch` setting (default **off** = soft-select). `UpdateState` resolution order is now hard lock → soft selection → closest, each honoured only while in range. `SwitchItem`/`SwitchItemPrevious` route through a new `SelectItem` helper.

### 9. Artwork Rotation & Size
- [x] **DONE (2026-05-31)**
- **Problem**: Artwork background was fixed at its native 256×128, no orientation control.
- **Fix**: Added `buttonMixin:SetArtworkScale` (resizes relative to native) and `SetArtworkRotation` (uses `TextureBase:SetRotation`). New `artworkScale`/`artworkRotation` settings, applied only on change (no per-frame cost), with controls in both the ElvUI panel and standalone Edit Mode.

### 10. Movement-Aware Distance Polling
- [x] **DONE (2026-05-31)**
- **Problem**: The 2-second ticker ran a full `GetNearbyQuestItems` scan unconditionally, even while standing still — work whose only purpose (distance change) only happens while moving.
- **Fix**: Track movement via `PLAYER_STARTED_MOVING`/`PLAYER_STOPPED_MOVING`; the ticker now scans only while moving, with a single settle update on stop. Event-driven `ScheduleUpdate` continues to cover everything else.

### 11. Profession-Item Quest Detection (scaffolding)
- [ ] SCAFFOLDED (2026-05-31) — needs real-world entries
- **Problem**: Items required by a quest but not exposed via `GetQuestLogSpecialItemInfo` (e.g. profession-crafted turn-ins) are invisible to the addon.
- **Fix**: Added an empty `data.professionQuestItems` table, consulted as an additional fallback in `utils.lua` (after `questItems`, reusing the bag-presence guard). Ships empty until verified `questID → itemID` pairs are collected in-game.

### 12. License / Attribution Correction
- [x] **DONE (2026-05-31)**
- **Problem**: README incorrectly claimed "MIT License"; the project is actually governed by p3lim's custom license (derivative works permitted, no standalone redistribution without permission).
- **Fix**: Corrected the README License section, added a `NOTICE` file with full attribution, and put third-party-store distribution (CurseForge/Wago) on hold pending the author's written permission.

### 13. Auto-Lock on Use — Detect Any Use Method
- [x] **DONE (2026-05-31)**
- **Problem**: Auto-Lock After Use only triggered via our button's `PostClick`, so using the item another way (bag click, keybind, or the hover/right-click world interaction — e.g. lassoing a flying mob) never locked it.
- **Fix**: Added a `UNIT_SPELLCAST_SUCCEEDED` (player) handler that matches the cast `spellID` against nearby quest items' spells (`C_Item.GetItemSpell`) and hard-locks the match. Catches every use path that casts the item's spell. The original `PostClick` hook is retained as a fallback for the rare items that don't cast a spell.

### 14. Selectable Lock / Switch Icons
- [x] **DONE (2026-05-31)**
- **Problem**: The Lock and Switch button icons were hardcoded.
- **Fix**: Added `LOCK_ICONS` (GoldLock [default], Padlock, KeyRing) and `SWITCH_ICONS` (Refresh, Rotate, Cycle) tables with `SetLockIcon`/`SetSwitchIcon` helpers, plus `lockIconStyle`/`switchIconStyle` settings and dropdowns in both the ElvUI panel and standalone Edit Mode. The gold/grey state tint still layers on top.
- **Curation (2026-05-31)**: trimmed to clean, reliable Blizzard art with the gold action-bar padlock as default. `applyIcon` now supports `atlas` entries with a runtime `C_Texture.GetAtlasInfo` existence check and texture fallback, so nicer atlas icons (discoverable via the TextureAtlasViewer addon) can be added later with zero blank-icon risk. Custom .tga assets remain a future option if desired.
