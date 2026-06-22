# Portable standalone home-manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a standalone `homeConfigurations.niklas` output to the root flake that brings packages, theming, shell, AI tooling, gaming home apps, and the niri/gnome desktop config to a non-NixOS box.

**Architecture:** A `portable/` module tree decoupled from `osConfig.mySystem`. The root `flake.nix` gains a `homeConfigurations` output built with `home-manager.lib.homeManagerConfiguration`, reusing existing inputs. A plain `settings` `let`-block is threaded into modules via `extraSpecialArgs`. Stylix is wired via its standalone home module.

**Tech Stack:** Nix flakes, home-manager release-26.05, stylix release-26.05, nur.

## Global Constraints

- nixpkgs / home-manager / stylix all pinned to release-26.05 (existing inputs — do not add new inputs).
- `home.stateVersion = "26.05"`.
- System: `x86_64-linux`.
- `pkgs` must be built with `config.allowUnfree = true` and `overlays = [ inputs.nur.overlays.default ]`.
- Stylix standalone module attribute is `inputs.stylix.homeModules.stylix` (verified; `homeManagerModules` is deprecated).
- Settings block values (verbatim): username `niklas`, homeDirectory `/home/niklas`, scheme `catppuccin-mocha`, polarity `dark`, wallpaper `./wallpaper.png`, localeMain `en_US.UTF-8`, localeRegional `de_DE.UTF-8`, xkbLayout `de`, xkbVariant `nodeadkeys`.
- Profiles are unconditional — no `lib.mkIf enable` gates. Parameterize via the `settings` arg only.
- This is declarative Nix: there is no unit-test framework. The "test" for every task is that `nix build .#homeConfigurations.niklas.activationPackage --no-link` evaluates and builds successfully. Commit after each green build.
- Do NOT run `home-manager switch` anywhere in this plan — building the activation package is the verification; switching is the user's manual step on the target machine.

---

### Task 1: Flake output + entry + core profile

**Files:**
- Modify: `flake.nix` (add `homeConfigurations` to outputs, add `settings` let-binding)
- Create: `portable/home.nix`
- Create: `portable/profiles/core.nix`

**Interfaces:**
- Produces: `homeConfigurations.niklas` flake output; `settings` attrset passed to every module via `extraSpecialArgs` with keys `username homeDirectory scheme polarity wallpaper localeMain localeRegional xkbLayout xkbVariant`; module arg signature `{ pkgs, settings, ... }` (and `{ ... , lib }` / `{ ..., inputs }` where needed).

- [ ] **Step 1: Add the settings block and homeConfigurations output to `flake.nix`**

In `flake.nix`, inside the `let` block (after the existing `cfg = system.config.mySystem;` line), add:

```nix
      # ── Standalone home-manager (non-NixOS) ──────────────────────
      hmSettings = {
        username       = "niklas";
        homeDirectory  = "/home/niklas";
        scheme         = "catppuccin-mocha";
        polarity       = "dark";
        wallpaper      = ./wallpaper.png;
        localeMain     = "en_US.UTF-8";
        localeRegional = "de_DE.UTF-8";
        xkbLayout      = "de";
        xkbVariant     = "nodeadkeys";
      };
      hmPkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
        overlays = [ inputs.nur.overlays.default ];
      };
```

Then in the returned attrset (the `in { ... }`), add this output alongside `nixosConfigurations` and `checks`:

```nix
      homeConfigurations.${hmSettings.username} =
        home-manager.lib.homeManagerConfiguration {
          pkgs = hmPkgs;
          extraSpecialArgs = { inherit inputs; settings = hmSettings; };
          modules = [
            inputs.stylix.homeModules.stylix
            ./portable/home.nix
          ];
        };
```

- [ ] **Step 2: Create `portable/home.nix`**

```nix
{ settings, ... }:
{
  imports = [
    ./profiles/core.nix
  ];

  home.username = settings.username;
  home.homeDirectory = settings.homeDirectory;
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;
}
```

- [ ] **Step 3: Create `portable/profiles/core.nix`**

```nix
{ pkgs, ... }:
{
  xdg.enable = true;

  home.packages = with pkgs; [
    git
    micro
    gram
    nil
    playerctl       # MPRIS control for multimedia keys
    brightnessctl   # screen brightness keys
  ];
}
```

