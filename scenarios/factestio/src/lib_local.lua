return function(F)

-- Since this code isn't running within Factorio, we can use whatever libraries
-- and OS calls we want
local io      = require('io')
local json    = require('cjson')
local serpent = require('serpent')

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
  d = depth or 0
  local indent = string.rep(" ", d * 2)

  -- Overwrite the scenario map.dat
  F.cmd('cp "%s" "%s"', F.starting_save(node), 'scenarios/factestio/map.dat')

  -- Do the thing.
  F.start_factorio(node, depth)

  if node.data.timeout then
    -- no-op
  else
    -- Check the results of the test.
    local file = io.open(node.results_file, "r")
    if not file then error("Error: Could not open results file " .. node.results_file) end
    local content = file:read("*a")
    if not content then error("Error: Could not read results file " .. node.results_file) end
    file:close()
    local parsed = json.decode(content)
    -- Overwrite the Node data with anything in the results file.
    for k, v in pairs(parsed) do
      node.data[k] = v
    end
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

  -- GTFO
  return
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
end
