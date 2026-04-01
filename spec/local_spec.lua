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
  local original_config
  local original_test_files
  local original_test_context
  local original_test_constants
  local original_alpha
  local original_beta
  local original_gamma
  local original_require

  before_each(function()
    original_io_popen = io.popen
    original_io_open = io.open
    original_script = rawget(_G, "script")
    original_config = package.loaded["factestio.config"]
    original_test_files = package.loaded["test_files"]
    original_test_context = package.loaded["test_context"]
    original_test_constants = package.loaded["test_constants"]
    original_alpha = package.loaded["factestio.alpha"]
    original_beta = package.loaded["factestio.beta"]
    original_gamma = package.loaded["factestio.gamma"]
    original_require = _G.require
  end)

  after_each(function()
    io.popen = original_io_popen -- luacheck: ignore
    io.open = original_io_open -- luacheck: ignore
    _G.script = original_script
    _G.require = original_require
    package.loaded["factestio.config"] = original_config
    package.loaded["test_files"] = original_test_files
    package.loaded["test_context"] = original_test_context
    package.loaded["test_constants"] = original_test_constants
    package.loaded["factestio.alpha"] = original_alpha
    package.loaded["factestio.beta"] = original_beta
    package.loaded["factestio.gamma"] = original_gamma
  end)

  it("discovers test files from the mod factestio directory", function()
    local F = new_local_F()
    F.MOD_DIR = "/tmp/mod/"

    local seen_cmd
    io.popen = function(cmd) -- luacheck: ignore
      seen_cmd = cmd
      local lines = {
        "/tmp/mod/factestio/zeta.lua",
        "/tmp/mod/factestio/config.lua",
        "/tmp/mod/factestio/alpha.lua",
      }
      local i = 0
      return {
        lines = function()
          return function()
            i = i + 1
            return lines[i]
          end
        end,
        close = function() end,
      }
    end

    assert.same({ "alpha", "zeta" }, F.discover_test_files())
    assert.equal("find '/tmp/mod/factestio' -maxdepth 1 -type f -name '*.lua' -print 2>/dev/null", seen_cmd)
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

    F.load()

    assert.same({ "alpha", "beta" }, manifest_written)
    assert.equal("tmp-mod", context_written)
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
    F.RESULTS_ROOT = "factestio/results"
    F.ROOT = "/tmp/factestio/"
    F.TEST_TIMEOUT = 1

    local commands = {}
    F.cmd = function(fmt, ...)
      local cmd = string.format(fmt, ...)
      table.insert(commands, cmd)
      return true
    end
    F.save_name = function()
      return "factestio/results/parent/factestio-parent.zip"
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
      return 0
    end
    os.execute = function() -- luacheck: ignore
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

    assert.is_truthy(commands[1]:match([[^cp "]]) or commands[1]:match("^cp '"))
    assert.is_truthy(commands[2]:find('/tmp/test_name.lua', 1, true))
    assert.is_truthy(commands[2]:find('child', 1, true))
    assert.is_truthy(table.concat(commands, "\n"):find("sh %-c '", 1, false))
    assert.is_nil(table.concat(commands, "\n"):match("zipfile"))
  end)
end)
