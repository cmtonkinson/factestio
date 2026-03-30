local F = {}
require("scenarios.factestio.src.lib_helpers")(F)

describe("F.shell_quote", function()
  it("wraps a plain string in single quotes", function()
    assert.are.equal("'hello'", F.shell_quote("hello"))
  end)

  it("wraps an empty string in single quotes", function()
    assert.are.equal("''", F.shell_quote(""))
  end)

  it("escapes an internal single quote", function()
    assert.are.equal("'it'\\''s'", F.shell_quote("it's"))
  end)

  it("wraps a string with spaces in single quotes", function()
    assert.are.equal("'hello world'", F.shell_quote("hello world"))
  end)

  it("wraps a string containing double quotes in single quotes", function()
    assert.are.equal("'say \"hi\"'", F.shell_quote('say "hi"'))
  end)

  it("safely wraps a string with shell metacharacter $", function()
    assert.are.equal("'$HOME'", F.shell_quote("$HOME"))
  end)

  it("safely wraps a string with shell metacharacter !", function()
    assert.are.equal("'!foo'", F.shell_quote("!foo"))
  end)

  it("safely wraps a string with shell metacharacter `", function()
    assert.are.equal("'`cmd`'", F.shell_quote("`cmd`"))
  end)

  it("safely wraps a string with shell metacharacter ;", function()
    assert.are.equal("'a;b'", F.shell_quote("a;b"))
  end)

  it("converts a number to string and wraps in single quotes", function()
    assert.are.equal("'42'", F.shell_quote(42))
  end)

  it("preserves a backslash inside single quotes", function()
    assert.are.equal("'a\\b'", F.shell_quote("a\\b"))
  end)
end)
