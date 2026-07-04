-- Loading Hopper prototype.
-- ContainerPrototype straddling a ground rail with a 4x6 footprint.
-- Center 2x6 sits over the rail; 1x6 side strips are inserter-accessible.
-- Collision mask must exclude the rail layer so it can be placed over rails.

local graphics = require("prototypes.graphics")

-- Shared setup for both container variants.
local function make_hopper_container(name, collision_box)
  local hopper_variant = table.deepcopy(data.raw["container"]["steel-chest"])
  hopper_variant.name = name
  hopper_variant.minable = { mining_time = 0.5, result = "train-hopper-loader" }
  hopper_variant.max_health = 500
  hopper_variant.inventory_size = 100
  hopper_variant.collision_box = collision_box
  hopper_variant.selection_box = collision_box
  hopper_variant.collision_mask = { layers = { player = true, is_object = true } }
  hopper_variant.next_upgrade = nil
  hopper_variant.fast_replaceable_group = "train-hopper"
  -- Hide the H and V variants from the crafting menu; only the placer is user-facing.
  hopper_variant.flags = { "placeable-neutral", "player-creation", "not-in-kill-statistics" }
  hopper_variant.hidden = true  -- keeps them out of Factoriopedia
  hopper_variant.placeable_by = { item = "train-hopper-loader", count = 1 }  -- enable Q selection
  hopper_variant.localised_name = { "entity-name.train-hopper-loader" }
  return hopper_variant
end

local loader_h = make_hopper_container(
  "train-hopper-loader-h",
  {{-2.9, -1.9}, {2.9, 1.9}}   -- 6 wide, 4 tall
)
loader_h.picture = graphics.build_chest_border_picture(graphics.h_positions, graphics.LOADER_TINT)

local loader_v = make_hopper_container(
  "train-hopper-loader-v",
  {{-1.9, -2.9}, {1.9, 2.9}}   -- 4 wide, 6 tall
)
loader_v.picture = graphics.build_chest_border_picture(graphics.v_positions, graphics.LOADER_TINT)

-- The placer: a rotatable proxy the player actually picks up.
-- Assembling-machine gives us R-key rotation of the ghost preview.
local loader_placer = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-1"])
loader_placer.name = "train-hopper-loader"  -- same name as the item; player-facing
loader_placer.minable = { mining_time = 0.5, result = "train-hopper-loader" }
loader_placer.max_health = 500
loader_placer.next_upgrade = nil
loader_placer.fast_replaceable_group = "train-hopper"
loader_placer.crafting_categories = { "train-hopper-transfer" }
loader_placer.crafting_speed = 1
loader_placer.energy_source = { type = "void" }
loader_placer.energy_usage = "1W"
loader_placer.module_slots = 0
loader_placer.allowed_effects = {}
loader_placer.fluid_boxes = nil
-- Start with the H orientation collision so the placer looks like the H variant.
loader_placer.collision_box = {{-2.9, -1.9}, {2.9, 1.9}}
loader_placer.selection_box = {{-2.9, -1.9}, {2.9, 1.9}}
loader_placer.collision_mask = { layers = { player = true, is_object = true } }
loader_placer.graphics_set = { animation = graphics.build_directional_border_animation(graphics.LOADER_TINT) }

data:extend({ loader_h, loader_v, loader_placer })