local Json = require("lib.factestio_json")
local ModList = require("lib.mod_list")
local System = require("lib.system")

local function read_json(path)
  local content = assert(System.read_file(path))
  return Json.decode(content, path)
end

local function temp_data_path()
  local base = string.format("/tmp/factestio-mod-list-%d-%d/", os.time(), math.random(100000, 999999))
  assert(os.execute("mkdir -p " .. System.shell_quote(base .. "mods")))
  return base
end

describe("ModList", function()
  before_each(function()
    math.randomseed(os.time())
  end)

  it("activates an isolated session and restores the original baseline", function()
    local data_path = temp_data_path()
    local mod_list_path = data_path .. "mods/mod-list.json"
    assert(System.write_file(mod_list_path, [[
{
  "mods": [
    { "name": "base", "enabled": true },
    { "name": "a", "enabled": true },
    { "name": "b", "enabled": false }
  ]
}
]]))

    assert(ModList.begin_session(data_path, "a"))
    assert(ModList.activate(data_path, "a", false, true))
    assert(ModList.activate(data_path, "b", false, true))

    local active = read_json(mod_list_path)
    local active_mods = {}
    for _, mod in ipairs(active.mods) do
      active_mods[mod.name] = mod.enabled
    end
    assert.is_true(active_mods.base)
    assert.is_true(active_mods.factestio)
    assert.is_true(active_mods.b)
    assert.is_false(active_mods.a)

    assert(ModList.deactivate(data_path, "b", true))

    local restored = read_json(mod_list_path)
    local restored_mods = {}
    for _, mod in ipairs(restored.mods) do
      restored_mods[mod.name] = mod.enabled
    end
    assert.is_true(restored_mods.base)
    assert.is_true(restored_mods.a)
    assert.is_false(restored_mods.b)
    assert.is_nil(restored_mods.factestio)

    os.execute("rm -rf " .. System.shell_quote(data_path))
  end)

  it("keeps other mods enabled when requested", function()
    local data_path = temp_data_path()
    local mod_list_path = data_path .. "mods/mod-list.json"
    assert(System.write_file(mod_list_path, [[
{
  "mods": [
    { "name": "base", "enabled": true },
    { "name": "other", "enabled": true }
  ]
}
]]))

    assert(ModList.begin_session(data_path, "sut"))
    assert(ModList.activate(data_path, "sut", true, true))

    local active = read_json(mod_list_path)
    local mods = {}
    for _, mod in ipairs(active.mods) do
      mods[mod.name] = mod.enabled
    end
    assert.is_true(mods.base)
    assert.is_true(mods.other)
    assert.is_true(mods.factestio)
    assert.is_true(mods.sut)

    os.execute("rm -rf " .. System.shell_quote(data_path))
  end)

  it("replaces stale session metadata with a fresh baseline", function()
    local data_path = temp_data_path()
    local mod_list_path = data_path .. "mods/mod-list.json"
    local session_dir = data_path .. "mods/.factestio/session"
    assert(System.write_file(mod_list_path, [[
{
  "mods": [
    { "name": "base", "enabled": true },
    { "name": "fresh", "enabled": true }
  ]
}
]]))
    assert(os.execute("mkdir -p " .. System.shell_quote(session_dir)))
    assert(System.write_file(session_dir .. "/meta.json", [[
{ "active_mod_name": "stale", "had_mod_list": true }
]]))
    assert(System.write_file(session_dir .. "/mod-list.json", [[
{
  "mods": [
    { "name": "base", "enabled": true },
    { "name": "stale", "enabled": true }
  ]
}
]]))

    assert(ModList.begin_session(data_path, "fresh"))
    assert(ModList.activate(data_path, "fresh", false, true))
    assert(ModList.deactivate(data_path, "fresh", true))

    local restored = read_json(mod_list_path)
    local restored_mods = {}
    for _, mod in ipairs(restored.mods) do
      restored_mods[mod.name] = mod.enabled
    end
    assert.is_true(restored_mods.base)
    assert.is_true(restored_mods.fresh)
    assert.is_nil(restored_mods.stale)

    os.execute("rm -rf " .. System.shell_quote(data_path))
  end)
end)
