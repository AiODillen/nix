# Portable home-manager config (non-NixOS)

Standalone [home-manager](https://github.com/nix-community/home-manager) setup
for a Linux box that has **only the Nix package manager** — no NixOS. It reuses
this repo's flake inputs (nixpkgs / home-manager / stylix / nur, all pinned to
release-26.05) and brings over the packages, theming, shell, AI tooling, gaming
home apps, and the niri/gnome desktop config from the NixOS side.

It does **not** touch anything system-level — your distro keeps owning boot,
kernel, networking, audio, login/session, Steam, etc.

---

## Prerequisites

1. **Nix with flakes enabled.** Add to `~/.config/nix/nix.conf` (or
   `/etc/nix/nix.conf`):

   ```
   experimental-features = nix-command flakes
   ```

2. **home-manager available.** You don't need to "install" it — run it straight
   from the flake registry:

   ```sh
   nix run home-manager/release-26.05 -- --help
   ```

3. **The repo cloned somewhere**, e.g. `~/Documents/nix`. All commands below
   assume that path; adjust if you cloned elsewhere.

---

## First apply

```sh
nix run home-manager/release-26.05 -- switch --flake ~/Documents/nix#niklas
```

After the first switch, the `rebuild` fish alias is available for subsequent
runs:

```sh
home-manager switch --flake ~/Documents/nix#niklas   # alias: rebuild
```

`#niklas` is the config name — it matches `hmSettings.username` in the root
`flake.nix`. If you change the username there, use the new name here.

---

## Configuring it

All knobs live in the **`hmSettings` block** in the repo-root `flake.nix`
(not in `portable/`):

```nix
hmSettings = {
  username       = "niklas";
  homeDirectory  = "/home/niklas";
  scheme         = "catppuccin-mocha";   # any pkgs.base16-schemes name
  polarity       = "dark";               # "dark" | "light" | "either"
  wallpaper      = ./wallpaper.png;
  localeMain     = "en_US.UTF-8";        # LANG
  localeRegional = "de_DE.UTF-8";        # LC_TIME, LC_MEASUREMENT, ...
  xkbLayout      = "de";                 # keyboard layout (wayland + X11)
  xkbVariant     = "nodeadkeys";
};
```

Edit, then `rebuild`. Theme scheme names: see the table in the repo-root
`README.md` or `ls ${pkgs.base16-schemes}/share/themes/`.

---

## What you get (profiles)

All under `portable/profiles/`, imported unconditionally by `portable/home.nix`:

| Profile | Brings |
|---|---|
| `core.nix` | `xdg.enable`; CLI: git, micro, gram, nil, playerctl, brightnessctl |
| `shell.nix` | fish + the `rebuild` alias |
| `locale.nix` | `LANG` / `LC_*` / `XKB_DEFAULT_*` session env |
| `theming.nix` | stylix (scheme, fonts, fish/firefox/qt/mangohud/vesktop targets) + Firefox with color theme, uBlock, Proton Pass |
| `ai.nix` | `~/.claude` config, codegraph + repomix (npm), superpowers + caveman plugins |
| `gaming.nix` | mangohud, vesktop, heroic, lact, protonplus, r2modman, faugus-launcher, goverlay |
| `niri.nix` | niri compositor + xwayland-satellite, nautilus, pavucontrol; foot, fuzzel, mako, waybar; templated `config.kdl` |
| `gnome.nix` | dconf dark-mode preference |

To drop a profile, remove its line from the `imports` list in
`portable/home.nix` and `rebuild`.

---

## Post-install notes

- **Locale:** home-manager only *exports* the env vars. The glibc locales named
  in `localeMain` / `localeRegional` must already exist on the distro — check
  `locale -a`, and generate them with your distro's tooling (e.g.
  `sudo locale-gen` / `sudo dpkg-reconfigure locales` on Debian/Mint) if missing.

- **AI tooling is skip-if-exists.** `~/.claude/CLAUDE.md`, `RTK.md`, and
  `settings.json` are written **only if they don't already exist** — an existing
  Claude Code setup is left untouched. Delete a file and `rebuild` to regenerate
  it. `codegraph` + `repomix` install to `~/.npm-global` (added to PATH);
  first run needs network.

- **niri** gets a `~/.local/share/wayland-sessions/niri.desktop` entry, so it
  shows up in your display manager's session picker. XWayland apps (e.g. Steam)
  work via `xwayland-satellite`. The session itself is launched by your distro's
  login manager — greetd/portals/flatpak are NixOS-only and not ported.

- **Steam / gamescope** are not included (system-level). Install Steam via your
  distro; the gaming profile only carries the user-space helpers.

---

## Updating

```sh
nix flake update                              # bump pinned inputs
home-manager switch --flake ~/Documents/nix#niklas
```

The Claude plugin/npm versions are pinned in `portable/profiles/ai.nix`
(outside `flake.lock`) — bump the version strings + hashes there manually.

---

## Uninstall

```sh
home-manager generations            # list
/nix/store/...-home-manager-generation/activate   # roll back to an older one
```

Removing a profile import + `rebuild` cleanly retracts the files/packages it
managed (HM tracks them). Manually-created files (skip-if-exist `~/.claude/*`,
`~/.npm-global`) are left for you to remove by hand.
</content>
