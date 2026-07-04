-- Train Hoppers - a Factorio mod
-- Copyright (C) 2026 Wizzowsky
-- SPDX-License-Identifier: GPL-3.0-or-later
-- This program is free software under the GNU GPL v3 or later; see the LICENSE
-- file at the mod root for the full terms. There is NO WARRANTY.

-- Runtime stage entry point. Enable requires below as each module is implemented.
-- See spec.md section "Runtime (control.lua) structure" for the event wiring plan.

require("scripts.placement")
require("scripts.transfer")
-- require("scripts.animation")
require("scripts.migration")