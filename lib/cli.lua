local Constants = require("lib.constants")
local System = require("lib.system")

local Cli = {}

function Cli.write_help(stream, version)
  stream:write("factestio " .. version .. "\n")
  stream:write("\n")
  stream:write("Hierarchical scenario-based test framework for Factorio mods.\n")
  stream:write("\n")
  stream:write("Usage:\n")
  stream:write("  factestio [options] [mod_dir]\n")
  stream:write("\n")
  stream:write("Modes:\n")
  stream:write(
    "  --doctor        Validate the Lua " .. Constants.LUA.VERSION_MINOR .. " and LuaRocks shell environment\n"
  )
  stream:write("  --on            Scaffold and enable Factestio for the target mod project\n")
  stream:write("  --off           Disable Factestio for the target mod project\n")
  stream:write("\n")
  stream:write("Run Options:\n")
  stream:write("  -d, --debug     Print debug output while running tests\n")
  stream:write("  -t, --timeout N Set per-scenario timeout in seconds (default: 8)\n")
  stream:write("  -q, --quiet     Suppress informational output for --on and --off\n")
  stream:write("\n")
  stream:write("General:\n")
  stream:write("  -h, --help      Show this help text\n")
  stream:write("  -V, --version   Print the Factestio version\n")
  stream:write("\n")
  stream:write("Arguments:\n")
  stream:write("  mod_dir         Mod project directory (default: current directory)\n")
  stream:write("\n")
  stream:write("Examples:\n")
  stream:write("  factestio --doctor\n")
  stream:write("  factestio --on /path/to/mod\n")
  stream:write("  factestio --debug --timeout 15 /path/to/mod\n")
end

local function parse_error(message, show_help)
  return nil, {
    message = message,
    show_help = show_help,
  }
end

function Cli.parse(argv)
  local args = {
    doctor = false,
    on = false,
    off = false,
    quiet = false,
    debug = false,
    timeout = Constants.RUNTIME.DEFAULT_TEST_TIMEOUT,
    mod_dir = "./",
  }

  local i = 1
  while i <= #argv do
    local current = argv[i]
    if current == "-h" or current == "--help" then
      return {
        action = "help",
      }
    elseif current == "-V" or current == "--version" then
      return {
        action = "version",
      }
    elseif current == "--doctor" then
      args.doctor = true
    elseif current == "--on" then
      args.on = true
    elseif current == "--off" then
      args.off = true
    elseif current == "-q" or current == "--quiet" then
      args.quiet = true
    elseif current == "-d" or current == "--debug" then
      args.debug = true
    elseif current == "-t" or current == "--timeout" then
      i = i + 1
      local value = argv[i]
      if not value then
        return parse_error(nil, true)
      end
      args.timeout = tonumber(value)
      if not args.timeout then
        return parse_error("Error: timeout must be a number.\n", false)
      end
    elseif current:match("^%-%-timeout=") then
      args.timeout = tonumber(current:match("^%-%-timeout=(.+)$"))
      if not args.timeout then
        return parse_error("Error: timeout must be a number.\n", false)
      end
    elseif current:sub(1, 1) == "-" then
      return parse_error(nil, true)
    else
      if args.mod_dir ~= "./" then
        return parse_error(nil, true)
      end
      args.mod_dir = current
    end
    i = i + 1
  end

  if (args.doctor and args.on) or (args.doctor and args.off) or (args.on and args.off) then
    return parse_error("Error: --doctor, --on, and --off are mutually exclusive.\n", false)
  end

  if args.doctor then
    return {
      action = "doctor",
    }
  end

  if args.on then
    return {
      action = "on",
      quiet = args.quiet,
      mod_dir = System.ensure_trailing_slash(args.mod_dir),
    }
  end

  if args.off then
    return {
      action = "off",
      quiet = args.quiet,
      mod_dir = System.ensure_trailing_slash(args.mod_dir),
    }
  end

  return {
    action = "run",
    debug = args.debug,
    timeout = args.timeout,
    mod_dir = System.ensure_trailing_slash(args.mod_dir),
  }
end

return Cli
