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

-- This is the module export variable.
local F = {}

-- We have to declare these ahead of time due to the conditional loading logic.
local Node    = nil
local io      = nil
local json    = nil
local serpent = nil

if _G.script ~= nil then -- when running as scenario
  Node = require('src.node')
else -- when runnning standalone from cli
  Node    = require('scenarios.factestio.src.node')
  io      = require('io')
  json    = require('cjson')
  serpent = require('serpent')
end

-------------------------------------------------------------------------------
-- These are initialized statically.
F.registry             = {}
F.DEBUG                = false
F.TEST_TIMEOUT         = 8
-- These will be set at runtime.
F.FACTORIO_BINARY      = ''
F.FACTORIO_DATA_PATH   = ''
F.DONE_FILE            = ''
F.ROOT                 = ''
F.SETTINGS             = ''
F.SAVES                = ''

-------------------------------------------------------------------------------
function F.init()
  F.ROOT           = './' -- TODO: Does this always work? Probably not.
  F.SCRIPT_OUTPUT  = F.FACTORIO_DATA_PATH .. 'script-output/'
  F.SETTINGS       = F.ROOT .. 'server-settings.json'
  F.SAVES          = F.ROOT .. 'saves'
  F.TEST_NAME_FILE = F.ROOT .. 'scenarios/factestio/test_name.lua'
  F.DONE_FILE      = F.SCRIPT_OUTPUT .. 'factestio.done'
  F.TEST_STDOUT    = F.SCRIPT_OUTPUT .. 'factestio.stdout'
  F.TEST_STDERR    = F.SCRIPT_OUTPUT .. 'factestio.stderr'
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
function F.cmd(string, ...)
  local cmd = string.format(string, ...)
  if F.DEBUG then F.yellow(cmd) end
  return os.execute(cmd)
end

-----------------------------------------------------------------------------
function F.cmd_capture(string, ...)
  local cmd = string.format(string, ...)
  if F.DEBUG then F.yellow(cmd) end
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  handle:close()
  return result
end

-----------------------------------------------------------------------------
function F.run(roots)
  local results_dir = 'results'
  -- Clean up results from the last run.
  F.cmd('rm -rf "%s"', results_dir)
  F.cmd('mkdir -p "%s"', results_dir)
  -- Kick off the root scenarios.
  for _, root in pairs(roots) do
    F.exec(root, 0)
  end
  F.report_results(roots)
end

