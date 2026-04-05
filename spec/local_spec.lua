local function new_local_F()
  local F = {}
  require("scenarios.factestio.src.lib_config")(F)
  require("scenarios.factestio.src.lib_helpers")(F)
  F.LOAD_PATH_PREFIX = "scenarios.factestio."
  require("scenarios.factestio.src.lib_shared")(F)
  require("scenarios.factestio.src.lib_local")(F)
  return F
end

describe("local loader", function()
  local original_io_popen
  local original_io_open
  local original_script
  local original_shell_module
  local original_config
  local original_test_files
  local original_test_context
  local original_test_constants
  local original_test_seed
  local original_alpha
  local original_beta
  local original_gamma
  local original_require

  before_each(function()
    original_io_popen = io.popen
    original_io_open = io.open
    original_script = rawget(_G, "script")
    original_shell_module = package.loaded["lib.shell"]
    original_config = package.loaded["factestio.config"]
    original_test_files = package.loaded["test_files"]
    original_test_context = package.loaded["test_context"]
    original_test_constants = package.loaded["test_constants"]
    original_test_seed = package.loaded["test_seed"]
    original_alpha = package.loaded["factestio.alpha"]
    original_beta = package.loaded["factestio.beta"]
    original_gamma = package.loaded["factestio.gamma"]
    original_require = _G.require
  end)

  after_each(function()
    io.popen = original_io_popen -- luacheck: ignore
    io.open = original_io_open -- luacheck: ignore
    _G.script = original_script
    package.loaded["lib.shell"] = original_shell_module
    _G.require = original_require
    package.loaded["factestio.config"] = original_config
    package.loaded["test_files"] = original_test_files
    package.loaded["test_context"] = original_test_context
    package.loaded["test_constants"] = original_test_constants
    package.loaded["test_seed"] = original_test_seed
    package.loaded["factestio.alpha"] = original_alpha
    package.loaded["factestio.beta"] = original_beta
    package.loaded["factestio.gamma"] = original_gamma
  end)

  it("discovers test files from the mod factestio directory", function()
    package.loaded["lib.shell"] = {
      find_files = function(path, pattern)
        assert.equal("/tmp/mod/factestio", path)
        assert.equal("*.lua", pattern)
        return {
          "/tmp/mod/factestio/zeta.lua",
          "/tmp/mod/factestio/config.lua",
          "/tmp/mod/factestio/alpha.lua",
        }
      end,
    }
    local F = new_local_F()
    F.MOD_DIR = "/tmp/mod/"

    assert.same({ "alpha", "zeta" }, F.discover_test_files())
  end)

  it("writes the discovered file manifest as a Lua module", function()
    local F = new_local_F()
    F.TEST_FILES_MANIFEST = "/tmp/test_files.lua"

    local writes = {}
    io.open = function(path, mode) -- luacheck: ignore
      assert.equal("/tmp/test_files.lua", path)
      assert.equal("w", mode)
      return {
        write = function(_, chunk)
          table.insert(writes, chunk)
        end,
        close = function() end,
      }
    end

    F.write_test_manifest({ "alpha", "beta" })

    assert.equal('return {\n  "alpha",\n  "beta",\n}\n', table.concat(writes))
  end)

  it("writes the test context manifest with the mod name", function()
    local F = new_local_F()
    F.TEST_CONTEXT_MANIFEST = "/tmp/test_context.lua"

    local writes = {}
    io.open = function(path, mode) -- luacheck: ignore
      assert.equal("/tmp/test_context.lua", path)
      assert.equal("w", mode)
      return {
        write = function(_, chunk)
          table.insert(writes, chunk)
        end,
        close = function() end,
      }
    end

    F.write_test_context("demo-mod")

    assert.equal('return {\n  mod_name = "demo-mod",\n}\n', table.concat(writes))
  end)

  it("writes the test constants manifest as a Lua module", function()
    local F = new_local_F()
    F.TEST_CONSTANTS_MANIFEST = "/tmp/test_constants.lua"

    local writes = {}
    io.open = function(path, mode) -- luacheck: ignore
      assert.equal("/tmp/test_constants.lua", path)
      assert.equal("w", mode)
      return {
        write = function(_, chunk)
          table.insert(writes, chunk)
        end,
        close = function() end,
      }
    end

    F.write_test_constants({
      FACTESTIO = { DONE_FILE_NAME = "factestio.done" },
      SCHEDULER = { RUN_TICK_OFFSET = 10 },
      RUNTIME = { DEFAULT_TEST_TIMEOUT = 8 },
    })

    local output = table.concat(writes)
    assert.matches('DONE_FILE_NAME = "factestio%.done"', output)
    assert.matches("RUN_TICK_OFFSET = 10", output)
    assert.matches("DEFAULT_TEST_TIMEOUT = 8", output)
  end)

  it("writes the test seed manifest as a Lua module", function()
    local F = new_local_F()
    F.TEST_SEED_FILE = "/tmp/test_seed.lua"

    local writes = {}
    io.open = function(path, mode) -- luacheck: ignore
      assert.equal("/tmp/test_seed.lua", path)
      assert.equal("w", mode)
      return {
        write = function(_, chunk)
          table.insert(writes, chunk)
        end,
        close = function() end,
      }
    end

    F.write_test_seed(12345)

    assert.equal("return 12345\n", table.concat(writes))
  end)

  it("loads discovered files and writes the manifest outside Factorio", function()
    local F = new_local_F()
    _G.script = nil
    F.MOD_DIR = "/tmp/mod/"
    F.TEST_CONTEXT_MANIFEST = "/tmp/test_context.lua"

    package.loaded["factestio.config"] = {
      os_paths = {
        binary = "/bin/factorio",
        data = "/tmp/factorio-data",
      },
    }
    package.loaded["factestio.alpha"] = {
      setup = { test = function() end },
    }
    package.loaded["factestio.beta"] = {
      child = { from = "setup", test = function() end },
    }

    io.open = function(path, mode) -- luacheck: ignore
      if path == "/tmp/mod/info.json" then
        assert.equal("r", mode)
        return {
          read = function()
            return [[{"name":"tmp-mod"}]]
          end,
          close = function() end,
        }
      end
      return original_io_open(path, mode)
    end

    local manifest_written
    local context_written
    local constants_written
    local seed_written
    F.discover_test_files = function()
      return { "alpha", "beta" }
    end
    F.write_test_manifest = function(file_names)
      manifest_written = file_names
    end
    F.write_test_context = function(mod_name)
      context_written = mod_name
    end
    F.write_test_constants = function(constants)
      constants_written = constants
    end
    F.write_test_seed = function(seed)
      seed_written = seed
    end
    F.SEED = 12345

    F.load()

    assert.same({ "alpha", "beta" }, manifest_written)
    assert.equal("tmp-mod", context_written)
    assert.equal(12345, seed_written)
    assert.equal("factestio.done", constants_written.FACTESTIO.DONE_FILE_NAME)
    assert.equal("/bin/factorio", F.FACTORIO_BINARY)
    assert.equal("/tmp/factorio-data/", F.FACTORIO_DATA_PATH)
    assert.is_truthy(F.registry["alpha.setup"])
    assert.is_truthy(F.registry["beta.child"])
    assert.equal("beta.setup", F.registry["beta.child"].from)
  end)

  it("loads file names from the manifest inside Factorio", function()
    local F = new_local_F()
    _G.script = {}

    package.loaded["factestio.config"] = {
      os_paths = {
        binary = "/bin/factorio",
        data = "/tmp/factorio-data",
      },
    }
    package.loaded["test_files"] = { "gamma" }
    package.loaded["test_context"] = { mod_name = "demo-mod" }
    package.loaded["test_constants"] = { FACTESTIO = { DONE_FILE_NAME = "factestio.done" } }
    package.loaded["test_seed"] = 12345
    package.loaded["factestio.gamma"] = {
      root = { test = function() end },
    }

    F.discover_test_files = function()
      error("host-side discovery should not run in the Factorio sandbox")
    end
    F.write_test_manifest = function()
      error("manifest writing should not run in the Factorio sandbox")
    end

    F.load()

    assert.is_truthy(F.registry["gamma.root"])
  end)

  it("maps bare src requires to the target mod while loading tests in Factorio", function()
    local F = new_local_F()
    _G.script = {}

    package.loaded["factestio.config"] = {
      os_paths = {
        binary = "/bin/factorio",
        data = "/tmp/factorio-data",
      },
    }
    package.loaded["test_files"] = { "gamma" }
    package.loaded["test_context"] = {
      mod_name = "demo-mod",
    }
    package.loaded["test_constants"] = { FACTESTIO = { DONE_FILE_NAME = "factestio.done" } }
    package.loaded["test_seed"] = 12345

    package.preload["__demo-mod__.src.helpers"] = function()
      return {
        marker = "target-mod-helper",
      }
    end

    package.preload["factestio.gamma"] = function()
      local helper = require("src.helpers")
      return {
        root = {
          test = function() end,
          helper_marker = helper.marker,
        },
      }
    end

    F.load()

    assert.is_truthy(F.registry["gamma.root"])
    assert.equal("target-mod-helper", F.registry["gamma.root"].helper_marker)

    package.preload["__demo-mod__.src.helpers"] = nil
    package.preload["factestio.gamma"] = nil
  end)
end)

