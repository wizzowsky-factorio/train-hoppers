local registry = require("scripts.hopper-registry")

local HOPPER_CONFIG = {
  ["train-hopper-loader"]   = { kind = "loader",   h = "train-hopper-loader-h",   v = "train-hopper-loader-v" },
  ["train-hopper-unloader"] = { kind = "unloader", h = "train-hopper-unloader-h", v = "train-hopper-unloader-v" },
}

-- Reverse lookup: a variant name -> its config, so rotation can find the sibling + kind.
local VARIANT_CONFIG = {}
for _, cfg in pairs(HOPPER_CONFIG) do
  VARIANT_CONFIG[cfg.h] = cfg
  VARIANT_CONFIG[cfg.v] = cfg
end

-- Map from the placer's direction to which real variant to spawn.
-- defines.direction.north (0) and south (4) → horizontal.
-- defines.direction.east (2) and west (6)   → vertical.
local function variant_for_direction(direction, cfg)
  if direction == defines.direction.east or direction == defines.direction.west then
    return cfg.v
  else
    return cfg.h
  end
end

-- Rail types a hopper's outer strips must stay clear of.
local RAIL_TYPES = { "straight-rail", "half-diagonal-rail", "curved-rail-a", "curved-rail-b" }

-- The two 1-tile outer strips of the footprint, inset slightly on the inner
-- edge so a correctly-centered rail (which sits in the middle 2 tiles) doesn't
-- clip the strip boundary. Rails live on a 2-tile grid, so a parallel or
-- off-by-one rail lands squarely inside a strip while a centered one stays out.
local function outer_strip_areas(position, is_horizontal)
  local x, y = position.x, position.y
  if is_horizontal then
    return {
      { {x - 3, y - 2},   {x + 3, y - 1.2} },  -- top strip
      { {x - 3, y + 1.2}, {x + 3, y + 2}   },  -- bottom strip
    }
  else
    return {
      { {x - 2,   y - 3}, {x - 1.2, y + 3} },  -- left strip
      { {x + 1.2, y - 3}, {x + 2,   y + 3} },  -- right strip
    }
  end
end

-- True if neither outer strip overlaps a rail, i.e. the hopper straddles a
-- single track cleanly rather than spanning or sitting off-center.
local function strips_clear_of_rails(surface, position, is_horizontal)
  for _, area in ipairs(outer_strip_areas(position, is_horizontal)) do
    if surface.count_entities_filtered{ area = area, type = RAIL_TYPES } > 0 then
      return false
    end
  end
  return true
end

-- Reject a misplaced placer, returning the item to its source.
local function refund_and_cancel(event, placer)
  local surface, position, item_name = placer.surface, placer.position, placer.name

  if event.player_index then
    local player = game.get_player(event.player_index)
    if player then
      player.create_local_flying_text{ text = { "train-hopper.bad-placement" }, position = position }
      player.mine_entity(placer, true)   -- returns the item, spills overflow, removes placer
      return
    end
  end

  -- Robots / script-raised builds: no player to mine it back, so spill and destroy.
  surface.spill_item_stack{ position = position, stack = { name = item_name, count = 1 } }
  placer.destroy()
end

-- Copy inventory contents from one entity to another. Both must have the same
-- inventory type (defines.inventory.chest here since they're containers).
local function transfer_inventory(from_entity, to_entity)
  local from_inv = from_entity.get_inventory(defines.inventory.chest)
  local to_inv   = to_entity.get_inventory(defines.inventory.chest)
  if not (from_inv and to_inv) then return end
  for i = 1, #from_inv do
    local stack = from_inv[i]
    if stack.valid_for_read then
      to_inv.insert(stack)
    end
  end
end

-- On placement of the placer, immediately replace it with the correct real variant.
local build_events = {
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive,
}
for _, event_id in ipairs(build_events) do
  script.on_event(event_id, function(event)
    local placer = event.entity
    if not (placer and placer.valid) then return end
    local cfg = HOPPER_CONFIG[placer.name]
    if not cfg then return end

    local surface   = placer.surface
    local position  = placer.position
    local force     = placer.force
    local direction = placer.direction

    local target_name = variant_for_direction(direction, cfg)

    local is_horizontal = (target_name == cfg.h)
    if not strips_clear_of_rails(surface, position, is_horizontal) then
      refund_and_cancel(event, placer)
      return
    end

    placer.destroy()

    local new_entity = surface.create_entity{
      name     = target_name,
      position = position,
      force    = force,
    }
    if new_entity then
      storage.hoppers.by_unit[new_entity.unit_number] = { entity = new_entity, kind = cfg.kind }
      registry.register_parked_wagons_for_hopper(new_entity)
    end
  end)
end

-- On rotation of an existing hopper, swap between H and V variants.
script.on_event(defines.events.on_player_rotated_entity, function(event)
  local rotated_entity = event.entity
  if not (rotated_entity and rotated_entity.valid) then return end

  local cfg = VARIANT_CONFIG[rotated_entity.name]
  if not cfg then return end

  local swap_to = (rotated_entity.name == cfg.h) and cfg.v or cfg.h -- lua ternaries suck
  local surface, position, force = rotated_entity.surface, rotated_entity.position, rotated_entity.force
  local new_entity = surface.create_entity{
    name     = swap_to,
    position = position,
    force    = force,
  }
  if new_entity then
    transfer_inventory(rotated_entity, new_entity)
    storage.hoppers.by_unit[rotated_entity.unit_number] = nil
    storage.hoppers.active[rotated_entity.unit_number] = nil
    storage.hoppers.by_unit[new_entity.unit_number] = { entity = new_entity, kind = cfg.kind }
    rotated_entity.destroy()
  end
end)

local destroy_events = {
  defines.events.on_player_mined_entity,
  defines.events.on_robot_mined_entity,
  defines.events.on_entity_died,
  defines.events.script_raised_destroy,
}
for _, event_id in ipairs(destroy_events) do
  script.on_event(event_id, function(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    if storage.hoppers.by_unit[entity.unit_number] then
      storage.hoppers.by_unit[entity.unit_number] = nil
      storage.hoppers.active[entity.unit_number] = nil
    end
  end)
end