{ lib, osConfig, pkgs, ... }:
let
  cavemanVersion = "25d22f864ad6";
  cavemanRev = "25d22f864ad68cc447a4cb93aefde918aa4aec9f";
  cavemanSrc = pkgs.fetchFromGitHub {
    owner = "JuliusBrussee";
    repo = "caveman";
    rev = cavemanRev;
    hash = "sha256-FbmfhFaPs/SnSZdfNdErdIUHXt1FfBzErpPpLy8kdIc=";
  };

  # superpowers plugin lives in obra/superpowers; obra/superpowers-marketplace is
  # only the marketplace index. Pin the plugin repo at the 6.0.2 release commit.
  superpowersVersion = "6.0.2";
  superpowersRev = "6efe32c9e2dd002d0c394e861e0529675d1ab32e";
  superpowersSrc = pkgs.fetchFromGitHub {
    owner = "obra";
    repo = "superpowers";
    rev = superpowersRev;
    # Placeholder — first `nixos-rebuild switch` fails and prints the real hash.
    # Paste the `got: sha256-...` value here and rebuild again.
    hash = lib.fakeHash;
  };

  # Pinned npm tool versions (installed to ~/.npm-global; see installNpmTools).
  codegraphVersion = "1.0.1";
  repomixVersion = "1.14.1";
