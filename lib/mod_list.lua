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

  local meta = Json.encode({ active_mod_name = active_mod_name, had_mod_list = had_mod_list })
  if not System.write_file(session_meta_path(data_path), meta) then
    return nil, "Error: could not write factestio session metadata\n"
  end

  return true
end

local function read_mods(path)
  local content = System.read_file(path)
  if not content then
    return nil
  end
  local ok, decoded = pcall(Json.decode, content, path)
  if not ok or type(decoded) ~= "table" then
    return nil
  end
  decoded.mods = decoded.mods or {}
  return decoded
end

local function write_mods(path, decoded)
  local tmp_path = path .. ".tmp"
  if not System.write_file(tmp_path, Json.encode(decoded)) then
    return false
  end
  return Shell.mv(tmp_path, path)
end

local function set_enabled(decoded, mod_name, enabled)
  for _, mod in ipairs(decoded.mods) do
    if mod.name == mod_name then
      mod.enabled = enabled
      return
    end
  end
  decoded.mods[#decoded.mods + 1] = { name = mod_name, enabled = enabled }
end

local function mod_enabled_named(data_path, mod_name)
  local decoded = read_mods(mod_list_path(data_path))
  for _, mod in ipairs(decoded and decoded.mods or {}) do
    if mod.name == mod_name and mod.enabled == true then
      return true
    end
  end
  return false
end

local function set_mod_enabled(data_path, mod_name, enabled)
  local mod_list_exists, path = ModList.read(data_path)
  if not mod_list_exists then
    return true
  end

  local decoded = read_mods(path)
  if not decoded then
    return nil, "Error: could not update mod-list.json at " .. path .. "\n"
  end
  set_enabled(decoded, mod_name, enabled)
  if not write_mods(path, decoded) then
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
    -- Keep the snapshot even if factestio was disabled since: it is the user's
    -- real mod list, and the current file has their other mods turned off.
    if meta.had_mod_list == true and System.exists(session_snapshot_path(data_path)) then
      return write_session_meta(data_path, active_mod_name, true)
    end

    local active_session = meta.had_mod_list ~= true
      and mod_enabled_named(data_path, "factestio")
      and meta.active_mod_name
      and mod_enabled_named(data_path, meta.active_mod_name)
    if active_session then
      return write_session_meta(data_path, active_mod_name, false)
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

  local decoded = read_mods(path)
  if not decoded then
    return nil, "Error: could not update mod-list.json at " .. path .. "\n"
  end
  if not keep_other_mods then
    for _, mod in ipairs(decoded.mods) do
      mod.enabled = false
    end
    set_enabled(decoded, "base", true)
  end
  set_enabled(decoded, "factestio", true)
  set_enabled(decoded, sut_name, true)
  if not write_mods(path, decoded) then
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
