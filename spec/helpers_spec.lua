local Shell = require("lib.shell")

describe("Shell.quote", function()
  it("wraps a plain string in single quotes", function()
    assert.are.equal("'hello'", Shell.quote("hello"))
  end)

  it("wraps an empty string in single quotes", function()
    assert.are.equal("''", Shell.quote(""))
  end)

  it("escapes an internal single quote", function()
    assert.are.equal("'it'\\''s'", Shell.quote("it's"))
  end)

  it("wraps a string with spaces in single quotes", function()
    assert.are.equal("'hello world'", Shell.quote("hello world"))
  end)

  it("wraps a string containing double quotes in single quotes", function()
    assert.are.equal("'say \"hi\"'", Shell.quote('say "hi"'))
  end)

  it("safely wraps a string with shell metacharacter $", function()
    assert.are.equal("'$HOME'", Shell.quote("$HOME"))
  end)

  it("safely wraps a string with shell metacharacter !", function()
    assert.are.equal("'!foo'", Shell.quote("!foo"))
  end)

  it("safely wraps a string with shell metacharacter `", function()
    assert.are.equal("'`cmd`'", Shell.quote("`cmd`"))
  end)

  it("safely wraps a string with shell metacharacter ;", function()
    assert.are.equal("'a;b'", Shell.quote("a;b"))
  end)

  it("converts a number to string and wraps in single quotes", function()
    assert.are.equal("'42'", Shell.quote(42))
  end)

  it("preserves a backslash inside single quotes", function()
    assert.are.equal("'a\\b'", Shell.quote("a\\b"))
  end)
end)
