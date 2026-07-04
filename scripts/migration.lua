local registry = require("scripts.hopper-registry")

local function ensure_storage()
  storage.hoppers           = storage.hoppers           or {}
  storage.hoppers.active    = storage.hoppers.active    or {}
  storage.hoppers.by_unit   = storage.hoppers.by_unit   or {}
end

-- Move data from the flat layout (0.1.1 and earlier) into the nested layout.
-- Safe to call more than once; a no-op if the old fields are absent.
local function migrate_flat_to_nested()
  if storage.loaders then
    storage.loaders = nil
  end
  if storage.active_transfers then
    storage.active_transfers = nil
  end
  if storage.hoppers.loaders then
    storage.hoppers.loaders = nil
  end
  if storage.hoppers.unloaders then
    storage.hoppers.unloaders = nil
  end
end

local function rescan_all_hoppers()
  storage.hoppers.by_unit = {}
  for _, surface in pairs(game.surfaces) do
    for _, hopper in ipairs(surface.find_entities_filtered { name = registry.LOADER_NAMES }) do
      storage.hoppers.by_unit[hopper.unit_number] = { entity = hopper, kind = "loader" }
    end
    for _, hopper in ipairs(surface.find_entities_filtered { name = registry.UNLOADER_NAMES }) do
        storage.hoppers.by_unit[hopper.unit_number] = { entity = hopper, kind = "unloader" }
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