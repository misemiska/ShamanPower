# sp-ci: ShamanPower's checks without the game

    sp-ci                      # from an addon tree: everything, both clients
    sp-ci --client forever     # one client
    sp-ci --only tests         # one step (syntax, endings, andor, changelog, lint, sweep, tests)
    sp-ci --only countdown     # one test by name
    sp-ci --skip-lint          # the lint takes ~30 s
    sp-ci --release            # strict: the CHANGELOG top section must match the TOC version

Steps, in order:

1. **syntax**: every Lua file through `luac5.1 -p`.
2. **endings**: the repo's line-ending rule (core Lua LF; TOCs, CHANGELOG and locale CRLF; module folders CRLF; ShamanPower_Config LF).
3. **andor**: the `cond and false or X` trap (always yields X).
4. **changelog**: CHANGELOG.md's top section and PatchNotes.lua's first entry agree; every TOC carries the same version.
5. **lint**: `shamanpower-lint`; only findings on lines new since `main` fail (`--lint-base` to change), the rest is a count.
6. **sweep** (per client): the real addon in the headless sim (`sp-uipreview`): every settings page and tab from Window.lua is opened,
   every icon row's menu is built and its submenus walked two deep, any Lua error fails.
7. **tests** (per client): `tools/ci/tests/*.lua` run inside the sim with `harness.lua` (`check`, `checkEq`, `skip`, `finish`).
   A `-- client: forever|anniversary|both` header picks where a test runs.

Needs `sp-uipreview`, `shamanpower-lint` and `luac5.1` on the PATH. The test files never ship: the packager takes the repo without `tools/`.
