return function(F)

local Node = require(F.LOAD_PATH_PREFIX .. 'src.node')

-----------------------------------------------------------------------------
function F.set_paths(cfg)
  assert(type(cfg) == "table", "Factestio.config: cfg must be a table")
  if cfg.binary then
    F.FACTORIO_BINARY = cfg.binary
  end
  if cfg.data then
    F.FACTORIO_DATA_PATH = cfg.data .. '/'
  end
  F.init()
end

-----------------------------------------------------------------------------
function F.register_scenario(name, config)
  assert(type(name) == "string", "name must be a string")
  assert(name:match("^[%w_-]+$"), "name must only contain letters, numbers, underscores, and dashes")

  assert(type(config) == "table", "config must be a table")
  assert(type(config.test) == "function", "config.test must be a function")

  if config.before then
    assert(type(config.before) == "function", "config.before must be a function")
  end
  if config.after then
    assert(type(config.after) == "function", "config.after must be a function")
  end
  if config.from then
    assert(type(config.from) == "string", "config.from must be a string")
  end

  F.registry[name] = config
end
F.test = F.register_scenario -- alias

-----------------------------------------------------------------------------
function F.load()
  local configuration = require('test.config')
  F.set_paths(configuration.os_paths)
  for _, name in ipairs(configuration.test_files) do
    local scenarios_tbl = require('test.' .. name)
    for name, config in pairs(scenarios_tbl) do
      F.register_scenario(name, config)
    end
  end
end

-----------------------------------------------------------------------------
function F.fully_qualified_name(node)
  local fqn = node.name
  if node.parent then
    fqn = F.fully_qualified_name(node.parent) .. "." .. fqn
  end
  return fqn
end

-----------------------------------------------------------------------------
function F.save_name(node)
  return 'results/' .. F.fully_qualified_name(node) .. '/factestio-' .. node.name .. '.zip'
end

-----------------------------------------------------------------------------
function F.starting_save(node)
  if (node.parent) then
    return F.save_name(node.parent)
  else
    return 'map.dat'
  end
end

-----------------------------------------------------------------------------
function F.compile()
  local nodes = {}
  local roots = {}

  -- First pass: Generate nodes for all scenarios.
  for name, details in pairs(F.registry) do
    details.name = name
    details.stats = {}
    details.stats.assertions = 0
    details.stats.passed = 0
    details.stats.failed = 0
    nodes[name] = Node.new(name, details)
  end

  -- Second pass: Link parent/child relationsips.
  for name, details in pairs(F.registry) do
    local node = nodes[name]
    if details.from then
      local parent = nodes[details.from]
      assert(parent, "Parent scenario '" .. details.from .. "' not found for '" .. name .. "'")
      node.root = false
      parent:add(node)
    else
      node.root = true
      table.insert(roots, node)
    end
  end

  return roots
end

-----------------------------------------------------------------------------
function F.get_current_test_name()
  local f = io.open(F.TEST_NAME_FILE, "r")
  if f then
    local name = f:read("*a")
    f:close()
    return name
  else
    return nil
  end
end

-----------------------------------------------------------------------------
function F.results_file(node)
  return 'factestio-' .. node.name .. '-results.json'
end

-----------------------------------------------------------------------------
function F.execute_test(self, node)
  if node.before then node.before(self, self.context) end
  node.test(self, self.context)
  if node.after then node.after(self, self.context) end
end

return F
end
