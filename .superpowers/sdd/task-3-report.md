# Task 3 Report: pc NixOS wiring for firefoxpwa

## Status: DONE

## Files

- **Created**: `machines/pc/profiles/webapps/nixos.nix` — NixOS module adding `firefoxpwa` to systemPackages, registering it as a native-messaging host, and force-installing the PWAsForFirefox extension via `programs.firefox.policies.ExtensionSettings`.
- **Modified**: `machines/pc/default.nix` — added `./profiles/webapps/nixos.nix` to the imports list.

## Eval-build

Command:
```bash
. ~/.nix-profile/etc/profile.d/nix.sh 2>/dev/null; nix build --no-link '.#nixosConfigurations.nixos.config.system.build.toplevel' 2>&1 | tail -30
```

Result: **Success**. Build completed with no evaluation errors. The new `ExtensionSettings."firefoxpwa@filips.si"` key deep-merged cleanly with the existing extension policies in `machines/pc/profiles/core/nixos.nix`. Final derivation built: `nixos-system-nixos-26.05.20260611.a037402`.

Tail output showed normal build activity: fetching `firefox-151.0.4`, building `firefoxpwa-2.18.2_fish-completions`, `firefox-policies.json`, `activation-script`, home-manager generation, system units, etc. No errors or warnings (beyond the expected "Git tree is dirty" from flakes).

## Commit

- **Hash**: `be04fa7`
- **Message**: `feat(webapps): pc NixOS wiring for firefoxpwa (connector + extension)`

## Concerns

None. The extension policy merges without conflict, firefoxpwa is available in nixpkgs, and the NUR addon path matches the pattern used by the laptop module.