in
lib.mkIf osConfig.mySystem.ai.enable {
  # User instructions loaded by Claude Code on every session
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

    @RTK.md
  '';

  # Loaded by @RTK.md reference above — rtk command reference
  home.file.".claude/RTK.md".text = ''
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

  # Declaratively owned: hooks, enabled plugins, preferences.
  # Claude Code UI cannot persist changes here — edit this file and rebuild instead.
  home.file.".claude/settings.json".text = builtins.toJSON {
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
            {
              type = "command";
              command = "rtk hook claude";
            }
          ];
        }
      ];
    };
  };

  home.sessionPath = [ "$HOME/.npm-global/bin" ];

  # Install codegraph and repomix to user-local npm prefix (nix store is read-only).
  # Versions are pinned; a version-stamp file forces reinstall when the pins change.
  home.activation.installNpmTools = lib.hm.dag.entryAfter ["writeBoundary"] ''
    _npm_global="$HOME/.npm-global"
    _stamp="$_npm_global/.nix-versions"
    _want="@colbymchenry/codegraph@${codegraphVersion} repomix@${repomixVersion}"
    if [ ! -f "$_npm_global/bin/codegraph" ] || [ ! -f "$_npm_global/bin/repomix" ] \
       || [ "$(cat "$_stamp" 2>/dev/null)" != "$_want" ]; then
      $DRY_RUN_CMD ${pkgs.nodejs}/bin/npm install -g --prefix "$_npm_global" $_want
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/tee "$_stamp" > /dev/null <<< "$_want"
    fi
  '';

  # Always overwrite codegraph MCP entry in ~/.claude.json
  home.activation.registerCodegraphMcp = lib.hm.dag.entryAfter ["installNpmTools"] ''
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

  # Copy superpowers plugin files from nix store to a writable path so Claude can
  # create .in_use/ lock files and other runtime state alongside the plugin files
  home.activation.installSuperpowersPlugin = lib.hm.dag.entryAfter ["writeBoundary"] ''
    _dst="$HOME/.claude/plugins/cache/superpowers-marketplace/superpowers/${superpowersVersion}"
    if [ ! -f "$_dst/.claude-plugin/plugin.json" ]; then
      $DRY_RUN_CMD rm -rf "$_dst"
      $DRY_RUN_CMD mkdir -p "$(dirname "$_dst")"
      $DRY_RUN_CMD cp -r "${superpowersSrc}" "$_dst"
      $DRY_RUN_CMD chmod -R u+w "$_dst"
    fi
  '';

  # Always ensure superpowers is registered in installed_plugins.json (merge, don't replace)
  home.activation.registerSuperpowersPlugin = lib.hm.dag.entryAfter ["installSuperpowersPlugin"] ''
    _installed="$HOME/.claude/plugins/installed_plugins.json"
    _dst="$HOME/.claude/plugins/cache/superpowers-marketplace/superpowers/${superpowersVersion}"
    _tmp=$(mktemp)
    if [ -f "$_installed" ]; then
      ${pkgs.jq}/bin/jq --arg path "$_dst" \
        '.plugins["superpowers@superpowers-marketplace"] = [{"scope":"user","installPath":$path,"version":"${superpowersVersion}","installedAt":"2026-06-16T00:00:00.000Z","lastUpdated":"2026-06-16T00:00:00.000Z","gitCommitSha":"${superpowersRev}"}]' \
        "$_installed" > "$_tmp"
    else
      mkdir -p "$(dirname "$_installed")"
      printf '{"version":2,"plugins":{"superpowers@superpowers-marketplace":[{"scope":"user","installPath":"%s","version":"${superpowersVersion}","installedAt":"2026-06-16T00:00:00.000Z","lastUpdated":"2026-06-16T00:00:00.000Z","gitCommitSha":"${superpowersRev}"}]}}\n' \
        "$_dst" > "$_tmp"
    fi
    $DRY_RUN_CMD mv "$_tmp" "$_installed"
  '';

  # Always ensure superpowers marketplace is registered in known_marketplaces.json (merge, don't replace)
  home.activation.registerSuperpowersMarketplace = lib.hm.dag.entryAfter ["writeBoundary"] ''
    _marketplaces="$HOME/.claude/plugins/known_marketplaces.json"
    _tmp=$(mktemp)
    if [ -f "$_marketplaces" ]; then
      ${pkgs.jq}/bin/jq --arg loc "$HOME/.claude/plugins/marketplaces/superpowers-marketplace" \
        '."superpowers-marketplace" = {"source":{"source":"github","repo":"obra/superpowers-marketplace"},"installLocation":$loc,"lastUpdated":"2026-06-16T00:00:00.000Z"}' \
        "$_marketplaces" > "$_tmp"
    else
      mkdir -p "$(dirname "$_marketplaces")"
      printf '{"superpowers-marketplace":{"source":{"source":"github","repo":"obra/superpowers-marketplace"},"installLocation":"%s/.claude/plugins/marketplaces/superpowers-marketplace","lastUpdated":"2026-06-16T00:00:00.000Z"}}\n' \
        "$HOME" > "$_tmp"
    fi
    $DRY_RUN_CMD mv "$_tmp" "$_marketplaces"
  '';

  # Copy caveman plugin files from nix store to a writable path so Claude can
  # create .in_use/ lock files and other runtime state alongside the plugin files
  home.activation.installCavemanPlugin = lib.hm.dag.entryAfter ["writeBoundary"] ''
    _dst="$HOME/.claude/plugins/cache/caveman/caveman/${cavemanVersion}"
    if [ ! -f "$_dst/.claude-plugin/plugin.json" ]; then
      $DRY_RUN_CMD rm -rf "$_dst"
      $DRY_RUN_CMD mkdir -p "$(dirname "$_dst")"
      $DRY_RUN_CMD cp -r "${cavemanSrc}" "$_dst"
      $DRY_RUN_CMD chmod -R u+w "$_dst"
    fi
  '';

  # Always ensure caveman is registered in installed_plugins.json (merge, don't replace)
  home.activation.registerCavemanPlugin = lib.hm.dag.entryAfter ["installCavemanPlugin"] ''
    _installed="$HOME/.claude/plugins/installed_plugins.json"
    _dst="$HOME/.claude/plugins/cache/caveman/caveman/${cavemanVersion}"
    _tmp=$(mktemp)
    if [ -f "$_installed" ]; then
      ${pkgs.jq}/bin/jq --arg path "$_dst" \
        '.plugins["caveman@caveman"] = [{"scope":"user","installPath":$path,"version":"${cavemanVersion}","installedAt":"2026-06-16T00:00:00.000Z","lastUpdated":"2026-06-16T00:00:00.000Z","gitCommitSha":"${cavemanRev}"}]' \
        "$_installed" > "$_tmp"
    else
      mkdir -p "$(dirname "$_installed")"
      printf '{"version":2,"plugins":{"caveman@caveman":[{"scope":"user","installPath":"%s","version":"${cavemanVersion}","installedAt":"2026-06-16T00:00:00.000Z","lastUpdated":"2026-06-16T00:00:00.000Z","gitCommitSha":"${cavemanRev}"}]}}\n' \
        "$_dst" > "$_tmp"
    fi
    $DRY_RUN_CMD mv "$_tmp" "$_installed"
  '';

  # Always ensure caveman marketplace is registered in known_marketplaces.json (merge, don't replace)
  home.activation.registerCavemanMarketplace = lib.hm.dag.entryAfter ["writeBoundary"] ''
    _marketplaces="$HOME/.claude/plugins/known_marketplaces.json"
    _tmp=$(mktemp)
    if [ -f "$_marketplaces" ]; then
      ${pkgs.jq}/bin/jq --arg loc "$HOME/.claude/plugins/marketplaces/caveman" \
        '.caveman = {"source":{"source":"github","repo":"JuliusBrussee/caveman"},"installLocation":$loc,"lastUpdated":"2026-06-16T00:00:00.000Z"}' \
        "$_marketplaces" > "$_tmp"
    else
      mkdir -p "$(dirname "$_marketplaces")"
      printf '{"caveman":{"source":{"source":"github","repo":"JuliusBrussee/caveman"},"installLocation":"%s/.claude/plugins/marketplaces/caveman","lastUpdated":"2026-06-16T00:00:00.000Z"}}\n' \
        "$HOME" > "$_tmp"
    fi
    $DRY_RUN_CMD mv "$_tmp" "$_marketplaces"
  '';
}
