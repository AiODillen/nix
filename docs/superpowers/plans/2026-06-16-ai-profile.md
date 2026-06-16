# AI Profile Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create `profiles/ai` with Claude Code, rtk, codegraph, caveman, and repomix; move `claude-code` out of `core`; wire a global `~/.claude/CLAUDE.md` via home-manager.

**Architecture:** A new `mySystem.ai.enable` option gates `profiles/ai/nixos.nix` (system packages) and `profiles/ai/home.nix` (CLAUDE.md + idempotent activation scripts for npm tools, MCP registration, caveman plugin, and rtk init). Follows the exact same opt-in pattern as `gaming` and `theming` profiles.

**Tech Stack:** NixOS 26.05, home-manager, nixpkgs (`rtk`), npm (`@colbymchenry/codegraph`, `repomix`), Claude Code plugin system (`caveman`).

---

## File Map

| File | Action |
|------|--------|
| `modules/options.nix` | Add `mySystem.ai.enable` option |
| `profiles/core/nixos.nix` | Remove `claude-code` from `systemPackages` |
| `profiles/ai/nixos.nix` | Create — packages: `claude-code`, `rtk`, `nodejs` |
| `profiles/ai/home.nix` | Create — CLAUDE.md + 4 activation scripts |
| `hosts/nixos/default.nix` | Import `profiles/ai/nixos.nix`; set `mySystem.ai.enable = true` |
| `users/dillen/default.nix` | Import `profiles/ai/home.nix` |

---

### Task 1: Add `mySystem.ai.enable` option

**Files:**
- Modify: `modules/options.nix`

- [ ] **Step 1: Add the option**

Replace the entire file with:

```nix
{ lib, ... }:
{
  options.mySystem = {
    desktop = lib.mkOption {
      type = lib.types.enum [
        "niri"
        "gnome"
      ];
      default = "niri";
      description = "Which desktop environment to enable. Change and run nixos-rebuild switch.";
    };

    ai.enable = lib.mkEnableOption "AI profile (Claude Code, rtk, codegraph, caveman, repomix)";

    gaming.enable = lib.mkEnableOption "gaming profile (Steam, gamescope, gaming home apps)";

    theming.enable = lib.mkEnableOption "stylix theming profile (system + home)";

    storage.automount.enable = lib.mkEnableOption "automount profile (extra filesystems under /home/dillen)";
  };
}
```

- [ ] **Step 2: Verify eval**

```bash
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --dry-run 2>&1 | tail -5
```

Expected: exits 0, no eval errors.

- [ ] **Step 3: Commit**

```bash
git add modules/options.nix
git commit -m "feat(ai): add mySystem.ai.enable option"
```

---

### Task 2: Remove `claude-code` from core

**Files:**
- Modify: `profiles/core/nixos.nix`

- [ ] **Step 1: Remove `claude-code` from systemPackages**

Replace the entire file with:

```nix
{ pkgs, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Berlin";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };

  console.keyMap = "de-latin1-nodeadkeys";

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  programs.fish.enable = true;

  users.users.dillen = {
    isNormalUser = true;
    description = "dillen";
    shell = pkgs.fish;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  programs.firefox.enable = true;
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    git
    micro
    gram
    r2modman
  ];

  system.stateVersion = "26.05";
}
```

Note: `claude-code` is removed. It will be re-added via `profiles/ai/nixos.nix`.

- [ ] **Step 2: Verify eval**

```bash
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --dry-run 2>&1 | tail -5
```

