#!/usr/bin/env lua

local F = require("scenarios.factestio.src.lib")

-- Verify required rocks are installed
local required_rocks = { "argparse", "cjson" }
local missing = {}
for _, rock in ipairs(required_rocks) do
  if not pcall(require, rock) then
    table.insert(missing, rock)
  end
end
if #missing > 0 then
  io.stderr:write("Error: missing required Lua rocks: " .. table.concat(missing, ", ") .. "\n")
  io.stderr:write("Run: luarocks install --deps-only factestio-0.1-0.rockspec\n")
  os.exit(1)
end

local argparse = require("argparse")
local cjson = require("cjson")
local os = require("os")

-----------------------------------------------------------------------------
-- Resolve FACTESTIO_ROOT (set by bin/factestio wrapper)
local FACTESTIO_ROOT = os.getenv("FACTESTIO_ROOT") or "./"
if FACTESTIO_ROOT:sub(-1) ~= "/" then
  FACTESTIO_ROOT = FACTESTIO_ROOT .. "/"
end

-----------------------------------------------------------------------------
-- Process CLI arguments
local parser = argparse()
  :name("factestio")
  :description("Run the Factestio Behavior DAG")
  :epilog("For more information, visit https://github.com/cmtonkinson/factestio")
parser:flag("--on"):description("Enable factestio for this mod project (symlink, mod-list, scaffold)")
parser:flag("--off"):description("Disable factestio for this mod project")
parser:flag("-q --quiet"):description("Suppress informational output (use with --on/--off)")
parser:flag("-d --debug"):description("Run in debug mode")
parser:option("-t --timeout"):description("Timeout for each scenario in seconds"):default("8"):convert(tonumber)
parser:argument("mod_dir"):description("Mod project directory (default: current directory)"):default("./"):args("?")

local args = parser:parse()

-- Normalize mod_dir
local mod_dir = args.mod_dir
if mod_dir:sub(-1) ~= "/" then
  mod_dir = mod_dir .. "/"
end

-----------------------------------------------------------------------------
-- Helper: read mod-list.json
local function read_mod_list(data_path)
  local path = data_path .. "mods/mod-list.json"
  local f = io.open(path, "r")
  if not f then
    return nil, path
  end
  local content = f:read("*a")
  f:close()
  return cjson.decode(content), path
end

-- Helper: write mod-list.json
local function write_mod_list(path, data)
  local f, err = io.open(path, "w")
  if not f then
    io.stderr:write("Error: could not write mod-list.json at " .. path .. ": " .. (err or "unknown error") .. "\n")
    os.exit(1)
  end
  f:write(cjson.encode(data))
  f:close()
end

-- Helper: set mod enabled state
local function set_mod_enabled(data_path, enabled, quiet)
  local mod_list, path = read_mod_list(data_path)
  if not mod_list then
    io.stderr:write("Warning: mod-list.json not found at " .. path .. "\n")
    return
  end
  for _, mod in ipairs(mod_list.mods) do
    if mod.name == "factestio" then
      if mod.enabled ~= enabled then
        mod.enabled = enabled
        write_mod_list(path, mod_list)
        if not quiet then
          print("factestio " .. (enabled and "enabled in mod-list.json" or "disabled in mod-list.json"))
        end
      end
      return
    end
  end
  -- not in list, add it
  table.insert(mod_list.mods, { name = "factestio", enabled = enabled })
  write_mod_list(path, mod_list)
  if not quiet then
    print("factestio " .. (enabled and "enabled" or "disabled") .. " in mod-list.json")
  end
end

-- Helper: file/dir exists
local function exists(path)
  local f = io.open(path, "r")
  if f then
    f:close()
    return true
  end
  return false
end

-- Helper: is symlink pointing to target
local function symlink_target(path)
  local f = io.popen("readlink " .. F.shell_quote(path) .. " 2>/dev/null")
  local result = f:read("*a"):gsub("\n$", "")
  f:close()
  return result ~= "" and result or nil
end

-- Helper: resolve absolute path
local function realpath(path)
  local f = io.popen("cd " .. F.shell_quote(path) .. " 2>/dev/null && pwd")
  local result = f:read("*a"):gsub("\n$", "")
  f:close()
  return result ~= "" and result or nil
end

-----------------------------------------------------------------------------
-- Load config to get data path (needed for --on/--off and enabled check)
-- We need factestio/config.lua from mod_dir
package.path = mod_dir .. "?.lua;" .. mod_dir .. "?/init.lua;" .. package.path

local ok, configuration = pcall(require, "factestio.config")
if not ok then
  if args.on or args.off then
    configuration = nil
  else
    io.stderr:write("Error: could not load factestio/config.lua from " .. mod_dir .. "\n")
    io.stderr:write("Run `factestio --on` first to scaffold the config.\n")
    os.exit(1)
  end
