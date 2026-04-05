local Constants = require("lib.constants")
local Json = require("lib.factestio_json")
local System = require("lib.system")

local ProjectConfig = {}
local info_cache = {}

local function info(mod_dir)
  if info_cache[mod_dir] ~= nil then
    return info_cache[mod_dir] or nil
  end

  local info_path = mod_dir .. Constants.FACTESTIO.PROJECT_INFO_FILE_NAME
  local content = System.read_file(info_path)
  if not content then
    info_cache[mod_dir] = false
    return nil
  end

  local ok, decoded = pcall(Json.decode, content, info_path)
  if not ok or type(decoded) ~= "table" then
    info_cache[mod_dir] = false
    return nil
  end

  info_cache[mod_dir] = decoded
  return decoded
end

function ProjectConfig.clear_cache()
  info_cache = {}
end

function ProjectConfig.title(mod_dir)
  local decoded = info(mod_dir)
  return decoded and decoded.title or nil
end

function ProjectConfig.name(mod_dir)
  local decoded = info(mod_dir)
  return decoded and decoded.name or nil
end

function ProjectConfig.load(mod_dir, opts)
  opts = opts or {}

  package.path = mod_dir .. "?.lua;" .. mod_dir .. "?/init.lua;" .. package.path

  local ok, configuration = pcall(require, Constants.FACTESTIO.PROJECT_CONFIG_MODULE_NAME)
  if not ok then
    if opts.allow_missing then
      return nil
    end

    return nil,
      "Error: could not load "
        .. Constants.FACTESTIO.PROJECT_CONFIG_MODULE_NAME:gsub("%.", "/")
        .. ".lua from "
        .. mod_dir
        .. "\n"
        .. "Run `factestio activate` first to scaffold the config.\n"
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
