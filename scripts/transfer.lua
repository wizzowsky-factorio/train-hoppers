-- Move items from a hopper's inventory into a cargo wagon's inventory.
-- Preserves quality, ammo, durability, etc., because we insert LuaItemStacks
-- directly rather than passing item-name-and-count pairs.
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

-- Immediate transfer when a train arrives at a station.
script.on_event(defines.events.on_train_changed_state, function(event)
  local train = event.train
  if train.state ~= defines.train_state.wait_station then return end

  for _, wagon in pairs(train.cargo_wagons) do
    local overlapping_hoppers = wagon.surface.find_entities_filtered{
      name = { "train-hopper-loader-h", "train-hopper-loader-v" },
      area = wagon.bounding_box,
    }
    for _, hopper in ipairs(overlapping_hoppers) do
      transfer_hopper_to_wagon(hopper, wagon)
    end
  end
end)

 -- Continuous transfer while trains sit at stations.
script.on_nth_tick(15, function()
  for _, record in pairs(storage.loaders) do
    local hopper = record.entity
    if hopper.valid then
      local wagons = hopper.surface.find_entities_filtered{
        type = "cargo-wagon",
        area = hopper.bounding_box,
      }
      for _, wagon in ipairs(wagons) do
        if wagon.valid and wagon.train and wagon.train.state == defines.train_state.wait_station then
          transfer_hopper_to_wagon(hopper, wagon)
        end
      end
    end
  end
end)