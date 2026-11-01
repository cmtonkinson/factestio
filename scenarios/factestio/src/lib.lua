-- The library runs both from the CLI, which builds the DAG, and inside Factorio,
-- once per test. Require paths differ between the two, and external libraries
-- (io, JSON) cannot load inside Factorio.
--
-- Subfiles depend on each other, so each returns a function that mutates the
-- shared module table; they are required and called in order.

local F = {}

-- _G.script exists only inside Factorio.
F.LOAD_PATH_PREFIX = ""
if _G.script == nil then
  F.LOAD_PATH_PREFIX = "scenarios.factestio."
end

-- Order matters: later subfiles call functions from earlier ones.
local subfiles = {
  "src.lib_config",
  "src.lib_helpers",
  "src.lib_shared",
}
for _, subfile in ipairs(subfiles) do
  require(F.LOAD_PATH_PREFIX .. subfile)(F)
end

if _G.script == nil then
  require(F.LOAD_PATH_PREFIX .. "src.lib_local")(F)
else
  require(F.LOAD_PATH_PREFIX .. "src.lib_sandboxed")(F)
end

return F
