local function ensure_storage()
  storage.loaders = storage.loaders or {}
end

local function rescan_all_hoppers()
  storage.loaders = {}
  for _, surface in pairs(game.surfaces) do
    local found = surface.find_entities_filtered{
      name = { "train-hopper-loader-h", "train-hopper-loader-v" }
    }
    for _, hopper in ipairs(found) do
      storage.loaders[hopper.unit_number] = { entity = hopper }
    end
  end
end

script.on_init(ensure_storage)
script.on_configuration_changed(function()
  ensure_storage()
  rescan_all_hoppers()
end)