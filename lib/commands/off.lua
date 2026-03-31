local ModList = require("lib.mod_list")
local ProjectLinks = require("lib.project_links")

local Command = {}

function Command.run(root, data_path, quiet)
  ProjectLinks.remove_project_symlink(root, quiet)

  if data_path then
    ProjectLinks.remove_mod_symlink(data_path, quiet)
    local ok, err = ModList.set_enabled(data_path, false, quiet)
    if not ok then
      return nil, err
    end
  end

  return 0
end

return Command
