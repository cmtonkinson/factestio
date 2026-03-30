return {
  setup = {
    test = function(f, context)
      local game = context.game
      local surface = game.surfaces[1]

      surface.create_entity({
        name = "assembling-machine-2",
        position = {x = 1, y = 1},
      })

      surface.create_entity({
        name = "fast-inserter",
        position = {x = 6, y = 6},
      })

      f:expect(1, 1)
    end,
  },

  secondary = {
    from = 'setup',
    test = function(f, context)
      local game = context.game
      local surface = game.surfaces[1]

      local found = surface.find_entities({{0, 0}, {2, 2}})
      f:expect(#found, 1)
      local first = found[1]
      f:expect(first.valid, true)
      f:expect(first.name, "assembling-machine-2")
      f:expect(first.position.x, 1)
      f:expect(first.position.y, 1)
    end,
  },
}
