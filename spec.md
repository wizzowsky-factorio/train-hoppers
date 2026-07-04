# Train Hoppers: Mod Specification

**Target game:** Factorio 2.0 (Space Age optional, see "Compatibility")
**Author:** wizzowsky
**Status:** v0.2 implemented (functional MVP). This document mixes the original
design intent with the shipped behavior. Sections describing features not yet
built are explicitly marked **Planned**; everything else reflects the current
code unless noted.

## 0. Implementation status (v0.2)

A quick source-of-truth for what actually exists today versus what remains
aspirational. The detailed sections below have been updated to match, but this
list is the fastest orientation.

**Implemented and working:**

- Two buildings — Loading Hopper and Unloading Hopper — as `ContainerPrototype`
  variants, 4x6, straddling a straight rail.
- Bidirectional transfer between hopper and parked cargo wagon, driven by
  **continuous per-tick servicing** (`on_nth_tick(15)`) plus an immediate
  transfer on train arrival. This replaced the original single-atomic-transfer
  design.
- **Single-wagon rule:** a hopper transfers only when it overlaps exactly one
  cargo wagon. If it spans two (e.g. sits on a wagon gap), it deterministically
  goes inactive.
- **Placement validation:** a hopper whose outer side strips overlap a rail is
  rejected on build, with the item refunded (mined back for players, spilled for
  bots) and a localized flying-text warning.
- Fixed inventory size of **40 slots**, chosen to match a normal cargo wagon
  (see §2.1). Not a setting.
- Rotation via an assembling-machine **placer proxy**: the player places a
  rotatable placer that is immediately swapped for the correct H or V hidden
  container variant. Placed hoppers do not re-rotate; fast-replace covers edits.
- Wagon-friendly selection: hoppers draw beneath rolling stock
  (`render_layer = "lower-object"`) and use a low `selection_priority` (25) so a
  parked wagon over the center stays selectable while the wider side strips still
  select the hopper.
- Inserter access and circuit connections inherited from the container base.
- Save/load and re-scan migration; storage keyed by `unit_number`.

**Planned / not yet built:**

- Pit-and-elevator and chute graphics (§2.3). Current art is a placeholder:
  tinted steel-chest borders (blue = loader, amber = unloader).
- Transfer-pulse animation (§3.3).
- Mod settings (§4.4) — capacity, manual-mode, pulse duration. None exist; the
  recipes are currently unlocked from the start with no technology gate.
- Technology unlock (`technology.lua`) and `settings.lua`.
- Custom circuit signals such as "wagon present" (§3.5).

## 1. Concept

Train Hoppers adds two new buildings designed for fast loading and unloading of cargo wagons. Both buildings straddle a straight ground-level rail segment. When a train arrives and a single cargo wagon sits over a hopper, items move rapidly between hopper and wagon with no inserter swing time in between.

The buildings function as large storage containers. They expose inventory access to inserters from the sides and support circuit network connections.

### Design pillars

1. **Speed.** Loading and unloading should feel near-instant compared to inserter-based setups. The hoppers are the late-game answer to "my station is the bottleneck."
2. **Footprint trade-off.** Hoppers are physically large and have a specific rail-aligned shape, so they require commitment to a rail layout rather than being drop-in inserter replacements.
3. **Readable visuals.** The player should instantly understand which direction a hopper moves items, and whether a hopper is currently servicing a train.

## 2. Buildings

Both buildings are 4 tiles wide by 6 tiles long, straddling a straight rail segment that runs through the center 2x6 of their footprint. Inserter-accessible strips run along both long edges (1x6 each).

### 2.1 Loading Hopper

- **Footprint:** 4x6 (center 2x6 over rail, 1x6 access strip on each long side).
- **Inventory:** 40 slots, matching a normal (quality) cargo wagon's capacity so
  a full hopper can fill an empty wagon and vice versa. A base-40 container
  slightly overshoots the wagon at mid quality tiers (the wagon's per-quality
  capacities are hard-coded, not the +30%/tier steel-chest curve); this overshoot
  is accepted rather than corrected at runtime.
