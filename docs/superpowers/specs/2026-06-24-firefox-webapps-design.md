# Firefox Webapps Module (Teams + Outlook via firefoxpwa)

**Date:** 2026-06-24
**Status:** SUPERSEDED — see revision note below.

> **Revision (2026-06-24, post-implementation):** This firefoxpwa design was
> implemented and then replaced. firefoxpwa cannot share the main Firefox
> profile (its own runtime + profile), so its app windows lacked the user's
> extensions. Final approach: **dedicated-profile Firefox site-specific
> browsers** — one Firefox profile per app (chromeless via userChrome),
> launched with `--class/--name` for a distinct niri app-id, inheriting the
> global `ExtensionSettings` policy for extensions. Outlook needs no manifest
> in this model. The firefoxpwa design below is kept for history.

## Goal

Add a "webapps" module that installs Microsoft Teams and Outlook as standalone,
Firefox-backed Progressive Web Apps (PWAs) with their own launchers and window
identities. Defined declaratively in the Nix config, available on both the
laptop (standalone Home Manager on Linux Mint) and the pc (NixOS). Adding a
third webapp later should be a one-line change.

## Why firefoxpwa

PWAsForFirefox (`firefoxpwa`) gives a real PWA experience: chrome-less windows,
proper icons, per-app profiles, and generated `.desktop` launchers — unlike
plain `firefox --new-window`, which shares the `firefox` window class and login.

The critical enabling fact comes from nixpkgs: `pkgs.firefoxpwa` is
`wrapFirefox firefoxpwa-unwrapped {}`, and `firefoxpwa-unwrapped` is built with
the `immutable-runtime` Cargo feature. It **bakes a nix `firefox-unwrapped`
runtime into the store path** (`$out/share/firefoxpwa/runtime`, pre-patched at
build time via `firefoxpwa runtime patch`). Consequences:

