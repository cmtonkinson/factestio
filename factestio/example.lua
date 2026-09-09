-- Example scenarios, scaffolded here by `factestio activate`.
--
-- They exist so your first `factestio` run proves the setup works end to end.
-- Once you have real scenarios, replace the bodies below with your own logic or
-- delete this file outright -- nothing depends on it.
--
-- Every *.lua file in this directory except config.lua is discovered
-- automatically, so there is nothing to register when you add a scenario.

return {
  setup = {
    test = function(f, context)
      local game = context.game
      local surface = game.surfaces[1]

      -- Factorio snaps an entity with an odd tile footprint to a tile center, so
      -- a 3x3 assembling machine always settles on .5 coordinates. Asking for a
      -- .5 position keeps what you request and what you get identical -- ask for
      -- { 1, 1 } here and the machine ends up at { 1.5, 1.5 }.
      local machine = surface.create_entity({
        name = "assembling-machine-2",
        position = { x = 1.5, y = 1.5 },
      })

      surface.create_entity({
        name = "fast-inserter",
        position = { x = 6.5, y = 6.5 },
      })

      f:expect(machine.valid, true)
    end,
  },

  -- `from` makes this scenario inherit setup's finished world, restored from a
  -- save snapshot: the machine built above is still standing when this runs.
  secondary = {
    from = "setup",
    test = function(f, context)
      local game = context.game
      local surface = game.surfaces[1]

      local found = surface.find_entities({ { 0, 0 }, { 2, 2 } })
      f:expect(#found, 1)
      local first = found[1]
      f:expect(first.valid, true)
      f:expect(first.name, "assembling-machine-2")
      f:expect(first.position.x, 1.5)
      f:expect(first.position.y, 1.5)
    end,
  },
}
