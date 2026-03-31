local Json = require("lib.factestio_json")
local System = require("lib.system")

local ProjectConfig = {}

function ProjectConfig.title(mod_dir)
  local info_path = mod_dir .. "info.json"
  local content = System.read_file(info_path)
  if not content then
    return nil
  end

  local ok, decoded = pcall(Json.decode, content, info_path)
  if not ok or type(decoded) ~= "table" then
    return nil
  end

  return decoded.title
end

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
