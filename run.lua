local f = require('scenarios.factestio.src.lib')

f.load()
local roots = f.compile()
f.run(roots)