- The runtime is the nix Firefox — no Mozilla tarball download. This both
  satisfies the requirement to "use nix firefox" and removes the usual NixOS
  blocker (a downloaded Firefox binary won't run under NixOS without FHS/nix-ld).
- The native-messaging host manifest ships at
  `$out/lib/mozilla/native-messaging-hosts/firefoxpwa.json`, with the connector
  binary path patched into it.
- Generated launchers contain no store-path references (`FFPWA_EXECUTABLES=""`
  at build time), so their `Exec` is `firefoxpwa site launch <id>`, resolved
  from `PATH`. Window/app-id is `FFPWA-<id>` — targetable by niri window rules.

## Components

1. **`pkgs.firefoxpwa`** — provides the `firefoxpwa` binary (connector + CLI) and
   the baked runtime. Must be on `PATH` for the browser extension to detect it
   and for the activation script to call it.
2. **Browser extension** — rycee `pwas-for-firefox`
   (id `firefoxpwa@filips.si`, v2.18.2, matching the connector version).
   Force-installed via `programs.firefox.policies.ExtensionSettings`, using the
   nix-store xpi — identical pattern to the existing uBlock / Proton Pass entries.
3. **Native-messaging host manifest** — must be reachable by the running Firefox
   so the extension can talk to the connector.
4. **Webapp definitions** — a single Nix list of `{ name; url; }` records, the
   source of truth for which apps to install. Initial contents:
   - `{ name = "Microsoft Teams"; url = "https://teams.microsoft.com/"; }`
   - `{ name = "Outlook"; url = "https://outlook.office.com/mail/"; }`
5. **Idempotent site-install activation** — a Home Manager activation step that
   runs `firefoxpwa site install` for any webapp not already installed.

## Per-machine wiring

The repo duplicates configuration per machine (no shared root modules dir;
laptop is standalone HM, pc is NixOS + HM). The two machines differ only in how
the package and manifest are delivered; the extension policy and the activation
script are the same logic.

| Concern | Laptop (HM-only, Mint) | pc (NixOS) |
|---|---|---|
| `firefoxpwa` on PATH | `home.packages` | `environment.systemPackages` |
| native-messaging manifest | `home.file.".mozilla/native-messaging-hosts/firefoxpwa.json".source = "${pkgs.firefoxpwa}/lib/mozilla/native-messaging-hosts/firefoxpwa.json"` | `programs.firefox.nativeMessagingHosts.packages = [ pkgs.firefoxpwa ]` (NixOS option, the upstream-blessed method) |
| extension force-install | add `"firefoxpwa@filips.si"` to `programs.firefox.policies.ExtensionSettings` | same, added to the existing policy block in `core/nixos.nix` |
| site install | HM `home.activation` (runs as the user) | HM `home.activation` (same) |

Why the manifest differs: on NixOS the wrapped system Firefox finds native
messaging hosts via `programs.firefox.nativeMessagingHosts.packages`. On
non-NixOS Mint there is no such wrapper, so the manifest is hand-placed in the
per-user `~/.mozilla/native-messaging-hosts/` directory, which every Firefox
build scans.

## File layout

Following the existing split-per-machine convention (`*/nixos.nix` for system,
`*/home.nix` for HM, and `_*-lib.nix` for shared pure helpers like
`_monitors-lib.nix`):

- **`machines/_webapps-lib.nix`** (new, shared pure helper) — exports the
  webapp list and a function that renders the idempotent install shell snippet
  from that list, so the laptop and pc activation scripts stay in sync from a
  single definition.
- **`machines/laptop/profiles/webapps.nix`** (new, HM) — `home.packages`,
  `home.file` manifest, extension policy, activation script (uses the lib).
  Added to `machines/laptop/home.nix` imports.
- **`machines/pc/profiles/webapps/nixos.nix`** (new) — `environment.systemPackages`,
  `programs.firefox.nativeMessagingHosts.packages`, extension policy.
  Added to `machines/pc/default.nix` imports.
- **`machines/pc/profiles/webapps/home.nix`** (new) — activation script (uses the
  lib). Added to `machines/pc/home.nix` imports.

(If a shared lib proves awkward to thread the same `pkgs` through both a NixOS
module and an HM module, fall back to inlining the identical list in each
activation script. Decide during implementation; default is the shared lib.)

## Activation script (idempotent, must never break a switch)

```sh
ffpwa=${pkgs.firefoxpwa}/bin/firefoxpwa
(
  $ffpwa profile list 2>/dev/null | grep -q "Microsoft Teams" \
    || $ffpwa site install https://teams.microsoft.com/ --name "Microsoft Teams"
  $ffpwa profile list 2>/dev/null | grep -q "Outlook" \
    || $ffpwa site install https://outlook.office.com/mail/ --name "Outlook"
) || true
```

- Calls the connector by absolute store path (`${pkgs.firefoxpwa}/bin/firefoxpwa`),
  so it does not depend on `PATH` ordering during activation. The wrapper sets
  `FFPWA_SYSDATA`, so the baked runtime is found.
- Idempotency: skip install when `firefoxpwa profile list` already names the app.
- The whole block is wrapped in `( … ) || true` so a network failure or a site
  that refuses to install can never abort `home-manager switch` /
  `nixos-rebuild`.
- HM concatenates all activation blocks into one bash script; the subshell keeps
  any internal `exit`/failure local (same lesson as the existing
  `firefox-profile.nix` adoption script).
- Ordering: run after packages are installed
  (`lib.hm.dag.entryAfter [ "installPackages" ]`) — though the script uses an
  absolute store path so ordering is not strictly required.

## Known risks / open implementation questions

- **Network at first switch.** `firefoxpwa site install` fetches the web app
  manifest and icons over the network. The first switch on a machine needs
  connectivity; the `|| true` guard means a missing network just defers install
  to the next switch rather than breaking activation.
- **Manifest availability.** Teams and Outlook may not expose a clean installable
  web-app manifest at the page URL. `site install <url> --name <name>` may need
  extra flags (e.g. `--start-url`, or a no-manifest mode). This will be confirmed
  by actually running the command during implementation; the webapp list records
  may grow a `startUrl` field if needed.
- **Theming.** PWA windows run under firefoxpwa's own profile, not the main
  stylix-themed Firefox profile, so they are not base16-themed. Out of scope.
- **Niri window rules.** App-id is `FFPWA-<id>` where `<id>` is a generated ULID,
  not stable/derivable from the config. If niri per-app rules are wanted later,
  the id must be read back after install (e.g. from
  `firefoxpwa profile list`). Out of scope for this module.

## Verification

1. `home-manager switch` (laptop) / `nixos-rebuild switch` (pc) completes without
   error.
2. `firefoxpwa profile list` lists both "Microsoft Teams" and "Outlook".
3. The extension popup in Firefox detects the connector (no "connector not
   found" error).
4. Launching `~/.local/share/applications/FFPWA-<id>.desktop` opens each app in
   its own window.
5. Re-running the switch does not create duplicate installs (idempotency holds).
