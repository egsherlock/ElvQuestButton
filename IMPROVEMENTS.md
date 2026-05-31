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
