local FactorioFlags = require("lib.factorio_flags")

local function help_text(text)
  return function(binary, args)
    assert.equal("/bin/factorio", binary)
    assert.same({ "--help" }, args)
    return text
  end
end

describe("FactorioFlags.client", function()
  it("passes the client flags a desktop build lists", function()
    local help = "      --disable-audio           Disable audio.\n      --nogamepad               Disable gamepad\n"
    assert.same({ "--disable-audio", "--nogamepad" }, FactorioFlags.client("/bin/factorio", help_text(help)))
  end)

  it("passes none to a headless build, which rejects them", function()
    local help = "Usage:\n  factorio [OPTION...]\n      --server-settings FILE    Path to file with server settings.\n"
    assert.same({}, FactorioFlags.client("/bin/factorio", help_text(help)))
  end)

  it("passes none when --help produces nothing", function()
    assert.same({}, FactorioFlags.client("/bin/factorio", help_text(nil)))
  end)
end)
