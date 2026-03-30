return function(F)
  -----------------------------------------------------------------------------
  function F.invoke(self, node, helpers, game, player, event)
    -- We bundle a bunch of stuff into a single table so that it's easy to pass
    -- parameters down, and get metadata back up (via node.data)
    self.context = {
      game = game,
      player = player,
      event = event,
      node = node,
    }

    -- We lump the before/test/after functions together in an isolated function
    -- so that we can pcall THAT. This lets us fail the whole thing immediately
    -- if anything raises an error.
    local ok, err = pcall(F.execute_test, self)
    if ok then
      node.data.status = "pass"
    else
      node.data.status = "fail"
      node.data.error = err
    end

    -- Store the results where the outer script can find them.
    local json = helpers.table_to_json({
      stats = node.data.stats,
      error = node.data.error,
      status = node.data.status,
    })
    helpers.write_file(F.results_file(node), json)
  end

  -----------------------------------------------------------------------------
  function F.execute_test(self)
    local data = self.context.node.data

    -- Yes, passing both `self` and `self.context` is technically redundant.
    -- Sue me.
    if data.before then
      local before_ok, before_err = pcall(function()
        data.before(self, self.context)
      end)
      if not before_ok then
        error(before_err, 0)
      end
    end
    local test_ok, test_err = pcall(function()
      data.test(self, self.context)
    end)
    local after_ok, after_err = true, nil
    if data.after then
      after_ok, after_err = pcall(function()
        data.after(self, self.context)
      end)
    end
    if not test_ok then
      error(test_err, 0)
    elseif not after_ok then
      error(after_err, 0)
    end
  end

  -----------------------------------------------------------------------------
  function F.expect(self, actual, expected)
    local context = self.context
    local data = context.node.data
    local stats = data.stats
    local result = actual == expected

    stats.assertions = stats.assertions + 1

    if result then
      stats.passed = stats.passed + 1
      return true
    else
      stats.failed = stats.failed + 1
      data.status = "fail"
      local function fmt(v)
        if type(v) == "table" then
          return serpent.line(v, { nocode = true })
        end
        return tostring(v)
      end
      local output = string.format("Expected %s but got %s", fmt(expected), fmt(actual))
      F.red(output)
      error(output)
    end
  end

  return F
end
