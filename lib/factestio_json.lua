local json = require("dkjson")

local Json = {}

function Json.decode(content, source)
  local decoded, _, err = json.decode(content, 1, nil)
  if err then
    error(string.format("Error: could not decode JSON from %s: %s", source or "<input>", err))
  end
  return decoded
end

function Json.encode(value)
  local encoded, err = json.encode(value)
  if err then
    error(string.format("Error: could not encode JSON: %s", err))
  end
  return encoded
end

return Json
