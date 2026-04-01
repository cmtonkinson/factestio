rockspec_format = "3.0"
package = "factestio"
version = "0.2.3-0"
source = {
  url = "git+https://github.com/cmtonkinson/factestio.git",
}
description = {
  summary = "A Lua library for creating hierarchical Factorio test scenarios",
  license = "MIT",
}
dependencies = {
  "argparse >= 0.7.1",
  "lua >= 5.2, < 5.3",
  "dkjson >= 2.8",
  "serpent >= 0.30-2",
}
test_dependencies = {
  "busted",
  "luacheck",
}
test = {
  type = "busted",
}
