local Cli = require("lib.cli")

describe("Cli.parse", function()
  it("parses activate with keep-other-mods", function()
    local parsed = assert(Cli.parse({ "activate", "--keep-other-mods", "/tmp/mod" }))

    assert.equal("activate", parsed.action)
    assert.is_true(parsed.keep_other_mods)
    assert.equal("/tmp/mod/", parsed.mod_dir)
  end)

  it("parses run seed", function()
    local parsed = assert(Cli.parse({ "--seed", "12345", "/tmp/mod" }))

    assert.equal("run", parsed.action)
    assert.equal(12345, parsed.seed)
    assert.equal("/tmp/mod/", parsed.mod_dir)
  end)

  it("parses leaf and branch selectors", function()
    local leaf = assert(Cli.parse({ "--leaf", "basic.setup", "/tmp/mod" }))
    local branch = assert(Cli.parse({ "--branch=regressions.setup", "/tmp/mod" }))

    assert.equal("run", leaf.action)
    assert.equal("basic.setup", leaf.leaf)
    assert.is_nil(leaf.branch)
    assert.equal("run", branch.action)
    assert.equal("regressions.setup", branch.branch)
    assert.is_nil(branch.leaf)
  end)

  it("parses deactivate", function()
    local parsed = assert(Cli.parse({ "deactivate", "/tmp/mod" }))

    assert.equal("deactivate", parsed.action)
    assert.equal("/tmp/mod/", parsed.mod_dir)
  end)

  it("rejects keep-other-mods outside activate", function()
    local parsed, err = Cli.parse({ "--keep-other-mods" })

    assert.is_nil(parsed)
    assert.matches("only applies to activate", err.message)
  end)

  it("rejects leaf and branch together", function()
    local parsed, err = Cli.parse({ "--leaf", "a", "--branch", "b" })

    assert.is_nil(parsed)
    assert.matches("mutually exclusive", err.message)
  end)
end)
