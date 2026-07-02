# Train Hoppers: Mod Specification

**Target game:** Factorio 2.0 (Space Age optional, see "Compatibility")
**Author:** wizzowsky
**Status:** Draft v1

## 1. Concept

Train Hoppers adds two new buildings designed for fast loading and unloading of cargo wagons. Both buildings straddle a straight ground-level rail segment and align with the wagon slots projected by a nearby train stop. When a train arrives at the station, items move between hopper and wagon in a single transfer, with no inserter swing time in between.

The buildings function as large storage containers. They expose inventory access to inserters from the sides and support circuit network connections.

### Design pillars

1. **Speed.** Loading and unloading should feel near-instant compared to inserter-based setups. The hoppers are the late-game answer to "my station is the bottleneck."
2. **Footprint trade-off.** Hoppers are physically large and have a specific rail-aligned shape, so they require commitment to a rail layout rather than being drop-in inserter replacements.
3. **Readable visuals.** The player should instantly understand which direction a hopper moves items, and whether a hopper is currently servicing a train.

## 2. Buildings

Both buildings are 4 tiles wide by 6 tiles long, straddling a straight rail segment that runs through the center 2x6 of their footprint. Inserter-accessible strips run along both long edges (1x6 each).

### 2.1 Loading Hopper

- **Footprint:** 4x6 (center 2x6 over rail, 1x6 access strip on each long side).
- **Inventory:** Large container, target ~80 to 120 slots (numbers to tune; roughly 2x a steel chest).
- **Input direction:** Inserters insert items from either side strip into the hopper.
- **Output direction:** Items leave the hopper by being transferred into a parked cargo wagon (no belt or inserter output to the world).
- **Behavior at a stop:** When a train is parked at an adjacent stop and a cargo wagon's bounding box overlaps the loader's footprint, transfer as many items as possible from the hopper into that wagon. Stop transferring when either the wagon is full or the hopper is empty.

### 2.2 Unloading Hopper (with visual "pit and elevators")

- **Footprint:** 4x6 (same as loader, so layouts are symmetric).
- **Inventory:** Same large container, same target capacity.
- **Input direction:** Items come from a parked cargo wagon overhead-conceptually-dropping into the hopper.
- **Output direction:** Inserters remove items from either side strip.
- **Behavior at a stop:** When a wagon's bounding box overlaps the unloader's footprint, transfer as many items as possible from the wagon's inventory into the hopper. Stop when wagon is empty or hopper is full.

### 2.3 Visual design

The unloader uses an "underground pit" conceit to sell the fast-unload fiction without needing actual elevated rails:

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
| Tech unlock | Behind "Logistic train network" or a new "Train hoppers" tech that requires Railway + Logistics 2 |

## 3. Mechanics

### 3.1 Detection

The transfer trigger is "a parked cargo wagon overlaps a hopper's wagon-detection area."

- The wagon-detection area is the inner 2x6 rail strip of each hopper's footprint, expanded slightly to handle wagon positional jitter.
- Detection happens on `on_train_changed_state` when the new state is `defines.train_state.wait_station` (and similar arrived-at-stop states).
- For each cargo wagon in `train.carriages`, the mod checks `surface.find_entities_filtered{type = "train-hopper-loader" | "train-hopper-unloader", area = wagon_bbox_expanded}`. A direct lookup keyed by tile position via a `storage` index can replace this if perf is a concern.

### 3.2 Transfer

A single transfer happens per (wagon, hopper) pair per stop. It is one logical operation, not per-tick streaming.

- **Loader:** `wagon_inv.insert(stack)` for every stack in the hopper, in slot order. Continue until the wagon refuses or the hopper is empty. Respect the wagon's bar (red line) and filter slots.
- **Unloader:** `hopper_inv.insert(stack)` from the wagon. Same loop.
- Items are moved respecting `LuaItemStack` durability, ammo magazine count, and other metadata. Use `LuaInventory.find_item_stack` and full stack `set_stack` rather than item-name+count where possible, to preserve quality and data.
- **Quality (Space Age):** transfers preserve quality. The item-stack copy approach handles this automatically.

### 3.3 Visual transfer pulse

When a transfer happens, fire a one-shot animation on the hopper (chutes flashing, elevators speeding up, particle puff). The animation should always last a fixed visible duration (e.g., 30 to 60 ticks) regardless of how many items actually moved, so that small transfers still feel satisfying. The actual inventory change is instantaneous on the first tick of the animation.

### 3.4 Edge cases the mod must handle

1. **Train arrives but no cargo wagon overlaps the hopper.** Do nothing. Common when a hopper is placed near a stop but not on a wagon slot.
2. **Multiple hoppers in a row.** Each hopper handles its own overlapping wagon independently.
3. **Train in manual mode at the stop.** Optional setting. Default: transfer happens. Player setting to disable for manual-only behavior.
4. **Train leaves mid-transfer.** Transfers are atomic in v1, so this should not happen. If we ever switch to streaming transfer, the transfer cancels gracefully.
5. **Hopper destroyed while train is at the stop.** Re-detection on the next state change avoids stale references; storage is cleaned on `on_entity_died` / mined events.
6. **Rail under hopper is mined.** The hopper itself is unaffected (it is a separate entity). The player may now have a hopper sitting over no rail; it stays placeable but cannot service trains until rail is rebuilt.
7. **Two-headed trains and reversed wagons.** Detection is based on wagon entity overlap, so direction does not matter.
8. **Filter inserters and red bar limits on the wagon.** Honor them. The Lua `insert` call already does.

