local Doctor = require("lib.factestio_doctor")

local Command = {}

function Command.run()
  return Doctor.run() and 0 or 1
end

return Command