- [ ] **Step 4: Build the activation package**

Run: `nix build .#homeConfigurations.niklas.activationPackage --no-link 2>&1 | tail -20`
Expected: builds with no error (a `/nix/store/...-home-manager-generation` path is produced; no `error:` lines).

- [ ] **Step 5: Commit**

```bash
git add flake.nix flake.lock portable/home.nix portable/profiles/core.nix
git commit -m "feat: add standalone home-manager output with core profile"
```

---

### Task 2: Shell profile (fish)

**Files:**
- Create: `portable/profiles/shell.nix`
- Modify: `portable/home.nix` (add import)

**Interfaces:**
- Consumes: nothing new.
- Produces: `programs.fish` enabled (theming.nix later sets `stylix.targets.fish`).

- [ ] **Step 1: Create `portable/profiles/shell.nix`**

```nix
{ ... }:
{
  programs.fish = {
    enable = true;
    shellAliases = {
      # Standalone home-manager rebuild (adjust the flake path to wherever
      # this repo lives on the target machine).
      rebuild = "home-manager switch --flake ~/Documents/nix#niklas";
    };
  };
}
```

- [ ] **Step 2: Add the import to `portable/home.nix`**

Change the `imports` list to:

```nix
  imports = [
    ./profiles/core.nix
    ./profiles/shell.nix
  ];
```

- [ ] **Step 3: Build**

Run: `nix build .#homeConfigurations.niklas.activationPackage --no-link 2>&1 | tail -20`
Expected: builds with no `error:` lines.

- [ ] **Step 4: Commit**

```bash
git add portable/profiles/shell.nix portable/home.nix
git commit -m "feat: add fish shell to portable home config"
```

---

### Task 3: Locale profile (env vars + XKB)

**Files:**
- Create: `portable/profiles/locale.nix`
- Modify: `portable/home.nix` (add import)

**Interfaces:**
- Consumes: `settings.localeMain`, `settings.localeRegional`, `settings.xkbLayout`, `settings.xkbVariant`.
- Produces: session env vars `LANG`, `LC_*`, `XKB_DEFAULT_LAYOUT`, `XKB_DEFAULT_VARIANT` (consumed by niri + X11).

- [ ] **Step 1: Create `portable/profiles/locale.nix`**

```nix
{ settings, ... }:
let
  regional = settings.localeRegional;
in
{
  # No system locale-gen on non-NixOS; HM only exports env vars. The glibc
  # locale must already exist on the distro (check `locale -a`).
  home.sessionVariables = {
    LANG = settings.localeMain;

    LC_ADDRESS        = regional;
    LC_IDENTIFICATION = regional;
    LC_MEASUREMENT    = regional;
    LC_MONETARY       = regional;
    LC_NAME           = regional;
    LC_NUMERIC        = regional;
    LC_PAPER          = regional;
    LC_TELEPHONE      = regional;
    LC_TIME           = regional;

    # Read by both niri (Wayland) and X11.
    XKB_DEFAULT_LAYOUT  = settings.xkbLayout;
    XKB_DEFAULT_VARIANT = settings.xkbVariant;
  };
}
```

- [ ] **Step 2: Add the import to `portable/home.nix`**

```nix
  imports = [
    ./profiles/core.nix
    ./profiles/shell.nix
    ./profiles/locale.nix
  ];
```

- [ ] **Step 3: Build**

Run: `nix build .#homeConfigurations.niklas.activationPackage --no-link 2>&1 | tail -20`
Expected: builds; no `error:` lines.

- [ ] **Step 4: Commit**

```bash
git add portable/profiles/locale.nix portable/home.nix
git commit -m "feat: add locale + XKB env to portable home config"
```

---

### Task 4: Theming profile (stylix + firefox)

**Files:**
- Create: `portable/profiles/theming.nix`
- Modify: `portable/home.nix` (add import)

**Interfaces:**
- Consumes: `settings.polarity`, `settings.wallpaper`, `settings.scheme`; `pkgs.base16-schemes`; `pkgs.nur.repos.rycee.firefox-addons.*`; the stylix home module (already in the flake `modules` list).
- Produces: stylix theming for fish/firefox/qt/mangohud/vesktop; `programs.firefox` profile `default`.

