local loader_item = table.deepcopy(data.raw["item"]["steel-chest"])

loader_item.name = "train-hopper-loader"
loader_item.place_result = "train-hopper-loader"
loader_item.stack_size = 20
loader_item.order = "z[train-hopper]-a[loader]"

-- Replace the single icon with a layered version that applies our tint.
-- `icons` takes precedence over `icon` if both are set, but we clear icon for cleanliness.
local graphics = require("prototypes.graphics")
loader_item.icon = nil
loader_item.icons = {
  {
    icon = data.raw["item"]["steel-chest"].icon,
    icon_size = data.raw["item"]["steel-chest"].icon_size or 64,
    tint = graphics.LOADER_TINT,
  }
}

data:extend({ loader_item })