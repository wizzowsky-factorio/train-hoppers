local M = {}

M.LOADER_TINT   = { r = 0.6, g = 0.9, b = 1.0, a = 1.0 }  -- soft blue
M.UNLOADER_TINT = { r = 1.0, g = 0.85, b = 0.6, a = 1.0 } -- soft amber

-- Grab steel-chest's sprite as our template. It's already a layered sprite
-- (chest body + drop shadow), so we'll copy both layers per position.
local chest_template = data.raw["container"]["steel-chest"].picture

-- Deep-copy chest_template's layers, then add (dx, dy) to each layer's shift.
local function chest_at(dx, dy, tint)
  local copied_layers = {}
  for _, layer in ipairs(chest_template.layers) do
    local shifted = table.deepcopy(layer)
    local existing_shift = shifted.shift or {0, 0}
    shifted.shift = { existing_shift[1] + dx, existing_shift[2] + dy }
    if tint then
      shifted.tint = tint
    end
    -- Draw beneath rolling stock so a parked wagon sits visually on top of the
    -- hopper (shadow layers keep their own layer regardless of this).
    shifted.render_layer = "lower-object"
    table.insert(copied_layers, shifted)
  end
  return copied_layers
end

-- Build a `{ layers = {...} }` picture from a list of tile-center positions.
function M.build_chest_border_picture(positions, tint)
  local all_layers = {}
  for _, position in ipairs(positions) do
    for _, layer in ipairs(chest_at(position[1], position[2], tint)) do
      table.insert(all_layers, layer)
    end
  end
  return { layers = all_layers }
end

-- Positions for H variant: top and bottom rows, 6 wide.
local h_positions = {}
for tile_x = -2.5, 2.5, 1 do
  table.insert(h_positions, { tile_x, -1.5 })  -- top strip
  table.insert(h_positions, { tile_x,  1.5 })  -- bottom strip
end
M.h_positions = h_positions

-- Positions for V variant: left and right columns, 6 tall.
local v_positions = {}
for tile_y = -2.5, 2.5, 1 do
  table.insert(v_positions, { -1.5, tile_y })  -- left strip
  table.insert(v_positions, {  1.5, tile_y })  -- right strip
end
M.v_positions = v_positions

-- Builds an Animation4Way (directional animation) where north/south use the
-- horizontal border and east/west use the vertical. Used for the placer entity
-- so its ghost preview reflects which real variant will spawn.
function M.build_directional_border_animation(tint)
  local horizontal = M.build_chest_border_picture(M.h_positions, tint)
  local vertical   = M.build_chest_border_picture(M.v_positions, tint)
  return {
    north = horizontal,
    south = horizontal,
    east  = vertical,
    west  = vertical,
  }
end

return M