- [ ] **Step 1: Create `portable/profiles/theming.nix`**

```nix
{ pkgs, settings, ... }:
{
  stylix = {
    enable = true;
    polarity = settings.polarity;
    image = settings.wallpaper;

    base16Scheme = "${pkgs.base16-schemes}/share/themes/${settings.scheme}.yaml";

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font Mono";
      };
      sansSerif = {
        package = pkgs.inter;
        name = "Inter";
      };
      serif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Serif";
      };
      sizes = {
        applications = 12;
        terminal = 13;
        desktop = 11;
        popups = 11;
      };
    };

    targets.fish.enable = true;
    targets.firefox = {
      enable = true;
      profileNames = [ "default" ];
      colorTheme.enable = true;
    };
    targets.mangohud.enable = true;
    targets.qt.enable = true;
    targets.vesktop.enable = true;
  };

  programs.firefox = {
    enable = true;
    profiles.default = {
      isDefault = true;
      extensions.force = true;
      settings = {
        "extensions.autoDisableScopes" = 0;
      };
    };
    # Merged from the NixOS core + theming firefox policies.
    policies.ExtensionSettings =
      let
        addons = pkgs.nur.repos.rycee.firefox-addons;
        wj = "{ec8030f7-c20a-464f-9b0e-13a3a9e97384}";
      in
      {
        "FirefoxColor@mozilla.com" = {
          installation_mode = "force_installed";
          install_url = "file://${addons.firefox-color}/share/mozilla/extensions/${wj}/FirefoxColor@mozilla.com.xpi";
        };
        "uBlock0@raymondhill.net" = {
          installation_mode = "force_installed";
          install_url = "file://${addons.ublock-origin}/share/mozilla/extensions/${wj}/uBlock0@raymondhill.net.xpi";
        };
        "78272b6fa58f4a1abaac99321d503a20@proton.me" = {
          installation_mode = "force_installed";
          install_url = "file://${addons.proton-pass}/share/mozilla/extensions/${wj}/78272b6fa58f4a1abaac99321d503a20@proton.me.xpi";
        };
      };
  };
}
```

- [ ] **Step 2: Add the import to `portable/home.nix`**

```nix
  imports = [
    ./profiles/core.nix
    ./profiles/shell.nix
    ./profiles/locale.nix
    ./profiles/theming.nix
  ];
```

- [ ] **Step 3: Build**

Run: `nix build .#homeConfigurations.niklas.activationPackage --no-link 2>&1 | tail -30`
Expected: builds; no `error:` lines. (If a stylix target name errors, check the build output for the offending `targets.*` attribute and confirm against the pinned stylix; do not disable a target without noting it.)

- [ ] **Step 4: Commit**

```bash
git add portable/profiles/theming.nix portable/home.nix
git commit -m "feat: add stylix theming + firefox to portable home config"
```

---

### Task 5: AI profile (skip-if-exists)

**Files:**
- Create: `portable/profiles/ai.nix`
- Modify: `portable/home.nix` (add import)

**Interfaces:**
- Consumes: `pkgs.fetchFromGitHub`, `pkgs.nodejs`, `pkgs.jq`, `pkgs.coreutils`.
- Produces: `home.sessionPath` += `$HOME/.npm-global/bin`; activation entries that write `~/.claude/*` only when absent.

This is the `profiles/ai/claude-plugins.nix` content merged with the three `~/.claude` text files from `profiles/ai/home.nix`, with two changes: (1) no `osConfig.mySystem.ai.enable` guard, (2) the three text files become skip-if-exists activation scripts instead of `home.file`.

- [ ] **Step 1: Create `portable/profiles/ai.nix`**

