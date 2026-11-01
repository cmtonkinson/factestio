local Doctor = require("lib.factestio_doctor")

local function find_check(checks, label)
  for _, check in ipairs(checks) do
    if check.label == label then
      return check
    end
  end
  error("missing check: " .. label)
end

local function installed_factorio()
  return { binary = "/bin/factorio", binary_ok = true }
end

local function missing_factorio()
  return { binary = "/bin/factorio", binary_ok = false }
end

local function factestio_info(factorio_version)
  return function(path)
    assert.equal("/tmp/factestio/info.json", path)
    return string.format('{ "name": "factestio", "factorio_version": "%s" }', factorio_version)
  end
end

describe("Doctor.collect", function()
  it("reports a healthy Lua 5.2 runtime", function()
    local checks = Doctor.collect({
      getenv = function(name)
        local env = {
          FACTESTIO_ROOT = "/tmp/factestio",
          LUA_PATH = "/tmp/?.lua",
        }
        return env[name]
      end,
      command_output = function(cmd)
        local outputs = {
          lua = "/usr/bin/lua",
          luarocks = "/usr/bin/luarocks",
          ["luarocks config lua_version"] = "5.2",
        }
        return outputs[cmd]
      end,
      require_fn = function(module_name)
        return { name = module_name }
      end,
      detect = installed_factorio,
      factorio_version = function()
        return "2.1.24"
      end,
      read_file = factestio_info("2.1"),
    })

    assert.is_true(find_check(checks, "FACTESTIO_ROOT set").ok)
    assert.is_true(find_check(checks, "lua on PATH").ok)
    assert.is_true(find_check(checks, "running under Lua 5.2").ok)
    assert.is_true(find_check(checks, "luarocks on PATH").ok)
    assert.is_true(find_check(checks, "LuaRocks targets Lua 5.2").ok)
    assert.is_true(find_check(checks, "LUA_PATH set").ok)
    assert.is_true(find_check(checks, 'require("argparse")').ok)
    assert.is_true(find_check(checks, 'require("dkjson")').ok)
    assert.is_true(find_check(checks, 'require("serpent")').ok)
    assert.is_true(find_check(checks, "Factorio binary found").ok)
    assert.is_true(find_check(checks, "Factorio version matches factestio factorio_version 2.1").ok)
  end)

  it("flags a Factorio release factestio does not target yet", function()
    local checks = Doctor.collect({
      getenv = function(name)
        return name == "FACTESTIO_ROOT" and "/tmp/factestio" or nil
      end,
      command_output = function()
        return nil
      end,
      require_fn = function(module_name)
        return { name = module_name }
      end,
      detect = installed_factorio,
      factorio_version = function()
        return "2.2.0"
      end,
      read_file = factestio_info("2.1"),
    })

    local check = find_check(checks, "Factorio version matches factestio factorio_version 2.1")
    assert.is_false(check.ok)
    assert.equal("installed 2.2.0", check.detail)
  end)

  it("surfaces missing tooling and modules", function()
    local checks = Doctor.collect({
      getenv = function()
        return nil
      end,
      command_output = function()
        return nil
      end,
      require_fn = function(module_name)
        error("module missing: " .. module_name)
      end,
      detect = missing_factorio,
    })

    assert.is_false(find_check(checks, "FACTESTIO_ROOT set").ok)
    assert.is_false(find_check(checks, "Factorio binary found").ok)
    assert.is_false(find_check(checks, "lua on PATH").ok)
    assert.is_false(find_check(checks, "luarocks on PATH").ok)
    assert.is_false(find_check(checks, "LUA_PATH set").ok)
    assert.is_false(find_check(checks, 'require("dkjson")').ok)
  end)
end)

describe("Doctor.run", function()
  it("returns false when any check fails", function()
    local emitted = {}

    local ok = Doctor.run({
      getenv = function()
        return nil
      end,
      command_output = function()
        return nil
      end,
      require_fn = function(module_name)
        error("module missing: " .. module_name)
      end,
      detect = missing_factorio,
      emit = function(line, passed)
        table.insert(emitted, { line = line, passed = passed })
      end,
    })

    assert.is_false(ok)
    assert.is_truthy(emitted[#emitted])
    assert.is_false(emitted[#emitted].passed)
    assert.matches("Fix the failing checks above", emitted[#emitted].line)
  end)
end)
