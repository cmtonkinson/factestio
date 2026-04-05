local Constants = require("lib.constants")
local System = require("lib.system")

local Version = {}

function Version.read(root)
  local content = System.read_file(root .. Constants.FACTESTIO.PROJECT_INFO_FILE_NAME)
  if not content then
    return "unknown"
  end

  local version = content:match('"version"%s*:%s*"([^"]+)"')
  return version or "unknown"
end

return Version
