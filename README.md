# factestio
A [Scenario Tree Testing] framework for Factorio mods. Define tests as a DAG —
child tests inherit their parent's full world state via save/restore snapshots,
letting you build up complex game states incrementally.

> **Platform support:** macOS is the primary supported platform. Linux bootstrap
> and path detection are now supported on a best-effort basis for common
> installs, but have not been validated as extensively.

## Requirements
- Factorio (headless)
- Lua 5.2.x on PATH (Factorio's runtime is Lua 5.2; other versions are not
  supported)
- LuaRocks
- bash

Lua 5.2 is not available via Homebrew core. The recommended approach is
[luaver](https://github.com/DhavalKapil/luaver):

```bash
luaver install 5.2.4 && luaver use 5.2.4
```

Or compile from source, or use your system package manager if it provides 5.2.x.

## Installation
```bash
brew install cmtonkinson/tap/factestio
```

Then install the Lua dependencies:

```bash
luarocks install --deps-only factestio-*.rockspec
```

## Setup
From your mod project directory, run:

```bash
factestio activate
```

This will:
1. Create a `factestio/` directory in your mod project (if not present)
2. Copy `factestio/config.lua.example` to `factestio/config.lua` for you to fill
   in
3. Copy `factestio/example.lua` as a starting point for your tests
4. Create or update `factestio/.gitignore` to ignore local config and generated
   results
5. Symlink your mod project's `factestio/` into the factestio scenario
6. Symlink the factestio repo into Factorio's mods directory
7. Symlink the SUT mod into Factorio's mods directory
8. Enable both factestio and the SUT in `mod-list.json`
9. By default, disable all other non-base mods for an isolated test session

Edit `factestio/config.lua` in your mod project:

```lua
return {
  os_paths = {
    binary = '/Applications/factorio.app/Contents/MacOS/factorio',
    data = '/Users/<you>/Library/Application Support/factorio',
  }
}
```

On Linux, common defaults are:

```lua
return {
  os_paths = {
    binary = '/home/<you>/.factorio/bin/x64/factorio',
    data = '/home/<you>/.factorio',
  }
}
```

`factestio activate` also checks `FACTESTIO_FACTORIO_BINARY` and
`FACTESTIO_FACTORIO_DATA` before falling back to platform defaults.

To keep other non-base mods enabled during activation:

```bash
factestio activate --keep-other-mods
```

## Running tests
```bash
factestio
```

Or with options:

```bash
factestio --seed 12345 --debug --timeout 15 /path/to/mod/project
factestio --leaf basic.setup
factestio --branch regressions.setup
```

At startup factestio prints:
- version
- mod title
- working directory
- seed

If you omit `--seed`, factestio generates one and prints it so the run can be reproduced later.

To validate your shell/runtime setup before running tests:

```bash
factestio --doctor
```

## Disabling
```bash
factestio deactivate
```

This removes the factestio/SUT symlinks and restores the pre-activation
`mod-list.json` state captured when the current factestio session began.

## CLI flags
| Flag | Description |
|------|-------------|
| `-h, --help` | Show command help |
| `activate` | Scaffold and activate factestio for this mod project |
| `deactivate` | Restore the original mod-list state and remove factestio links |
| `--keep-other-mods` | Keep other non-base mods enabled during `activate` |
| `-q, --quiet` | Suppress informational output (use with `activate`/`deactivate`) |
| `-d, --debug` | Run in debug mode |
| `--leaf ID` | Run only the named scenario and its parent chain |
| `--branch ID` | Run the named scenario, its parents, and all children |
| `--seed N` | Seed Lua `math.random` for reproducible test runs |
| `-t, --timeout N` | Timeout for each scenario in seconds (default: 8) |
| `--doctor` | Validate the Lua 5.2 + LuaRocks environment |
| `-V, --version` | Print the installed factestio version |
| `mod_dir` | Mod project directory (default: current directory) |

## The `factestio/` directory
Your mod project's `factestio/` directory contains:

| File | Description |
|------|-------------|
| `config.lua` | Required. Local Factorio paths (gitignored). |
| `config.lua.example` | Template for `config.lua`. |
| `*.lua` | Your test files, one per suite. |
| `.gitignore` | Created by `factestio activate`; ignores `config.lua` and `results/`. |
| `results/` | Generated artifacts from the most recent run. |

`factestio activate` creates `factestio/.gitignore` for you so local config and
generated results stay out of version control.

## Writing tests
Tests are defined in `factestio/` as Lua files returning a table of named
scenarios. Each scenario is a table with a `test` function and optional `from`,
`before`, and `after` keys.

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

All `factestio/*.lua` files are discovered automatically at runtime, except
`factestio/config.lua`.

### DSL reference
| Key | Type | Description |
|-----|------|-------------|
| `test` | `function(f, context)` | Required. Main test body. |
| `from` | `string` | Parent test name. Child starts from parent's saved world state. |
| `before` | `function(f, context)` | Runs before `test`. |
| `after` | `function(f, context)` | Runs after `test`. Always runs even if `test` fails. |

#### `from` name resolution

Within a single test file, `from` is a bare name:

```lua
verify = { from = 'setup', ... }  -- refers to 'setup' in the same file
```

To reference a test in a different file, use a fully-qualified dotted name:

```lua
verify = { from = 'other_file.setup', ... }  -- cross-file reference
```

Test names are automatically prefixed with their filename in the registry (e.g.
`my_tests.setup`), so bare names are relative and dotted names are absolute.

### Targeting a scenario

Use the fully-qualified scenario id when targeting part of the DAG:

```bash
factestio --leaf my_tests.setup
factestio --branch other_file.root_case
```

`--leaf` runs just that scenario plus its parent chain. `--branch` runs that
scenario, its parent chain, and all of its descendants.

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

- **Root tests** (`no from`): launched with `--start-server-load-scenario`,
  generating a fresh world.
- **Child tests** (`from = 'parent'`): the parent's save zip is loaded with
  `--start-server`, restoring the full world state including all entities.

At tick +10 the test runs, at tick +20 the world is saved, at tick +30 the
process signals completion. Results and saves are collected under
`factestio/results/`.


[Scenario Tree Testing]: https://medium.com/@chris_59795/you-write-too-many-tests-6ce58e959045