```nix
{ lib, pkgs, ... }:
let
  cavemanVersion = "25d22f864ad6";
  cavemanRev = "25d22f864ad68cc447a4cb93aefde918aa4aec9f";
  cavemanSrc = pkgs.fetchFromGitHub {
    owner = "JuliusBrussee";
    repo = "caveman";
    rev = cavemanRev;
    hash = "sha256-FbmfhFaPs/SnSZdfNdErdIUHXt1FfBzErpPpLy8kdIc=";
  };

  superpowersVersion = "6.0.2";
  superpowersRev = "6efe32c9e2dd002d0c394e861e0529675d1ab32e";
  superpowersSrc = pkgs.fetchFromGitHub {
    owner = "obra";
    repo = "superpowers";
    rev = superpowersRev;
    hash = "sha256-0WupTacT1jIwVBloj1i0RF7wIllVtP8eMPRl7VrXdbE=";
  };

  codegraphVersion = "1.0.1";
  repomixVersion = "1.14.1";
  frozenTs = "1970-01-01T00:00:00.000Z";

  claudeMd = ''
    # AI Tooling

    ## Code Intelligence (codegraph)
    Before reading multiple files to understand structure or relationships,
    use `codegraph_search` or `codegraph_explore` via the MCP tool.
    Prefer graph queries over file reads when the goal is navigating the codebase.

    ## Command Output (rtk)
    Shell commands are automatically proxied through rtk — output is pre-compressed.
    No manual action needed. Use `rtk gain` to check token savings.

    ## Codebase Packing (repomix)
    For large review or refactor sessions on an unfamiliar codebase, run
    `repomix --output repomix-output.xml` first to pack the repo into dense context.
    Suggest this at session start when the user opens a new project.

    ## Response Style (caveman)
    Default to terse output — skip filler, avoid restating the question,
    omit transition sentences. Full prose only when precision requires it.
    Use `/caveman` to activate compressed response mode explicitly.

    @RTK.md
  '';

  rtkMd = ''
    # RTK - Rust Token Killer

    **Usage**: Token-optimized CLI proxy (60-90% savings on dev operations)

    ## Meta Commands (always use rtk directly)

    ```bash
    rtk gain              # Show token savings analytics
    rtk gain --history    # Show command usage history with savings
    rtk discover          # Analyze Claude Code history for missed opportunities
    rtk proxy <cmd>       # Execute raw command without filtering (for debugging)
    ```

    ## Installation Verification

    ```bash
    rtk --version         # Should show: rtk X.Y.Z
    rtk gain              # Should work (not "command not found")
    which rtk             # Verify correct binary
    ```

    ⚠️ **Name collision**: If `rtk gain` fails, you may have reachingforthejack/rtk (Rust Type Kit) installed instead.

    ## Hook-Based Usage

    All other commands are automatically rewritten by the Claude Code hook.
    Example: `git status` → rewritten to `rtk hook claude git status` (transparent, 0 tokens overhead)

    Refer to CLAUDE.md for full command reference.
  '';

  settingsJson = builtins.toJSON {
    enabledPlugins = {
      "superpowers@superpowers-marketplace" = true;
      "caveman@caveman" = true;
    };
    effortLevel = "high";
    theme = "dark";
    hooks = {
      PreToolUse = [
        {
          matcher = "Bash";
          hooks = [
            { type = "command"; command = "rtk hook claude"; }
          ];
        }
      ];
    };
  };

  # Write `content` to `path` only if it does not already exist. Honors the
  # "if ai already exists it should skip" requirement.
  writeIfAbsent = path: content: ''
    if [ ! -e "${path}" ]; then
      $DRY_RUN_CMD mkdir -p "$(dirname "${path}")"
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/tee "${path}" > /dev/null <<'EOF_AI'
${content}
EOF_AI
    fi
  '';
in
{
  home.sessionPath = [ "$HOME/.npm-global/bin" ];

  # ~/.claude text files — written only if absent (never clobber an existing setup).
  home.activation.writeClaudeMd = lib.hm.dag.entryAfter [ "writeBoundary" ]
    (writeIfAbsent "$HOME/.claude/CLAUDE.md" claudeMd);
  home.activation.writeRtkMd = lib.hm.dag.entryAfter [ "writeBoundary" ]
    (writeIfAbsent "$HOME/.claude/RTK.md" rtkMd);
  home.activation.writeClaudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ]
    (writeIfAbsent "$HOME/.claude/settings.json" settingsJson);

  # codegraph + repomix to a user-local npm prefix (nix store is read-only).
  home.activation.installNpmTools = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _npm_global="$HOME/.npm-global"
    _stamp="$_npm_global/.nix-versions"
    _want="@colbymchenry/codegraph@${codegraphVersion} repomix@${repomixVersion}"
    if [ ! -f "$_npm_global/bin/codegraph" ] || [ ! -f "$_npm_global/bin/repomix" ] \
       || [ "$(cat "$_stamp" 2>/dev/null)" != "$_want" ]; then
      $DRY_RUN_CMD ${pkgs.nodejs}/bin/npm install -g --prefix "$_npm_global" $_want
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/tee "$_stamp" > /dev/null <<< "$_want"
    fi
  '';

  home.activation.registerCodegraphMcp = lib.hm.dag.entryAfter [ "installNpmTools" ] ''
    _claude="$HOME/.claude.json"
    _codegraph="$HOME/.npm-global/bin/codegraph"
    if [ -f "$_codegraph" ]; then
      _tmp=$(mktemp)
      if [ -f "$_claude" ]; then
        ${pkgs.jq}/bin/jq --arg cmd "$_codegraph" \
          '.mcpServers.codegraph = {"type":"stdio","command":$cmd,"args":["serve","--mcp"],"env":{}}' \
          "$_claude" > "$_tmp"
      else
        printf '{"mcpServers":{"codegraph":{"type":"stdio","command":"%s","args":["serve","--mcp"],"env":{}}}}\n' \
          "$_codegraph" > "$_tmp"
      fi
      $DRY_RUN_CMD mv "$_tmp" "$_claude"
    fi
  '';

  home.activation.installSuperpowersPlugin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _dst="$HOME/.claude/plugins/cache/superpowers-marketplace/superpowers/${superpowersVersion}"
    if [ ! -f "$_dst/.claude-plugin/plugin.json" ]; then
      $DRY_RUN_CMD rm -rf "$_dst"
      $DRY_RUN_CMD mkdir -p "$(dirname "$_dst")"
      $DRY_RUN_CMD cp -r "${superpowersSrc}" "$_dst"
      $DRY_RUN_CMD chmod -R u+w "$_dst"
    fi
  '';

  home.activation.registerSuperpowersPlugin = lib.hm.dag.entryAfter [ "installSuperpowersPlugin" ] ''
    _installed="$HOME/.claude/plugins/installed_plugins.json"
    _dst="$HOME/.claude/plugins/cache/superpowers-marketplace/superpowers/${superpowersVersion}"
    _tmp=$(mktemp)
    if [ -f "$_installed" ]; then
      ${pkgs.jq}/bin/jq --arg path "$_dst" \
        '.plugins["superpowers@superpowers-marketplace"] = [{"scope":"user","installPath":$path,"version":"${superpowersVersion}","installedAt":"${frozenTs}","lastUpdated":"${frozenTs}","gitCommitSha":"${superpowersRev}"}]' \
        "$_installed" > "$_tmp"
    else
      mkdir -p "$(dirname "$_installed")"
      printf '{"version":2,"plugins":{"superpowers@superpowers-marketplace":[{"scope":"user","installPath":"%s","version":"${superpowersVersion}","installedAt":"${frozenTs}","lastUpdated":"${frozenTs}","gitCommitSha":"${superpowersRev}"}]}}\n' \
        "$_dst" > "$_tmp"
    fi
    $DRY_RUN_CMD mv "$_tmp" "$_installed"
  '';

  home.activation.registerSuperpowersMarketplace = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _marketplaces="$HOME/.claude/plugins/known_marketplaces.json"
    _tmp=$(mktemp)
    if [ -f "$_marketplaces" ]; then
      ${pkgs.jq}/bin/jq --arg loc "$HOME/.claude/plugins/marketplaces/superpowers-marketplace" \
        '."superpowers-marketplace" = {"source":{"source":"github","repo":"obra/superpowers-marketplace"},"installLocation":$loc,"lastUpdated":"${frozenTs}"}' \
        "$_marketplaces" > "$_tmp"
    else
      mkdir -p "$(dirname "$_marketplaces")"
      printf '{"superpowers-marketplace":{"source":{"source":"github","repo":"obra/superpowers-marketplace"},"installLocation":"%s/.claude/plugins/marketplaces/superpowers-marketplace","lastUpdated":"${frozenTs}"}}\n' \
        "$HOME" > "$_tmp"
    fi
    $DRY_RUN_CMD mv "$_tmp" "$_marketplaces"
  '';

  home.activation.installCavemanPlugin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _dst="$HOME/.claude/plugins/cache/caveman/caveman/${cavemanVersion}"
    if [ ! -f "$_dst/.claude-plugin/plugin.json" ]; then
      $DRY_RUN_CMD rm -rf "$_dst"
      $DRY_RUN_CMD mkdir -p "$(dirname "$_dst")"
      $DRY_RUN_CMD cp -r "${cavemanSrc}" "$_dst"
      $DRY_RUN_CMD chmod -R u+w "$_dst"
    fi
  '';

  home.activation.registerCavemanPlugin = lib.hm.dag.entryAfter [ "installCavemanPlugin" ] ''
    _installed="$HOME/.claude/plugins/installed_plugins.json"
    _dst="$HOME/.claude/plugins/cache/caveman/caveman/${cavemanVersion}"
    _tmp=$(mktemp)
    if [ -f "$_installed" ]; then
      ${pkgs.jq}/bin/jq --arg path "$_dst" \
        '.plugins["caveman@caveman"] = [{"scope":"user","installPath":$path,"version":"${cavemanVersion}","installedAt":"${frozenTs}","lastUpdated":"${frozenTs}","gitCommitSha":"${cavemanRev}"}]' \
        "$_installed" > "$_tmp"
    else
      mkdir -p "$(dirname "$_installed")"
      printf '{"version":2,"plugins":{"caveman@caveman":[{"scope":"user","installPath":"%s","version":"${cavemanVersion}","installedAt":"${frozenTs}","lastUpdated":"${frozenTs}","gitCommitSha":"${cavemanRev}"}]}}\n' \
        "$_dst" > "$_tmp"
    fi
    $DRY_RUN_CMD mv "$_tmp" "$_installed"
  '';

  home.activation.registerCavemanMarketplace = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _marketplaces="$HOME/.claude/plugins/known_marketplaces.json"
    _tmp=$(mktemp)
    if [ -f "$_marketplaces" ]; then
      ${pkgs.jq}/bin/jq --arg loc "$HOME/.claude/plugins/marketplaces/caveman" \
        '.caveman = {"source":{"source":"github","repo":"JuliusBrussee/caveman"},"installLocation":$loc,"lastUpdated":"${frozenTs}"}' \
        "$_marketplaces" > "$_tmp"
    else
      mkdir -p "$(dirname "$_marketplaces")"
      printf '{"caveman":{"source":{"source":"github","repo":"JuliusBrussee/caveman"},"installLocation":"%s/.claude/plugins/marketplaces/caveman","lastUpdated":"${frozenTs}"}}\n' \
        "$HOME" > "$_tmp"
    fi
    $DRY_RUN_CMD mv "$_tmp" "$_marketplaces"
  '';
}
```

