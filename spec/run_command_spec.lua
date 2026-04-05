local Command = require("lib.commands.run")

describe("RunCommand.run", function()
  local original_verify_mod_root
  local original_mod_list_enabled
  local original_read_version

  before_each(function()
    original_verify_mod_root = require("lib.project_links").verify_mod_root
    original_mod_list_enabled = require("lib.mod_list").enabled
    original_read_version = require("lib.version").read
  end)

  after_each(function()
    require("lib.project_links").verify_mod_root = original_verify_mod_root
    require("lib.mod_list").enabled = original_mod_list_enabled
    require("lib.version").read = original_read_version
  end)

  it("fails fast when factestio is not active in mod-list.json", function()
    require("lib.project_links").verify_mod_root = function()
      return true
    end
    require("lib.mod_list").enabled = function()
      return false
    end
    require("lib.version").read = function()
      return "0.0.0"
    end

    local ok, err = Command.run("/tmp/root/", "/tmp/mod/", "/tmp/data/", false, 8, 123, nil, nil)

    assert.is_nil(ok)
    assert.matches("factestio is not enabled in mod%-list%.json", err)
    assert.matches("factestio activate", err)
  end)
end)
