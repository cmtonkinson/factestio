local TICK_EXIT = 60

script.on_game_created_from_scenario(function(event)
  game.write_file('factestio.log', "init\n", true)
  game.tick_paused = false
end)

script.on_event(defines.events.on_tick, function(event)
  game.write_file('factestio.log', "tick " .. event.tick .. "\n", true)
  if event.tick == TICK_EXIT then
    game.quit_to_menu()
    return
  end
end)

