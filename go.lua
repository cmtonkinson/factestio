local e = require("tests.example")
local f = require("scenarios.factestio.src.factestio")

f.set_factorio_binary("/Applications/factorio.app/Contents/MacOS/factorio")
f.set_factorio_data_path("/Users/chris/Library/Application Support/factorio/")
f.set_project_path("/Users/chris/repo/factestio")
f.init()

f.register_scenarios(e)

local roots = f.compile()
f.run(roots)

