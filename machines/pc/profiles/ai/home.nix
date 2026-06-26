# AI home profile (Claude Code config files). Imported only when
# vars.modules.ai = true (gated in machines/pc/home.nix), no guard here.
{ ... }:
{
  imports = [ ./claude-plugins.nix ];

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
}

