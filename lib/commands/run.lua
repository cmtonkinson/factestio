local Constants = require("lib.constants")
local ModList = require("lib.mod_list")
local ProjectLinks = require("lib.project_links")
local ProjectConfig = require("lib.project_config")

local Command = {}

function Command.run(root, mod_dir, data_path, debug, timeout)
  local version = require("lib.version").read(root)

  if data_path then
    local ok, err = ProjectLinks.verify_mod_root(root, data_path)
    if not ok then
      return nil, err
    end

    if not ModList.enabled(data_path) then
      io.stderr:write("Warning: factestio is not enabled in mod-list.json. Run `factestio --on` first.\n")
    end
  end

  if not pcall(require, "dkjson") then
    return nil, "Error: missing required Lua rocks: dkjson\nRun: luarocks install --deps-only factestio-*.rockspec\n"
  end

  local mod_title = ProjectConfig.title(mod_dir) or mod_dir:match("([^/]+)/?$") or mod_dir
  print(string.format("factestio: %s", version))
  print(string.format("mod: %s", mod_title))
  print(string.format("workdir: %s", mod_dir))

  local F = require("scenarios.factestio.src.lib")
  F.DEBUG = debug
  F.TEST_TIMEOUT = timeout
  F.MOD_DIR = mod_dir
  F.ROOT = root
  F.TEST_FILES_MANIFEST = root .. "scenarios/factestio/" .. Constants.FACTESTIO.TEST_FILES_MANIFEST
  F.TEST_CONTEXT_MANIFEST = root .. "scenarios/factestio/" .. Constants.FACTESTIO.TEST_CONTEXT_MANIFEST
  F.TEST_CONSTANTS_MANIFEST = root .. "scenarios/factestio/" .. Constants.FACTESTIO.TEST_CONSTANTS_MANIFEST

  F.load()
  F.init(root)

  local roots = F.compile()
  F.run(roots)

  if F.had_failures then
    return 1
  end
  return 0
end

return Command
