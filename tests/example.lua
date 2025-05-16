return {
  setup = {
    test = function(f, context)
      local game = context.game
      local surface = game.surfaces[1]

      local assembler = surface.create_entity({
        name = "assembling-machine-2",
        position = {x = 1, y = 1},
      })

      local inserter = surface.create_entity({
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

      local assembler = surface.find_entity("assembling-machine-2", {x = 1, y = 1})
      local inserter = surface.find_entity("fast-inserter", {x = 6, y = 6})

      if assembler and inserter then
        game.print("Entities found successfully!")
      else
        game.print("Failed to find entities.")
      end

      f:expect(2, 2)
      f:expect(3, 3)
  end,
  },
}
