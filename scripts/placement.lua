-- Map from the placer's direction to which real variant to spawn.
-- defines.direction.north (0) and south (4) → horizontal.
-- defines.direction.east (2) and west (6)   → vertical.
local function variant_for_direction(direction)
  if direction == defines.direction.east or direction == defines.direction.west then
    return "train-hopper-loader-v"
  else
    return "train-hopper-loader-h"
  end
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
    if placer.name ~= "train-hopper-loader" then return end

    local surface  = placer.surface
    local position = placer.position
    local force    = placer.force
    local direction = placer.direction

    local target_name = variant_for_direction(direction)
    placer.destroy()

    surface.create_entity{
      name     = target_name,
      position = position,
      force    = force,
    }
  end)
end

-- On rotation of an existing hopper, swap between H and V variants.
script.on_event(defines.events.on_player_rotated_entity, function(event)
  local rotated_entity = event.entity
  if not (rotated_entity and rotated_entity.valid) then return end

  local swap_to
  if rotated_entity.name == "train-hopper-loader-h" then swap_to = "train-hopper-loader-v"
  elseif rotated_entity.name == "train-hopper-loader-v" then swap_to = "train-hopper-loader-h"
  else return end

  local surface, position, force = rotated_entity.surface, rotated_entity.position, rotated_entity.force
  local new_entity = surface.create_entity{
    name     = swap_to,
    position = position,
    force    = force,
  }
  if new_entity then
    transfer_inventory(rotated_entity, new_entity)
    rotated_entity.destroy()
  end
end)