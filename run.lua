#!/usr/bin/env lua

local argparse = require('argparse')
local f = require('scenarios.factestio.src.lib')

-- Process CLI arguments.
local parser = argparse('run', 'Run the Factestio Behvaior DAG')
parser:flag('-d --debug', 'Run in debug mode')
parser:option('-t --timeout', 'Timeout for each scenario in seconds', '8')

local args = parser:parse()
if args.debug then f.DEBUG = true end
f.TIMEOUT = tonumber(args.timeout)

-- Load the configuration and run DAG root scenarios.
f.load()
local roots = f.compile()
f.run(roots)