- **Input direction:** Inserters insert items from either side strip into the hopper.
- **Output direction:** Items leave the hopper by being transferred into a parked cargo wagon (no belt or inserter output to the world).
- **Behavior at a stop:** While a train is parked and exactly one cargo wagon
  overlaps the loader's footprint, continuously transfer items from the hopper
  into that wagon each service tick. Stop when the wagon is full or the hopper is
  empty. If the loader overlaps more than one wagon it stays inactive (§3.2).

### 2.2 Unloading Hopper (with visual "pit and elevators")

- **Footprint:** 4x6 (same as loader, so layouts are symmetric).
- **Inventory:** 40 slots, same as the loader (see §2.1).
- **Input direction:** Items come from a parked cargo wagon overhead-conceptually-dropping into the hopper.
- **Output direction:** Inserters remove items from either side strip.
- **Behavior at a stop:** While exactly one wagon overlaps the unloader's
  footprint, continuously transfer items from the wagon into the hopper each
  service tick. Stop when the wagon is empty or the hopper is full. If the
  unloader overlaps more than one wagon it stays inactive (§3.2).

### 2.3 Visual design

**Planned.** The graphics below are the design target; the current build ships a
placeholder (tinted steel-chest borders on the side strips — blue for the loader,
amber for the unloader — drawn beneath rolling stock). The unloader will use an
"underground pit" conceit to sell the fast-unload fiction without needing actual
elevated rails:

- **Surface layer:** the rail runs along the ground at standard elevation, same as anywhere else.
- **Below the rail (between sleepers, where players normally see grass/concrete):** a dark recessed pit graphic. This is purely a sprite illusion; the tile itself is unchanged.
- **Side strips:** small animated elevator shafts run up the inside edges of the side strips. Items appear to ride the elevators up from the pit to platform height, where inserters can grab them. Animation is decorative only; logic uses the standard container inventory.
- **Active state:** when a wagon is parked and transfer is happening, the elevators animate faster or emit small particles. When idle, they sit still or animate at a low ambient rate.
- **Loader visual:** mirror image without the pit. A raised "chute" structure on each side feeds visibly down into the wagon. Items can briefly animate dropping from the chutes into the wagon during a transfer pulse.

Both buildings rotate to align with horizontal or vertical rail.

### 2.4 Interaction surface

| Feature | Loader | Unloader |
| --- | --- | --- |
| Inserter access | Side strips, inserts INTO building | Side strips, removes FROM building |
| Belt access | None in v1 | None in v1 |
| Circuit wires | Yes, read inventory contents | Yes, read inventory contents |
| Logistic network | Optional setting; off by default | Optional setting; off by default |
| Filter slots | Yes (standard container filter) | Yes (standard container filter) |
| Recipe cost | Roughly: steel chest x2, iron gear x40, electronic circuit x20, steel plate x40 (tune later) |
| Tech unlock | **Planned.** Currently the recipes are `enabled = true` (available from the start, no gate). Intended target: a "Train hoppers" tech requiring Railway + Logistics 2. |

## 3. Mechanics

### 3.1 Detection

The transfer trigger is "a parked cargo wagon overlaps a hopper's footprint."

