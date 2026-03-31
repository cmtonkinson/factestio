return function(F)
  local Node = require(F.LOAD_PATH_PREFIX .. "src.node")

  -----------------------------------------------------------------------------
  function F.discovered_test_files(paths)
    local file_names = {}

    for _, path in ipairs(paths) do
      local file_name = path:match("([^/]+)%.lua$")
      if file_name and file_name ~= "config" then
        table.insert(file_names, file_name)
      end
    end

    table.sort(file_names)
    return file_names
  end

  -----------------------------------------------------------------------------
  function F.load()
    local configuration = require("factestio.config")
    F.set_paths(configuration.os_paths)

    local file_names
    if _G.script == nil then
      file_names = F.discover_test_files()
      F.write_test_manifest(file_names)
    else
      file_names = require("test_files")
    end

    for _, file_name in ipairs(file_names) do
      local scenarios_tbl = require("factestio." .. file_name)
      -- Register with prefixed names, resolve from
      for name, config in pairs(scenarios_tbl) do
        local prefixed_name = file_name .. "." .. name
        -- Resolve 'from': if it's a bare name (no dot), it's relative to this file
        if config.from then
          if not config.from:find("%.") then
            -- bare name — resolve to same file
            config.from = file_name .. "." .. config.from
          end
          -- else: already qualified (e.g. 'other_file.setup') — leave as-is
        end
        F.register_scenario(prefixed_name, config)
      end
    end
  end

  -----------------------------------------------------------------------------
  function F.ensure_trailing_slash(path)
    if path:sub(-1) ~= "/" then
      return path .. "/"
    end
    return path
  end

  -----------------------------------------------------------------------------
  function F.set_paths(cfg)
    assert(type(cfg) == "table", "Factestio.config: cfg must be a table")
    if cfg.binary then
      F.FACTORIO_BINARY = cfg.binary
    end
    if cfg.data then
      F.FACTORIO_DATA_PATH = F.ensure_trailing_slash(cfg.data)
    end
  end

  -----------------------------------------------------------------------------
  function F.register_scenario(name, config)
    assert(type(name) == "string", "name must be a string")
    assert(name:match("^[%w_.%-]+$"), "name must only contain letters, numbers, underscores, dashes, and dots")

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

    if F.registry[name] then
      error(
        "Duplicate test name '" .. name .. "': already registered. Test names must be unique across all test files."
      )
    end
    F.registry[name] = config
  end

  -----------------------------------------------------------------------------
  function F.fully_qualified_name(node)
    local fqn = node.data.name
    if node.parent then
      fqn = F.fully_qualified_name(node.parent) .. "." .. fqn
    end
    return fqn
  end

  -----------------------------------------------------------------------------
  -- Factorio treats dots in save names as file extensions and truncates them.
  -- Replace dots with hyphens so "example.setup" → "example-setup".
  function F.safe_save_name(name)
    return name:gsub("%.", "-")
  end

  -----------------------------------------------------------------------------
  function F.save_name(node)
    return F.RESULTS_ROOT
      .. "/"
      .. F.fully_qualified_name(node)
      .. "/factestio-"
      .. F.safe_save_name(node.data.name)
      .. ".zip"
  end

  -----------------------------------------------------------------------------
  function F.starting_save(node)
    if node.parent then
      return F.save_name(node.parent)
    else
      return "root-save.zip"
    end
  end

  -----------------------------------------------------------------------------
  function F.compile()
    local roots = {}

    -- First pass: Generate nodes for all scenarios.
    for name, config in pairs(F.registry) do
      local d = {}
      d.name = name
      d.from = config.from
      d.root = false
      d.before = config.before
      d.test = config.test
      d.after = config.after
      d.status = "pending"
      d.error = ""
      d.stats = {
        assertions = 0,
        passed = 0,
        failed = 0,
      }
      -- Replace the original registry configuration with the new Node.
      F.registry[name] = Node.new(name, d)
    end

    -- Second pass: Link parent/child relationships.
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

    -- Third pass: Sort children of every node for deterministic execution order.
    for _, node in pairs(F.registry) do
      table.sort(node.children, function(a, b)
        return a.data.name < b.data.name
      end)
    end

    -- Third pass: detect cycles
    local function check_cycles(node, visited, path)
      if visited[node.data.name] then
        local cycle = {}
        for _, n in ipairs(path) do
          table.insert(cycle, n)
        end
        table.insert(cycle, node.data.name)
        error("Cycle detected in test DAG: " .. table.concat(cycle, " -> "))
      end
      visited[node.data.name] = true
      table.insert(path, node.data.name)
      for _, child in ipairs(node.children) do
        check_cycles(child, visited, path)
      end
      visited[node.data.name] = nil
      table.remove(path)
    end
    -- Note: cycle detection only covers root-reachable nodes. A group of nodes
    -- that all have 'from' set (no roots among them) would form an orphaned
    -- subgraph that is never reached here. Those nodes simply produce no roots
    -- and are silently excluded from the run — they do not cause an error.
    for _, root in ipairs(roots) do
      check_cycles(root, {}, {})
    end

    table.sort(roots, function(a, b)
      return a.data.name < b.data.name
    end)

    -- Return DAG roots.
    return roots
  end

  -----------------------------------------------------------------------------
  function F.results_file(node)
    return "factestio-" .. node.data.name .. "-results.json"
  end

  return F
end
