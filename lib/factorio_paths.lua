local System = require("lib.system")

local FactorioPaths = {}

local DEFAULT_BINARY_CANDIDATES = {
  "/Applications/factorio.app/Contents/MacOS/factorio",
}

function FactorioPaths.default_data_path(home)
  return home .. "/Library/Application Support/factorio"
end

function FactorioPaths.default_binary_candidates()
  local candidates = {}
  for _, candidate in ipairs(DEFAULT_BINARY_CANDIDATES) do
    candidates[#candidates + 1] = candidate
  end
  return candidates
end

function FactorioPaths.detect(opts)
  opts = opts or {}

  local getenv = opts.getenv or os.getenv
  local exists = opts.exists or System.exists

  local home = getenv("HOME")
  local binary = getenv("FACTESTIO_FACTORIO_BINARY")
  local data = getenv("FACTESTIO_FACTORIO_DATA")

  if not binary then
    for _, candidate in ipairs(FactorioPaths.default_binary_candidates()) do
      if exists(candidate) then
        binary = candidate
        break
      end
    end
  end

  if not data and home and home ~= "" then
    local default_data = FactorioPaths.default_data_path(home)
    if exists(default_data .. "/mods") then
      data = default_data
    end
  end

  return {
    binary = binary or FactorioPaths.default_binary_candidates()[1],
    data = data or (home and home ~= "" and FactorioPaths.default_data_path(home) or nil),
    binary_ok = binary ~= nil and exists(binary),
    data_ok = data ~= nil and exists(data .. "/mods"),
  }
end

return FactorioPaths
