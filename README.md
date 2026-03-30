# factestio

A hierarchical scenario-based test framework for Factorio mods. Define tests as a DAG — child tests inherit their parent's full world state via save/restore snapshots, letting you build up complex game states incrementally.

## Requirements

- Factorio (headless)
- Lua 5.2.x (via [luaver](https://github.com/DhavalKapil/luaver))
- LuaRocks

## Installation

```bash
brew install cmtonkinson/tap/factestio
```

Then install the Lua dependencies (Factorio requires Lua 5.2 — not available via Homebrew):

```bash
luaver install 5.2.4 && luaver use 5.2.4
luarocks install --deps-only factestio-0.1-0.rockspec
```

## Setup

From your mod project directory, run:

```bash
factestio --on
```

This will:
1. Create a `factestio/` directory in your mod project (if not present)
2. Copy `factestio/config.lua.example` to `factestio/config.lua` for you to fill in
3. Copy `factestio/example.lua` as a starting point for your tests
4. Symlink your mod project's `factestio/` into the factestio scenario
5. Symlink the factestio repo into Factorio's mods directory
6. Enable factestio in `mod-list.json`

Edit `factestio/config.lua` in your mod project:

```lua
return {
  os_paths = {
    binary = '/Applications/factorio.app/Contents/MacOS/factorio',
    data = '/Users/<you>/Library/Application Support/factorio',
  },
  test_files = {
    'example',  -- loads factestio/example.lua
  }
}
```

## Running tests

```bash
factestio
```

Or with options:

```bash
factestio --debug --timeout 15 /path/to/mod/project
```

## Disabling

```bash
factestio --off
```

This removes symlinks and disables factestio in `mod-list.json`.

## CLI flags

| Flag | Description |
|------|-------------|
| `--on` | Enable factestio for this mod project (symlink, mod-list, scaffold) |
| `--off` | Disable factestio for this mod project |
| `-q, --quiet` | Suppress informational output (use with `--on`/`--off`) |
| `-d, --debug` | Run in debug mode |
| `-t, --timeout N` | Timeout for each scenario in seconds (default: 8) |
| `mod_dir` | Mod project directory (default: current directory) |

## The `factestio/` directory

Your mod project's `factestio/` directory contains:

| File | Description |
|------|-------------|
| `config.lua` | Required. Paths and test file list (gitignored). |
| `config.lua.example` | Template for `config.lua`. |
| `*.lua` | Your test files, one per suite. |

## Writing tests

Tests are defined in `factestio/` as Lua files returning a table of named scenarios. Each scenario is a table with a `test` function and optional `from`, `before`, and `after` keys.

```lua
-- factestio/my_tests.lua
return {
  -- Root test: starts from a fresh world
  setup = {
    test = function(f, context)
      local surface = context.game.surfaces[1]
      surface.create_entity({ name = "assembling-machine-2", position = {x=1, y=1} })
      f:expect(1, 1)
    end,
  },

  -- Child test: inherits setup's world state (assembler is present)
  verify_entity = {
    from = 'setup',
    test = function(f, context)
      local surface = context.game.surfaces[1]
      local found = surface.find_entities({{0,0},{2,2}})
      f:expect(#found, 1)
      f:expect(found[1].name, "assembling-machine-2")
    end,
  },
}
```

Register test files in `factestio/config.lua`:

```lua
test_files = { 'my_tests' }
```

### DSL reference

| Key | Type | Description |
|-----|------|-------------|
| `test` | `function(f, context)` | Required. Main test body. |
| `from` | `string` | Parent test name. Child starts from parent's saved world state. |
| `before` | `function(f, context)` | Runs before `test`. |
| `after` | `function(f, context)` | Runs after `test`. |

### Assertions

```lua
f:expect(actual, expected)   -- assert actual == expected
```

### Context

```lua
context.game     -- LuaGameScript
context.player   -- nil in headless (no player)
context.event    -- the on_tick event
context.node     -- the test node (metadata)
```

## How it works

Each test runs Factorio headlessly in a fresh process:

- **Root tests** (`no from`): launched with `--start-server-load-scenario`, generating a fresh world.
- **Child tests** (`from = 'parent'`): the parent's save zip is loaded with `--start-server`, restoring the full world state including all entities.

At tick +10 the test runs, at tick +20 the world is saved, at tick +30 the process signals completion. Results and saves are collected under `results/`.
