# factestio

A hierarchical scenario-based test framework for Factorio mods. Define tests as a DAG — child tests inherit their parent's full world state via save/restore snapshots, letting you build up complex game states incrementally.

## Requirements

- Factorio (headless)
- Lua 5.2.x (via [luaver](https://github.com/DhavalKapil/luaver))
- LuaRocks

## Installation

```bash
luarocks install --deps-only factestio-0.1-0.rockspec
```

## Setup

1. Copy `test/config.lua.example` to `test/config.lua` and fill in your paths:

```lua
return {
  os_paths = {
    binary = '/Applications/factorio.app/Contents/MacOS/factorio',
    data = '/Users/<you>/Library/Application Support/factorio',
  },
  test_files = {
    'example',  -- loads test/example.lua
  }
}
```

2. Symlink the project into Factorio's mods directory so the scenario is accessible:

```bash
./enable-localdev.sh
```

## Running tests

```bash
lua run.lua
```

## Writing tests

Tests are defined in `test/` as Lua files returning a table of named scenarios. Each scenario is a table with a `test` function and optional `from`, `before`, and `after` keys.

```lua
-- test/my_tests.lua
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

Register test files in `test/config.lua`:

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
