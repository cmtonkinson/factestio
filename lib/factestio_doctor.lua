local Constants = require("lib.constants")

local Doctor = {}

local function trim(s)
  return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function read_command_output(cmd)
  local proc = io.popen(cmd .. " 2>/dev/null")
  if not proc then
    return nil
  end

  local output = trim(proc:read("*a"))
  local ok, _, code = proc:close()
  local succeeded = (type(ok) == "number" and ok == 0) or ok == true or code == 0

  if not succeeded or output == "" then
    return nil
  end

  return output
end

function Doctor.collect(opts)
  opts = opts or {}

  local getenv = opts.getenv or os.getenv
  local command_output = opts.command_output or read_command_output
  local require_fn = opts.require_fn or require
  local checks = {}

  local function add(ok, label, detail)
    checks[#checks + 1] = {
      ok = ok,
      label = label,
      detail = detail or "",
    }
  end

  local factestio_root = getenv("FACTESTIO_ROOT")
  add(factestio_root ~= nil and factestio_root ~= "", "FACTESTIO_ROOT set", factestio_root or "unset")

  local lua_path = command_output("command -v lua")
  add(lua_path ~= nil, "lua on PATH", lua_path or "not found")
  add(_VERSION == Constants.LUA.VERSION_STRING, "running under " .. Constants.LUA.VERSION_STRING, _VERSION)

  local luarocks_path = command_output("command -v luarocks")
  add(luarocks_path ~= nil, "luarocks on PATH", luarocks_path or "not found")
  if luarocks_path then
    local lua_version = command_output("luarocks config lua_version")
    add(
      lua_version == Constants.LUA.VERSION_MINOR,
      "LuaRocks targets Lua " .. Constants.LUA.VERSION_MINOR,
      lua_version or "unknown"
    )
  end

  local lua_path_env = getenv("LUA_PATH")
  add(lua_path_env ~= nil and lua_path_env ~= "", "LUA_PATH set", lua_path_env or "unset")

  for _, module_name in ipairs({ "argparse", "dkjson", "serpent" }) do
    local ok, loaded_or_err = pcall(require_fn, module_name)
    add(ok, string.format("require(%q)", module_name), ok and "ok" or tostring(loaded_or_err))
  end

  return checks
end

function Doctor.run(opts)
  opts = opts or {}

  local emit = opts.emit
    or function(line, ok)
      if ok then
        print(line)
      else
        io.stderr:write(line .. "\n")
      end
    end

  local failures = 0
  for _, check in ipairs(Doctor.collect(opts)) do
    local prefix = check.ok and "[ok]" or "[fail]"
    local line = string.format("%-6s %s", prefix, check.label)
    if check.detail ~= "" then
      line = line .. " :: " .. check.detail
    end

    emit(line, check.ok)
    if not check.ok then
      failures = failures + 1
    end
  end

  if failures == 0 then
    emit("Environment looks good for factestio.", true)
    return true
  end

  emit("Fix the failing checks above before running factestio.", false)
  return false
end

return Doctor
