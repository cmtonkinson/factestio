-- bin/factestio runs main.lua in the background and waits on it, so its exit
-- code is the only failure signal make and CI ever see.
describe("bin/factestio", function()
  local function exit_code(args)
    local _, _, code = os.execute('PATH="$PWD/.hererocks/bin:$PATH" bin/factestio ' .. args .. " >/dev/null 2>&1")
    return code
  end

  it("passes a failing exit code through", function()
    assert.equal(1, exit_code("--definitely-not-a-flag"))
  end)

  it("exits 0 when main.lua succeeds", function()
    assert.equal(0, exit_code("--version"))
  end)
end)
