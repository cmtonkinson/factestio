#!/usr/bin/env lua

local Cli = require("lib.cli")
local DoctorCommand = require("lib.commands.doctor")
local OffCommand = require("lib.commands.off")
local OnCommand = require("lib.commands.on")
local ProjectConfig = require("lib.project_config")
local RunCommand = require("lib.commands.run")
local System = require("lib.system")
local Version = require("lib.version")

local root = System.ensure_trailing_slash(os.getenv("FACTESTIO_ROOT") or "./")
local version = Version.read(root)

local parsed, err = Cli.parse(arg)
if not parsed then
  if err.message then
    io.stderr:write(err.message)
  end
  if err.show_help then
    Cli.write_help(io.stderr, version)
  end
  os.exit(1)
end

if parsed.action == "help" then
  Cli.write_help(io.stdout, version)
  os.exit(0)
end

if parsed.action == "version" then
  print("factestio " .. version)
  os.exit(0)
end

if parsed.action == "doctor" then
  os.exit(DoctorCommand.run())
end

local configuration, config_err = ProjectConfig.load(parsed.mod_dir, {
  allow_missing = parsed.action == "on" or parsed.action == "off",
})
if config_err then
  io.stderr:write(config_err)
  os.exit(1)
end

local data_path = ProjectConfig.data_path(configuration)

local exit_code, command_err
if parsed.action == "on" then
  exit_code, command_err = OnCommand.run(root, parsed.mod_dir, parsed.quiet)
elseif parsed.action == "off" then
  exit_code, command_err = OffCommand.run(root, data_path, parsed.quiet)
else
  exit_code, command_err = RunCommand.run(root, parsed.mod_dir, data_path, parsed.debug, parsed.timeout)
end

if not exit_code then
  io.stderr:write(command_err)
  os.exit(1)
end

os.exit(exit_code)