Expected: exits 0 (eval will succeed because `ai.enable = true` will be set in Task 5, but Task 2 alone may warn about missing claude-code — that's fine, the next tasks add it back).

- [ ] **Step 3: Commit**

```bash
git add profiles/core/nixos.nix
git commit -m "refactor(core): remove claude-code from core — moved to ai profile"
```

---

### Task 3: Create `profiles/ai/nixos.nix`

**Files:**
- Create: `profiles/ai/nixos.nix`

- [ ] **Step 1: Create the file**

```nix
{ config, lib, pkgs, ... }:
lib.mkIf config.mySystem.ai.enable {
  environment.systemPackages = with pkgs; [
    claude-code
    rtk
    nodejs
  ];
}
```

- [ ] **Step 2: Verify eval**

```bash
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --dry-run 2>&1 | tail -5
```

Expected: exits 0. (Will succeed once Task 5 adds the import and enables the option.)

- [ ] **Step 3: Commit**

```bash
git add profiles/ai/nixos.nix
git commit -m "feat(ai): add ai nixos profile with claude-code, rtk, nodejs"
```

---

### Task 4: Create `profiles/ai/home.nix`

**Files:**
- Create: `profiles/ai/home.nix`

This file manages the global `~/.claude/CLAUDE.md` and runs four idempotent activation scripts during every `nixos-rebuild switch`.

**Activation script notes:**
- `$DRY_RUN_CMD` expands to `echo` during `--dry-run` and to empty string during real switches — always prefix state-changing commands with it.
- `entryAfter ["writeBoundary"]` ensures scripts run after home-manager writes its own files.
- `registerCodegraphMcp` uses `entryAfter ["installNpmTools"]` so `codegraph` is on PATH before MCP registration.
- If `claude plugin marketplace add` requires interactive auth and fails, caveman won't install automatically — the user can run `claude plugin marketplace add JuliusBrussee/caveman` manually post-switch.

- [ ] **Step 1: Create the file**

```nix
{ lib, osConfig, pkgs, ... }:
lib.mkIf osConfig.mySystem.ai.enable {
  home.file.".claude/CLAUDE.md".text = ''
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
  '';

  home.activation.installNpmTools = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if ! command -v codegraph >/dev/null 2>&1 || ! command -v repomix >/dev/null 2>&1; then
      $DRY_RUN_CMD ${pkgs.nodejs}/bin/npm install -g @colbymchenry/codegraph repomix
    fi
  '';

  home.activation.registerCodegraphMcp = lib.hm.dag.entryAfter ["installNpmTools"] ''
    if command -v claude >/dev/null 2>&1 && command -v codegraph >/dev/null 2>&1; then
      if ! claude mcp list 2>/dev/null | grep -q "codegraph"; then
        $DRY_RUN_CMD claude mcp add codegraph -s user -- codegraph serve --mcp
      fi
    fi
  '';

  home.activation.installCaveman = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ ! -d "$HOME/.claude/plugins/caveman" ]; then
      if command -v claude >/dev/null 2>&1; then
        $DRY_RUN_CMD claude plugin marketplace add JuliusBrussee/caveman
        $DRY_RUN_CMD claude plugin install caveman@caveman
      fi
    fi
  '';

  home.activation.initRtk = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if command -v rtk >/dev/null 2>&1; then
      if ! grep -q "rtk-rewrite" "$HOME/.claude/settings.json" 2>/dev/null; then
        $DRY_RUN_CMD ${pkgs.rtk}/bin/rtk init -g
      fi
    fi
  '';
}
```

- [ ] **Step 2: Verify eval**

```bash
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --dry-run 2>&1 | tail -5
```

Expected: exits 0.

- [ ] **Step 3: Commit**

```bash
git add profiles/ai/home.nix
git commit -m "feat(ai): add ai home profile — CLAUDE.md, rtk init, codegraph MCP, caveman"
```

---

### Task 5: Wire host and user configs

**Files:**
- Modify: `hosts/nixos/default.nix`
- Modify: `users/dillen/default.nix`

- [ ] **Step 1: Update `hosts/nixos/default.nix`**

Replace the entire file with:

```nix
{ inputs, ... }:
{
  disabledModules = [
    # Stylix's kmscon module is incompatible with nixpkgs 26.05
    # services.kmscon.config was removed
    "${inputs.stylix}/modules/kmscon/nixos.nix"
  ];

  imports = [
    ./hardware.nix
    ../../modules/options.nix
    ../../profiles/core/nixos.nix
    ../../profiles/theming/nixos.nix
    ../../profiles/desktop/niri/nixos.nix
    ../../profiles/desktop/gnome/nixos.nix
    ../../profiles/gaming/nixos.nix
    ../../profiles/storage/nixos.nix
    ../../profiles/ai/nixos.nix
  ];

  # ── DE SWITCH ──────────────────────────────────────────────
  # Change to "gnome" and run: sudo nixos-rebuild switch --flake ~/nixos-config#nixos
  mySystem = {
    desktop = "niri";
    ai.enable = true;
    gaming.enable = true;
    theming.enable = true;
    storage.automount.enable = true;
  };
  # ───────────────────────────────────────────────────────────

  # wallpaper.png is at the flake root; path resolves correctly from this file
  stylix.image = ../../wallpaper.png;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit inputs; };
    users.dillen = import ../../users/dillen/default.nix;
  };
}
```

- [ ] **Step 2: Update `users/dillen/default.nix`**

Replace the entire file with:

```nix
{ ... }:
{
  imports = [
    ../../profiles/core/home.nix
    ../../profiles/theming/home.nix
    ../../profiles/desktop/niri/home.nix
    ../../profiles/desktop/gnome/home.nix
    ../../profiles/gaming/home.nix
    ../../profiles/ai/home.nix
    ../../profiles/shell/fish.nix
  ];

  home.username = "dillen";
  home.homeDirectory = "/home/dillen";
  home.stateVersion = "26.05";
}
```

- [ ] **Step 3: Verify eval**

```bash
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --dry-run 2>&1 | tail -5
```

Expected: exits 0, no eval errors.

- [ ] **Step 4: Commit**

```bash
git add hosts/nixos/default.nix users/dillen/default.nix
git commit -m "feat(ai): wire ai profile into host and user configs"
```

---

### Task 6: Apply and verify

- [ ] **Step 1: Switch to the new config** (requires sudo)

```bash
sudo nixos-rebuild switch --flake .#nixos 2>&1 | tail -20
```

Expected: build and activation complete with no errors.

- [ ] **Step 2: Verify rtk is present and initialised**

```bash
which rtk && rtk --version
grep -c "rtk-rewrite" ~/.claude/settings.json
```

Expected: `rtk` found, version printed, count ≥ 1 (hook present in settings.json).

If `grep` returns 0, run `rtk init -g` manually and re-check.

- [ ] **Step 3: Verify CLAUDE.md content**

```bash
cat ~/.claude/CLAUDE.md
```

Expected: file contains all four sections — `## Code Intelligence (codegraph)`, `## Command Output (rtk)`, `## Codebase Packing (repomix)`, `## Response Style (caveman)`.

- [ ] **Step 4: Verify codegraph is installed**

```bash
which codegraph && codegraph --version 2>/dev/null || codegraph --help 2>&1 | head -3
```

Expected: `codegraph` binary found.

- [ ] **Step 5: Verify codegraph MCP registration**

```bash
claude mcp list
```

Expected: output includes a `codegraph` entry. If not present, run manually:

```bash
claude mcp add codegraph -s user -- codegraph serve --mcp
```

- [ ] **Step 6: Verify repomix is installed**

```bash
which repomix && repomix --version
```

Expected: `repomix` found and version printed.

- [ ] **Step 7: Check caveman plugin**

```bash
ls ~/.claude/plugins/ | grep -i caveman || echo "caveman not yet installed"
```

If not present, run manually (requires Claude Code login):

```bash
claude plugin marketplace add JuliusBrussee/caveman
claude plugin install caveman@caveman
```

- [ ] **Step 8: Run flake check**

```bash
nix --extra-experimental-features "nix-command flakes" flake check 2>&1 | tail -5
```

Expected: `all checks passed!`