end

local data_path = nil
if configuration and configuration.os_paths and configuration.os_paths.data then
  data_path = configuration.os_paths.data
  if data_path:sub(-1) ~= "/" then
    data_path = data_path .. "/"
  end
end

-----------------------------------------------------------------------------
-- --on: enable factestio for this mod project
if args.on then
  local quiet = args.quiet

  -- 1. Check/create scenarios/factestio/factestio symlink
  local link_path = FACTESTIO_ROOT .. "scenarios/factestio/factestio"
  local target = symlink_target(link_path)
  local abs_expected = realpath(mod_dir) and (realpath(mod_dir) .. "/factestio") or (mod_dir .. "factestio")
  local abs_target = target and realpath(target) or nil

  if target then
    if abs_target ~= abs_expected then
      io.stderr:write("Error: factestio already on for another mod " .. target .. "\n")
      os.exit(1)
    else
      if not quiet then
        print("factestio symlink already correct")
      end
    end
  else
    os.execute("ln -sf " .. F.shell_quote(abs_expected) .. " " .. F.shell_quote(link_path))
    if not quiet then
      print("Created symlink: " .. link_path .. " -> " .. abs_expected)
    end
  end

  -- 2. Create mods/factestio symlink
  if data_path then
    local mods_link = data_path .. "mods/factestio"
    local mods_target = symlink_target(mods_link)
    if mods_target then
      if not quiet then
        print("Mod symlink already exists: " .. mods_link)
      end
    else
      os.execute("ln -sf " .. F.shell_quote(FACTESTIO_ROOT:gsub("/$", "")) .. " " .. F.shell_quote(mods_link))
      if not quiet then
        print("Created mod symlink: " .. mods_link)
      end
    end

    -- 3. Enable in mod-list.json
    set_mod_enabled(data_path, true, quiet)
  else
    if not quiet then
      print("Note: skipping mod-list.json (no config found yet)")
    end
  end

  -- 4. Scaffold factestio/ in mod project
  local factestio_dir = mod_dir .. "factestio"
  if not realpath(factestio_dir) then
    os.execute("mkdir -p " .. F.shell_quote(factestio_dir))
    if not quiet then
      print("Created directory: " .. factestio_dir)
    end
  end

  local config_dst = factestio_dir .. "/config.lua"
  if not exists(config_dst) then
    local config_src = FACTESTIO_ROOT .. "factestio/config.lua.example"
    os.execute("cp " .. F.shell_quote(config_src) .. " " .. F.shell_quote(config_dst))
    if not quiet then
      print("Created: " .. config_dst)
    end
  end

  local example_dst = factestio_dir .. "/example.lua"
  if not exists(example_dst) then
    local example_src = FACTESTIO_ROOT .. "factestio/example.lua"
    os.execute("cp " .. F.shell_quote(example_src) .. " " .. F.shell_quote(example_dst))
    if not quiet then
      print("Created: " .. example_dst)
    end
  end

  os.exit(0)
end

-----------------------------------------------------------------------------
-- --off: disable factestio for this mod project
if args.off then
  local quiet = args.quiet

  -- 1. Remove scenarios/factestio/factestio symlink
  local link_path = FACTESTIO_ROOT .. "scenarios/factestio/factestio"
  local target = symlink_target(link_path)
  if target then
    os.execute("rm " .. F.shell_quote(link_path))
    if not quiet then
      print("Removed symlink: " .. link_path)
    end
  end

  -- 2. Remove mods/factestio symlink
  if data_path then
    local mods_link = data_path .. "mods/factestio"
    local mods_target = symlink_target(mods_link)
    if mods_target then
      os.execute("rm " .. F.shell_quote(mods_link))
      if not quiet then
        print("Removed mod symlink: " .. mods_link)
      end
    end

    -- 3. Disable in mod-list.json
    set_mod_enabled(data_path, false, quiet)
  end

  os.exit(0)
end

-----------------------------------------------------------------------------
-- Normal test run

-- Warn if factestio not enabled
if data_path then
  local mod_list = read_mod_list(data_path)
  if mod_list then
    local enabled = false
    for _, mod in ipairs(mod_list.mods) do
      if mod.name == "factestio" and mod.enabled then
        enabled = true
        break
      end
    end
    if not enabled then
      io.stderr:write("Warning: factestio is not enabled in mod-list.json. Run `factestio --on` first.\n")
    end
  end
end

F.DEBUG = args.debug
F.TEST_TIMEOUT = args.timeout

-- Init paths (F.FACTORIO_DATA_PATH set during F.load via F.set_paths)
F.load()
F.init(FACTESTIO_ROOT)

local roots = F.compile()
F.run(roots)

if F.had_failures then
  os.exit(1)
else
  os.exit(0)
end
