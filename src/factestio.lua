local serpent = require("serpent")
local Node = require("src.node")
local F = {}

F.registry       = {}
F.DEBUG          = true
F.PATH           = ""
F.ROOT           = "/Users/chris/repo/factestio/factestio"
F.BASE           = F.ROOT .. "/base.zip_"
F.SETTINGS       = F.ROOT .. "/server-settings.json"
F.SAVES          = F.ROOT .. "/saves"
F.TEST_NAME_FILE = F.ROOT .. "/test_name.txt"

-----------------------------------------------------------------------------
function F.set_path(new_path)
  F.PATH = new_path
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
function F.fully_qualified_name(node)
  local fqn = node.name
  if node.parent then
    fqn = F.fully_qualified_name(node.parent) .. "." .. fqn
  end
  return fqn
end

-----------------------------------------------------------------------------
function F.save_name(node)
  return F.SAVES .. "/" .. F.fully_qualified_name(node) .. ".zip"
end

-----------------------------------------------------------------------------
function F.starting_save(node)
  if (node.parent) then
    return F.save_name(node.parent)
  else
    return F.BASE
  end
end

-----------------------------------------------------------------------------
function F.compile()
  local nodes = {}
  local roots = {}

  -- First pass: Generate nodes for all scenarios.
  for name, details in pairs(F.registry) do
    nodes[name] = Node.new(name, details)
  end

  -- Second pass: Link parent/child relationsips.
  for name, details in pairs(F.registry) do
    local node = nodes[name]
    if details.from then
      local parent = nodes[details.from]
      assert(parent, "Parent scenario '" .. details.from .. "' not found for '" .. name .. "'")
      parent:add(node)
    else
      table.insert(roots, node)
    end
  end

  return roots
end

-----------------------------------------------------------------------------
function F.cmd(string, ...)
  local cmd = string.format(string, ...)
  if F.DEBUG then print("Executing command: \27[33m" .. cmd .. '\27[0m') end
  os.execute(cmd)
end

-----------------------------------------------------------------------------
function F.run(roots)
  -- Clean up saves from last run.
  F.cmd('rm %s/*.zip', F.SAVES)

  -- Kick off the root scenarios.
  for _, root in pairs(roots) do
    F.exec(root)
  end
end

-----------------------------------------------------------------------------
function F.exec(node, depth)
  local d = depth or 0
  local indent = string.rep(" ", d * 2)
  print(indent .. "running scenario: " .. node.name)

  -- Create the new save file.
  F.cmd('cp "%s" "%s"', F.starting_save(node), F.save_name(node))

  F.start_factorio(node, d)
  for _, child in pairs(node.children) do
    F.exec(child, d + 1)
  end
end

-----------------------------------------------------------------------------
function F.start_factorio(node, depth)
  local d = depth or 0
  local indent = string.rep(" ", d * 2)
  print(indent .. "..starting factorio for scenario: " .. node.name)

  -- Create the test name file.
  F.cmd('echo "%s" > "%s"', node.name, F.TEST_NAME_FILE)

  -- Start factorio with the new save file.
  F.cmd('%s --start-server-load-scenario "%s" --server-settings "%s" --mod-directory "%s" --disable-audio --nogamepad'
    , F.PATH
    , 'factestio/factestio'
--   ,  F.save_name(node)
    , F.SETTINGS
    , '/Users/chris/repo/factestio'
  )

  -- Clean up the test name file.
  F.cmd('rm "%s"', F.TEST_NAME_FILE)
end

-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------





return F
