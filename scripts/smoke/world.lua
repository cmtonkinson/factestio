-- Asserts the starting world factestio promises every root scenario.
-- scripts/smoke.sh copies this file and options.lua into the smoke mod.
local RADIUS = require("factestio.options").map_radius

return {
  starting_world = {
    test = function(f, context)
      local surface = context.game.surfaces[1]

      local chunks = 0
      for chunk in surface.get_chunks() do
        if surface.is_chunk_generated(chunk) then
          chunks = chunks + 1
        end
      end
      f:expect(chunks, (2 * RADIUS + 1) ^ 2)

      f:expect(surface.count_tiles_filtered({ name = "grass-1" }), surface.count_tiles_filtered({}))
      f:expect(surface.count_entities_filtered({}), 0)
      f:expect(#surface.find_decoratives_filtered({}), 0)

      -- A player's build check passes only on generated land, so these 3x3
      -- machines probe the outermost tiles of the promised area.
      local near, far = -RADIUS * 32 + 1.5, (RADIUS + 1) * 32 - 1.5
      for _, position in pairs({ { 0.5, 0.5 }, { near, near }, { far, near }, { near, far }, { far, far } }) do
        local placeable = surface.can_place_entity({
          name = "assembling-machine-2",
          position = position,
          force = "player",
          build_check_type = defines.build_check_type.manual_ghost,
        })
        f:expect(placeable, true)
      end
    end,
  },
}
