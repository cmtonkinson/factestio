-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- This gets weird. Because of the way Factorio sandboxes, paths, and loads
-- scripts, we need to be able to run this logic both within the context of
-- the Factorio scenario and from the outside world. That means specifically:
--   * the apparent path to required files will change
--   * external libraries (io, cjson, etc.) can't be loaded inside Factorio
--
-- But the annoyance doesn't stop there - most of this logic is executed N+1
-- times per test suite invocation. We first have to analyze the tests that are
-- written to build the DAG and know which tests need to be run. But then we're
-- booting the game engine once per test, which needs to run all this logic
-- again each time, just to be able to execute one single test case and exit.
--
-- ALSO, the Facestio library is broken up across multiple files, because
-- 1. Organization; my head was asplode.
-- 2. Some functions are only used/definable in CLI context, while others
--    are only used in sandboxed context.
-- HOWEVER, there are cross-dependencies between functions across subfiles,
-- so we can't just define and require each file the usual way (by doing
-- `local X = {}` and `return X`). The pattern instead is that each file
-- returns a function that accepts, and directly mutates, the main module
-- table. So each file, in order, is required and then that function called
-- immediately. It's a strange pattern but it seems to work well here.
--
-- "If it's stupid but it works, it ain't stupid."
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

-- This is the primary definition of the main module table.
local F = {}

-- _G.script is defined by Factorio when running a mod/scenario. It's the main
-- way we can tell if we're running sanboxed or not.
F.LOAD_PATH_PREFIX = ""
if _G.script == nil then
  -- When running outside of Factorio we have to add additional path prefixes.
  F.LOAD_PATH_PREFIX = "scenarios.factestio."
end

-- These subfiles need to be defined in order.
local subfiles = {
  "src.lib_config",
  "src.lib_helpers",
  "src.lib_shared",
}
for _, subfile in ipairs(subfiles) do
  require(F.LOAD_PATH_PREFIX .. subfile)(F)
end

-- Require whichever remaining specific functions are needed.
if _G.script == nil then
  require(F.LOAD_PATH_PREFIX .. "src.lib_local")(F)
else
  require(F.LOAD_PATH_PREFIX .. "src.lib_sandboxed")(F)
end

return F
