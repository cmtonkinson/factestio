return function(F)

-----------------------------------------------------------------------------
function F.yellow(string, ...)
  if F.DEBUG then
    print("\27[0;33m" .. string .. "\27[0m", ...)
  end
end

-----------------------------------------------------------------------------
function F.red(string, ...)
  print("\27[1;31m" .. string .. "\27[0m", ...)
end

-----------------------------------------------------------------------------
function F.green(string, ...)
  print("\27[1;32m" .. string .. "\27[0m", ...)
end

-----------------------------------------------------------------------------
function F.cmd(string, ...)
  local cmd = string.format(string, ...)
  if F.DEBUG then F.yellow(cmd) end
  return os.execute(cmd)
end

-----------------------------------------------------------------------------
function F.cmd_capture(string, ...)
  local cmd = string.format(string, ...)
  if F.DEBUG then F.yellow(cmd) end
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  handle:close()
  return result
end

return F
end