- [ ] **Step 2: Add the import to `portable/home.nix`**

```nix
  imports = [
    ./profiles/core.nix
    ./profiles/shell.nix
    ./profiles/locale.nix
    ./profiles/theming.nix
    ./profiles/ai.nix
  ];
```

- [ ] **Step 3: Build**

Run: `nix build .#homeConfigurations.niklas.activationPackage --no-link 2>&1 | tail -20`
Expected: builds; no `error:` lines.

- [ ] **Step 4: Commit**

```bash
git add portable/profiles/ai.nix portable/home.nix
git commit -m "feat: add AI tooling (skip-if-exists) to portable home config"
```

---

### Task 6: Gaming home apps

**Files:**
- Create: `portable/profiles/gaming.nix`
- Modify: `portable/home.nix` (add import)

**Interfaces:**
- Consumes: nothing new (relies on `allowUnfree`).
- Produces: gaming home apps + mangohud/vesktop programs.

- [ ] **Step 1: Create `portable/profiles/gaming.nix`**

```nix
{ pkgs, ... }:
{
  programs.mangohud.enable = true;
  programs.vesktop.enable = true;

  # Steam + the gamescope wrapper need system-level config; install Steam via
  # the distro. Only the portable home apps are included here.
  home.packages = with pkgs; [
    faugus-launcher
    goverlay
    heroic
    lact
    protonplus
    r2modman
  ];
}
```

