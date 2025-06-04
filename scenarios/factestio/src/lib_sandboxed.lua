return function(F)

-----------------------------------------------------------------------------
function F.invoke(self, node, helpers, game, player, event)
  -- We bundle a bunch of stuff into a single table so that it's easy to pass
  -- parameters down, and get metadata back up (via node.data)
  self.context = {
    game   = game,
    player = player,
    event  = event,
    node   = node,
  }

  -- We lump the before/test/after functions together in an isolated function
  -- so that we can pcall THAT. This lets us fail the whole thing immediately
  -- if anything raises an error.
  local ok, err = pcall(F.execute_test, self)
  if ok then
    node.data.status = 'pass'
  else
    node.data.status = 'fail'
    node.data.error = err
  end

  -- Store the results where the outer script can find them.
  local json = helpers.table_to_json({
    stats  = node.data.stats,
    error  = node.data.error,
    status = node.data.status,
  })
  helpers.write_file(F.results_file(node), json)
end

-----------------------------------------------------------------------------
function F.execute_test(self)
  local node = self.context.node

  -- Yes, passing both `self` and `self.context` is technically redundant.
  -- Sue me.
  if node.before then node.before(self, self.context) end
  node.test(self, self.context)
  if node.after then node.after(self, self.context) end
end

-----------------------------------------------------------------------------
function F.expect(self, actual, expected)
  local context = self.context
  local node = context.node
  local stats = node.data.stats
  local result = actual == expected

  stats.assertions = stats.assertions + 1

  if result then
    stats.passed = stats.passed + 1
    return true
  else
    stats.failed = stats.failed + 1
    node.data.status = 'fail'
    local output = string.format("Expected '%s' but got '%s'", expected, actual)
    F.red(output)
    error(output)
  end
end
return F
end
