return function(F)
  function F.shell_quote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
  end

  -----------------------------------------------------------------------------
  function F.yellow(fmt, ...)
    if F.DEBUG then
      print("\27[0;33m" .. fmt .. "\27[0m", ...)
    end
  end

  -----------------------------------------------------------------------------
  function F.red(fmt, ...)
    print("\27[1;31m" .. fmt .. "\27[0m", ...)
  end

  -----------------------------------------------------------------------------
  function F.green(fmt, ...)
    print("\27[1;32m" .. fmt .. "\27[0m", ...)
  end

  -----------------------------------------------------------------------------
  function F.cmd(fmt, ...)
    local cmd = string.format(fmt, ...)
    if F.DEBUG then
      F.yellow(cmd)
    end
    return os.execute(cmd)
  end

  return F
end
