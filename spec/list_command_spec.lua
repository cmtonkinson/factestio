local Command = require("lib.commands.list")

describe("ListCommand.run", function()
  local original_lib

  before_each(function()
    original_lib = package.loaded["scenarios.factestio.src.lib"]
  end)

  after_each(function()
    package.loaded["scenarios.factestio.src.lib"] = original_lib
  end)

  local function stub_runner()
    local writes = {}
    local root = { data = { name = "alpha.setup" }, children = {} }
    local child = { data = { name = "alpha.child" }, children = {} }
    child.parent = root
    root.children = { child }
    local registry = {
      ["alpha.setup"] = root,
      ["alpha.child"] = child,
    }
    local fake = {}
    fake.registry = registry
    fake.load = function() end
    fake.init = function() end
    fake.compile = function()
      return { root }
    end
    fake.find_node = function(name)
      return registry[name]
    end
    fake.find_nodes_by_prefix = function(prefix)
      local matches = {}
      local dotted_prefix = prefix .. "."
      for name, node in pairs(registry) do
        if name == prefix or name:sub(1, #dotted_prefix) == dotted_prefix then
          table.insert(matches, node)
        end
      end
      table.sort(matches, function(a, b)
        return a.data.name < b.data.name
      end)
      return matches
    end
    fake.serialize_node = function(node)
      local children = {}
      for _, c in ipairs(node.children) do
        table.insert(children, { name = c.data.name, children = {} })
      end
      return { name = node.data.name, children = children }
    end
    fake.write_node_lines = function(stream, nodes, depth)
      local indent = string.rep(" ", (depth or 0) * 2)
      for _, node in ipairs(nodes) do
        stream:write(indent .. node.data.name .. "\n")
        fake.write_node_lines(stream, node.children, (depth or 0) + 1)
      end
    end
    package.loaded["scenarios.factestio.src.lib"] = fake
    local stream = {
      write = function(_, chunk)
        table.insert(writes, chunk)
      end,
    }
    return fake, writes, stream
  end

  it("writes text output for the full list", function()
    local _, writes, stream = stub_runner()

    assert.equal(0, Command.run("/tmp/root/", "/tmp/mod/", false, nil, false, stream))
    assert.equal("alpha.setup\n  alpha.child\n", table.concat(writes))
  end)

  it("writes text output for children", function()
    local _, writes, stream = stub_runner()

    assert.equal(0, Command.run("/tmp/root/", "/tmp/mod/", false, "alpha.setup", false, stream))
    assert.equal("alpha.setup\n  alpha.child\n", table.concat(writes))
  end)

  it("accepts a suite prefix for children", function()
    local _, writes, stream = stub_runner()

    assert.equal(0, Command.run("/tmp/root/", "/tmp/mod/", false, "alpha", false, stream))
    assert.equal("alpha.setup\n  alpha.child\n", table.concat(writes))
  end)

  it("writes text output for roots only", function()
    local _, writes, stream = stub_runner()

    assert.equal(0, Command.run("/tmp/root/", "/tmp/mod/", true, nil, false, stream))
    assert.equal("alpha.setup\n", table.concat(writes))
  end)

  it("writes json output", function()
    local _, writes, stream = stub_runner()

    assert.equal(0, Command.run("/tmp/root/", "/tmp/mod/", false, nil, true, stream))
    assert.matches('"name":"alpha%.setup"', table.concat(writes))
    assert.matches('"name":"alpha%.child"', table.concat(writes))
  end)

  it("writes json output for roots only", function()
    local _, writes, stream = stub_runner()

    assert.equal(0, Command.run("/tmp/root/", "/tmp/mod/", true, nil, true, stream))
    assert.matches('"name":"alpha%.setup"', table.concat(writes))
    assert.does_not_match('"name":"alpha%.child"', table.concat(writes))
  end)

  it("errors on unknown child ids", function()
    local _, _, stream = stub_runner()

    local ok, err = Command.run("/tmp/root/", "/tmp/mod/", false, "ghost.test", false, stream)
    assert.is_nil(ok)
    assert.matches("Unknown scenario id: ghost%.test", err)
  end)
end)
