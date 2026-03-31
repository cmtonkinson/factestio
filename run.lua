#!/usr/bin/env lua

local os = require("os")

-----------------------------------------------------------------------------
-- Ensure a path ends with exactly one trailing slash
local function ensure_trailing_slash(path)
  if path:sub(-1) ~= "/" then
    return path .. "/"
  end
  return path
end

-----------------------------------------------------------------------------
local function shell_quote(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

-----------------------------------------------------------------------------
local function command_succeeds(cmd)
  local ok, _, code = os.execute(cmd)
  if type(ok) == "number" then
    return ok == 0
  end
  if ok == true then
    return true
  end
  return code == 0
end

-----------------------------------------------------------------------------
-- Resolve FACTESTIO_ROOT (set by bin/factestio wrapper)
local FACTESTIO_ROOT = ensure_trailing_slash(os.getenv("FACTESTIO_ROOT") or "./")

-----------------------------------------------------------------------------
-- Read version from info.json
local VERSION = "unknown"
do
  local f = io.open(FACTESTIO_ROOT .. "info.json", "r")
  if f then
    local content = f:read("*a")
    f:close()
    local version = content and content:match('"version"%s*:%s*"([^"]+)"')
    if version then
      VERSION = version
    end
  end
end

-----------------------------------------------------------------------------
local function usage()
  io.stderr:write("Usage: factestio [--on|--off] [-q|--quiet] [-d|--debug] [-t|--timeout N] [mod_dir]\n")
  os.exit(1)
end

local args = {
  on = false,
  off = false,
  quiet = false,
  debug = false,
  timeout = 8,
  mod_dir = "./",
}

do
  local i = 1
  while i <= #arg do
    local current = arg[i]
    if current == "-V" or current == "--version" then
      print("factestio " .. VERSION)
      os.exit(0)
    elseif current == "--on" then
      args.on = true
    elseif current == "--off" then
      args.off = true
    elseif current == "-q" or current == "--quiet" then
      args.quiet = true
    elseif current == "-d" or current == "--debug" then
      args.debug = true
    elseif current == "-t" or current == "--timeout" then
      i = i + 1
      local value = arg[i]
      if not value then
        usage()
      end
      args.timeout = tonumber(value)
      if not args.timeout then
        io.stderr:write("Error: timeout must be a number.\n")
        os.exit(1)
      end
    elseif current:match("^%-%-timeout=") then
      args.timeout = tonumber(current:match("^%-%-timeout=(.+)$"))
      if not args.timeout then
        io.stderr:write("Error: timeout must be a number.\n")
        os.exit(1)
      end
    elseif current:sub(1, 1) == "-" then
      usage()
    else
      if args.mod_dir ~= "./" then
        usage()
      end
      args.mod_dir = current
    end
    i = i + 1
  end
end

if args.on and args.off then
  io.stderr:write("Error: --on and --off are mutually exclusive.\n")
  os.exit(1)
end

local mod_dir = ensure_trailing_slash(args.mod_dir or "./")

-----------------------------------------------------------------------------
-- Helper: file/dir exists
local function exists(path)
  local f = io.open(path, "r")
  if f then
    f:close()
    return true
  end
  return false
end

-----------------------------------------------------------------------------
-- Helper: read mod-list.json
local function read_mod_list(data_path)
  local path = data_path .. "mods/mod-list.json"
  if not exists(path) then
    return nil, path
  end
  return true, path
end

-- Helper: set mod enabled state
local function set_mod_enabled(data_path, enabled, quiet)
  local mod_list_exists, path = read_mod_list(data_path)
  if not mod_list_exists then
    io.stderr:write("Warning: mod-list.json not found at " .. path .. "\n")
    return
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
    shell_quote(jq_filter),
    shell_quote(path),
    shell_quote(tmp_path),
    shell_quote(tmp_path),
    shell_quote(path)
  )
  if not command_succeeds(cmd) then
    io.stderr:write("Error: could not update mod-list.json at " .. path .. "\n")
    os.exit(1)
  end
  if not quiet then
    print("factestio " .. (enabled and "enabled" or "disabled") .. " in mod-list.json")
  end
end

-- Helper: check if the mod is enabled in mod-list.json
local function mod_enabled(data_path)
  local _, path = read_mod_list(data_path)
  if not path or not exists(path) then
    return false
  end
  local cmd = string.format(
    "jq -e '.mods[]? | select(.name == \"factestio\" and .enabled == true)' %s >/dev/null 2>&1",
    shell_quote(path)
  )
  return command_succeeds(cmd)
end

-- Helper: is symlink pointing to target
local function symlink_target(path)
  local f = io.popen("readlink " .. shell_quote(path) .. " 2>/dev/null")
  local result = f:read("*a"):gsub("\n$", "")
  f:close()
  return result ~= "" and result or nil
end

