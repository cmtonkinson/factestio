local System = {}

function System.ensure_trailing_slash(path)
  if path:sub(-1) ~= "/" then
    return path .. "/"
  end
  return path
end

function System.shell_quote(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

function System.command_succeeds(cmd)
  local ok, _, code = os.execute(cmd)
  if type(ok) == "number" then
    return ok == 0
  end
  if ok == true then
    return true
  end
  return code == 0
end

function System.exists(path)
  local f = io.open(path, "r")
  if f then
    f:close()
    return true
  end
  return false
end

function System.symlink_target(path)
  local f = io.popen("readlink " .. System.shell_quote(path) .. " 2>/dev/null")
  local result = f:read("*a"):gsub("\n$", "")
  f:close()
  return result ~= "" and result or nil
end

function System.realpath(path)
  local f = io.popen("cd " .. System.shell_quote(path) .. " 2>/dev/null && pwd")
  local result = f:read("*a"):gsub("\n$", "")
  f:close()
  return result ~= "" and result or nil
end

function System.ensure_lines(path, entries)
  local current = ""
  local f = io.open(path, "r")
  if f then
    current = f:read("*a") or ""
    f:close()
  end

  local seen = {}
  for line in current:gmatch("[^\r\n]+") do
    seen[line] = true
  end

  local changed = false
  local output = current
  for _, entry in ipairs(entries) do
    if not seen[entry] then
      if output ~= "" and not output:match("\n$") then
        output = output .. "\n"
      end
      output = output .. entry .. "\n"
      seen[entry] = true
      changed = true
    end
  end

  if changed or not System.exists(path) then
    local out, err = io.open(path, "w")
    if not out then
      return nil, "Error: could not write " .. path .. ": " .. (err or "unknown error")
    end
    out:write(output)
    out:close()
  end

  return changed
end

function System.read_file(path)
  local f, err = io.open(path, "r")
  if not f then
    return nil, err
  end

  local content = f:read("*a")
  f:close()
  return content
end

function System.write_file(path, content)
  local f, err = io.open(path, "w")
  if not f then
    return nil, err
  end

  f:write(content)
  f:close()
  return true
end

return System
