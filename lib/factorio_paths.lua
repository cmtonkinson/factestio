local System = require("lib.system")

local FactorioPaths = {}

function FactorioPaths.default_data_path(home, system_name)
  if not home or home == "" then
    return nil
  end

  if system_name == "Linux" then
    return home .. "/.factorio"
  end

  return home .. "/Library/Application Support/factorio"
end

function FactorioPaths.default_binary_candidates(system_name, home)
  local candidates

  if system_name == "Linux" then
    candidates = {
      home and (home .. "/.factorio/bin/x64/factorio") or nil,
      home and (home .. "/.steam/steam/steamapps/common/Factorio/bin/x64/factorio") or nil,
      home and (home .. "/.local/share/Steam/steamapps/common/Factorio/bin/x64/factorio") or nil,
    }
  else
    candidates = {
      "/Applications/factorio.app/Contents/MacOS/factorio",
    }
  end

  local compacted = {}
  for _, candidate in ipairs(candidates) do
    if candidate and candidate ~= "" then
      compacted[#compacted + 1] = candidate
    end
  end
  return compacted
end

function FactorioPaths.detect(opts)
  opts = opts or {}

  local getenv = opts.getenv or os.getenv
  local exists = opts.exists or System.exists
  local system_name = (opts.system_name or function()
    local maybe_jit = rawget(_G, "jit")
    return maybe_jit and maybe_jit.os or "Darwin"
  end)()

  local home = getenv("HOME")
  local binary = getenv("FACTESTIO_FACTORIO_BINARY")
  local data = getenv("FACTESTIO_FACTORIO_DATA")

  if not binary then
    for _, candidate in ipairs(FactorioPaths.default_binary_candidates(system_name, home)) do
      if exists(candidate) then
        binary = candidate
        break
      end
    end
  end

  if not data and home and home ~= "" then
    local default_data = FactorioPaths.default_data_path(home, system_name)
    if exists(default_data .. "/mods") then
      data = default_data
    end
  end

  return {
    binary = binary or FactorioPaths.default_binary_candidates(system_name, home)[1],
    data = data or FactorioPaths.default_data_path(home, system_name),
    binary_ok = binary ~= nil and exists(binary),
    data_ok = data ~= nil and exists(data .. "/mods"),
  }
end

return FactorioPaths