-- Helper: resolve absolute path
local function realpath(path)
  local f = io.popen("cd " .. shell_quote(path) .. " 2>/dev/null && pwd")
  local result = f:read("*a"):gsub("\n$", "")
  f:close()
  return result ~= "" and result or nil
end

-- Helper: verify the active Factorio mod symlink points at this CLI's root
local function verify_factestio_mod_root(data_path)
  local mods_link = data_path .. "mods/factestio"
  local mods_target = symlink_target(mods_link)
  if not mods_target then
    return
  end

  local expected_root = realpath(FACTESTIO_ROOT:gsub("/$", ""))
  local actual_root = realpath(mods_target)
  if expected_root and actual_root and expected_root ~= actual_root then
    io.stderr:write("Error: factestio CLI/mod mismatch detected.\n")
    io.stderr:write("CLI root: " .. expected_root .. "\n")
    io.stderr:write("mods/factestio -> " .. actual_root .. "\n")
    io.stderr:write(
      "Run `factestio --on` using the factestio binary you intend to use, or invoke the matching binary directly.\n"
    )
    os.exit(1)
  end
end

-- Helper: add lines to a file if missing
local function ensure_lines(path, entries)
  local current = ""
  local f = io.open(path, "r")
  if f then
    current = f:read("*a") or ""
    f:close()
  end

  local seen = {}
  for line in current:gmatch("[^\r\n]+") do
    seen[line] = true
  end

  local changed = false
  local output = current
  for _, entry in ipairs(entries) do
    if not seen[entry] then
      if output ~= "" and not output:match("\n$") then
        output = output .. "\n"
      end
      output = output .. entry .. "\n"
      seen[entry] = true
      changed = true
    end
  end

  if changed or not exists(path) then
    local out, err = io.open(path, "w")
    if not out then
      io.stderr:write("Error: could not write " .. path .. ": " .. (err or "unknown error") .. "\n")
      os.exit(1)
    end
    out:write(output)
    out:close()
  end

  return changed
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
  data_path = ensure_trailing_slash(configuration.os_paths.data)
end