-----------------------------------------------------------------------------
function F.exec(node, depth)
  depth = depth or 0
  local indent = string.rep(" ", depth * 2)

  -- Overwrite the scenario map.dat
  F.cmd('cp "%s" "%s"', F.starting_save(node), 'scenarios/factestio/map.dat')

  -- Do the thing.
  F.start_factorio(node, depth)
  F.yellow(indent .. serpent.block(node, {comment = false, nocode = true}))

  if node.data.timeout then
    -- no-op
  else
    -- Check the results of the test.
    local file = io.open(node.results_file, "r")
    if not file then error("Error: Could not open results file " .. node.results_file) end
    local content = file:read("*a")
    if not content then error("Error: Could not read results file " .. node.results_file) end
    file:close()
    node.data.results = json.decode(content)
    node.data.stats = node.data.stats or {}
  end

  if node.data and node.data.status == "pass" then
    F.green(string.format("%s%s (%d assertions)", indent, node.name, node.data.stats.assertions))
  else
    F.red(string.format("%s%s (failed: %s)", indent, node.name, node.data.error))
  end

  -- Return if the test didn't pass. We assume children are invalid if the
  -- parent falied.
  if node.data.status ~= "pass" then
    if #node.children > 0 then
      F.red(indent .. "Skipping children of '" .. node.name .. "' due to failure.")
    end
    return
  end

  -- Recursively call the children.
  for _, child in pairs(node.children) do
    F.exec(child, depth + 1)
  end
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
function F.start_factorio(node, depth)
  local d = depth or 0
  local indent = string.rep(" ", d * 2)

  -- The way we pass the test name into the scenario is by writing it to a
  -- Lua file which just returns the string.
  F.cmd('echo return \'"%s"\' > "%s"', node.name, F.TEST_NAME_FILE)

  -- Start the headless scenario in the background. Lot of BS going on here
  -- to redirect output to the right places and set the correct paths.
  local redirect = ''
  F.cmd('> "%s"', F.TEST_STDOUT)
  F.cmd('> "%s"', F.TEST_STDERR)
  if F.DEBUG then
    -- Send stdout and stderr both to the CLI and to log files.
    redirect = string.format('> >(tee "%s") 2> >(tee "%s" >&2)', F.TEST_STDOUT, F.TEST_STDERR)
  else
    -- Send stdout and stderr to log files only.
    redirect = string.format('>"%s" 2>"%s"', F.TEST_STDOUT, F.TEST_STDERR)
  end
  -- Do the thing.
  F.cmd('/bin/bash -c \'%s --start-server-load-scenario factestio/factestio --server-settings "%s" --disable-audio --nogamepad %s &\''
    , F.FACTORIO_BINARY
    , F.SETTINGS
    , redirect
  )

  -- The scenario will write to DONE_FILE when it's finished. Busywait
  -- for that. But also we need to be wary of a scenario that may hang, so
  -- we add a timeout component to the check as well.
  local done = false
  local timeout = os.time() + F.TEST_TIMEOUT
  while not done and os.time() <= timeout do
    local f = io.open(F.DONE_FILE, "r")
    if f then
      done = true
      f:close()
    else
      os.execute("sleep 0.1")
    end
  end

  -- This could theoretically fire a false positive, but the probability is small
  -- and I don't care that much.
  node.data = node.data or {}
  if os.time() > timeout then
    node.data.timeout = true
    node.data.status = 'fail'
    node.data.error = 'scenario timeout after ' .. F.TEST_TIMEOUT .. ' seconds'
  end

  if node.data.stats.failed == 0 and node.data.status ~= 'fail' then
    node.data.status = 'pass'
  end

  -- Now that the scenario is done, we have to find the Factorio PID and
  -- kill the process manually.
  local grep = F.cmd_capture('ps aux | grep "start-server-load-scenario factestio/factestio" | grep -v grep')
  local pid = grep:match("(%d+)")
  if pid then
    F.cmd('kill -9 %s', pid)
  else
    F.red("Error: No PID found for Factorio process.")
  end

  -- Anything we want to save from the test run needs to get put into the appropriate results subdirectory.
  local fqn = F.fully_qualified_name(node)
  local results_dir = 'results/' .. fqn .. '/'
  local save = F.FACTORIO_DATA_PATH .. 'saves/factestio-' .. node.name .. '.zip'
  F.cmd('mkdir -p "%s"', results_dir)
  F.cmd('mv "%s" "%s"', save, results_dir .. 'factestio-' .. node.name .. ".zip")
  F.cmd('mv "%s" "%s"', F.TEST_STDOUT, results_dir .. 'stdout.txt')
  F.cmd('mv "%s" "%s"', F.TEST_STDERR, results_dir .. 'stderr.txt')
  node.results_file = results_dir .. 'results.json'
  F.cmd('mv "%s" "%s"', F.SCRIPT_OUTPUT .. F.results_file(node), node.results_file)

  -- Clean up transient files.
  F.cmd('rm -f "%s"', 'scenarios/factestio/map.dat')
  F.cmd('rm "%s"', F.TEST_NAME_FILE)
  F.cmd('rm -f "%s"', F.DONE_FILE)

  -- Ensure we export the proper structure so we don't have to check
  -- elsewhere.
  node.data = node.data or {}
  node.data.results = node.data.results or {}
  node.data.stats = node.data.stats or {}

  -- GTFO
  return
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

-----------------------------------------------------------------------------
function F.yellow(string, ...)
  if F.DEBUG then
    print("\27[0;33m" .. string .. "\27[0m", ...)
  end
end

-----------------------------------------------------------------------------
function F.red(string, ...)
  print("\27[1;31m" .. string .. "\27[0m", ...)
end

-----------------------------------------------------------------------------
function F.green(string, ...)
  print("\27[1;32m" .. string .. "\27[0m", ...)
end

-----------------------------------------------------------------------------
function F.report_results(roots)
  local results = {
    assertions = 0,
    passed = 0,
    failed = 0,
  }

  for _, root in pairs(roots) do
    local root_results = F.collect_stats(root)
    results = F.add_stats(results, root_results)
  end

  print(string.format("\n\n\tTotal Assertions: %d\n\tPassed: %d\n\tFailed: %d", results.assertions, results.passed, results.failed))
end

-----------------------------------------------------------------------------
function F.collect_stats(node)
  local stats = {
    assertions = node.stats and node.stats.assertions or 0,
    passed = node.stats and node.stats.passed or 0,
    failed = node.stats and node.stats.failed or 0,
  }

  for _, child in pairs(node.children) do
    local child_stats = F.collect_stats(child)
    stats = F.add_stats(stats, child_stats)
  end

  return stats
end

-----------------------------------------------------------------------------
function F.add_stats(a, b)
  return {
    assertions = (a.assertions or 0) + (b.assertions or 0),
    passed = (a.passed or 0) + (b.passed or 0),
    failed = (a.failed or 0) + (b.failed or 0),
  }
end


return F
