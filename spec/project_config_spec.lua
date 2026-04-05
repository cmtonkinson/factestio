local ProjectConfig = require("lib.project_config")
local System = require("lib.system")

describe("ProjectConfig", function()
  local original_read_file

  before_each(function()
    original_read_file = System.read_file
    ProjectConfig.clear_cache()
  end)

  after_each(function()
    System.read_file = original_read_file
    ProjectConfig.clear_cache()
  end)

  it("caches decoded info.json per mod dir", function()
    local reads = 0
    System.read_file = function(path)
      reads = reads + 1
      assert.equal("/tmp/mod/info.json", path)
      return [[{"name":"demo-mod","title":"Demo Mod"}]]
    end

    assert.equal("demo-mod", ProjectConfig.name("/tmp/mod/"))
    assert.equal("Demo Mod", ProjectConfig.title("/tmp/mod/"))
    assert.equal(1, reads)
  end)
end)
