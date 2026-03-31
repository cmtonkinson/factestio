return function(F)
  local Constants = require("lib.constants")
  -- Since this code isn't running within Factorio, we can use whatever libraries
  -- and OS calls we want
  local io = require("io")
  local json = require("lib.factestio_json")
  local os = require("os")

  F.start_time = 0
  F.end_time = 0
  F.had_failures = false

  -----------------------------------------------------------------------------
  function F.discover_test_files()
    assert(type(F.MOD_DIR) == "string" and F.MOD_DIR ~= "", "F.MOD_DIR must be set before loading tests")

    local test_dir = F.MOD_DIR .. "factestio"
    local find_cmd =
      string.format("find %s -maxdepth 1 -type f -name '*.lua' -print 2>/dev/null", F.shell_quote(test_dir))
    local proc = io.popen(find_cmd)
    if not proc then
      error("Error: could not scan " .. test_dir .. " for test files")
    end

    local paths = {}
    for line in proc:lines() do
      table.insert(paths, line)
    end
    proc:close()

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
    -- Clean up results from the last run.
    F.cmd('rm -rf "%s"', results_dir)
    F.cmd('mkdir -p "%s"', results_dir)
    -- Kick off the root scenarios.
    F.start_time = os.time()
    for _, root in ipairs(roots) do
      F.exec(root, 0)
    end
    F.end_time = os.time()
    F.report_results(roots)
  end

  -----------------------------------------------------------------------------
  local function move_if_exists(source_path, target_path)
    if not source_path or not F.cmd('test -e "%s"', source_path) then
      return false
    end
    F.cmd('mv "%s" "%s"', source_path, target_path)
    return true
  end

  -----------------------------------------------------------------------------
  function F.exec(node, depth)
    local d = depth or 0
    local indent = string.rep(" ", d * 2)
    -- Do the thing.
    F.start_factorio(node)
    if not node.data.timeout then
      -- Check the results of the test.
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
      -- Overwrite the Node data with anything in the results file.
      for k, v in pairs(parsed) do
        node.data[k] = v
      end
    end

    if node.data and node.data.status == "pass" then
      F.green(string.format("%s%s (%d assertions)", indent, node.name, node.data.stats.assertions))
    else
      F.had_failures = true
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

    -- Recursively call the children (already sorted at compile time).
    for _, child in ipairs(node.children) do
      F.exec(child, depth + 1)
    end
  end

  -----------------------------------------------------------------------------
  function F.start_factorio(node)
    -- Build the Factorio launch command.
    -- Root tests (no parent): start a fresh world from the scenario on disk.
    -- Child tests (has parent): restore the parent's saved world state from zip.
    local load_arg
    if not node.parent then
      -- Root test: write the test name to disk so control.lua can require() it,
      -- then load the scenario fresh (on_init fires, brand-new world).
      local ok = F.cmd('echo return \'"%s"\' > "%s"', node.data.name, F.TEST_NAME_FILE)
      if not ok then
        error("Failed to write test name file: " .. F.TEST_NAME_FILE)
      end
      load_arg = "--start-server-load-scenario factestio/factestio"
    else
      -- Child test: take the parent's save zip and inject this test's name into
      -- it via Python zip surgery, then load it directly (on_load fires, full
      -- world state — entities, map, storage — is restored from the zip).
      local parent_zip = F.save_name(node.parent)
      local child_zip = F.FACTORIO_DATA_PATH .. "saves/" .. Constants.FACTESTIO.CHILD_LOAD_BASENAME .. ".zip"
      local cp_ok = F.cmd('cp "%s" "%s"', parent_zip, child_zip)
      if not cp_ok then
        error("Failed to copy parent save: " .. parent_zip)
      end
      -- Overwrite test_name.lua inside the zip so control.lua require()s the
      -- right name when Factorio loads the save.
      local zip_ok = F.cmd(
        "python3 -c '"
          .. "import zipfile, sys, os; "
          .. 'src = sys.argv[1]; tmp = src + ".tmp"; name = sys.argv[2]; '
          .. 'zin = zipfile.ZipFile(src, "r"); zout = zipfile.ZipFile(tmp, "w"); '
          .. '[zout.writestr(i, ("return \\"" + name + "\\"\\n")'
          .. ' if i.filename.endswith("/test_name.lua") else zin.read(i.filename)) for i in zin.infolist()]; '
          .. "zin.close(); zout.close(); os.replace(tmp, src)"
          .. '\' "%s" "%s"',
        child_zip,
        node.data.name
      )
      if not zip_ok then
        error("Failed to inject test name into child zip: " .. child_zip)
      end
      load_arg = string.format('--start-server "%s"', Constants.FACTESTIO.CHILD_LOAD_BASENAME)
    end

    -- Start the headless server in the background. Redirect output to log files.
    F.cmd('> "%s"', F.TEST_STDOUT)
    F.cmd('> "%s"', F.TEST_STDERR)
    local factorio_cmd =
      string.format('%s %s --server-settings "%s" --disable-audio --nogamepad', F.FACTORIO_BINARY, load_arg, F.SETTINGS)
    F.cmd(
      'sh -c \'%s > "%s" 2>&1 & PID=$!; echo $PID > "%s"; echo $PID > "%s"\'',
      factorio_cmd,
      F.TEST_STDOUT,
      F.PID_FILE,
      F.ROOT .. Constants.FACTESTIO.TMP_PID_FILE
    )

    -- Busywait for the scenario's DONE_FILE signal, with a timeout guard.
    local done = false
    local timeout = os.time() + F.TEST_TIMEOUT
    while not done and os.time() <= timeout do
      local f = io.open(F.DONE_FILE, "r")
      if f then
        done = true
        f:close()
      else
        os.execute("sleep " .. tostring(Constants.RUNTIME.POLL_INTERVAL_SECONDS))
      end
    end

    if not done then
      node.data.timeout = true
      node.data.status = "fail"
      node.data.error = "scenario timeout after " .. F.TEST_TIMEOUT .. " seconds"
    end

    if node.data.stats.failed == 0 and node.data.status ~= "fail" then
      node.data.status = "pass"
    end

    -- Kill the Factorio process using the saved PID file.
    local pid_f = io.open(F.PID_FILE, "r")
    if pid_f then
      local pid = pid_f:read("*a"):gsub("%s+", "")
      pid_f:close()
      if pid ~= "" then
        F.cmd("kill -9 %s 2>/dev/null", pid)
      end
      os.remove(F.PID_FILE)
      os.remove(F.ROOT .. Constants.FACTESTIO.TMP_PID_FILE)
    end

    -- Move artifacts into the per-test results subdirectory.
    local fqn = F.fully_qualified_name(node)
    local results_dir = F.RESULTS_ROOT .. "/" .. fqn .. "/"
    local save = F.FACTORIO_DATA_PATH .. "saves/factestio-" .. F.safe_save_name(node.data.name) .. ".zip"
    F.cmd('mkdir -p "%s"', results_dir)
    move_if_exists(save, results_dir .. "factestio-" .. F.safe_save_name(node.data.name) .. ".zip")
    move_if_exists(F.TEST_STDOUT, results_dir .. "stdout.txt")
    move_if_exists(F.TEST_STDERR, results_dir .. "stderr.txt")

    local results_target = results_dir .. "results.json"
    local results_source = F.SCRIPT_OUTPUT .. F.results_file(node)
    if move_if_exists(results_source, results_target) then
      node.results_file = results_target
    end

    -- Clean up transient files.
    F.cmd('rm -f "%s"', F.TEST_NAME_FILE)
    F.cmd('rm -f "%s"', F.DONE_FILE)
    F.cmd('rm -f "%s"', F.FACTORIO_DATA_PATH .. "saves/" .. Constants.FACTESTIO.CHILD_LOAD_BASENAME .. ".zip")

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
