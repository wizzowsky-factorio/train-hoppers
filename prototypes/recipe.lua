local loader_recipe = {
  type = "recipe",
  name = "train-hopper-loader",
  enabled = true,
  energy_required = 2,
  ingredients = {
    { type = "item", name = "steel-plate",        amount = 20 },
    { type = "item", name = "iron-gear-wheel",    amount = 10 },
    { type = "item", name = "electronic-circuit", amount = 5 },
  },
  results = {
    { type = "item", name = "train-hopper-loader", amount = 1 },
  },
}

data:extend({ loader_recipe })

local unloader_recipe = {
  type = "recipe",
  name = "train-hopper-unloader",
  enabled = true,
  energy_required = 2,
  ingredients = {
    { type = "item", name = "steel-plate",        amount = 20 },
    { type = "item", name = "iron-gear-wheel",    amount = 10 },
    { type = "item", name = "electronic-circuit", amount = 5 },
  },
  results = {
    { type = "item", name = "train-hopper-unloader", amount = 1 },
  },
}

data:extend({ unloader_recipe })