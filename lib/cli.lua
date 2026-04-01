local Constants = require("lib.constants")
local System = require("lib.system")

local Cli = {}

function Cli.write_help(stream, version)
  stream:write("factestio " .. version .. "\n")
  stream:write("\n")
  stream:write("Hierarchical scenario-based test framework for Factorio mods.\n")
  stream:write("\n")
  stream:write("Usage:\n")
  stream:write("  factestio [command] [options] [mod_dir]\n")
  stream:write("\n")
  stream:write("Commands:\n")
  stream:write(
    "  doctor          Validate the Lua " .. Constants.LUA.VERSION_MINOR .. " and LuaRocks shell environment\n"
  )
  stream:write("  list            Show the compiled scenario DAG\n")
  stream:write("  activate        Scaffold and activate factestio for the target mod project\n")
  stream:write("  deactivate      Restore the pre-activate mod-list state and remove factestio links\n")
  stream:write("\n")
  stream:write("Run Options:\n")
  stream:write("  -d, --debug     Print debug output while running tests\n")
  stream:write("  --leaf ID       Run only the named scenario and its parent chain\n")
  stream:write("  --branch ID     Run the named scenario, its parents, and all children\n")
  stream:write("  --seed N        Seed Lua math.random for reproducible test runs\n")
  stream:write("  -t, --timeout N Set per-scenario timeout in seconds (default: 8)\n")
  stream:write("  -q, --quiet     Suppress informational output for activate and deactivate\n")
  stream:write("  --keep-other-mods  Keep other non-base mods enabled during activate\n")
  stream:write("  --roots         With `list`, show only root scenarios\n")
  stream:write("  --children ID   With `list`, show the named scenario and all descendants\n")
  stream:write("  --json          Emit JSON for `list`\n")
  stream:write("\n")
  stream:write("General:\n")
  stream:write("  -h, --help      Show this help text\n")
  stream:write("  -V, --version   Print the factestio version\n")
  stream:write("\n")
  stream:write("Arguments:\n")
  stream:write("  mod_dir         Mod project directory (default: current directory)\n")
  stream:write("\n")
  stream:write("Examples:\n")
  stream:write("  factestio doctor\n")
  stream:write("  factestio list\n")
  stream:write("  factestio list --roots --json\n")
  stream:write("  factestio list --children regressions.setup\n")
  stream:write("  factestio activate /path/to/mod\n")
  stream:write("  factestio activate --keep-other-mods /path/to/mod\n")
  stream:write("  factestio --leaf basic.setup\n")
  stream:write("  factestio --branch regressions.setup\n")
  stream:write("  factestio --seed 12345 --debug --timeout 15 /path/to/mod\n")
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
    list = false,
    activate = false,
    deactivate = false,
    keep_other_mods = false,
    json = false,
    roots = false,
    children = nil,
    quiet = false,
    debug = false,
    leaf = nil,
    branch = nil,
    seed = nil,
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
    elseif current == "doctor" then
      args.doctor = true
    elseif current == "list" then
      args.list = true
    elseif current == "activate" then
      args.activate = true
    elseif current == "deactivate" then
      args.deactivate = true
    elseif current == "--keep-other-mods" then
      args.keep_other_mods = true
    elseif current == "--json" then
      args.json = true
    elseif current == "--roots" then
      args.roots = true
    elseif current == "--children" then
      i = i + 1
      local value = argv[i]
      if not value then
        return parse_error(nil, true)
      end
      args.children = value
    elseif current == "-q" or current == "--quiet" then
      args.quiet = true
    elseif current == "-d" or current == "--debug" then
      args.debug = true
    elseif current == "--leaf" then
      i = i + 1
      local value = argv[i]
      if not value then
        return parse_error(nil, true)
      end
      args.leaf = value
    elseif current == "--branch" then
      i = i + 1
      local value = argv[i]
      if not value then
        return parse_error(nil, true)
      end
      args.branch = value
    elseif current == "--seed" then
      i = i + 1
      local value = argv[i]
      if not value then
        return parse_error(nil, true)
      end
      args.seed = tonumber(value)
      if not args.seed then
        return parse_error("Error: seed must be a number.\n", false)
      end
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
    elseif current:match("^%-%-seed=") then
      args.seed = tonumber(current:match("^%-%-seed=(.+)$"))
      if not args.seed then
        return parse_error("Error: seed must be a number.\n", false)
      end
    elseif current:match("^%-%-children=") then
      args.children = current:match("^%-%-children=(.+)$")
    elseif current:match("^%-%-leaf=") then
      args.leaf = current:match("^%-%-leaf=(.+)$")
    elseif current:match("^%-%-branch=") then
      args.branch = current:match("^%-%-branch=(.+)$")
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

  local command_count = 0
  if args.doctor then
    command_count = command_count + 1
  end
  if args.list then
    command_count = command_count + 1
  end
  if args.activate then
    command_count = command_count + 1
  end
  if args.deactivate then
    command_count = command_count + 1
  end
  if command_count > 1 then
    return parse_error("Error: doctor, list, activate, and deactivate are mutually exclusive.\n", false)
  end

  if args.leaf and args.branch then
    return parse_error("Error: --leaf and --branch are mutually exclusive.\n", false)
  end

  if args.keep_other_mods and not args.activate then
    return parse_error("Error: --keep-other-mods only applies to activate.\n", false)
  end

  if (args.leaf or args.branch) and (args.activate or args.deactivate or args.doctor or args.list) then
    return parse_error("Error: --leaf and --branch only apply to test runs.\n", false)
  end

  if (args.roots or args.children or args.json) and not args.list then
    return parse_error("Error: --roots, --children, and --json only apply to list.\n", false)
  end

  if args.roots and args.children then
    return parse_error("Error: --roots and --children are mutually exclusive.\n", false)
  end

  if args.doctor then
    return {
      action = "doctor",
    }
  end

  if args.list then
    return {
      action = "list",
      children = args.children,
      json = args.json,
      mod_dir = System.ensure_trailing_slash(args.mod_dir),
      roots = args.roots,
    }
  end

  if args.activate then
    return {
      action = "activate",
      quiet = args.quiet,
      keep_other_mods = args.keep_other_mods,
      mod_dir = System.ensure_trailing_slash(args.mod_dir),
    }
  end

  if args.deactivate then
    return {
      action = "deactivate",
      quiet = args.quiet,
      mod_dir = System.ensure_trailing_slash(args.mod_dir),
    }
  end

  return {
    action = "run",
    debug = args.debug,
    branch = args.branch,
    leaf = args.leaf,
    seed = args.seed,
    timeout = args.timeout,
    mod_dir = System.ensure_trailing_slash(args.mod_dir),
  }
end

return Cli
