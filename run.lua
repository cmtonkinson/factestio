#!/usr/bin/env lua

local F = require('scenarios.factestio.src.lib')

local argparse = require('argparse')
local os       = require('os')

-----------------------------------------------------------------------------
-- Process CLI arguments and flags.
local parser = argparse()
  :name('run')
  :description('Run the Factestio Behvaior DAG')
  :epilog('For more information, visit https://gitlab.com/cmtonkinson/factestio')
parser:flag('-d --debug')
  :description('Run in debug mode')
parser:option('-t --timeout')
  :description('Timeout for each scenario in seconds')
  :default('8')
  :convert(tonumber)

local args = parser:parse()
F.DEBUG = args.debug
F.TIMEOUT = args.timeout

-----------------------------------------------------------------------------
-- Load the configured DAG and run the root scenarios.
F.load()
local roots = F.compile()
F.run(roots)

if F.had_failures then
  os.exit(1)
else
  os.exit(0)
end
