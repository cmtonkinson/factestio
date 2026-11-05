local ProjectConfig = require("lib.project_config")
local System = require("lib.system")

describe("ProjectConfig", function()
  local original_read_file

  before_each(function()
    original_read_file = System.read_file
  end)

  after_each(function()
    System.read_file = original_read_file
  end)

  it("reads name and title from info.json", function()
    System.read_file = function(path)
      assert.equal("/tmp/mod/info.json", path)
      return [[{"name":"demo-mod","title":"Demo Mod"}]]
    end

    assert.equal("demo-mod", ProjectConfig.name("/tmp/mod/"))
    assert.equal("Demo Mod", ProjectConfig.title("/tmp/mod/"))
  end)

  it("returns nil for unreadable or invalid info.json", function()
    System.read_file = function()
      return "not json"
    end

    assert.is_nil(ProjectConfig.name("/tmp/mod/"))
  end)

  describe("map_radius", function()
    local function with_options(content)
      System.read_file = function(path)
        assert.equal("/tmp/mod/factestio/options.lua", path)
        return content
      end
    end

    it("falls back to the default without an options file or a map_radius", function()
      local default = require("lib.constants").RUNTIME.DEFAULT_MAP_RADIUS

      with_options(nil)
      assert.equal(default, ProjectConfig.map_radius("/tmp/mod/"))

      with_options("return {}")
      assert.equal(default, ProjectConfig.map_radius("/tmp/mod/"))
    end)

    it("reads map_radius from options.lua", function()
      with_options("return { map_radius = 0 }")
      assert.equal(0, ProjectConfig.map_radius("/tmp/mod/"))

      with_options("return { map_radius = 33 }")
      assert.equal(33, ProjectConfig.map_radius("/tmp/mod/"))
    end)

    it("rejects a radius that is not a whole number of chunks, 0 or more", function()
      for _, value in ipairs({ "-1", "2.5", '"20"', "true" }) do
        with_options("return { map_radius = " .. value .. " }")
        assert.has_error(function()
          ProjectConfig.map_radius("/tmp/mod/")
        end, "Error: map_radius in /tmp/mod/factestio/options.lua must be a whole number of chunks, 0 or more")
      end
    end)

    it("rejects unknown options, a non-table, and a file that does not parse", function()
      with_options("return { map_radus = 20 }")
      assert.has_error(function()
        ProjectConfig.map_radius("/tmp/mod/")
      end, "Error: unknown option 'map_radus' in /tmp/mod/factestio/options.lua")

      with_options("return 20")
      assert.has_error(function()
        ProjectConfig.map_radius("/tmp/mod/")
      end, "Error: /tmp/mod/factestio/options.lua must return a table")

      with_options("return {")
      assert.has_error(function()
        ProjectConfig.map_radius("/tmp/mod/")
      end)
    end)
  end)
end)
