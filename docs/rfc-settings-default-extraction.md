# RFC: Extract Mod Setting Defaults For `with_player_settings`

## Status
Proposed

## Problem

`f:with_player_settings(player, overrides, fn)` is intended to behave like:

1. start from the mod's current player settings
2. overlay only the provided overrides
3. restore the original settings table afterward

In practice, Factestio sometimes cannot read real per-player settings during
headless scenario execution. In those cases the helper currently falls back to
an empty table and applies only the explicit overrides.

That behavior is too weak for real mod tests:

- non-overridden settings disappear
- newly introduced settings can become `nil`
- test authors are pushed toward re-declaring default settings values manually
- the helper violates the intuitive contract of "override these keys, leave the
  rest alone"

This is a framework problem, not a per-mod testing problem.

## Goal

Make `with_player_settings` preserve sane defaults even when real player
settings are unavailable, without requiring mod authors to duplicate their
setting defaults in test files.

## Non-Goals

- fully emulate Factorio's settings stage
- perfectly support every possible arbitrary `settings.lua`
- replace the need for nil-safe mod code where runtime values may still be
  absent for unrelated reasons

## Proposal

Before executing tests, Factestio should extract the mod's settings defaults
host-side and write them into a manifest that the sandboxed test helper can use
as a fallback baseline.

### High-level flow

1. Host-side Factestio locates the target mod's `settings.lua`.
2. Factestio executes that file in a sandboxed host-side Lua environment.
3. The sandbox provides a minimal settings-stage stub:
   - `data:extend(...)`
   - `data.raw`
   - `mods`
   - standard safe Lua globals (`pairs`, `ipairs`, `string`, etc.)
4. The sandbox captures setting prototypes and any later mutations to them.
5. Factestio derives a baseline runtime-style table:
   - `{ [setting_name] = { value = default_value } }`
6. Factestio writes this baseline to a manifest in the generated scenario
   metadata alongside `test_files.lua`, `test_context.lua`, and `test_seed.lua`.
7. In sandboxed execution, `f:with_player_settings(...)` uses this precedence:
   - explicit overrides
   - real player settings, if readable
   - extracted defaults from the manifest

## Expected `with_player_settings` behavior

The helper should behave as:

1. Try to read `settings.get_player_settings(player.index)`.
2. If available, clone that table as the baseline.
3. If unavailable, use the extracted default-settings manifest as the baseline.
4. Overlay explicit overrides:
   - raw values become `{ value = raw }`
   - full tables with `value` remain intact
5. Temporarily replace `settings.get_player_settings(...)` for the duration of
   the callback.
6. Always restore the original `settings` table, even on failure.

## Why this belongs in Factestio

This preserves the intended ergonomics:

- mod authors write only the overrides they care about
- defaults remain sourced from the mod's own settings definitions
- tests do not duplicate configuration knowledge
- adding a new mod setting does not require editing every test that uses
  `with_player_settings`

## Real-world feasibility

Even large mods often keep `settings.lua` reasonably simple. A representative
example is Space Exploration, whose `settings.lua` uses:

- `data:extend{...}`
- `mods[...]`
- `data.raw[...]` mutation after extension
- small local helper functions that mutate captured setting prototypes

That pattern is still compatible with a host-side stubbed settings extractor.

## Sharp edges

### 1. Arbitrary Lua execution

`settings.lua` is Lua code, not pure data. Running it host-side means accepting:

- loops
- dynamic control flow
- helper functions
- possible unexpected side effects

Factestio already runs arbitrary local mod code as part of testing, so this is
an acceptable trust boundary, but it should be acknowledged explicitly.

### 2. `require(...)` support

Some mods may split settings definitions across multiple files. The extractor
should support `require(...)` rooted at the mod directory.

### 3. `mods[...]` support

Some settings are conditional on other active mods. The extractor should expose
an active-mods table consistent with the current test environment.

### 4. `data.raw` mutation

Capturing only `data:extend(...)` is not enough. The stub must also populate
`data.raw` so later prototype mutation works.

### 5. Partial support is acceptable

The extractor does not need to emulate all of Factorio's settings stage to be
useful. A narrow implementation that covers common settings files is still a
major improvement over the current behavior.

### 6. Failure mode design

If extraction fails, Factestio should fail clearly or warn clearly. It should
not silently degrade into confusing partial behavior.

## Recommended implementation boundaries

### First version

Support:

- `data:extend(...)`
- `data.raw`
- `mods`
- safe Lua stdlib
- `require(...)` within the mod tree

Derive defaults for:

- `runtime-per-user`
- optionally `runtime-global`
- optionally `startup`

Write only the runtime-per-user defaults into the sandbox manifest at first,
because that is what `with_player_settings(...)` needs.

### Deferred work

- richer settings-stage emulation
- diagnostics for unsupported `settings.lua` patterns
- exposing extracted defaults through additional test helper APIs

## Precedence contract

The effective baseline for `with_player_settings(...)` should be:

1. explicit override values passed by the test
2. real current player settings, if readable
3. extracted mod defaults from `settings.lua`

This preserves the closest possible behavior to real gameplay while still
keeping tests ergonomic.

## Alternatives considered

### Require every mod to provide test defaults manually

Rejected because:

- it duplicates mod configuration knowledge into tests
- it creates unnecessary ceremony
- it makes new setting additions brittle

### Parse `settings.lua` as text

Rejected because:

- `settings.lua` is executable Lua
- defaults may be modified after `data:extend(...)`
- conditional logic and helper functions would be missed

### Ignore the problem and rely on nil-safe mod code only

Rejected because:

- it weakens the test helper contract
- it pushes framework deficiencies onto every mod

## Open questions

1. Should the extracted defaults manifest include only `runtime-per-user`, or
   all setting types for future helper use?
2. Should extraction failure be fatal for test runs, or warning-only?
3. Should the extractor cache by mtime/hash of `settings.lua` and required
   setting files?

## Summary

This feature is both feasible and worth doing.

The right design is not "read `settings.lua` directly at runtime", but rather:

- execute `settings.lua` host-side in a stubbed settings-stage environment
- capture the resulting setting prototypes and defaults
- persist them into a manifest
- use that manifest as the fallback baseline for `f:with_player_settings(...)`

That keeps the contract where it belongs: in Factestio, not in every mod's
test suite.
