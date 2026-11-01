local Shell = require("lib.shell")

local FactorioFlags = {}

-- Client-only options that speed up launches. Headless builds reject them
-- ("Option 'disable-audio' does not exist"), so pass only what --help lists.
local CLIENT_FLAGS = { "--disable-audio", "--nogamepad" }

function FactorioFlags.client(binary, capture)
  local help = (capture or Shell.capture)(binary, { "--help" }, { stderr_to_stdout = true }) or ""
  local flags = {}
  for _, flag in ipairs(CLIENT_FLAGS) do
    if help:find(flag, 1, true) then
      flags[#flags + 1] = flag
    end
  end
  return flags
end

return FactorioFlags