-----------------------------------------------------------------------------
-- --on: enable factestio for this mod project
if args.on then
  local quiet = args.quiet

  -- Guess Factorio paths from the current user
  local whoami_f = io.popen("whoami")
  local whoami = whoami_f:read("*a"):gsub("%s+$", "")
  whoami_f:close()
  local guessed_binary = "/Applications/factorio.app/Contents/MacOS/factorio"
  local guessed_data = "/Users/" .. whoami .. "/Library/Application Support/factorio"

  local binary_ok = exists(guessed_binary)
  local data_ok = exists(guessed_data .. "/mods")

  if not quiet then
    if binary_ok then
      print("binary @ " .. guessed_binary)
    else
      io.stderr:write("Warning: binary not found @ " .. guessed_binary .. "\n")
    end
    if data_ok then
      print("data   @ " .. guessed_data)
    else
      io.stderr:write("Warning: data not found @ " .. guessed_data .. "\n")
    end
  end

  -- 1. Scaffold factestio/ in mod project
  local factestio_dir = mod_dir .. "factestio"
  if not realpath(factestio_dir) then
    os.execute("mkdir -p " .. shell_quote(factestio_dir))
    if not quiet then
      print("Created directory: " .. factestio_dir)
    end
  end

  -- 2. Write config.lua from template, substituting guessed paths
  local config_dst = factestio_dir .. "/config.lua"
  local already_initialized = exists(config_dst)
  if not exists(config_dst) then
    local config_src = FACTESTIO_ROOT .. "factestio/config.lua.example"
    local src_f = io.open(config_src, "r")
    if src_f then
      local content = src_f:read("*a")
      src_f:close()
      content = content:gsub("<binary>", guessed_binary)
      content = content:gsub("<data>", guessed_data)
      local dst_f = io.open(config_dst, "w")
      if dst_f then
        dst_f:write(content)
        dst_f:close()
        if not quiet then
          print("Created: " .. config_dst)
        end
      end
    end
  end

  -- 3. Write example test file on first-time initialization only
  local example_dst = factestio_dir .. "/example.lua"
  if not already_initialized and not exists(example_dst) then
    local example_src = FACTESTIO_ROOT .. "factestio/example.lua"
    os.execute("cp " .. shell_quote(example_src) .. " " .. shell_quote(example_dst))
    if not quiet then
      print("Created: " .. example_dst)
    end
  end

  -- 4. Add a scoped gitignore for local config and generated results
  local gitignore_dst = factestio_dir .. "/.gitignore"
  local gitignore_changed = ensure_lines(gitignore_dst, {
    "config.lua",
    "results/",
  })
  if not quiet and gitignore_changed then
    print("Updated: " .. gitignore_dst)
  end

  -- Steps 5 & 6 require Factorio to be present
  if binary_ok and data_ok then
    local detected_data = guessed_data .. "/"

    -- 5. Enable in mod-list.json (back up original first via read/modify/write)
    set_mod_enabled(detected_data, true, quiet)

    -- 6. Create symlinks
    local mods_link = detected_data .. "mods/factestio"
    local mods_target = symlink_target(mods_link)
    local abs_mods_target = mods_target and realpath(mods_target) or nil
    local abs_expected_root = realpath(FACTESTIO_ROOT:gsub("/$", "")) or FACTESTIO_ROOT:gsub("/$", "")
    if mods_target then
      if abs_mods_target ~= abs_expected_root then
        io.stderr:write("Error: factestio mod symlink mismatch detected during --on.\n")
        io.stderr:write("CLI root: " .. abs_expected_root .. "\n")
        io.stderr:write("mods/factestio -> " .. (abs_mods_target or mods_target) .. "\n")
        io.stderr:write("Remove the existing symlink or run the matching factestio binary instead.\n")
        os.exit(1)
      elseif not quiet then
        print("Mod symlink already exists: " .. mods_link)
      end
    else
      os.execute("ln -sf " .. shell_quote(abs_expected_root) .. " " .. shell_quote(mods_link))
      if not quiet then
        print("Created mod symlink: " .. mods_link)
      end
    end

    local link_path = FACTESTIO_ROOT .. "scenarios/factestio/factestio"
    local target = symlink_target(link_path)
    local abs_expected = realpath(mod_dir) and (realpath(mod_dir) .. "/factestio") or (mod_dir .. "factestio")
    local abs_target = target and realpath(target) or nil

    if target then
      if abs_target ~= abs_expected then
        io.stderr:write("Error: factestio already on for another mod " .. target .. "\n")
        os.exit(1)
      elseif not quiet then
        print("factestio symlink already correct")
      end
    else
      os.execute("ln -sf " .. shell_quote(abs_expected) .. " " .. shell_quote(link_path))
      if not quiet then
        print("Created symlink: " .. link_path .. " -> " .. abs_expected)
      end
    end

    -- 6. Generate root-save.zip using Factorio's --create mode (no scenario Lua needed)
    local root_save = FACTESTIO_ROOT .. "root-save.zip"
    if not exists(root_save) then
      if not quiet then
        print("Generating root-save.zip (this may take a moment)...")
      end

      local tmp_save_name = "factestio-root-save-init"
      local tmp_save_path = detected_data .. "saves/" .. tmp_save_name .. ".zip"
      local map_gen = FACTESTIO_ROOT .. "map-gen-settings.json"
      local stdout_log = FACTESTIO_ROOT .. "tmp/setup-stdout.txt"
      os.execute("mkdir -p " .. shell_quote(FACTESTIO_ROOT .. "tmp"))

      -- --create generates a world and exits immediately — no timeout needed
      local create_cmd = string.format(
        '"%s" --create "%s" --map-gen-settings "%s" --disable-audio --nogamepad > "%s" 2>&1',
        guessed_binary,
        tmp_save_name,
        map_gen,
        stdout_log
      )
      local create_ok = os.execute(create_cmd)

      if create_ok and exists(tmp_save_path) then
        os.execute("mv " .. shell_quote(tmp_save_path) .. " " .. shell_quote(root_save))
        if not quiet then
          print("Created root-save.zip")
        end
      else
        io.stderr:write("Warning: Factorio --create failed to produce a save.\n")
        io.stderr:write("Check " .. stdout_log .. " for details.\n")
        io.stderr:write("You can retry with `factestio --on` after resolving the issue.\n")
      end
    else
      if not quiet then
        print("root-save.zip already exists")
      end
    end
  else
    if not quiet then
      io.stderr:write("Warning: skipping mod-list.json and symlinks (Factorio not found)\n")
      io.stderr:write("Edit " .. config_dst .. " then re-run `factestio --on`\n")
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
    os.execute("rm " .. shell_quote(link_path))
    if not quiet then
      print("Removed symlink: " .. link_path)
    end
  end

  -- 2. Remove mods/factestio symlink
  if data_path then
    local mods_link = data_path .. "mods/factestio"
    local mods_target = symlink_target(mods_link)
    if mods_target then
      os.execute("rm " .. shell_quote(mods_link))
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
  verify_factestio_mod_root(data_path)

  if not mod_enabled(data_path) then
    io.stderr:write("Warning: factestio is not enabled in mod-list.json. Run `factestio --on` first.\n")
  end
end

-- From here on we need the full local runtime stack, including cjson.
if not pcall(require, "cjson") then
  io.stderr:write("Error: missing required Lua rocks: cjson\n")
  io.stderr:write("Run: luarocks install --deps-only factestio-*.rockspec\n")
  os.exit(1)
end

local F = require("scenarios.factestio.src.lib")
F.DEBUG = args.debug
F.TEST_TIMEOUT = args.timeout
F.MOD_DIR = mod_dir
F.ROOT = FACTESTIO_ROOT
F.TEST_FILES_MANIFEST = FACTESTIO_ROOT .. "scenarios/factestio/test_files.lua"

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
