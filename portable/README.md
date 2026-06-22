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

There is **one settings file for every config** — `hosts/default/default.nix`
(the `mySystem` block), the same file the NixOS build uses. The portable build
inherits theming, locale, and the feature toggles from it.

Only **identity** differs per machine, and that lives in the `standalone`
sub-block:

```nix
mySystem = {
  # ... shared: theming.scheme, theming.polarity, locale.*, desktop, etc.

  standalone = {
    enable = true;       # exposes homeConfigurations.<user>
    user   = "niklas";   # login user on the non-NixOS box (defaults to user.name)
    # homeDirectory = "/home/niklas";   # optional; defaults to /home/<user>
  };
};
```

Change theme/locale/keyboard in the shared `mySystem` block (affects both the
NixOS and portable builds); change only the non-NixOS username/home in
`standalone`. Then `rebuild`. Theme scheme names: see the table in
`hosts/default/default.nix` or `ls ${pkgs.base16-schemes}/share/themes/`.

### Feature toggles

The portable profiles honor the same toggles as NixOS:

| Profile | Enabled when |
|---|---|
| theming | `mySystem.theming.enable` |
| ai | `mySystem.ai.enable` |
| gaming | `mySystem.gaming.enable` |
| niri | `mySystem.desktop == "niri"` |
| gnome | `mySystem.desktop == "gnome"` |

core, shell, and locale are always on.

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

- **GPU apps need nixGL.** A non-NixOS box has no `/run/opengl-driver`, so
  nix-built GL/Vulkan apps can't find the system driver ("no suitable graphics
  adapter"). The niri profile installs the `nixGLIntel` (Mesa GL) and
  `nixVulkanIntel` (Mesa Vulkan) wrappers — despite the name they cover AMD too.
  Run a nix GUI app through the matching wrapper:

  ```sh
  nixGLIntel <app>        # OpenGL apps
  nixVulkanIntel gram     # Vulkan apps
  ```

- **niri session:** the greeter (LightDM/GDM/SDDM) only scans the system dir
  `/usr/share/wayland-sessions`, which home-manager can't write. The profile
  generates the entry in your home; copy it there once with root:

  ```sh
  sudo cp ~/.local/share/wayland-sessions/niri.desktop /usr/share/wayland-sessions/
  ```

  Its `Exec` runs `~/.nix-profile/bin/niri-session-nixgl` — niri wrapped in both
  nixGL shims so the compositor finds the GPU. XWayland apps (e.g. Steam) work
  via `xwayland-satellite`. greetd/portals/flatpak are NixOS-only and not ported.

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
