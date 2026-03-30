std = "lua52"

-- Factorio sandbox globals (used in sandboxed scenario code)
files["scenarios/factestio/control.lua"] = {
  read_globals = {
    "script", "game", "remote", "rendering", "storage",
    "serpent", "defines",
  }
}
files["scenarios/factestio/src/lib_sandboxed.lua"] = {
  read_globals = {
    "script", "game", "remote", "rendering", "storage",
    "serpent", "defines",
  }
}

-- Ignore generated/result directories
exclude_files = { "tmp/**", "results/**" }

-- Allow long lines (Lua idiom)
max_line_length = 120
