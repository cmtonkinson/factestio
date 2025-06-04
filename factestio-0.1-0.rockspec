package = "factestio"
version = "0.1-0"
source = {
  url = "https://gitlab.com/cmtonkinson/factestio.git",
}
description = {
  summary = "A Lua library for creating heirarchical Factorio test scenarios",
  license = "MIT",
}
dependencies = {
  "argparse >= 0.7.1",
  "lua >= 5.1, < 5.5",
  "lua-cjson >= 2.1.0",
  "luassert >= 1.9.0 < 2.0",
  "serpent >= 0.30-2",
}
build = {
  type = "builtin",
  modules = {
    factestio = "src/factestio.lua",
  },
}
