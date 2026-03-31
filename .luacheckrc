std = "lua52"

-- Factorio sandbox globals (used in sandboxed scenario code)
files["scenarios/factestio/control.lua"] = {
  globals = {
    "game", "storage", "helpers", "player",
  },
  read_globals = {
    "script", "remote", "rendering", "serpent", "defines",
  },
}
files["scenarios/factestio/src/lib_sandboxed.lua"] = {
  read_globals = {
    "script", "game", "remote", "rendering", "storage",
    "serpent", "defines",
  }
}
files["scenarios/factestio/factestio/*.lua"] = {
  globals = {
    "settings",
  },
  read_globals = {
    "defines", "prototypes",
  },
  max_line_length = false,
}

-- Ignore generated/result directories
exclude_files = { "tmp/**", "results/**", ".luarocks/**" }

-- Allow long lines (Lua idiom)
max_line_length = 120
