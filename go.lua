local e = require("example")
local f = require("src.factestio")

f.set_path("/Applications/factorio.app/Contents/MacOS/factorio")
local roots = f.compile()
f.run(roots)

