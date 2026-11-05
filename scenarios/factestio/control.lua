local Constants = require("test_constants")

local f = nil
local this_test = nil
local map_radius = nil
local TEST_NAME_MODULE = "__factestio__.scenarios.factestio.test_name"
local TEST_SEED_MODULE = "__factestio__.scenarios.factestio.test_seed"

if _G.script ~= nil then
  f = require("src.lib")
  this_test = require(TEST_NAME_MODULE)
  map_radius = require("test_context").map_radius
  math.randomseed(require(TEST_SEED_MODULE))

  f.load()
  f.compile()
  f.sandbox_init()
end

script.on_init(function(event) -- luacheck: ignore 212
  game.tick_paused = false
  storage.factestio_test_name = nil
end)

-- A child test loads its parent's save here. storage is read-only in on_load,
-- so new-test detection happens in on_tick.
script.on_load(function() end)

-- Nothing but grass-1 may autoplace, so a root's world holds no water, cliffs,
-- resources, enemies, trees, rocks, or decoratives, whatever mods are loaded.
local function clear_to_grass(surface)
  surface.map_gen_settings = {
    autoplace_settings = {
      tile = { treat_missing_as_default = false, settings = { ["grass-1"] = {} } },
      entity = { treat_missing_as_default = false },
      decorative = { treat_missing_as_default = false },
    },
    -- Constant terrain inputs: evaluating grass-1's noise triples generation time.
    property_expression_names = { moisture = "1", aux = "0.5" },
  }
  surface.clear()
end

script.on_event(defines.events.on_tick, function(event) -- luacheck: ignore 212
  -- clear() only takes effect after the tick that called it.
  if storage.factestio_needs_land then
    storage.factestio_needs_land = nil
    game.surfaces[1].request_to_generate_chunks({ 0, 0 }, map_radius)
    game.surfaces[1].force_generate_chunk_requests()
  end

  -- A child's save carries its parent's test name. test_name.lua is read from
  -- the installed mod on disk, so each process sees its own target test.
  if storage.factestio_test_name ~= this_test then
    -- Only a root's fresh world carries no test name; a child keeps its parent's land.
    if storage.factestio_test_name == nil then
      clear_to_grass(game.surfaces[1])
      storage.factestio_needs_land = true
    end
    storage.factestio_test_name = this_test
    storage.factestio_base_tick = event.tick
    storage.factestio_ran = false
  end

  local base = storage.factestio_base_tick or 0
  local offset = event.tick - base

  if offset == Constants.SCHEDULER.RUN_TICK_OFFSET and not storage.factestio_ran then
    storage.factestio_ran = true
    f:invoke(f.registry[this_test], helpers, game, player, event)
  elseif offset == Constants.SCHEDULER.SAVE_TICK_OFFSET then
    game.server_save("factestio-" .. f.safe_save_name(this_test))
  elseif offset == Constants.SCHEDULER.EXIT_TICK_OFFSET then
    game.tick_paused = true
    helpers.write_file(f.DONE_FILE, "1")
  end

  return nil
end)
