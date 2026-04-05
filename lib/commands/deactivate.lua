local Constants = require("lib.constants")
local ModList = require("lib.mod_list")
local ProjectConfig = require("lib.project_config")
local ProjectLinks = require("lib.project_links")

local Command = {}

function Command.run(root, mod_dir, data_path, quiet)
  local sut_name = ProjectConfig.name(mod_dir)
  if not sut_name then
    return nil,
      "Error: could not determine mod name from " .. mod_dir .. Constants.FACTESTIO.PROJECT_INFO_FILE_NAME .. "\n"
  end

  local ok, err = ProjectLinks.remove_project_symlink(root, quiet)
  if not ok then
    return nil, err
  end

  if data_path then
    ok, err = ProjectLinks.remove_mod_symlink(data_path, quiet)
    if not ok then
      return nil, err
    end

    ok, err = ProjectLinks.remove_sut_symlink(data_path, sut_name, quiet)
    if not ok then
      return nil, err
    end

    ok, err = ModList.deactivate(data_path, sut_name, quiet)
    if not ok then
      return nil, err
    end
  end

  return 0
end

return Command
