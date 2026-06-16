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

    @RTK.md
  '';

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
    Example: `git status` → `rtk hook claude git status` (transparent, 0 tokens overhead)

    Refer to CLAUDE.md for full command reference.
  '';

  home.sessionPath = [ "$HOME/.npm-global/bin" ];

  # Install codegraph and repomix to user-local npm prefix (nix store is read-only)
  home.activation.installNpmTools = lib.hm.dag.entryAfter ["writeBoundary"] ''
    _npm_global="$HOME/.npm-global"
    if [ ! -f "$_npm_global/bin/codegraph" ] || [ ! -f "$_npm_global/bin/repomix" ]; then
      $DRY_RUN_CMD ${pkgs.nodejs}/bin/npm install -g --prefix "$_npm_global" @colbymchenry/codegraph repomix
    fi
  '';

  # Register codegraph as a user-scoped MCP server in ~/.claude.json
  # Uses absolute claude path — claude mcp add is non-interactive and handles file creation/merge
  home.activation.registerCodegraphMcp = lib.hm.dag.entryAfter ["installNpmTools"] ''
    _codegraph="$HOME/.npm-global/bin/codegraph"
    _claude="/run/current-system/sw/bin/claude"
    if [ -f "$_codegraph" ] && [ -x "$_claude" ]; then
      if ! grep -q '"codegraph"' "$HOME/.claude.json" 2>/dev/null; then
        $DRY_RUN_CMD "$_claude" mcp add codegraph -s user -- "$_codegraph" serve --mcp
      fi
    fi
  '';

  # Install caveman plugin — requires network to fetch from GitHub marketplace
  home.activation.installCaveman = lib.hm.dag.entryAfter ["writeBoundary"] ''
    _claude="/run/current-system/sw/bin/claude"
    if [ -x "$_claude" ] && ! grep -q '"caveman@caveman"' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null; then
      $DRY_RUN_CMD "$_claude" plugin marketplace add JuliusBrussee/caveman || true
      $DRY_RUN_CMD "$_claude" plugin install caveman@caveman || true
    fi
  '';

  # Write rtk PreToolUse hook directly to ~/.claude/settings.json via jq
  # Cannot use `rtk init -g` — it tries to modify ~/.claude/CLAUDE.md which is a
  # read-only nix store symlink, and in non-interactive mode it skips the hook write anyway
  home.activation.initRtk = lib.hm.dag.entryAfter ["writeBoundary"] ''
    _settings="$HOME/.claude/settings.json"
    if ! grep -q "rtk hook claude" "$_settings" 2>/dev/null; then
      _tmp=$(mktemp)
      if [ -f "$_settings" ]; then
        ${pkgs.jq}/bin/jq \
          '.hooks.PreToolUse = ((.hooks.PreToolUse // []) + [{"matcher":"Bash","hooks":[{"type":"command","command":"rtk hook claude"}]}])' \
          "$_settings" > "$_tmp"
      else
        mkdir -p "$HOME/.claude"
        printf '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"rtk hook claude"}]}]}}\n' > "$_tmp"
      fi
      $DRY_RUN_CMD mv "$_tmp" "$_settings"
    fi
  '';
}