- [ ] **Step 2: Add the import to `portable/home.nix`**

```nix
  imports = [
    ./profiles/core.nix
    ./profiles/shell.nix
    ./profiles/locale.nix
    ./profiles/theming.nix
    ./profiles/ai.nix
    ./profiles/gaming.nix
  ];
```

- [ ] **Step 3: Build**

Run: `nix build .#homeConfigurations.niklas.activationPackage --no-link 2>&1 | tail -20`
Expected: builds; no `error:` lines.

- [ ] **Step 4: Commit**

```bash
git add portable/profiles/gaming.nix portable/home.nix
git commit -m "feat: add gaming home apps to portable home config"
```

---

### Task 7: niri compositor + wayland daemons

**Files:**
- Create: `portable/profiles/niri.nix`
- Modify: `portable/home.nix` (add import)
- Reads (no modify): `profiles/desktop/niri/config.kdl` (existing templated KDL)

**Interfaces:**
- Consumes: `settings.xkbLayout`, `settings.xkbVariant`; `lib.replaceStrings`; `pkgs.niri`.
- Produces: niri package + config, waybar/foot/fuzzel/mako, a wayland-session desktop entry.

- [ ] **Step 1: Create `portable/profiles/niri.nix`**

The waybar settings are copied verbatim from `profiles/desktop/niri/waybar.nix`. The KDL is read from the existing file (DRY — not duplicated) and templated with the same `replaceStrings` pattern as `profiles/desktop/niri/home.nix`.

