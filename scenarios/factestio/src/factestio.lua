-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- This gets weird. Because of the way Factorio sandboxes, paths, and loads
-- scripts, we need to be able to run this logic both within the context of
-- the Factorio scenario and from the outside world. That means specifically
-- the path to the "node" library will change.
--
-- But the annoyance doesn't stop there - most of this logic is executed N+1
-- times per test suite invocation. We first have to analyze the tests that are
-- written to build the DAG and know which tests need to be run. But then we're
-- booting the game engine once per test, which needs to run all this logic
-- again each time, just to be able to execute one single test case.
--
-- "If it's stupid but it works, it ain't stupid."
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

-- Node will be in a differrent relative location depending on context.
local Node = nil
if _G.script ~= nil then
  Node = require("src.node")
else
  Node = require("scenarios.factestio.src.node")
end

-------------------------------------------------------------------------------
-- Module interface.
local F                = {}
-- These are initialized statically.
F.registry             = {}
F.DEBUG                = true
F.TEST_TIMEOUT         = 5
-- These will be set at runtime.
F.FACTORIO_BINARY      = ''
F.FACTORIO_DATA_PATH   = ''
F.PROJECT_PATH         = ''
F.DONE_FILE            = ''
F.ROOT                 = ''
F.SETTINGS             = ''
F.SAVES                = ''

-------------------------------------------------------------------------------
function F.init()
  F.DONE_FILE      = F.FACTORIO_DATA_PATH .. "/script-output/factestio.done"
  F.ROOT           = "/Users/chris/repo/factestio"
  F.SETTINGS       = F.ROOT .. "/server-settings.json"
  F.SAVES          = F.ROOT .. "/saves"
  F.TEST_NAME_FILE = F.ROOT .. "/scenarios/factestio/test_name.lua"
  F.BASE           = F.ROOT .. "/base.zip_"
end

-----------------------------------------------------------------------------
function F.set_factorio_binary(new_path)
  F.FACTORIO_BINARY = new_path
end

-----------------------------------------------------------------------------
function F.set_factorio_data_path(new_path)
  F.FACTORIO_DATA_PATH = new_path
end

-----------------------------------------------------------------------------
function F.set_project_path(new_path)
  F.PROJECT_PATH = new_path
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
function F.register_scenarios(table)
  print('registering scenarios...')
  for name, config in pairs(table) do
    if F.DEBUG then print("registering " .. name) end
    F.register_scenario(name, config)
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
  return "results/" .. F.fully_qualified_name(node) .. "/map.dat"
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
    nodes[name] = Node.new(name, details)
  end

  -- Second pass: Link parent/child relationsips.
  for name, details in pairs(F.registry) do
    local node = nodes[name]
    if details.from then
      local parent = nodes[details.from]
      assert(parent, "Parent scenario '" .. details.from .. "' not found for '" .. name .. "'")
      parent:add(node)
    else
      table.insert(roots, node)
    end
  end

  return roots
end

-----------------------------------------------------------------------------
function F.cmd(string, ...)
  local cmd = string.format(string, ...)
  if F.DEBUG then print("Executing command: \27[33m" .. cmd .. '\27[0m') end
  return os.execute(cmd)
end

-----------------------------------------------------------------------------
function F.cmd_capture(string, ...)
  local cmd = string.format(string, ...)
  if F.DEBUG then print("Capturing command: \27[33m" .. cmd .. '\27[0m') end
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
    F.exec(root)
  end
end

-----------------------------------------------------------------------------
function F.exec(node, depth)
  local d = depth or 0
  local indent = string.rep(" ", d * 2)
  print(indent .. "running scenario: " .. node.name)

  -- Overwrite the scenario map.daa
  F.cmd('cp "%s" "%s"', F.starting_save(node), 'scenarios/factestio/map.dat')

  F.start_factorio(node, d)
  for _, child in pairs(node.children) do
    F.exec(child, d + 1)
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
  print(indent .. "..starting factorio for scenario: " .. node.name)

  F.cmd('echo return \'"%s"\' > "%s"', node.name, F.TEST_NAME_FILE)

  -- Start the headless scenario in the background.
  local output = '>/dev/null 2>&1'
  if F.DEBUG then output = '' end
  F.cmd('%s --start-server-load-scenario factestio/factestio --server-settings "%s" --disable-audio --nogamepad %s &'
    , F.FACTORIO_BINARY
    , F.SETTINGS
    , output
  )

  -- The scenario will write to TEST_TIMEOUT when it's finished. Busywait
  -- for that. But also we need to be wary of a scenario that may hang, so
  -- we add a timeout component to the check as well.
  local done = false
  local timeout = os.time() + F.TEST_TIMEOUT
  while not done and os.time() < timeout do
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
  if os.time() > timeout then
    print(indent .. "Error: Timeout waiting for scenario to finish.")
  end

  -- Now that the scenario is done, we have to find the Factorio PID and
  -- kill the process manually.
  local grep = F.cmd_capture('ps aux | grep "start-server-load-scenario factestio/factestio" | grep -v grep')
  local pid = grep:match("(%d+)")
  if pid then
    F.cmd('kill -9 %s', pid)
  else
    print("Error: No PID found for Factorio process.")
  end

  -- Anything we want to save from the test run needs to get put into the appropriate results subdirectory.
  local fqn = F.fully_qualified_name(node)
  local results_dir = 'results/' .. fqn .. '/'
  local save = F.FACTORIO_DATA_PATH .. '/saves/factestio-' .. fqn .. '.zip'
  F.cmd('mkdir -p "%s"', results_dir)
  F.cmd('mv "%s" "%s"', save, results_dir .. node.name .. ".zip")

  -- Clean up transient files.
  F.cmd('rm "%s"', 'scenarios/factestio/map.dat')
  F.cmd('rm "%s"', F.TEST_NAME_FILE)
  F.cmd('rm "%s"', F.DONE_FILE)
end


return F
