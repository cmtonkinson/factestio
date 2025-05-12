local LOG_FILE = 'factestio.log'
local DONE_FILE = 'factestio.done'
local TICK_EXIT = 60

script.on_init(function(event)
  helpers.write_file(LOG_FILE, "init\n", true)
  game.tick_paused = false
end)

script.on_event(defines.events.on_tick, function(event)
  helpers.write_file(LOG_FILE, "tick " .. event.tick .. "\n", true)
  if event.tick == TICK_EXIT then
    helpers.write_file(DONE_FILE, '1')
    return
  end
end)

