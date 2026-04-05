local Shell = {}

function Shell.quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function join_command(command, args)
  local parts = { Shell.quote(command) }
  for _, arg in ipairs(args or {}) do
    parts[#parts + 1] = Shell.quote(arg)
  end
  return table.concat(parts, " ")
end

local function with_redirection(command, opts)
  local rendered = command
  opts = opts or {}

  if opts.stdout_path then
    local operator = opts.stdout_append and " >> " or " > "
    rendered = rendered .. operator .. Shell.quote(opts.stdout_path)
  end

  if opts.stderr_to_stdout then
    rendered = rendered .. " 2>&1"
  elseif opts.stderr_path then
    local operator = opts.stderr_append and " 2>> " or " 2> "
    rendered = rendered .. operator .. Shell.quote(opts.stderr_path)
  elseif opts.stderr_to_devnull then
    rendered = rendered .. " 2>/dev/null"
  end

  return rendered
end

local function execute_rendered(command)
  local ok, _, code = os.execute(command)
  if type(ok) == "number" then
    return ok == 0
  end
  if ok == true then
    return true
  end
  return code == 0
end

function Shell.succeeds(command, args, opts)
  return execute_rendered(with_redirection(join_command(command, args), opts))
end

function Shell.capture(command, args, opts)
  local proc = io.popen(with_redirection(join_command(command, args), opts))
  if not proc then
    return nil, false
  end

  local output = proc:read("*a")
  local ok, _, code = proc:close()
  local succeeded = (type(ok) == "number" and ok == 0) or ok == true or code == 0
  return output, succeeded
end

function Shell.capture_lines(command, args, opts)
  local output, succeeded = Shell.capture(command, args, opts)
  if not succeeded or not output then
    return nil
  end

  local lines = {}
  for line in output:gmatch("[^\r\n]+") do
    lines[#lines + 1] = line
  end
  return lines
end

function Shell.mkdir_p(path)
  return Shell.succeeds("mkdir", { "-p", path })
end

function Shell.rm_rf(path)
  return Shell.succeeds("rm", { "-rf", path })
end

function Shell.rm_f(path)
  return Shell.succeeds("rm", { "-f", path })
end

function Shell.cp(source_path, target_path)
  return Shell.succeeds("cp", { source_path, target_path })
end

function Shell.mv(source_path, target_path)
  return Shell.succeeds("mv", { source_path, target_path })
end

function Shell.ln_s(target_path, link_path)
  return Shell.succeeds("ln", { "-s", target_path, link_path })
end

function Shell.test_exists(path)
  return Shell.succeeds("test", { "-e", path })
end

function Shell.test_exists_or_symlink(path)
  return Shell.succeeds("test", { "-e", path, "-o", "-L", path })
end

function Shell.readlink(path)
  local output, succeeded = Shell.capture("readlink", { path }, { stderr_to_devnull = true })
  output = output and output:gsub("\n$", "") or ""
  if not succeeded or output == "" then
    return nil
  end
  return output
end

function Shell.realpath(path)
  local command = "cd " .. Shell.quote(path) .. " 2>/dev/null && pwd"
  local output, succeeded = Shell.capture("sh", { "-lc", command })
  output = output and output:gsub("\n$", "") or ""
  if not succeeded or output == "" then
    return nil
  end
  return output
end

function Shell.find_files(path, name_pattern)
  return Shell.capture_lines("find", {
    path,
    "-maxdepth",
    "1",
    "-type",
    "f",
    "-name",
    name_pattern,
    "-print",
  }, {
    stderr_to_devnull = true,
  }) or {}
end

function Shell.sleep(seconds)
  return Shell.succeeds("sleep", { tostring(seconds) })
end

function Shell.is_pid_alive(pid)
  return Shell.succeeds("kill", { "-0", tostring(pid) }, { stderr_to_devnull = true })
end

function Shell.kill(pid, signal)
  return Shell.succeeds("kill", { "-" .. signal, tostring(pid) }, { stderr_to_devnull = true })
end

function Shell.write_output(output_path, command, args, opts)
  local redirection_opts = {}
  for key, value in pairs(opts or {}) do
    redirection_opts[key] = value
  end
  redirection_opts.stdout_path = output_path
  local command_string = with_redirection(join_command(command, args), redirection_opts)
  return execute_rendered(command_string)
end

function Shell.write_file(path, content)
  local file, err = io.open(path, "w")
  if not file then
    return nil, err
  end
  file:write(content or "")
  file:close()
  return true
end

function Shell.command_path(name)
  local output, succeeded = Shell.capture("sh", { "-lc", "command -v " .. Shell.quote(name) }, {
    stderr_to_devnull = true,
  })
  output = output and output:gsub("^%s+", ""):gsub("%s+$", "") or ""
  if not succeeded or output == "" then
    return nil
  end
  return output
end

function Shell.launch_background(argv, stdout_path, pid_path, root_pid_path)
  local script = 'trap "" INT TERM; '
    .. "stdout_path=$1; pid_path=$2; root_pid_path=$3; shift 3; "
    .. '"$@" > "$stdout_path" 2>&1 & '
    .. "PID=$!; "
    .. 'echo "$PID" > "$pid_path"; '
    .. 'echo "$PID" > "$root_pid_path"'
  local args = { "-c", script, "sh", stdout_path, pid_path, root_pid_path }
  for _, arg in ipairs(argv) do
    args[#args + 1] = arg
  end
  return Shell.succeeds("sh", args)
end

return Shell
