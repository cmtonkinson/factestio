local f = nil
local this_test = nil

-- Setup (but only if we're actually running in scenario mode)
if _G.script ~= nil then
  f = require("src.lib")
  this_test = require("test_name")

  f.load()
  f.compile()
end

-- Initialize (fresh scenario start)
script.on_init(function(event) -- luacheck: ignore 212
  game.tick_paused = false
  storage.factestio_test_name = nil
end)

-- Resume from save (child test loading parent's save)
script.on_load(function()
  -- on_load is read-only for storage; detection happens in on_tick
end)

script.on_event(defines.events.on_tick, function(event) -- luacheck: ignore 212
  -- Detect if this is a new test (child loading parent's save).
  -- When test_name.lua inside the save is updated via zip surgery,
  -- this_test won't match storage.factestio_test_name, triggering a reset.
  if storage.factestio_test_name ~= this_test then
    storage.factestio_test_name = this_test
    storage.factestio_base_tick = event.tick
    storage.factestio_ran = false
  end

  local base = storage.factestio_base_tick or 0
  local offset = event.tick - base

  -- Run the test
  if offset == 10 and not storage.factestio_ran then
    storage.factestio_ran = true
    f:invoke(f.registry[this_test], helpers, game, player, event)

  -- Save
  elseif offset == 20 then
    game.server_save("factestio-" .. this_test)

  -- Exit
  elseif offset == 30 then
    game.tick_paused = true
    helpers.write_file(f.DONE_FILE, "1")
  end

  return nil
end)
