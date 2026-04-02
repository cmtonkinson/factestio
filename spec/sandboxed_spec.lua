local function new_sandboxed_F()
  local F = {}
  require("scenarios.factestio.src.lib_sandboxed")(F)
  return F
end

describe("sandboxed helpers", function()
  local original_settings

  before_each(function()
    original_settings = rawget(_G, "settings")
  end)

  after_each(function()
    _G.settings = original_settings
  end)

  it("with_player_settings merges overrides for one player and restores settings", function()
    local F = new_sandboxed_F()
    local player = { index = 1 }
    local seen

    _G.settings = {
      get_player_settings = function(index)
        assert.equal(1, index)
        return {
          untouched = { value = "keep" },
          override_me = { value = "old" },
        }
      end,
    }

    F:with_player_settings(player, {
      override_me = "new",
      added = 7,
    }, function(current_player)
      assert.equal(player, current_player)
      seen = _G.settings.get_player_settings(1)
      assert.equal("keep", seen.untouched.value)
      assert.equal("new", seen.override_me.value)
      assert.equal(7, seen.added.value)
    end)

    assert.equal("old", _G.settings.get_player_settings(1).override_me.value)
  end)

  it("with_player_settings restores settings when the callback fails", function()
    local F = new_sandboxed_F()
    local player = { index = 1 }

    _G.settings = {
      get_player_settings = function()
        return {
          baseline = { value = "original" },
        }
      end,
    }

    local ok, err = pcall(function()
      F:with_player_settings(player, {
        baseline = "temporary",
      }, function()
        error("boom")
      end)
    end)

    assert.is_false(ok)
    assert.matches("boom", err)
    assert.equal("original", _G.settings.get_player_settings(1).baseline.value)
  end)

  it("with_player_settings falls back to player index 1 when none is provided", function()
    local F = new_sandboxed_F()
    local seen_index

    _G.settings = {
      get_player_settings = function(index)
        seen_index = index
        return {}
      end,
    }

    F:with_player_settings(nil, {
      only = "value",
    }, function(player)
      assert.equal(1, player.index)
      assert.equal("value", _G.settings.get_player_settings(1).only.value)
    end)

    assert.equal(1, seen_index)
  end)

  it("with_player_settings tolerates real settings lookup failure", function()
    local F = new_sandboxed_F()

    _G.settings = {
      get_player_settings = function()
        error("Invalid PlayerIdentification")
      end,
    }

    F:with_player_settings(nil, {
      only = "value",
    }, function(player)
      assert.equal(1, player.index)
      assert.equal("value", _G.settings.get_player_settings(1).only.value)
    end)
  end)
end)
