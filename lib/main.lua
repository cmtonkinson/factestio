#!/usr/bin/env lua

local ActivateCommand = require("lib.commands.activate")
local Cli = require("lib.cli")
local DeactivateCommand = require("lib.commands.deactivate")
local DoctorCommand = require("lib.commands.doctor")
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
  allow_missing = parsed.action == "activate" or parsed.action == "deactivate",
})
if config_err then
  io.stderr:write(config_err)
  os.exit(1)
end

local data_path = ProjectConfig.data_path(configuration)

local exit_code, command_err
if parsed.action == "activate" then
  exit_code, command_err = ActivateCommand.run(root, parsed.mod_dir, parsed.quiet, parsed.keep_other_mods)
elseif parsed.action == "deactivate" then
  exit_code, command_err = DeactivateCommand.run(root, parsed.mod_dir, data_path, parsed.quiet)
else
  exit_code, command_err = RunCommand.run(
    root,
    parsed.mod_dir,
    data_path,
    parsed.debug,
    parsed.timeout,
    parsed.seed,
    parsed.leaf,
    parsed.branch
  )
end

if not exit_code then
  io.stderr:write(command_err)
  os.exit(1)
end

os.exit(exit_code)
