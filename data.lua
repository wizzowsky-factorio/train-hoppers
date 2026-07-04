-- Prototype stage entry point. Enable requires below as each module is implemented.
-- See spec.md section "Technical implementation" for what belongs in each file.

data:extend({{ type = "recipe-category", name = "train-hopper-transfer" }})

require("prototypes.entity-loader")
require("prototypes.entity-unloader")
require("prototypes.item")
require("prototypes.recipe")
-- require("prototypes.technology")
