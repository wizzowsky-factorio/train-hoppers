-- Move items from a hopper's inventory into a cargo wagon's inventory.
-- Preserves quality, ammo, durability, etc., because we insert LuaItemStacks
-- directly rather than passing item-name-and-count pairs.
local registry = require("scripts.hopper-registry")

local function transfer_hopper_to_wagon(hopper, wagon)
  local hopper_inv = hopper.get_inventory(defines.inventory.chest)
  local wagon_inv  = wagon.get_inventory(defines.inventory.cargo_wagon)
  if not (hopper_inv and wagon_inv) then return end
  if wagon_inv.is_full() then return end

  for slot_index = 1, #hopper_inv do
    local hopper_stack = hopper_inv[slot_index]
    if hopper_stack.valid_for_read then
      local inserted_count = wagon_inv.insert(hopper_stack)
      if inserted_count > 0 then
        hopper_stack.count = hopper_stack.count - inserted_count
      end
      -- If the wagon rejected any of this stack, it's full for this item.
      -- Move on to the next slot — a different item might still fit if the
      -- wagon has filter slots or is not entirely full.
    end
  end
end

-- Immediate transfer on arrival (before the first tick handler fires).
script.on_event(defines.events.on_train_changed_state, function(event)
  local train = event.train
  if train.state == defines.train_state.wait_station then
    registry.register_train_hoppers(train)
    for _, wagon in pairs(train.cargo_wagons) do
      for _, hopper in ipairs(registry.find_hoppers_overlapping_wagon(wagon)) do
        transfer_hopper_to_wagon(hopper, wagon)
      end
    end
  elseif event.old_state == defines.train_state.wait_station then
    registry.unregister_train_hoppers(train)
  end
end)

 -- Continuous transfer while trains sit at stations.
script.on_nth_tick(15, function()
  if not (storage.hoppers and storage.hoppers.active) then return end
  for hopper_unit_number, record in pairs(storage.hoppers.active) do
    if not record.hopper.valid then
      storage.hoppers.active[hopper_unit_number] = nil
    else
      for _, wagon in ipairs(record.wagons) do
        if wagon.valid then
          transfer_hopper_to_wagon(record.hopper, wagon)
        end
      end
    end
  end
end)