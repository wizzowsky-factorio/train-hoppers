local registry = require("scripts.hopper-registry")

local function ensure_storage()
  storage.hoppers           = storage.hoppers           or {}
  storage.hoppers.loaders   = storage.hoppers.loaders   or {}
  storage.hoppers.unloaders = storage.hoppers.unloaders or {}
  storage.hoppers.active    = storage.hoppers.active    or {}
end

-- Move data from the flat layout (0.1.1 and earlier) into the nested layout.
-- Safe to call more than once; a no-op if the old fields are absent.
local function migrate_flat_to_nested()
  if storage.loaders then
    for unit_number, record in pairs(storage.loaders) do
      storage.hoppers.loaders[unit_number] = record
    end
    storage.loaders = nil
  end
  if storage.active_transfers then
    for unit_number, record in pairs(storage.active_transfers) do
      storage.hoppers.active[unit_number] = record
    end
    storage.active_transfers = nil
  end
end

local function rescan_all_hoppers()
  storage.hoppers.loaders = {}
  for _, surface in pairs(game.surfaces) do
    local found = surface.find_entities_filtered{
      name = { "train-hopper-loader-h", "train-hopper-loader-v" }
    }
    for _, hopper in ipairs(found) do
      storage.hoppers.loaders[hopper.unit_number] = { entity = hopper }
    end
  end
end

local function reregister_parked_trains()
  storage.hoppers.active = {}
  for _, train in pairs(game.train_manager.get_trains{ state = defines.train_state.wait_station }) do
    registry.register_train_hoppers(train)
  end
end

local function schedule_reregister_on_next_tick()
  script.on_event(defines.events.on_tick, function()
    reregister_parked_trains()
    script.on_event(defines.events.on_tick, nil) -- unregister the handler
  end)
end

script.on_load(schedule_reregister_on_next_tick)

script.on_init(function()
  ensure_storage()
  rescan_all_hoppers()
  reregister_parked_trains()
end)

script.on_configuration_changed(function()
  ensure_storage()
  migrate_flat_to_nested()
  rescan_all_hoppers()
end)