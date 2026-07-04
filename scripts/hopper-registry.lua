local M = {}

M.LOADER_NAMES = { "train-hopper-loader-h",   "train-hopper-loader-v" }
M.UNLOADER_NAMES = { "train-hopper-unloader-h", "train-hopper-unloader-v" }
M.ALL_HOPPER_NAMES = {}
for _, name in ipairs(M.LOADER_NAMES) do table.insert(M.ALL_HOPPER_NAMES, name) end
for _, name in ipairs(M.UNLOADER_NAMES) do table.insert(M.ALL_HOPPER_NAMES, name) end

function M.find_hoppers_overlapping_wagon(wagon)
  return wagon.surface.find_entities_filtered{
    name = M.ALL_HOPPER_NAMES,
    area = wagon.bounding_box,
  }
end

-- When a hopper is placed next to an already-parked train, on_train_changed_state
-- won't fire for that train. Scan for overlapping cargo wagons whose train is
-- stopped and register them so the tick loop starts transferring.
function M.register_parked_wagons_for_hopper(hopper)
  local wagons = hopper.surface.find_entities_filtered{
    type = "cargo-wagon",
    area = hopper.bounding_box,
  }
  for _, wagon in ipairs(wagons) do
    local train = wagon.train
    if train and train.state == defines.train_state.wait_station then
      local record = storage.hoppers.active[hopper.unit_number]
      if not record then
        record = { wagons = {} }
        storage.hoppers.active[hopper.unit_number] = record
      end
      table.insert(record.wagons, wagon)
    end
  end
end

-- Called when a train arrives at wait_station. Register every (hopper, wagon)
-- pair for continuous transfer.
function M.register_train_hoppers(train)
  for _, wagon in pairs(train.cargo_wagons) do
    for _, hopper in ipairs(M.find_hoppers_overlapping_wagon(wagon)) do
      local record = storage.hoppers.active[hopper.unit_number]
      if not record then
        record = { wagons = {} }
        storage.hoppers.active[hopper.unit_number] = record
      end
      table.insert(record.wagons, wagon)
    end
  end
end

-- Called when a train leaves wait_station. Remove every (hopper, wagon) pair
-- involving this train's wagons.
function M.unregister_train_hoppers(train)
  for _, wagon in pairs(train.cargo_wagons) do
    for _, hopper in ipairs(M.find_hoppers_overlapping_wagon(wagon)) do
      local record = storage.hoppers.active[hopper.unit_number]
      if record then
        for wagon_index = #record.wagons, 1, -1 do
          if record.wagons[wagon_index] == wagon
            or not record.wagons[wagon_index].valid then
            table.remove(record.wagons, wagon_index)
          end
        end
        if #record.wagons == 0 then
          storage.hoppers.active[hopper.unit_number] = nil
        end
      end
    end
  end
end

return M