describe("local runner", function()
  local original_io_open
  local original_time
  local original_execute

  before_each(function()
    original_io_open = io.open
    original_time = os.time
    original_execute = os.execute
  end)

  after_each(function()
    io.open = original_io_open -- luacheck: ignore
    os.time = original_time -- luacheck: ignore
    os.execute = original_execute -- luacheck: ignore
  end)

  it("launches child scenarios without child save rewrites", function()
    local shell_commands = {}
    local process_running = true
    local now = 0
    package.loaded["lib.shell"] = {
      quote = function(value)
        return "'" .. tostring(value) .. "'"
      end,
      rm_rf = function(path)
        table.insert(shell_commands, { op = "rm_rf", path = path })
        return true
      end,
      mkdir_p = function(path)
        table.insert(shell_commands, { op = "mkdir_p", path = path })
        return true
      end,
      test_exists = function(path)
        table.insert(shell_commands, { op = "test_exists", path = path })
        return true
      end,
      mv = function(source_path, target_path)
        table.insert(shell_commands, { op = "mv", source = source_path, target = target_path })
        return true
      end,
      is_pid_alive = function(pid)
        table.insert(shell_commands, { op = "is_pid_alive", pid = pid })
        if process_running then
          process_running = false
          return true
        end
        return false
      end,
      sleep = function(seconds)
        now = now + seconds
        table.insert(shell_commands, { op = "sleep", seconds = seconds })
        return true
      end,
      kill = function(pid, signal)
        table.insert(shell_commands, { op = "kill", pid = pid, signal = signal })
        return true
      end,
      cp = function(source_path, target_path)
        table.insert(shell_commands, { op = "cp", source = source_path, target = target_path })
        return true
      end,
      launch_background = function(argv, stdout_path, pid_path, root_pid_path)
        table.insert(shell_commands, {
          op = "launch_background",
          argv = argv,
          stdout_path = stdout_path,
          pid_path = pid_path,
          root_pid_path = root_pid_path,
        })
        return true
      end,
      rm_f = function(path)
        table.insert(shell_commands, { op = "rm_f", path = path })
        return true
      end,
      find_files = function()
        return {}
      end,
    }
    local F = new_local_F()
    F.FACTORIO_BINARY = "/bin/factorio"
    F.FACTORIO_DATA_PATH = "/tmp/factorio/"
    F.TEST_NAME_FILE = "/tmp/test_name.lua"
    F.TEST_STDOUT = "/tmp/stdout.log"
    F.TEST_STDERR = "/tmp/stderr.log"
    F.SETTINGS = "/tmp/server-settings.json"
    F.PID_FILE = "/tmp/factestio.pid"
    F.DONE_FILE = "/tmp/factestio.done"
    F.SCRIPT_OUTPUT = "/tmp/script-output/"
    F.RESULTS_ROOT = "factestio_results"
    F.ROOT = "/tmp/factestio/"
    F.TEST_TIMEOUT = 1

    F.save_name = function()
      return "factestio_results/parent/factestio-parent.zip"
    end

    local done_reads = 0
    io.open = function(path, mode) -- luacheck: ignore
      if path == F.DONE_FILE then
        done_reads = done_reads + 1
        if done_reads == 1 then
          return {
            close = function() end,
          }
        end
        return nil
      end
      if path == F.PID_FILE then
        return {
          read = function()
            return "123\n"
          end,
          close = function() end,
        }
      end
      return original_io_open(path, mode)
    end
    os.time = function() -- luacheck: ignore
      return now
    end
    os.execute = function(cmd) -- luacheck: ignore
      if cmd:match("^sleep ") then
        now = now + 1
      end
      return true
    end

    local parent = { data = { name = "parent" } }
    local child = {
      data = {
        name = "child",
        stats = { failed = 0 },
        status = "pending",
      },
      parent = parent,
    }

    F.start_factorio(child)

    assert.same({
      op = "cp",
      source = "factestio_results/parent/factestio-parent.zip",
      target = "/tmp/factorio/saves/factestio-child-load.zip",
    }, shell_commands[1])
    assert.same({
      op = "launch_background",
      argv = {
        "/bin/factorio",
        "--start-server",
        "factestio-child-load",
        "--server-settings",
        "/tmp/server-settings.json",
        "--disable-audio",
        "--nogamepad",
      },
      stdout_path = "/tmp/stdout.log",
      pid_path = "/tmp/factestio.pid",
      root_pid_path = "/tmp/factestio/tmp/factestio.pid",
    }, shell_commands[2])
  end)
end)