### 3.5 Circuit network

Each hopper exposes a single combinator-like output of its current inventory contents, identical to a regular container. v1 does not add custom signals (e.g., "wagon present"). v2 candidate: emit a signal indicating "a wagon is currently being serviced this tick."

## 4. Technical implementation

### 4.1 Prototype definitions (data stage)

Both buildings are defined as `ContainerPrototype` instances. Container is chosen over `LogisticContainerPrototype` because logistic integration is optional and we want it off by default.

Key prototype fields:

- `collision_box`: 4x6 footprint matching the visible building, but `collision_mask` configured so the entity does not collide with `rail-layer`. The exact mask is the standard container mask minus the rail layer. Reference: `data.raw["straight-rail"]["straight-rail"]` for the rail's own layer set.
- `selection_box`: matches the 4x6 visible area.
- `flags`: include `"player-creation"`, `"placeable-neutral"`. Avoid `"not-on-map"`.
- `inventory_size`: 80 to 120, tune later.
- `circuit_wire_max_distance`: standard (9 or so).
- `picture`: rotated sprite sheet, four orientations (or two if rail orientation is restricted to horizontal/vertical only).

### 4.2 Placement validation

After `on_built_entity`, `on_robot_built_entity`, and `script_raised_built`:

1. Look for a `straight-rail` entity centered in the hopper's inner 2x6 area.
2. Verify the rail's direction matches the hopper's rotation.
3. If invalid: destroy the hopper, return the item to the player (or robot), print a localized error message.

This avoids the "hopper floating over nothing" problem and gives the player clear feedback.

### 4.3 Runtime (control.lua) structure

```
storage = {
  hoppers = {            -- keyed by unit_number
    [unit_number] = {
      entity = LuaEntity,
      kind = "loader" | "unloader",
      rail = LuaEntity,     -- the rail it straddles
      detection_area = BoundingBox,
    }
  },
  trains_being_serviced = {}, -- optional, for animation tracking
}
```

**Event handlers:**

- `script.on_init`, `script.on_configuration_changed`: initialize and migrate `storage`.
- Build events (`on_built_entity`, `on_robot_built_entity`, `script_raised_built`): register hopper, validate placement.
- Destroy events (`on_player_mined_entity`, `on_robot_mined_entity`, `on_entity_died`, `script_raised_destroy`): unregister hopper.
- `on_train_changed_state`: if new state is `wait_station`, iterate `event.train.carriages`, find overlapping hoppers, perform transfers.
- `on_nth_tick(N)`: only used to drive the visual animation state machine. Not used for transfer logic.

### 4.4 Settings

Per-mod settings (startup + runtime as appropriate):

- `train-hopper-capacity` (startup int, default 100): inventory slot count.
- `train-hopper-transfer-on-manual` (runtime bool, default true).
- `train-hopper-visual-pulse-duration` (runtime int, default 45 ticks).

### 4.5 Save/load and migration

- All persistent state lives in `storage`.
- LuaEntity references are valid across save/load and do not need re-resolution.
- On `on_configuration_changed`, scan all surfaces for any hopper entities that exist but are not in `storage` and re-register them. Also drop entries whose entity has become invalid.

### 4.6 File structure

```
train-hoppers/
  info.json
  thumbnail.png
  changelog.txt
  data.lua                  -- requires prototypes/*
  control.lua               -- requires scripts/*
  settings.lua
  prototypes/
    entity-loader.lua
    entity-unloader.lua
    item.lua
    recipe.lua
    technology.lua
  scripts/
    placement.lua
    transfer.lua
    animation.lua
    migration.lua
  graphics/
    entity/
      loader/
      unloader/
    icons/
  locale/
    en/
      train-hoppers.cfg
  migrations/
    (empty in v1)
```

## 5. Compatibility

- **Base game 2.0:** required.
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

1. **M1: Prototype boilerplate.** Two entities placeable in the world via creative mode, no logic. Verifies collision_mask trick works. Estimate: 1 evening.
2. **M2: Placement validation.** Cancel placement when not on a valid straight rail. Estimate: 1 evening.
3. **M3: Transfer logic.** `on_train_changed_state` handler that moves items in both directions. Verified working end-to-end with a vanilla train at a vanilla stop. Estimate: 1 weekend.
4. **M4: Inserter and circuit integration.** Should already work from the container prototype; verify and tune. Estimate: half an evening.
5. **M5: Graphics pass.** First version of sprites including the pit/elevator illusion. Estimate: longest single task, multiple weekends depending on art skill.
6. **M6: Settings, localization, recipes, technology.** Estimate: 1 evening.
7. **M7: Polish, edge cases, packaging.** Estimate: 1 weekend.
8. **Release v1.0 to the mod portal.**

## 8. Open questions to revisit before coding

1. **Should both hoppers share a single entity prototype with a "kind" property, or be two separate prototypes?** Two separate prototypes is simpler, more idiomatic, and makes graphics and recipes cleaner. Going with two unless a reason emerges.
2. **Inventory size: 80, 100, or 120 slots?** Defer until playtest. Default 100 is reasonable.
3. **Should the unloader and loader have different recipes/tech tiers?** Possibly. Loader is more obviously useful early; unloader benefits more from late-game throughput needs. Could tier them.
4. **Visual: how literal should the elevator be?** A heavy "obvious mechanism" look reads better than a subtle one. Lean toward chunky, readable industrial design.
5. **Should hoppers occupy the train signal's path collision?** No: they must be transparent to train movement. The collision_mask configuration handles this.

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
