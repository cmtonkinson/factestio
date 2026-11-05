local Constants = require("lib.constants")
local Json = require("lib.factestio_json")
local System = require("lib.system")

local ProjectConfig = {}

local function info(mod_dir)
  local info_path = mod_dir .. Constants.FACTESTIO.PROJECT_INFO_FILE_NAME
  local content = System.read_file(info_path)
  if not content then
    return nil
  end

  local ok, decoded = pcall(Json.decode, content, info_path)
  if not ok or type(decoded) ~= "table" then
    return nil
  end
  return decoded
end

function ProjectConfig.title(mod_dir)
  local decoded = info(mod_dir)
  return decoded and decoded.title or nil
end

function ProjectConfig.name(mod_dir)
  local decoded = info(mod_dir)
  return decoded and decoded.name or nil
end

-- options.lua is committed and shared with CI; config.lua is machine-local.
function ProjectConfig.map_radius(mod_dir)
  local path = mod_dir .. Constants.FACTESTIO.PROJECT_DIR_NAME .. "/options.lua"
  local content = System.read_file(path)
  if not content then
    return Constants.RUNTIME.DEFAULT_MAP_RADIUS
  end

  local options = assert(load(content, "@" .. path))()
  if type(options) ~= "table" then
    error("Error: " .. path .. " must return a table", 0)
  end
  for key in pairs(options) do
    if key ~= "map_radius" then
      error("Error: unknown option '" .. tostring(key) .. "' in " .. path, 0)
    end
  end

  local radius = options.map_radius or Constants.RUNTIME.DEFAULT_MAP_RADIUS
  if type(radius) ~= "number" or radius < 0 or radius % 1 ~= 0 then
    error("Error: map_radius in " .. path .. " must be a whole number of chunks, 0 or more", 0)
  end
  return radius
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
