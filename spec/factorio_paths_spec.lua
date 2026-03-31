local FactorioPaths = require("lib.factorio_paths")

describe("FactorioPaths.default_data_path", function()
  it("returns the macOS default for darwin", function()
    assert.equal(
      "/Users/chris/Library/Application Support/factorio",
      FactorioPaths.default_data_path("/Users/chris", "Darwin")
    )
  end)

  it("returns the Linux default for linux", function()
    assert.equal("/home/chris/.factorio", FactorioPaths.default_data_path("/home/chris", "Linux"))
  end)
end)

describe("FactorioPaths.default_binary_candidates", function()
  it("includes macOS candidates on darwin", function()
    assert.same({
      "/Applications/factorio.app/Contents/MacOS/factorio",
    }, FactorioPaths.default_binary_candidates("Darwin"))
  end)

  it("includes Linux candidates on linux", function()
    assert.same({
      "/home/chris/.factorio/bin/x64/factorio",
      "/home/chris/.steam/steam/steamapps/common/Factorio/bin/x64/factorio",
      "/home/chris/.local/share/Steam/steamapps/common/Factorio/bin/x64/factorio",
    }, FactorioPaths.default_binary_candidates("Linux", "/home/chris"))
  end)
end)

describe("FactorioPaths.detect", function()
  it("prefers explicit env overrides", function()
    local detected = FactorioPaths.detect({
      getenv = function(name)
        local env = {
          HOME = "/home/chris",
          FACTESTIO_FACTORIO_BINARY = "/custom/factorio",
          FACTESTIO_FACTORIO_DATA = "/custom/data",
        }
        return env[name]
      end,
      exists = function(path)
        return path == "/custom/factorio" or path == "/custom/data/mods"
      end,
      system_name = function()
        return "Linux"
      end,
    })

    assert.equal("/custom/factorio", detected.binary)
    assert.equal("/custom/data", detected.data)
    assert.is_true(detected.binary_ok)
    assert.is_true(detected.data_ok)
  end)

  it("discovers Linux defaults", function()
    local detected = FactorioPaths.detect({
      getenv = function(name)
        local env = {
          HOME = "/home/chris",
        }
        return env[name]
      end,
      exists = function(path)
        return path == "/home/chris/.local/share/Steam/steamapps/common/Factorio/bin/x64/factorio"
          or path == "/home/chris/.factorio/mods"
      end,
      system_name = function()
        return "Linux"
      end,
    })

    assert.equal("/home/chris/.local/share/Steam/steamapps/common/Factorio/bin/x64/factorio", detected.binary)
    assert.equal("/home/chris/.factorio", detected.data)
    assert.is_true(detected.binary_ok)
    assert.is_true(detected.data_ok)
  end)
end)
