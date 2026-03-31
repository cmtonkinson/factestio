local Json = require("lib.factestio_json")

describe("Json.decode", function()
  it("decodes valid JSON", function()
    local decoded = Json.decode('{"status":"pass","stats":{"failed":0}}', "results.json")

    assert.same({
      status = "pass",
      stats = {
        failed = 0,
      },
    }, decoded)
  end)

  it("errors with the source path on invalid JSON", function()
    assert.has_error(function()
      Json.decode("{invalid", "results.json")
    end, "Error: could not decode JSON from results.json: no valid JSON value at line 1, column 2")
  end)
end)
