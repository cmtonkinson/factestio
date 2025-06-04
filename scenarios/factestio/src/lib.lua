-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- This gets weird. Because of the way Factorio sandboxes, paths, and loads
-- scripts, we need to be able to run this logic both within the context of
-- the Factorio scenario and from the outside world. That means specifically:
--   * the apparent path to the "node" library will change
--   * external libraries (io, cjson, etc.) can't be loaded inside Factorio
--
-- But the annoyance doesn't stop there - most of this logic is executed N+1
-- times per test suite invocation. We first have to analyze the tests that are
-- written to build the DAG and know which tests need to be run. But then we're
-- booting the game engine once per test, which needs to run all this logic
-- again each time, just to be able to execute one single test case and exit.
--
-- "If it's stupid but it works, it ain't stupid."
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

-- This is the primary module table.
local F = {}

-- _G.script is defined by Factorio when running a sanboxed scenario. That
-- means we can check it to determine whether this module is being run within
-- that context, or outside of it.
local script_prefix = ''
if _G.script == nil then
  -- When running outside of Factorio we have to add additional path prefixes.
  script_prefix = 'scenarios.factestio.'
end

-- We'll always need the Node module.
local Node = require(script_prefix .. 'src.node')

-- The actual Factesteio module is split up across multiple files. Some of them
-- always need to be loaded, so they must be defined (IN ORDER) here and then
-- required. Then, we load either the local file (if we're running in CLI
-- context) or the sandboxed file (if we're running inside Factorio).
--
-- Honestly, this just helps keep my brain screwed on straight during
-- development because I need to be very clear about whether a given function
-- is sanboxed always, sometimes, or never.
local subfiles = {
  'src.lib_config',
  'src.lib_helpers',
  'src.lib_shared',
}
for _, subfile in ipairs(subfiles) do
  require(script_prefix .. subfile)(F)
end

if _G.script == nil then
  require(script_prefix .. 'src.lib_local')(F)
else
  require(script_prefix .. 'src.lib_sandboxed')(F)
end

-----------------------------------------------------------------------------
function F.set_paths(cfg)
  assert(type(cfg) == "table", "Factestio.config: cfg must be a table")
  if cfg.binary then
    F.FACTORIO_BINARY = cfg.binary
  end
  if cfg.data then
    F.FACTORIO_DATA_PATH = cfg.data .. '/'
  end
  F.init()
end

-----------------------------------------------------------------------------
function F.register_scenario(name, config)
  assert(type(name) == "string", "name must be a string")
  assert(name:match("^[%w_-]+$"), "name must only contain letters, numbers, underscores, and dashes")

  assert(type(config) == "table", "config must be a table")
  assert(type(config.test) == "function", "config.test must be a function")

  if config.before then
    assert(type(config.before) == "function", "config.before must be a function")
  end
  if config.after then
    assert(type(config.after) == "function", "config.after must be a function")
  end
  if config.from then
    assert(type(config.from) == "string", "config.from must be a string")
  end

  F.registry[name] = config
end
F.test = F.register_scenario -- alias

-----------------------------------------------------------------------------
function F.load()
  local configuration = require('test.config')
  F.set_paths(configuration.os_paths)
  for _, name in ipairs(configuration.test_files) do
    local scenarios_tbl = require('test.' .. name)
    for name, config in pairs(scenarios_tbl) do
      F.register_scenario(name, config)
    end
  end
end

-----------------------------------------------------------------------------
function F.fully_qualified_name(node)
  local fqn = node.name
  if node.parent then
    fqn = F.fully_qualified_name(node.parent) .. "." .. fqn
  end
  return fqn
end

-----------------------------------------------------------------------------
function F.save_name(node)
  return 'results/' .. F.fully_qualified_name(node) .. '/factestio-' .. node.name .. '.zip'
end

-----------------------------------------------------------------------------
function F.starting_save(node)
  if (node.parent) then
    return F.save_name(node.parent)
  else
    return 'map.dat'
  end
end

-----------------------------------------------------------------------------
function F.compile()
  local nodes = {}
  local roots = {}

  -- First pass: Generate nodes for all scenarios.
  for name, details in pairs(F.registry) do
    details.name = name
    details.stats = {}
    details.stats.assertions = 0
    details.stats.passed = 0
    details.stats.failed = 0
    nodes[name] = Node.new(name, details)
  end

  -- Second pass: Link parent/child relationsips.
  for name, details in pairs(F.registry) do
    local node = nodes[name]
    if details.from then
      local parent = nodes[details.from]
      assert(parent, "Parent scenario '" .. details.from .. "' not found for '" .. name .. "'")
      node.root = false
      parent:add(node)
    else
      node.root = true
      table.insert(roots, node)
    end
  end

  return roots
end


-----------------------------------------------------------------------------
function F.get_current_test_name()
  local f = io.open(F.TEST_NAME_FILE, "r")
  if f then
    local name = f:read("*a")
    f:close()
    return name
  else
    return nil
  end
end


-----------------------------------------------------------------------------
function F.invoke(self, node, helpers, game, player, event)
  -- We bundle a bunch of stuff into a single table so that it's easy to pass
  -- parameters down, and get metadata back up (via node.data)
  self.context = {
    game   = game,
    player = player,
    event  = event,
    node   = node,
  }

  -- Stub out the node.data table if it doesn't exist.
  node.data = node.data or {}
  node.data.stats = node.data.stats or {
    assertions = 0,
    passed = 0,
    failed = 0,
  }

  -- We lump the before/test/after functions together in an isolated function
  -- so that we can pcall THAT. This lets us fail the whole thing immediately
  -- if anything raises an error.
  -- And yes, passing both `self` and `node` is redundant - sue me.
  local ok, err = pcall(F.execute_test, self, node)
  if ok then
    node.data.status = 'pass'
  else
    node.data.status = 'fail'
    node.data.error = err
  end

  -- Store the results where the outer script can find them.
  local json = helpers.table_to_json({
    stats  = node.data.stats,
    error  = node.data.error,
    status = node.data.status,
  })
  helpers.write_file(F.results_file(node), json)
end

-----------------------------------------------------------------------------
function F.results_file(node)
  return 'factestio-' .. node.name .. '-results.json'
end

-----------------------------------------------------------------------------
function F.execute_test(self, node)
  if node.before then node.before(self, self.context) end
  node.test(self, self.context)
  if node.after then node.after(self, self.context) end
end

-----------------------------------------------------------------------------
function F.expect(self, actual, expected)
  local context = self.context
  local node = context.node
  local stats = node.stats
  local result = actual == expected

  stats.assertions = stats.assertions + 1

  if result then
    stats.passed = stats.passed + 1
    return true
  else
    stats.failed = stats.failed + 1
    context.status = 'fail'
    local output = string.format("Expected '%s' but got '%s'", expected, actual)
    F.red(output)
    error(output)
  end
end


return F
