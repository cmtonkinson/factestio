local Constants = require("lib.constants")
local FactorioPaths = require("lib.factorio_paths")
local ModList = require("lib.mod_list")
local ProjectLinks = require("lib.project_links")
local System = require("lib.system")

local Command = {}

function Command.run(root, mod_dir, quiet)
  local detected = FactorioPaths.detect()
  local guessed_binary = detected.binary
  local guessed_data = detected.data
  local binary_ok = detected.binary_ok
  local data_ok = detected.data_ok

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

  local factestio_dir = mod_dir .. "factestio"
  if not System.realpath(factestio_dir) then
    os.execute("mkdir -p " .. System.shell_quote(factestio_dir))
    if not quiet then
      print("Created directory: " .. factestio_dir)
    end
  end

  local config_dst = factestio_dir .. "/config.lua"
  local already_initialized = System.exists(config_dst)
  if not System.exists(config_dst) then
    local content, err = System.read_file(root .. "factestio/config.lua.example")
    if not content then
      return nil, "Error: could not read config template: " .. (err or "unknown error") .. "\n"
    end

    content = content:gsub("<binary>", guessed_binary)
    content = content:gsub("<data>", guessed_data)
    local ok, write_err = System.write_file(config_dst, content)
    if not ok then
      return nil, "Error: could not write " .. config_dst .. ": " .. (write_err or "unknown error") .. "\n"
    end

    if not quiet then
      print("Created: " .. config_dst)
    end
  end

  local example_dst = factestio_dir .. "/example.lua"
  if not already_initialized and not System.exists(example_dst) then
    local example_src = root .. "factestio/example.lua"
    os.execute("cp " .. System.shell_quote(example_src) .. " " .. System.shell_quote(example_dst))
    if not quiet then
      print("Created: " .. example_dst)
    end
  end

  local gitignore_changed, gitignore_err = System.ensure_lines(factestio_dir .. "/.gitignore", {
    "config.lua",
    "results/",
  })
  if gitignore_changed == nil then
    return nil, gitignore_err .. "\n"
  end
  if not quiet and gitignore_changed then
    print("Updated: " .. factestio_dir .. "/.gitignore")
  end

  if not (binary_ok and data_ok) then
    if not quiet then
      io.stderr:write("Warning: skipping mod-list.json and symlinks (Factorio not found)\n")
      io.stderr:write("Edit " .. config_dst .. " then re-run `factestio --on`\n")
    end
    return 0
  end

  local detected_data = guessed_data .. "/"
  local ok, err = ModList.set_enabled(detected_data, true, quiet)
  if not ok then
    return nil, err
  end

  ok, err = ProjectLinks.ensure_mod_symlink(root, detected_data, quiet)
  if not ok then
    return nil, err
  end

  ok, err = ProjectLinks.ensure_project_symlink(root, mod_dir, quiet)
  if not ok then
    return nil, err
  end

  local root_save = root .. Constants.FACTESTIO.ROOT_SAVE_NAME
  if System.exists(root_save) then
    if not quiet then
      print(Constants.FACTESTIO.ROOT_SAVE_NAME .. " already exists")
    end
    return 0
  end

  if not quiet then
    print("Generating " .. Constants.FACTESTIO.ROOT_SAVE_NAME .. " (this may take a moment)...")
  end

  local tmp_save_name = Constants.FACTESTIO.ROOT_SAVE_INIT_BASENAME
  local tmp_save_base = detected_data .. "saves/" .. tmp_save_name
  local tmp_save_path = tmp_save_base .. ".zip"
  local map_gen = root .. Constants.FACTESTIO.MAP_GEN_SETTINGS_FILE
  local stdout_log = root .. Constants.FACTESTIO.TMP_SETUP_STDOUT
  os.execute("mkdir -p " .. System.shell_quote(root .. "tmp"))

  local create_cmd = string.format(
    '"%s" --create "%s" --map-gen-settings "%s" --disable-audio --nogamepad > "%s" 2>&1',
    guessed_binary,
    tmp_save_base,
    map_gen,
    stdout_log
  )
  local create_ok = os.execute(create_cmd)

  if create_ok and System.exists(tmp_save_path) then
    os.execute("mv " .. System.shell_quote(tmp_save_path) .. " " .. System.shell_quote(root_save))
    if not quiet then
      print("Created root-save.zip")
    end
  else
    io.stderr:write("Warning: Factorio --create failed to produce a save.\n")
    io.stderr:write("Check " .. stdout_log .. " for details.\n")
    io.stderr:write("You can retry with `factestio --on` after resolving the issue.\n")
  end

  return 0
end

return Command
