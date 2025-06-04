#!/usr/bin/env lua

local argparse = require('argparse')
local f = require('scenarios.factestio.src.lib')

-- Process CLI arguments.
local parser = argparse('run', 'Run the Factestio Behvaior DAG')
parser:flag('-d --debug')
  :description('Run in debug mode')
parser:option('-t --timeout')
  :description('Timeout for each scenario in seconds')
  :default('8')
  :convert(tonumber)

local args = parser:parse()
f.DEBUG = args.debug
f.TIMEOUT = args.timeout

-- Load the configuration and run DAG root scenarios.
f.load()
local roots = f.compile()
f.run(roots)