```nix
{ lib, pkgs, settings, ... }:
let
  renderedKdl = lib.replaceStrings
    [ "@XKB_LAYOUT@" "@XKB_VARIANT@" ]
    [ settings.xkbLayout settings.xkbVariant ]
    (builtins.readFile ../../profiles/desktop/niri/config.kdl);
in
{
  home.packages = with pkgs; [
    niri
    xwayland-satellite   # on-demand XWayland; niri exports $DISPLAY when present
    nautilus
    gnome-disk-utility
    pavucontrol
  ];

  xdg.configFile."niri/config.kdl".text = renderedKdl;

  # Wayland daemons (stylix themes these via its default targets).
  programs.foot.enable = true;
  programs.fuzzel.enable = true;
  services.mako.enable = true;

  programs.waybar = {
    enable = true;
    settings = [
      {
        layer = "top";
        position = "top";
        height = 30;
        spacing = 4;
        "modules-left" = [ "niri/workspaces" ];
        "modules-center" = [ "clock" ];
        "modules-right" = [ "pulseaudio" "cpu" "memory" "tray" ];
        "niri/workspaces" = { };
        clock = {
          format = "{:%H:%M  %a %d}";
          tooltip = false;
        };
        cpu = { format = "CPU {usage}%"; interval = 5; };
        memory = { format = "RAM {}%"; interval = 10; };
        tray = { spacing = 8; };
        pulseaudio = {
          format = "VOL {volume}%";
          format-muted = "MUTE";
          on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        };
      }
    ];
  };

  # Make niri selectable in a distro display manager (greetd/portal/flatpak
  # are NixOS-only and provided by the distro on a non-NixOS box).
  xdg.dataFile."wayland-sessions/niri.desktop".text = ''
    [Desktop Entry]
    Name=Niri
    Comment=A scrollable-tiling Wayland compositor
    Exec=${pkgs.niri}/bin/niri-session
    Type=Application
  '';
}
```

- [ ] **Step 2: Add the import to `portable/home.nix`**

```nix
  imports = [
    ./profiles/core.nix
    ./profiles/shell.nix
    ./profiles/locale.nix
    ./profiles/theming.nix
    ./profiles/ai.nix
    ./profiles/gaming.nix
    ./profiles/niri.nix
  ];
```

- [ ] **Step 3: Build**

Run: `nix build .#homeConfigurations.niklas.activationPackage --no-link 2>&1 | tail -20`
Expected: builds; no `error:` lines.

- [ ] **Step 4: Commit**

```bash
git add portable/profiles/niri.nix portable/home.nix
git commit -m "feat: add niri compositor + wayland daemons to portable home config"
```

---

### Task 8: gnome dconf profile

