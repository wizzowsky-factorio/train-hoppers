-- Unnloading Hopper prototype.
-- ContainerPrototype straddling a ground rail with a 4x6 footprint.
-- Center 2x6 sits over the rail; 1x6 side strips are inserter-accessible.
-- Collision mask must exclude the rail layer so it can be placed over rails.

local graphics = require("prototypes.graphics")

-- Shared setup for both container variants.
local function make_hopper_container(name, collision_box)
  local hopper_variant = table.deepcopy(data.raw["container"]["steel-chest"])
  hopper_variant.name = name
  hopper_variant.minable = { mining_time = 0.5, result = "train-hopper-unloader" }
  hopper_variant.max_health = 500
  hopper_variant.inventory_size = 40
  hopper_variant.collision_box = collision_box
  hopper_variant.selection_box = collision_box
  hopper_variant.collision_mask = { layers = { player = true, is_object = true } }
  -- Below the default (50) so a cargo wagon parked over the center wins hover
  -- selection; the wider side strips still select the hopper (see graphics.lua).
  hopper_variant.selection_priority = 25
  hopper_variant.next_upgrade = nil
  hopper_variant.fast_replaceable_group = "train-hopper"
  -- Hide the H and V variants from the crafting menu; only the placer is user-facing.
  hopper_variant.flags = { "placeable-neutral", "player-creation", "not-in-kill-statistics" }
  hopper_variant.hidden = true  -- keeps them out of Factoriopedia
  hopper_variant.placeable_by = { item = "train-hopper-unloader", count = 1 }  -- enable Q selection
  hopper_variant.localised_name = { "entity-name.train-hopper-unloader" }
  return hopper_variant
end

local unloader_h = make_hopper_container(
  "train-hopper-unloader-h",
  {{-2.9, -1.9}, {2.9, 1.9}}   -- 6 wide, 4 tall
)
unloader_h.picture = graphics.build_chest_border_picture(graphics.h_positions, graphics.UNLOADER_TINT)

local unloader_v = make_hopper_container(
  "train-hopper-unloader-v",
  {{-1.9, -2.9}, {1.9, 2.9}}   -- 4 wide, 6 tall
)
unloader_v.picture = graphics.build_chest_border_picture(graphics.v_positions, graphics.UNLOADER_TINT)

-- The placer: a rotatable proxy the player actually picks up.
-- Assembling-machine gives us R-key rotation of the ghost preview.
local unloader_placer = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-1"])
unloader_placer.name = "train-hopper-unloader"  -- same name as the item; player-facing
unloader_placer.minable = { mining_time = 0.5, result = "train-hopper-unloader" }
unloader_placer.max_health = 500
unloader_placer.next_upgrade = nil
unloader_placer.fast_replaceable_group = "train-hopper"
unloader_placer.crafting_categories = { "train-hopper-transfer" }
unloader_placer.crafting_speed = 1
unloader_placer.energy_source = { type = "void" }
unloader_placer.energy_usage = "1W"
unloader_placer.module_slots = 0
unloader_placer.allowed_effects = {}
unloader_placer.fluid_boxes = nil
-- Start with the H orientation collision so the placer looks like the H variant.
unloader_placer.collision_box = {{-2.9, -1.9}, {2.9, 1.9}}
unloader_placer.selection_box = {{-2.9, -1.9}, {2.9, 1.9}}
unloader_placer.collision_mask = { layers = { player = true, is_object = true } }
unloader_placer.graphics_set = { animation = graphics.build_directional_border_animation(graphics.UNLOADER_TINT) }

data:extend({ unloader_h, unloader_v, unloader_placer })