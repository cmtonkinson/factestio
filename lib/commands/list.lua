local Json = require("lib.factestio_json")

local Command = {}

local function json_string(value)
  local encoded = Json.encode(value)
  if type(encoded) ~= "string" then
    error("Error: could not encode JSON output")
  end
  return encoded
end

local function shallow_node(node)
  return {
    name = node.data.name,
    children = {},
  }
end

local function top_level_targets(nodes)
  local included = {}
  local result = {}

  for _, node in ipairs(nodes) do
    included[node] = true
  end

  for _, node in ipairs(nodes) do
    if not included[node.parent] then
      result[#result + 1] = node
    end
  end

  return result
end

function Command.run(root, mod_dir, roots_only, children_name, as_json, output_stream)
  local stream = output_stream or io.stdout
  local F = require("scenarios.factestio.src.lib")
  F.DEBUG = false
  F.SEED = 1
  F.MOD_DIR = mod_dir
  F.ROOT = root
  F.TEST_FILES_MANIFEST = root .. "scenarios/factestio/test_files.lua"
  F.TEST_SEED_FILE = root .. "scenarios/factestio/test_seed.lua"
  F.TEST_CONTEXT_MANIFEST = root .. "scenarios/factestio/test_context.lua"
  F.TEST_CONSTANTS_MANIFEST = root .. "scenarios/factestio/test_constants.lua"

  F.load()
  F.init(root)

  local compiled_roots = F.compile()
  local nodes

  if children_name then
    local matches = F.find_nodes_by_prefix(children_name)
    if #matches == 0 then
      return nil, "Unknown scenario id: " .. tostring(children_name) .. "\n"
    end
    nodes = top_level_targets(matches)
  elseif roots_only then
    nodes = compiled_roots
  else
    nodes = compiled_roots
  end

  if as_json then
    local payload = {}
    for _, node in ipairs(nodes) do
      payload[#payload + 1] = roots_only and shallow_node(node) or F.serialize_node(node)
    end
    stream:write(json_string(payload) .. "\n")
    return 0
  end

  if roots_only then
    for _, node in ipairs(nodes) do
      stream:write(node.data.name .. "\n")
    end
  else
    F.write_node_lines(stream, nodes, 0)
  end
  return 0
end

return Command
