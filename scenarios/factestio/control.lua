local f         = nil
local this_test = nil

-- Setup (but only if we're actually running in scenario mode)
if _G.script ~= nil then
  f = require('src.lib')
  this_test = require('test_name')

  f.load()
  f.compile()
end

-- Initialize
script.on_init(function(event)
  game.tick_paused = false
end)

script.on_event(defines.events.on_tick, function(event)
  -- Load & run the test
  if event.tick == 10 then
    f:invoke(f.registry[this_test], helpers, game, player, event)

  -- Save
  elseif event.tick == 20 then
    game.server_save('factestio-' .. this_test)

  -- Exit
  elseif event.tick == 30 then
    game.tick_paused = true
    helpers.write_file(f.DONE_FILE, '1')
  end

  return nil
end)
