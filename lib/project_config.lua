local System = require("lib.system")

local ProjectConfig = {}

function ProjectConfig.load(mod_dir, opts)
  opts = opts or {}

  package.path = mod_dir .. "?.lua;" .. mod_dir .. "?/init.lua;" .. package.path

  local ok, configuration = pcall(require, "factestio.config")
  if not ok then
    if opts.allow_missing then
      return nil
    end

    return nil,
      "Error: could not load factestio/config.lua from "
        .. mod_dir
        .. "\n"
        .. "Run `factestio --on` first to scaffold the config.\n"
  end

  return configuration
end

function ProjectConfig.data_path(configuration)
  if configuration and configuration.os_paths and configuration.os_paths.data then
    return System.ensure_trailing_slash(configuration.os_paths.data)
  end
  return nil
end

return ProjectConfig