- Overlap is tested with `surface.find_entities_filtered{ name = <hopper variant
  names>, area = wagon.bounding_box }` (and the reverse, cargo wagons within a
  hopper's bounding box). The generous bounding-box test means a correctly
  aligned hopper counts exactly one wagon; a hopper straddling a wagon gap counts
  two and is disabled by the single-wagon rule (§3.2).
- Registration happens on `on_train_changed_state` when the new state is
  `defines.train_state.wait_station`, and is torn down when the train leaves.
- Because `on_train_changed_state` only fires on transitions, two extra paths
  cover trains that are *already* parked: a one-shot re-scan on `on_load`
  (save/load), and a scan when a hopper is **placed** next to a parked train
  (`register_parked_wagons_for_hopper`).
- Active (train-present) hoppers are tracked in `storage.hoppers.active` keyed by
  `unit_number`; the canonical registry of all hoppers is `storage.hoppers.by_unit`.

### 3.2 Transfer

Transfer is **continuous while a train is parked**, not a single atomic
operation. A service tick (`on_nth_tick(15)`) walks the active hoppers and moves
items; an immediate transfer also runs the instant a train arrives so there is no
visible delay before the first tick.

- **Single-wagon rule:** each service call resolves the hopper's *sole* valid
  overlapping wagon. Zero or more than one → the hopper does nothing that tick
  (deterministic "ambiguous = off" behavior, pairing with a future inactive-state
  graphic). The registry still tracks every overlapping wagon; the policy lives in
  the transfer layer.
- **Loader:** `wagon_inv.insert(stack)` for every readable stack in the hopper, in
  slot order, decrementing the source stack by the inserted count. Stops when the
  wagon is full. Respects the wagon's bar and filter slots.
- **Unloader:** `hopper_inv.insert(stack)` from the wagon, same loop; stops when
  the hopper is full (backpressure).
- Items are moved by inserting the `LuaItemStack` directly rather than by
  item-name+count, so quality, durability, ammo, and other metadata are preserved.
- **Quality (Space Age):** transfers preserve quality automatically via the
  stack-copy approach.

### 3.3 Visual transfer pulse

**Planned.** Not yet implemented. When built, a transfer will fire a one-shot
animation on the hopper (chutes flashing, elevators speeding up, particle puff)
lasting a fixed visible duration regardless of how many items moved.

### 3.4 Edge cases the mod must handle

1. **Train arrives but no cargo wagon overlaps the hopper.** Do nothing. Common when a hopper is placed near a stop but not on a wagon slot.
2. **Multiple hoppers in a row.** Each hopper handles its own overlapping wagon independently.
3. **Hopper overlaps more than one wagon.** The hopper straddles a wagon gap. It
   deterministically goes inactive (single-wagon rule, §3.2) rather than guessing
   which wagon to service. Placement validation (§4.2) already prevents most
   misalignment; this is the runtime backstop.
4. **Train in manual mode at the stop.** Currently transfers happen whenever the
   train state is `wait_station`. A manual-mode opt-out is a **planned** setting.
5. **Train leaves mid-transfer.** Transfer is continuous per-tick, so a partial
   transfer simply stops on the tick the train leaves; the hopper is unregistered
   on the state change. No cleanup needed for in-flight state.
6. **Hopper destroyed while train is at the stop.** Storage is cleaned on
   `on_entity_died` / mined / script-destroy events, and the service tick drops any
   entry whose entity has become invalid.
7. **Rail under hopper is mined.** The hopper itself is unaffected (separate
   entity). It stays placed but cannot service trains until rail is rebuilt.
8. **Two-headed trains and reversed wagons.** Detection is based on wagon entity overlap, so direction does not matter.
9. **Filter inserters and red bar limits on the wagon.** Honored automatically by the Lua `insert` call.
10. **Wagon selection blocked by the hopper.** Hoppers draw beneath rolling stock
    and use a lower `selection_priority`, so a parked wagon over the center stays
    selectable; the wider side strips still select the hopper.

### 3.5 Circuit network

Each hopper exposes a single combinator-like output of its current inventory contents, identical to a regular container. v1 does not add custom signals (e.g., "wagon present"). v2 candidate: emit a signal indicating "a wagon is currently being serviced this tick."

## 4. Technical implementation

### 4.1 Prototype definitions (data stage)

Both buildings are defined as `ContainerPrototype` instances (cloned from
`steel-chest`). Container is chosen over `LogisticContainerPrototype` because
logistic integration is optional and we want it off by default. Each building is
actually **three** prototypes: a hidden horizontal container variant, a hidden
vertical variant, and a rotatable assembling-machine **placer** the player picks
up (assembling-machine gives R-key rotation of the ghost). On build, the placer
is swapped for the correct H/V variant based on its direction (§4.3).

Key prototype fields:

- `collision_box`: 4x6 footprint, with `collision_mask = { player, is_object }`
  (notably **excluding** the rail layer) so the entity can be placed over rails.
- `selection_box`: matches the collision box.
- `selection_priority`: 25 (below the default 50) so a parked wagon wins hover
  selection over the center; the side strips still select the hopper.
- `flags`: `"player-creation"`, `"placeable-neutral"`, `"not-in-kill-statistics"`;
  the H/V variants are `hidden` so only the placer is user-facing.
- `inventory_size`: 40 (matches the cargo wagon; see §2.1).
- `fast_replaceable_group`: `"train-hopper"` (shared, so loader/unloader
  fast-replace each other).
- `picture`: composited from tinted steel-chest sprites on the side strips, drawn
  on `render_layer = "lower-object"` so hoppers sit visually beneath trains.

### 4.2 Placement validation

On `on_built_entity`, `on_robot_built_entity`, `script_raised_built`, and
`script_raised_revive`, before the placer is swapped for a real variant:

1. Compute the two 1-tile **outer side strips** of the target footprint (inset
   slightly on the inner edge so a correctly-centered rail does not clip them).
2. Reject placement if either strip overlaps a rail
   (`straight-rail`/`half-diagonal-rail`/`curved-rail-a`/`curved-rail-b`) — this
   catches off-center placement and hoppers spanning between two parallel tracks.
3. On rejection: return the item to its source (players mine it back, bots/scripts
   get the item spilled) and show a localized flying-text warning.

This enforces "straddle a single track cleanly" and gives immediate feedback,
rather than the original "find a centered straight-rail + match direction" check.

### 4.3 Runtime (control.lua) structure

```
storage.hoppers = {
  by_unit = {              -- canonical registry of every hopper, keyed by unit_number
    [unit_number] = {
      entity = LuaEntity,
      kind   = "loader" | "unloader",
    }
  },
  active = {               -- only hoppers with a parked train; keyed by unit_number
    [unit_number] = {
      wagons = { LuaEntity, ... },  -- all overlapping wagons (policy picks the sole one)
    }
  },
}
```

The registry (`by_unit`) is kind-tagged so runtime branching never parses entity
names. The `active` map holds only the wagon list; the entity and kind are always
looked up from `by_unit`. (The original design stored `rail` and
`detection_area` per hopper; neither is persisted — overlap is recomputed from
bounding boxes as needed.)

**Event handlers:**

- `on_init` / `on_configuration_changed` / `on_load`: initialize and migrate
  `storage`, and re-scan surfaces so already-parked trains are picked up.
- Build events (`on_built_entity`, `on_robot_built_entity`, `script_raised_built`,
  `script_raised_revive`): validate placement, swap placer for the H/V variant,
  register it, and pick up any already-parked wagon it overlaps.
- Destroy events (`on_player_mined_entity`, `on_robot_mined_entity`,
  `on_entity_died`, `script_raised_destroy`): unregister the hopper.
- `on_player_rotated_entity`: swap a placed hopper between H and V variants,
  carrying its inventory across.
- `on_train_changed_state`: on `wait_station`, register overlapping hoppers and
  run an immediate transfer; on leaving, unregister.
- `on_nth_tick(15)`: continuous transfer for every active hopper (this drives the
  actual item movement, not just animation).

### 4.4 Settings

**Planned — none currently exist.** No `settings.lua` ships in v0.2; inventory
capacity is fixed at 40 and transfers always run at `wait_station`. The intended
settings when added:

- `train-hopper-capacity` (startup int): inventory slot count (currently fixed at 40).
- `train-hopper-transfer-on-manual` (runtime bool, default true).
- `train-hopper-visual-pulse-duration` (runtime int, default 45 ticks) — pairs
  with the planned transfer-pulse animation (§3.3).

### 4.5 Save/load and migration

- All persistent state lives in `storage`.
- LuaEntity references are valid across save/load and do not need re-resolution.
- On `on_configuration_changed`, scan all surfaces for any hopper entities that exist but are not in `storage` and re-register them. Also drop entries whose entity has become invalid.

### 4.6 File structure

Current layout (planned-but-unbuilt files marked):

```
train-hoppers/
  info.json
  data.lua                  -- requires prototypes/*
  control.lua               -- requires scripts/*
  README.md
  spec.md
  prototypes/
    entity-loader.lua
    entity-unloader.lua
    item.lua
    recipe.lua
    graphics.lua            -- shared sprite compositing + tints
    technology.lua          -- PLANNED (not present)
  scripts/
    hopper-registry.lua     -- shared bookkeeping: name lists, overlap, register/unregister
    placement.lua           -- placer swap, rotation, placement validation, lifecycle
    transfer.lua            -- item movement + single-wagon rule
    migration.lua           -- storage init + save/load re-scan
    animation.lua           -- PLANNED (not present)
  settings.lua              -- PLANNED (not present)
  locale/
    en/
      train-hoppers.cfg
  graphics/                 -- PLANNED: real art (pit/elevator/chute); placeholder is code-composited
  migrations/               -- (empty)
```

## 5. Compatibility

- **Base game 2.1:** required (`base >= 2.1`, per `info.json`).
- **Space Age:** not required, but quality is supported automatically by using stack-based transfer. Elevated rails are explicitly out of scope.
- **Other mods:** any mod that adds new cargo wagons should work, since detection is based on `type = "cargo-wagon"`.

## 6. Out of scope for v1

These are intentionally excluded to keep the scope tight:

- Fluid wagons. Different prototype, different inventory, different visual. Candidate for v2.
- Elevated-rail variant. Verified hard to do; deferred indefinitely. Visual pit illusion replaces the original elevated unloader idea.
- Custom circuit signals (e.g., "wagon present", "transfer in progress").
- Belt-based input/output. Inserter access only in v1.
- Per-wagon filter rules from the hopper itself (relying on the wagon's own filter slots).
- Streaming transfer animation (items visibly flowing during a multi-second transfer). v1 uses an instantaneous transfer with a fixed visual pulse.

## 7. Milestones

Progress markers reflect the v0.2 build.

1. **M1: Prototype boilerplate.** ✅ Done. Container variants + placer proxy
   placeable in the world; collision_mask rail-transparency verified.
2. **M2: Placement validation.** ✅ Done — implemented as an outer-strip rail
   overlap check with refund + flying text (§4.2).
3. **M3: Transfer logic.** ✅ Done, and extended beyond the original scope:
   continuous per-tick transfer in both directions plus the single-wagon rule,
   verified end-to-end with a vanilla train at a vanilla stop.
4. **M4: Inserter and circuit integration.** ✅ Inherited from the container base;
   working. Fine-tuning ongoing.
5. **M5: Graphics pass.** ⏳ Planned. Placeholder tinted borders in place; real
   pit/elevator/chute sprites outstanding. Longest single task.
6. **M6: Settings, localization, recipes, technology.** ◑ Partial — recipes and
   localization exist; settings and technology are not yet built (§4.4, §2.4).
7. **M7: Polish, edge cases, packaging.** ⏳ Ongoing (edge cases handled: parked-
   train registration, save/load, wagon selection). Packaging pending.
8. **Release v1.0 to the mod portal.** ⏳ Pending (currently v0.2, internal).

## 8. Open questions (status)

Several of these are now resolved by the v0.2 build; kept here for the rationale.

1. **Shared prototype with a "kind" property, or two separate prototypes?**
   **Resolved — separate.** Each building is its own set of container variants +
   placer. The *storage* layer is unified (`by_unit` with a `kind` tag), but the
   prototypes, recipes, and graphics are distinct.
2. **Inventory size: 80, 100, or 120 slots?** **Resolved — 40**, to match a normal
   cargo wagon rather than overshoot it (see §2.1). Revisit if playtesting wants a
   buffer larger than one wagon.
3. **Different recipes/tech tiers for loader vs unloader?** **Deferred.** Both are
   currently ungated with parallel recipes. Tiering remains possible once a tech
   gate exists.
4. **Visual: how literal should the elevator be?** Still open; graphics are
   placeholder. Lean toward chunky, readable industrial design when built.
5. **Should hoppers occupy the train signal's path collision?** **Resolved — no.**
   The `collision_mask` excludes the rail layer, so hoppers are transparent to
   train movement.
6. **Should misaligned hoppers be prevented or just inactive?** **Resolved — both.**
   Placement validation (§4.2) prevents building across rails; the single-wagon
   rule (§3.2) is the runtime backstop for anything that slips through.

## 9. Reference mods to study

When you start implementation, read source from these for patterns:

- **Miniloader** family of mods: example of scripted loader-like behavior over containers.
- **Vehicle Wagon 2**: script-driven interaction with cargo wagons at stops.
- **Rail Signal Planner** or similar: examples of entities placed over rails with custom collision masks.
- **LTN (Logistic Train Network)** and **Project Cybersyn**: not directly applicable, but useful for advanced train-state handling if v2 or v3 needs it.

## 10. Glossary

- **Hopper:** either of the two buildings added by this mod.
- **Wagon slot:** the 2x6 area of rail covered by a single cargo wagon when parked at a stop.
- **Transfer pulse:** the brief one-time visual effect played when items move between hopper and wagon.
- **Side strip:** the 1x6 strips on each long side of a hopper, accessible to inserters.
