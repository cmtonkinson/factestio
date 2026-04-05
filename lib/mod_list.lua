local Constants = require("lib.constants")
local Json = require("lib.factestio_json")
local Shell = require("lib.shell")
local System = require("lib.system")

local ModList = {}

local function mod_list_path(data_path)
  return data_path
    .. Constants.FACTESTIO.FACTORIO_MODS_DIR_NAME
    .. "/"
    .. Constants.FACTESTIO.FACTORIO_MOD_LIST_FILE_NAME
end

local function session_dir(data_path)
  return data_path .. Constants.FACTESTIO.FACTORIO_MODS_DIR_NAME .. "/" .. Constants.FACTESTIO.SESSION_DIR .. "/"
end

local function session_snapshot_path(data_path)
  return session_dir(data_path) .. Constants.FACTESTIO.SESSION_SNAPSHOT_FILE
end

local function session_meta_path(data_path)
  return session_dir(data_path) .. Constants.FACTESTIO.SESSION_META_FILE
end

local function ensure_session_dir(data_path)
  return Shell.mkdir_p(session_dir(data_path))
end

local function session_meta(data_path)
  local path = session_meta_path(data_path)
  local content = System.read_file(path)
  if not content then
    return nil
  end

  local ok, decoded = pcall(Json.decode, content, path)
  if not ok or type(decoded) ~= "table" then
    return nil
  end

  return decoded
end

local function write_session_meta(data_path, active_mod_name, had_mod_list)
  if not ensure_session_dir(data_path) then
    return nil, "Error: could not create factestio session directory\n"
  end

  if
    not Shell.write_output(session_meta_path(data_path), "jq", {
      "-n",
      "--arg",
      "active_mod_name",
      active_mod_name,
      "--argjson",
      "had_mod_list",
      had_mod_list and "true" or "false",
      "{active_mod_name:$active_mod_name,had_mod_list:$had_mod_list}",
    })
  then
    return nil, "Error: could not write factestio session metadata\n"
  end

  return true
end

local function mod_enabled_named(data_path, mod_name)
  local _, path = ModList.read(data_path)
  if not path or not System.exists(path) then
    return false
  end

  return Shell.succeeds("jq", {
    "-e",
    "--arg",
    "mod_name",
    mod_name,
    ".mods[]? | select(.name == $mod_name and .enabled == true)",
    path,
  }, {
    stdout_path = "/dev/null",
    stderr_to_devnull = true,
  })
end

local function apply_filter(path, filter, args)
  local tmp_path = path .. ".tmp"
  local jq_args = {}
  for _, arg in ipairs(args or {}) do
    jq_args[#jq_args + 1] = arg
  end
  jq_args[#jq_args + 1] = filter
  jq_args[#jq_args + 1] = path

  if not Shell.write_output(tmp_path, "jq", jq_args) then
    return false
  end

  return Shell.mv(tmp_path, path)
end

local function set_mod_enabled(data_path, mod_name, enabled)
  local mod_list_exists, path = ModList.read(data_path)
  if not mod_list_exists then
    return true
  end

  local enabled_literal = enabled and "true" or "false"
  local filter = string.format(
    [[
(.mods //= [])
| if any(.mods[]?; .name == $mod_name)
  then .mods |= map(if .name == $mod_name then .enabled = %s else . end)
  else .mods += [{"name": $mod_name, "enabled": %s}] end
]],
    enabled_literal,
    enabled_literal
  )
  if not apply_filter(path, filter, {
    "--arg",
    "mod_name",
    mod_name,
  }) then
    return nil, "Error: could not update mod-list.json at " .. path .. "\n"
  end

  return true
end

function ModList.read(data_path)
  local path = mod_list_path(data_path)
  if not System.exists(path) then
    return nil, path
  end
  return true, path
end

function ModList.begin_session(data_path, active_mod_name)
  local meta = session_meta(data_path)
  if meta then
    local snapshot_exists = System.exists(session_snapshot_path(data_path))
    local active_session = mod_enabled_named(data_path, "factestio")
      and meta.active_mod_name
      and mod_enabled_named(data_path, meta.active_mod_name)
      and (meta.had_mod_list ~= true or snapshot_exists)

    if active_session then
      return write_session_meta(data_path, active_mod_name, meta.had_mod_list == true)
    end

    Shell.rm_rf(session_dir(data_path))
  end

  local mod_list_exists, path = ModList.read(data_path)
  local had_mod_list = mod_list_exists == true

  if had_mod_list then
    if not ensure_session_dir(data_path) then
      return nil, "Error: could not create factestio session directory\n"
    end
    if not Shell.cp(path, session_snapshot_path(data_path)) then
      return nil, "Error: could not snapshot mod-list.json at " .. path .. "\n"
    end
  end

  return write_session_meta(data_path, active_mod_name, had_mod_list)
end

function ModList.activate(data_path, sut_name, keep_other_mods, quiet)
  local _, path = ModList.read(data_path)
  path = path or mod_list_path(data_path)

  if not System.exists(path) then
    local created = System.write_file(path, '{ "mods": [] }\n')
    if not created then
      return nil, "Error: could not create mod-list.json at " .. path .. "\n"
    end
  end

  local filter
  if keep_other_mods then
    filter = [[
(.mods //= [])
| def enable_mod($name):
    if any(.mods[]?; .name == $name)
    then .mods |= map(if .name == $name then .enabled = true else . end)
    else .mods += [{"name": $name, "enabled": true}] end;
  enable_mod("factestio")
| enable_mod($sut_name)
]]
  else
    filter = [[
(.mods //= [])
| def enable_mod($name):
    if any(.mods[]?; .name == $name)
    then .mods |= map(if .name == $name then .enabled = true else . end)
    else .mods += [{"name": $name, "enabled": true}] end;
  .mods |= map(
    if (.name == "base" or .name == "factestio" or .name == $sut_name)
    then .enabled = true
    else .enabled = false
    end
  )
| enable_mod("base")
| enable_mod("factestio")
| enable_mod($sut_name)
]]
  end

  if not apply_filter(path, filter, {
    "--arg",
    "sut_name",
    sut_name,
  }) then
    return nil, "Error: could not update mod-list.json at " .. path .. "\n"
  end

  if not quiet then
    if keep_other_mods then
      print("Enabled factestio and " .. sut_name .. " in mod-list.json")
    else
      print("Isolated factestio + " .. sut_name .. " in mod-list.json")
    end
  end

  return true
end

function ModList.deactivate(data_path, sut_name, quiet)
  local meta = session_meta(data_path)
  local path = mod_list_path(data_path)

  if meta then
    if meta.had_mod_list and System.exists(session_snapshot_path(data_path)) then
      if not Shell.cp(session_snapshot_path(data_path), path) then
        return nil, "Error: could not restore mod-list.json at " .. path .. "\n"
      end
    elseif not meta.had_mod_list and System.exists(path) then
      Shell.rm_f(path)
    end

    Shell.rm_rf(session_dir(data_path))
    if not quiet then
      print("Restored original mod-list.json state")
    end
    return true
  end

  local ok, err = set_mod_enabled(data_path, "factestio", false)
  if not ok then
    return nil, err
  end

  ok, err = set_mod_enabled(data_path, sut_name, false)
  if not ok then
    return nil, err
  end

  if not quiet then
    print("Disabled factestio and " .. sut_name .. " in mod-list.json")
  end

  return true
end

function ModList.enabled(data_path)
  return mod_enabled_named(data_path, "factestio")
end

return ModList