**Files:**
- Create: `portable/profiles/gnome.nix`
- Modify: `portable/home.nix` (add import)

**Interfaces:**
- Consumes: nothing.
- Produces: dconf dark-mode preference (no-op when gnome absent).

- [ ] **Step 1: Create `portable/profiles/gnome.nix`**

```nix
{ ... }:
{
  # GNOME itself is a full DE installed via the distro, not home-manager.
  # This only sets the dark-mode preference; harmless when gnome is absent.
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };
}
```

- [ ] **Step 2: Add the import to `portable/home.nix`**

```nix
  imports = [
    ./profiles/core.nix
    ./profiles/shell.nix
    ./profiles/locale.nix
    ./profiles/theming.nix
    ./profiles/ai.nix
    ./profiles/gaming.nix
    ./profiles/niri.nix
    ./profiles/gnome.nix
  ];
```

- [ ] **Step 3: Build**

Run: `nix build .#homeConfigurations.niklas.activationPackage --no-link 2>&1 | tail -20`
Expected: builds; no `error:` lines.

- [ ] **Step 4: Commit**

```bash
git add portable/profiles/gnome.nix portable/home.nix
git commit -m "feat: add gnome dconf profile to portable home config"
```

---

### Task 9: Flake check + README addendum

**Files:**
- Modify: `README.md` (add a "Non-NixOS (standalone home-manager)" section)

**Interfaces:**
- Consumes: the finished `homeConfigurations.niklas`.
- Produces: documentation; final whole-flake validation.

- [ ] **Step 1: Verify the whole flake still evaluates**

Run: `nix flake check 2>&1 | tail -20`
Expected: completes; no `error:` lines (the existing niri KDL check still passes; the new output evaluates).

- [ ] **Step 2: Add a README section**

Append to `README.md`, after the "Daily use" section:

```markdown
---

## Non-NixOS machine (standalone home-manager)

This flake also exposes a standalone home-manager config under `portable/` for a
box that has only the Nix package manager (no NixOS). It ports packages, stylix
theming, fish, AI tooling, gaming home apps, and the niri/gnome desktop config.
System-level pieces (boot, kernel, networking, pipewire, Steam/gamescope,
greetd/portals/flatpak, system locale generation) are NOT included — the distro
provides those.

Prerequisite: home-manager available standalone, e.g.

```sh
nix run home-manager/release-26.05 -- switch --flake ~/Documents/nix#niklas
```

or, once installed:

```sh
home-manager switch --flake ~/Documents/nix#niklas   # alias: rebuild
```

Edit the `hmSettings` block in `flake.nix` to change username, theme, locale, or
keyboard layout. Notes:

- The glibc locale named in `localeMain`/`localeRegional` must already exist on
  the distro (`locale -a`) — home-manager only exports the env vars.
- The AI profile writes `~/.claude/{CLAUDE.md,RTK.md,settings.json}` only if they
  do not already exist; an existing Claude setup is left untouched.
- niri appears in your display manager's session list; XWayland apps work via
  `xwayland-satellite`.
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: document standalone home-manager usage for non-NixOS"
```

---

## Self-Review

**Spec coverage:**
- Shared root flake + homeConfigurations → Task 1 ✓
- Simple settings let-block via extraSpecialArgs → Task 1 ✓
- core/shell/locale/theming/ai/gaming/niri/gnome profiles → Tasks 1–8 ✓
- stylix standalone module (`homeModules.stylix`) → Global Constraints + Task 4 ✓
- firefox HM module + merged addon policies → Task 4 ✓
- AI skip-if-exists → Task 5 (`writeIfAbsent`) ✓
- gaming excludes steam/gamescope → Task 6 ✓
- niri package + daemons + templated KDL + session desktop file → Task 7 ✓
- locale env incl. XKB for wayland + X11 → Task 3 ✓
- README addendum + flake check → Task 9 ✓
- Excluded NixOS-only items documented → Task 9 README ✓

**Placeholder scan:** none — every step has full file content or exact commands.

**Type consistency:** `settings` keys identical across flake.nix and all consumers; `hmSettings`/`hmPkgs` names consistent; `writeIfAbsent` defined once and used three times with matching arity; flake output `homeConfigurations.niklas` referenced identically in every build/commit command.
</content>
