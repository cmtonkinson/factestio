local Cli = require("lib.cli")

describe("factestio --help", function()
  it("prints a real help screen", function()
    local chunks = {}
    local stream = {
      write = function(_, chunk)
        table.insert(chunks, chunk)
      end,
    }

    Cli.write_help(stream, "0.0.19")

    local output = table.concat(chunks)

    assert.matches("^factestio 0%.0%.19", output)
    assert.matches("Hierarchical scenario%-based test framework", output)
    assert.is_truthy(output:find("factestio [command] [options] [mod_dir]", 1, true))
    assert.matches("%-%-doctor", output)
    assert.matches("activate", output)
    assert.matches("deactivate", output)
    assert.matches("%-%-leaf", output)
    assert.matches("%-%-branch", output)
    assert.matches("%-%-seed", output)
    assert.matches("%-%-keep%-other%-mods", output)
    assert.matches("%-%-timeout", output)
    assert.matches("%-%-help", output)
    assert.matches("Examples:", output)
  end)
end)
