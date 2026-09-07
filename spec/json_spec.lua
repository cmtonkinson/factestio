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
    -- Match only factestio's own message format. The reason is dkjson's wording,
    -- which varies across the versions the rockspec allows.
    local ok, err = pcall(Json.decode, "{invalid", "results.json")

    assert.is_false(ok)
    assert.matches("Error: could not decode JSON from results%.json: .+", err)
  end)
end)
