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

  home.sessionPath = [ "$HOME/.npm-global/bin" ];

  home.activation.installNpmTools = lib.hm.dag.entryAfter ["writeBoundary"] ''
    _npm_global="$HOME/.npm-global"
    if [ ! -f "$_npm_global/bin/codegraph" ] || [ ! -f "$_npm_global/bin/repomix" ]; then
      $DRY_RUN_CMD ${pkgs.nodejs}/bin/npm install -g --prefix "$_npm_global" @colbymchenry/codegraph repomix
    fi
  '';

  home.activation.registerCodegraphMcp = lib.hm.dag.entryAfter ["installNpmTools"] ''
    _codegraph="$HOME/.npm-global/bin/codegraph"
    _claude="/run/current-system/sw/bin/claude"
    if [ -x "$_claude" ] && [ -f "$_codegraph" ]; then
      if ! "$_claude" mcp list 2>/dev/null | grep -q "codegraph"; then
        $DRY_RUN_CMD "$_claude" mcp add codegraph -s user -- "$_codegraph" serve --mcp
      fi
    fi
  '';

  home.activation.installCaveman = lib.hm.dag.entryAfter ["writeBoundary"] ''
    _claude="/run/current-system/sw/bin/claude"
    if [ -x "$_claude" ] && ! grep -q '"caveman"' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null; then
      $DRY_RUN_CMD "$_claude" plugin marketplace add JuliusBrussee/caveman || true
      $DRY_RUN_CMD "$_claude" plugin install caveman@caveman || true
    fi
  '';

  home.activation.initRtk = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if ! grep -q "rtk-rewrite" "$HOME/.claude/settings.json" 2>/dev/null; then
      $DRY_RUN_CMD ${pkgs.rtk}/bin/rtk init -g
    fi
  '';
}
