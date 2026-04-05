local Shell = require("lib.shell")

describe("Shell", function()
  local original_execute
  local original_popen
  local original_io_open

  before_each(function()
    original_execute = os.execute
    original_popen = io.popen
    original_io_open = io.open
  end)

  after_each(function()
    os.execute = original_execute -- luacheck: ignore
    io.popen = original_popen -- luacheck: ignore
    io.open = original_io_open -- luacheck: ignore
  end)

  it("quotes shell arguments safely", function()
    assert.equal("'it'\\''s'", Shell.quote("it's"))
  end)

  it("wraps cp without exposing shell interpolation at the call site", function()
    local seen
    os.execute = function(cmd) -- luacheck: ignore
      seen = cmd
      return true
    end

    assert.is_true(Shell.cp("/tmp/src file", "/tmp/dst file"))
    assert.equal("'cp' '/tmp/src file' '/tmp/dst file'", seen)
  end)

  it("writes command output to a file path", function()
    local seen
    os.execute = function(cmd) -- luacheck: ignore
      seen = cmd
      return true
    end

    assert.is_true(Shell.write_output("/tmp/out.json", "jq", { "-n", "{x:1}" }))
    assert.equal("'jq' '-n' '{x:1}' > '/tmp/out.json'", seen)
  end)

  it("launches a background process via one helper", function()
    local seen
    os.execute = function(cmd) -- luacheck: ignore
      seen = cmd
      return true
    end

    assert.is_true(
      Shell.launch_background({ "/bin/factorio", "--start-server" }, "/tmp/stdout", "/tmp/pid", "/tmp/rootpid")
    )
    assert.matches("^'sh' '%-c' ", seen)
    assert.matches("/bin/factorio", seen)
    assert.matches("%-%-start%-server", seen)
  end)

  it("captures command output", function()
    io.popen = function(cmd) -- luacheck: ignore
      assert.equal("'readlink' '/tmp/link' 2>/dev/null", cmd)
      return {
        read = function()
          return "/tmp/target\n"
        end,
        close = function()
          return true
        end,
      }
    end

    assert.equal("/tmp/target", Shell.readlink("/tmp/link"))
  end)
end)
