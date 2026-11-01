local ProjectLinks = require("lib.project_links")
local Shell = require("lib.shell")

local function temp_dir()
  local base = string.format("/tmp/factestio-links-%d-%d/", os.time(), math.random(100000, 999999))
  assert(Shell.mkdir_p(base .. "data/mods"))
  assert(Shell.mkdir_p(base .. "factestio"))
  assert(Shell.mkdir_p(base .. "sut"))
  assert(Shell.mkdir_p(base .. "elsewhere"))
  return base
end

describe("ProjectLinks baseline", function()
  local base, data_path

  before_each(function()
    math.randomseed(os.time())
    base = temp_dir()
    data_path = base .. "data/"
  end)

  after_each(function()
    Shell.rm_rf(base)
  end)

  it("restores a link that existed before activation and removes ones it created", function()
    local sut_link = data_path .. "mods/sut"
    local factestio_link = data_path .. "mods/factestio"
    assert(Shell.ln_s(base .. "elsewhere", sut_link))

    assert(ProjectLinks.record_baseline(data_path, "sut"))
    assert(ProjectLinks.ensure_mod_symlink(base .. "factestio/", data_path, true))
    assert(ProjectLinks.ensure_sut_symlink(base .. "sut/", "sut", data_path, true))
    assert.equal(Shell.realpath(base .. "sut"), Shell.realpath(Shell.readlink(sut_link)))

    -- A second activate in the same session must not record factestio's own links.
    assert(ProjectLinks.record_baseline(data_path, "sut"))

    assert(ProjectLinks.remove_mod_symlink(data_path, true))
    assert(ProjectLinks.remove_sut_symlink(data_path, "sut", true))

    assert.is_false(Shell.test_exists_or_symlink(factestio_link))
    assert.equal(base .. "elsewhere", Shell.readlink(sut_link))
  end)

  it("only removes links when no baseline was recorded", function()
    local sut_link = data_path .. "mods/sut"
    assert(Shell.ln_s(base .. "sut", sut_link))

    assert(ProjectLinks.remove_sut_symlink(data_path, "sut", true))

    assert.is_false(Shell.test_exists_or_symlink(sut_link))
  end)
end)
