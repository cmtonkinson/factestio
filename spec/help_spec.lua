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
    assert.matches("Usage:%s+factestio %[%options%] %[%mod_dir%]", output)
    assert.matches("%-%-doctor", output)
    assert.matches("%-%-on", output)
    assert.matches("%-%-off", output)
    assert.matches("%-%-timeout", output)
    assert.matches("%-%-help", output)
    assert.matches("Examples:", output)
  end)
end)
