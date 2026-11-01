local FactorioLog = {}

local MAX_LINES = 5

local function strip_timestamp(line)
  return (line:gsub("^%s*%d+%.%d+%s+", ""))
end

-- Returns the first error Factorio logged, joined with the detail lines that
-- follow it, or nil. Detail lines carry no timestamp, e.g.
--    0.258 Error Util.cpp:81: Failed to load mod "factestio":
--     • Incompatible Factorio version (current: 2.1, required: 2.0)
function FactorioLog.first_error(text)
  if not text then
    return nil
  end

  local found
  for line in text:gmatch("[^\r\n]+") do
    if found then
      -- A timestamped line or a "---- Error ----" banner starts the next entry.
      if line:match("^%s*%d+%.%d+%s") or line:match("^%-%-%-") or #found >= MAX_LINES then
        break
      end
      found[#found + 1] = (line:gsub("^%s+", ""):gsub("%s+$", ""))
    elseif strip_timestamp(line):match("^Error") then
      found = { (strip_timestamp(line):gsub("%s+$", "")) }
    end
  end

  return found and table.concat(found, " ") or nil
end

return FactorioLog
