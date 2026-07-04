-- Train Hoppers - a Factorio mod
-- Copyright (C) 2026 Wizzowsky
-- SPDX-License-Identifier: GPL-3.0-or-later
-- This program is free software under the GNU GPL v3 or later; see the LICENSE
-- file at the mod root for the full terms. There is NO WARRANTY.

-- Prototype stage entry point. Enable requires below as each module is implemented.
-- See spec.md section "Technical implementation" for what belongs in each file.

data:extend({{ type = "recipe-category", name = "train-hopper-transfer" }})

require("prototypes.entity-loader")
require("prototypes.entity-unloader")
require("prototypes.item")
require("prototypes.recipe")
-- require("prototypes.technology")
