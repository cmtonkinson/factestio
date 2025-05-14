local LOG_FILE  = nil
local DONE_FILE = nil
local f         = nil
local this_test = nil

-- Setup (but only if we're running as a proper scenario)
if _G.script ~= nil then
  LOG_FILE = 'factestio.log'
  DONE_FILE = 'factestio.done'
  f = require("src.factestio")
  this_test = require('test_name')

  t = require('tests/example')
  f.init()
  f.register_scenarios(t)
  f.compile()
end

-- Initialize
script.on_init(function(event)
  helpers.write_file(LOG_FILE, "------------------\n")
  helpers.write_file(LOG_FILE, "Initializing test " .. this_test .. "\n", true)
  game.tick_paused = false
end)


script.on_event(defines.events.on_tick, function(event)
  -- Load & run the test
  if event.tick == 10 then
    helpers.write_file(LOG_FILE, "Running test " .. this_test .. "\n", true)
    f.registry[this_test].test(game, player, event)

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
