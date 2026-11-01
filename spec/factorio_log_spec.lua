local FactorioLog = require("lib.factorio_log")

describe("FactorioLog.first_error", function()
  it("joins a timestamped error with its detail lines", function()
    local log = table.concat({
      "   0.000 2026-11-01 08:10:18; Factorio 2.1.24 (build 87808, mac-arm64, full, space-age)",
      '   0.258 Error Util.cpp:81: Failed to load mod "factestio": ',
      "    • Incompatible Factorio version (current: 2.1, required: 2.0)",
      "------------- Error -------------",
      'Failed to load mod "factestio": ',
    }, "\n")

    assert.equal(
      'Error Util.cpp:81: Failed to load mod "factestio": '
        .. "• Incompatible Factorio version (current: 2.1, required: 2.0)",
      FactorioLog.first_error(log)
    )
  end)

  it("handles an untimestamped error and stops at the next timestamped line", function()
    local log = table.concat({
      "   0.552 Info Create.cpp:32: Creating new map /tmp/factestio-root-save-init",
      'Error: An error occured while compiling "entity:coal:probability" noise expression:',
      "NoiseExpression cannot be NaN: spotNoise[3]",
      "   0.582 Goodbye",
    }, "\n")

    assert.equal(
      'Error: An error occured while compiling "entity:coal:probability" noise expression: '
        .. "NoiseExpression cannot be NaN: spotNoise[3]",
      FactorioLog.first_error(log)
    )
  end)

  it("ignores lines that only mention errors", function()
    assert.is_nil(FactorioLog.first_error("   0.100 Info Mod.cpp:1: Errors: none\n   0.200 Goodbye"))
  end)

  it("returns nil without a log", function()
    assert.is_nil(FactorioLog.first_error(nil))
  end)
end)
