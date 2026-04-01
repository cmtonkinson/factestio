local Constants = require("test_constants")

local f = nil
local this_test = nil
local TEST_NAME_MODULE = "__factestio__.scenarios.factestio.test_name"
local TEST_SEED_MODULE = "__factestio__.scenarios.factestio.test_seed"

-- Setup (but only if we're actually running in scenario mode)
if _G.script ~= nil then
  f = require("src.lib")
  this_test = require(TEST_NAME_MODULE)
  math.randomseed(require(TEST_SEED_MODULE))

  f.load()
  f.compile()
  f.sandbox_init()
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
  -- test_name.lua is loaded from the installed factestio mod on disk so each
  -- fresh Factorio process sees the current target test, even when loading a
  -- child save from a prior scenario.
  if storage.factestio_test_name ~= this_test then
    storage.factestio_test_name = this_test
    storage.factestio_base_tick = event.tick
    storage.factestio_ran = false
  end

  local base = storage.factestio_base_tick or 0
  local offset = event.tick - base

  -- Run the test
  if offset == Constants.SCHEDULER.RUN_TICK_OFFSET and not storage.factestio_ran then
    storage.factestio_ran = true
    f:invoke(f.registry[this_test], helpers, game, player, event)

  -- Save
  elseif offset == Constants.SCHEDULER.SAVE_TICK_OFFSET then
    game.server_save("factestio-" .. f.safe_save_name(this_test))

  -- Exit
  elseif offset == Constants.SCHEDULER.EXIT_TICK_OFFSET then
    game.tick_paused = true
    helpers.write_file(f.DONE_FILE, "1")
  end

  return nil
end)
