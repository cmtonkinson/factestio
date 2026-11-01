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
end)
