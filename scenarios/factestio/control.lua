local LOG_FILE = 'factestio.log'
local DONE_FILE = 'factestio.done'

local f = require("src.factestio")
local this_test = settings.startup["factestio-test-name"].value

-- Initialize
script.on_init(function(event)
  helpers.write_file(LOG_FILE, "Initializing test " .. this_test .. "\n")
  game.tick_paused = false
end)

script.on_event(defines.events.on_tick, function(event)
  -- Load & run the test
  if event.tick == 1 then

  -- Save
  elseif event.tick == 20 then
    game.server_save('factestio-' .. this_test)

  -- Exit
  elseif event.tick == 30 then
    game.tick_paused = true
    helpers.write_file(DONE_FILE, '1')
  end

  return nil
end)
