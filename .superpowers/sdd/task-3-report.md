# Task 3 Report: Delete dead tree + rewrite docs

## Status: DONE

## Deletions

Removed the entire shared tree via `git rm -r`:
- `profiles/` (all shared feature profiles)
- `settings.nix` (shared mySystem settings)
- `modules/` (options.nix schema + home/monitors.nix shared module)
- `users/` (nixos.nix + home.nix user glue)
- `template/` (standalone HM base: home.nix, profiles/)
- `wallpaper.png` (root; each machine has its own copy)

Note: `template/README.md` was not `git mv`'d because `machines/laptop/README.md` already existed with its own content (from Task 1). The template copy was deleted with the rest of `template/`.

## Comment fixes

1. `machines/pc/profiles/theming/home.nix` line 12: `./firefox-profile.nix` -> `../../firefox-profile.nix`
2. `machines/laptop/profiles/theming.nix` line 61: `../../modules/home/firefox-profile.nix` -> `../firefox-profile.nix` (stale path to deleted modules/ dir, caught by verification grep)

## README rewrites

### `machines/laptop/README.md`
- Replaced "thin overlay importing ../../template" framing with self-contained machine description
- Removed references to `../../settings.nix`, `device.nix`, `modules/home/monitors.nix`, `mySystem` toggles
- Updated to `vars.nix` references; stated "no toggles — profile runs iff imported"
- Added post-install notes (locale, nixGL, niri session, Steam) from template/README.md
- Added updating section pointing at `machines/laptop/profiles/ai.nix`

### `README.md` (root)
- Replaced "shared settings vs per-device" model with two-independent-machines model
- Documented both build commands
- Updated repo layout to show only `machines/pc/` and `machines/laptop/`
- Removed `mySystem` options reference table, `settings.nix` references, `modules/`, `users/`, `template/`, `profiles/` from layout
- Simplified common-changes section (no more `mySystem.*` paths — edit `vars.nix`)

## Verification

### Build evaluation (all exit 0)

```
$ nix flake check
all checks passed!

$ nix build .#nixosConfigurations.nixos.config.system.build.toplevel --dry-run
(exit 0, only "Git tree is dirty" warning)

$ nix build .#homeConfigurations.niklas.activationPackage --dry-run
(exit 0, only "Git tree is dirty" warning)
```

### Stale-reference grep

```
grep -rn -e "\.\./\.\./profiles" -e "settings.nix" -e "modules/home" -e "modules/options" -e "/template/" -e "mySystem" --include="*.nix" .
```

Matches (all expected):
- **Laptop comments (prose, not code):** monitors.nix:3, shell.nix:7, _monitors-lib.nix:6 — mention "mySystem" in explanatory comments, not as code references
- **Unimported PC profiles (by design):** gaming/{nixos,home}.nix, ai/{nixos,home,claude-plugins}.nix, storage/nixos.nix, local-ai/nixos.nix — contain `config.mySystem`/`osConfig.mySystem` code references; these profiles are intentionally kept but not imported
- **Zero matches in:** flake.nix, machines/pc/{default.nix,home.nix,monitors.nix}, machines/pc/profiles/{core,shell,theming,desktop/niri}/*, machines/laptop/* (imported files)

## Concerns

None.
