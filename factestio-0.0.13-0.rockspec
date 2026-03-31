rockspec_format = "3.0"
package = "factestio"
version = "0.0.13-0"
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
  "lua-cjson >= 2.1.0",
  "serpent >= 0.30-2",
}
test_dependencies = {
  "busted",
  "luacheck",
}
test = {
  type = "busted",
}
