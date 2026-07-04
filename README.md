# Train Hoppers

Two new buildings for Factorio 2.0+ that straddle a ground-level straight rail segment and rapidly load or unload cargo wagons when a train stops nearby.

## Concept

Inserter-based train loading and unloading works, but it is slow at scale. Train Hoppers replaces the "many inserters, many chests" pattern with a single large building on each side of the transfer. When a train arrives at a station, the hopper instantly moves items between its own inventory and the parked wagon.

- **Loading Hopper (4x6):** Inserters feed items into the side strips. When a wagon parks over the center 2x6 rail area, the hopper dumps items into the wagon.
- **Unloading Hopper (4x6):** When a wagon parks over the center 2x6 rail area, the hopper pulls items down into itself. Ground-level inserters remove items from the side strips. Visually presented as a pit under the rail with animated elevators bringing items back to platform height.

Both buildings work as large storage containers, accept inserter access on both long sides, and support circuit network connections.

## Status

Early development. See `spec.md` for the full design specification, milestones, and open questions.

## Compatibility

- **Factorio version:** 2.1+
- **Required:** `base >= 2.1`
- **Space Age:** not required. Elevated rails and quality wagons are handled correctly if present but not required.

## License

Copyright (C) 2026 Wizzowsky.

This mod's source code is licensed under the **GNU General Public License v3.0 or
later** (GPL-3.0-or-later). You are free to use, study, share, and modify it, but
any distributed derivative work must also be licensed under the GPL and keep its
source available. See the [`LICENSE`](LICENSE) file for the full text.

The mod's placeholder graphics are composited at runtime from Factorio's vanilla
sprites (e.g. the steel chest). Those base-game assets remain the property of
Wube Software and are **not** covered by this license.
