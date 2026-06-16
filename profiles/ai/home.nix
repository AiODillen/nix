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
