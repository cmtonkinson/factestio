return function(F)

local Node = require(F.LOAD_PATH_PREFIX .. 'src.node')

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

-----------------------------------------------------------------------------
function F.fully_qualified_name(node)
  local fqn = node.data.name
  if node.data.parent then
    fqn = F.fully_qualified_name(node.data.parent) .. "." .. fqn
  end
  return fqn
end

-----------------------------------------------------------------------------
function F.save_name(node)
  return 'results/' .. F.fully_qualified_name(node) .. '/factestio-' .. node.data.name .. '.zip'
end

-----------------------------------------------------------------------------
function F.starting_save(node)
  if (node.data.parent) then
    return F.save_name(node.data.parent)
  else
    return 'map.dat'
  end
end

-----------------------------------------------------------------------------
function F.compile()
  local roots = {}

  -- First pass: Generate nodes for all scenarios.
  for name, config in pairs(F.registry) do
    local d = {}
    d.name   = name
    d.from   = config.from
    d.root   = false
    d.before = config.before
    d.test   = config.test
    d.after  = config.after
    d.status = 'pending'
    d.error  = ''
    d.stats = {
      assertions = 0,
      passed     = 0,
      failed     = 0,
    }
    -- Replace the original registry configuration with the new Node.
    F.registry[name] = Node.new(name, d)
  end

  -- Second pass: Link parent/child relationsips.
  for name, node in pairs(F.registry) do
    local data = node.data
    if data.from then
      local parent = F.registry[data.from]
      assert(parent, "Parent scenario '" .. data.from .. "' not found for '" .. name .. "'")
      node.root = false
      parent:add(node)
    else
      node.root = true
      table.insert(roots, node)
    end
  end

  -- Return DAG roots.
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

return F
end
