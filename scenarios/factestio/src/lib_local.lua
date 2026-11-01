return function(F)
  local Constants = require("lib.constants")
  local FactorioLog = require("lib.factorio_log")
  local Shell = require("lib.shell")
  local System = require("lib.system")
  local io = require("io")
  local json = require("lib.factestio_json")
  local os = require("os")

  F.start_time = 0
  F.end_time = 0
  F.had_failures = false

  -----------------------------------------------------------------------------
  function F.interrupt_requested()
    local path = F.ROOT .. Constants.FACTESTIO.TMP_INTERRUPT_FILE
    local f = io.open(path, "r")
    if f then
      f:close()
      return true
    end
    return false
  end

  -----------------------------------------------------------------------------
  function F.discover_test_files()
    assert(type(F.MOD_DIR) == "string" and F.MOD_DIR ~= "", "F.MOD_DIR must be set before loading tests")

    local test_dir = F.MOD_DIR .. Constants.FACTESTIO.PROJECT_DIR_NAME
    local paths = Shell.find_files(test_dir, "*.lua")

    return F.discovered_test_files(paths)
  end

  -----------------------------------------------------------------------------
  function F.write_test_manifest(file_names)
    local f, err = io.open(F.TEST_FILES_MANIFEST, "w")
    if not f then
      error("Error: could not write test manifest " .. F.TEST_FILES_MANIFEST .. ": " .. (err or "unknown error"))
    end

    f:write("return {\n")
    for _, file_name in ipairs(file_names) do
      f:write(string.format("  %q,\n", file_name))
    end
    f:write("}\n")
    f:close()
  end

  -----------------------------------------------------------------------------
  function F.run(roots)
    local results_dir = F.RESULTS_ROOT
    Shell.rm_rf(results_dir)
    Shell.mkdir_p(results_dir)
    -- The PID and log files live here, and a fresh Factorio install has none yet.
    Shell.mkdir_p(F.SCRIPT_OUTPUT)
    os.remove(F.ROOT .. Constants.FACTESTIO.TMP_INTERRUPT_FILE)
    F.start_time = os.time()
    for _, root in ipairs(roots) do
      if F.interrupt_requested() then
        break
      end
      F.exec(root, 0)
    end
    F.end_time = os.time()
    F.report_results(roots)
  end

  -----------------------------------------------------------------------------
  local function move_if_exists(source_path, target_path)
    if not source_path or not Shell.test_exists(source_path) then
      return false
    end
    Shell.mv(source_path, target_path)
    return true
  end

  -----------------------------------------------------------------------------
  local function wait_for_pid_exit(pid, timeout_seconds)
    local deadline = os.time() + (timeout_seconds or 5)

    while os.time() <= deadline do
      if not Shell.is_pid_alive(pid) then
        return true
      end
      Shell.sleep(Constants.RUNTIME.POLL_INTERVAL_SECONDS)
    end

    return not Shell.is_pid_alive(pid)
  end

  -----------------------------------------------------------------------------
  local function stop_factorio_process(pid)
    if not pid or pid == "" then
      return
    end

    Shell.kill(pid, "TERM")
    if not wait_for_pid_exit(pid, 2) then
      Shell.kill(pid, "9")
      wait_for_pid_exit(pid, 5)
    end
  end

  -----------------------------------------------------------------------------
  local function read_text(path)
    local f = io.open(path, "r")
    if not f then
      return nil
    end
    local content = f:read("*a")
    f:close()
    return content
  end

  -----------------------------------------------------------------------------
  local function read_pid()
    local content = read_text(F.PID_FILE)
    local pid = content and content:gsub("%s+", "")
    if pid == "" then
      return nil
    end
    return pid
  end

  -----------------------------------------------------------------------------
  local function done_file_exists()
    local f = io.open(F.DONE_FILE, "r")
    if f then
      f:close()
      return true
    end
    return false
  end

  -----------------------------------------------------------------------------
  function F.exec(node, depth)
    local d = depth or 0
    local indent = string.rep(" ", d * 2)
    local started_at = os.time()
    F.start_factorio(node)
    if not node.data.timeout and not node.data.exited then
      if not node.results_file then
        error("Error: missing results file for " .. node.data.name)
      end
      local file = io.open(node.results_file, "r")
      if not file then
        error("Error: Could not open results file " .. node.results_file)
      end
      local content = file:read("*a")
      if not content then
        error("Error: Could not read results file " .. node.results_file)
      end
      file:close()
      local parsed = json.decode(content, node.results_file)
      for k, v in pairs(parsed) do
        node.data[k] = v
      end
    end

    if node.data and node.data.status == "pass" then
      local elapsed_seconds = os.time() - started_at
      F.green(
        string.format("%s%s (%d assertions in %ds)", indent, node.name, node.data.stats.assertions, elapsed_seconds)
      )
    else
      F.had_failures = true
      F.red(string.format("%s%s (failed: %s)", indent, node.name, node.data.error))
    end

    -- Children start from the parent's save, so a failed parent invalidates them.
    if node.data.status ~= "pass" then
      if #node.children > 0 then
        F.red(indent .. "Skipping children of '" .. node.name .. "' due to failure.")
      end
      return
    end

    for _, child in ipairs(node.children) do
      if F.interrupt_requested() then
        return
      end
      F.exec(child, depth + 1)
    end
  end

  -----------------------------------------------------------------------------
  function F.start_factorio(node)
    local launch_args = {
      F.FACTORIO_BINARY,
    }
    if not node.parent then
      -- control.lua requires the test name file; on_init fires on a fresh world.
      local ok = System.write_file(F.TEST_NAME_FILE, string.format("return %q\n", node.data.name))
      if not ok then
        error("Failed to write test name file: " .. F.TEST_NAME_FILE)
      end
      launch_args[#launch_args + 1] = "--start-server-load-scenario"
      launch_args[#launch_args + 1] = Constants.FACTESTIO.SCENARIO_LOAD_TARGET
    else
      -- on_load fires and the full world state, storage included, comes from the zip.
      local parent_zip = F.save_name(node.parent)
      local child_zip = F.FACTORIO_DATA_PATH .. "saves/" .. Constants.FACTESTIO.CHILD_LOAD_BASENAME .. ".zip"
      local cp_ok = Shell.cp(parent_zip, child_zip)
      if not cp_ok then
        error("Failed to copy parent save: " .. parent_zip)
      end
      local ok = System.write_file(F.TEST_NAME_FILE, string.format("return %q\n", node.data.name))
      if not ok then
        error("Failed to write test name file: " .. F.TEST_NAME_FILE)
      end
      launch_args[#launch_args + 1] = "--start-server"
      launch_args[#launch_args + 1] = Constants.FACTESTIO.CHILD_LOAD_BASENAME
    end

    System.write_file(F.TEST_STDOUT, "")
    System.write_file(F.TEST_STDERR, "")
    launch_args[#launch_args + 1] = "--server-settings"
    launch_args[#launch_args + 1] = F.SETTINGS
    for _, flag in ipairs(F.CLIENT_FLAGS or {}) do
      launch_args[#launch_args + 1] = flag
    end
    local launch_ok =
      Shell.launch_background(launch_args, F.TEST_STDOUT, F.PID_FILE, F.ROOT .. Constants.FACTESTIO.TMP_PID_FILE)
    if not launch_ok then
      error("Failed to launch Factorio process")
    end

    -- Busywait for the scenario's DONE_FILE signal, with a timeout guard. Stop
    -- early if Factorio exits first: after a load error it never writes DONE_FILE.
    local pid = read_pid()
    local done = false
    local exited = false
    local timeout = os.time() + F.TEST_TIMEOUT
    while not done and not exited and os.time() <= timeout do
      if done_file_exists() then
        done = true
      elseif pid and not Shell.is_pid_alive(pid) then
        exited = true
        done = done_file_exists() -- it may have finished just before exiting
      else
        Shell.sleep(Constants.RUNTIME.POLL_INTERVAL_SECONDS)
      end
    end

    if exited and not done then
      node.data.exited = true
      node.data.status = "fail"
      node.data.error = "Factorio exited before the test finished: "
        .. (FactorioLog.first_error(read_text(F.TEST_STDOUT)) or "no error found in its log (see stdout.txt)")
    elseif not done then
      node.data.timeout = true
      node.data.status = "fail"
      node.data.error = "scenario timeout after " .. F.TEST_TIMEOUT .. " seconds"
    end

    if node.data.stats.failed == 0 and node.data.status ~= "fail" then
      node.data.status = "pass"
    end

    if pid then
      stop_factorio_process(pid)
      os.remove(F.PID_FILE)
      os.remove(F.ROOT .. Constants.FACTESTIO.TMP_PID_FILE)
    end

    local fqn = F.fully_qualified_name(node)
    local results_dir = F.RESULTS_ROOT .. "/" .. fqn .. "/"
    local save = F.FACTORIO_DATA_PATH .. "saves/factestio-" .. F.safe_save_name(node.data.name) .. ".zip"
    Shell.mkdir_p(results_dir)
    move_if_exists(save, results_dir .. "factestio-" .. F.safe_save_name(node.data.name) .. ".zip")
    move_if_exists(F.TEST_STDOUT, results_dir .. "stdout.txt")
    move_if_exists(F.TEST_STDERR, results_dir .. "stderr.txt")

    local results_target = results_dir .. "results.json"
    local results_source = F.SCRIPT_OUTPUT .. F.results_file(node)
    if move_if_exists(results_source, results_target) then
      node.results_file = results_target
    end

    Shell.rm_f(F.TEST_NAME_FILE)
    Shell.rm_f(F.DONE_FILE)
    Shell.rm_f(F.FACTORIO_DATA_PATH .. "saves/" .. Constants.FACTESTIO.CHILD_LOAD_BASENAME .. ".zip")

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

    print(
      string.format(
        "\n\nPassed: %d\nFailed: %d\n\n%d total assertions took %d seconds.",
        results.passed,
        results.failed,
        results.assertions,
        (F.end_time - F.start_time)
      )
    )
  end

  -----------------------------------------------------------------------------
  function F.collect_stats(node)
    local stats = node.data.stats
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
