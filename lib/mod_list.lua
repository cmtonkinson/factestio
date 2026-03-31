local System = require("lib.system")

local ModList = {}

function ModList.read(data_path)
  local path = data_path .. "mods/mod-list.json"
  if not System.exists(path) then
    return nil, path
  end
  return true, path
end

function ModList.set_enabled(data_path, enabled, quiet)
  local mod_list_exists, path = ModList.read(data_path)
  if not mod_list_exists then
    io.stderr:write("Warning: mod-list.json not found at " .. path .. "\n")
    return true
  end

  local enabled_literal = enabled and "true" or "false"
  local tmp_path = path .. ".tmp"
  local jq_filter = string.format(
    "(.mods //= []) | "
      .. '(if any(.mods[]?; .name == "factestio") '
      .. 'then .mods |= map(if .name == "factestio" then .enabled = %s else . end) '
      .. 'else .mods += [{"name":"factestio","enabled":%s}] end)',
    enabled_literal,
    enabled_literal
  )
  local cmd = string.format(
    "jq %s %s > %s && mv %s %s",
    System.shell_quote(jq_filter),
    System.shell_quote(path),
    System.shell_quote(tmp_path),
    System.shell_quote(tmp_path),
    System.shell_quote(path)
  )
  if not System.command_succeeds(cmd) then
    return nil, "Error: could not update mod-list.json at " .. path .. "\n"
  end

  if not quiet then
    print("factestio " .. (enabled and "enabled" or "disabled") .. " in mod-list.json")
  end

  return true
end

function ModList.enabled(data_path)
  local _, path = ModList.read(data_path)
  if not path or not System.exists(path) then
    return false
  end

  local cmd = string.format(
    "jq -e '.mods[]? | select(.name == \"factestio\" and .enabled == true)' %s >/dev/null 2>&1",
    System.shell_quote(path)
  )
  return System.command_succeeds(cmd)
end

return ModList
