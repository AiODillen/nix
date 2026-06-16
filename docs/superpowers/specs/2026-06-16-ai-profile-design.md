# AI Profile Module Design

**Date:** 2026-06-16
**Status:** Approved

## Goal

Create a dedicated `profiles/ai` NixOS profile module that installs and configures Claude Code and its supporting AI tooling: `rtk` (command proxy), `codegraph` (semantic MCP server), `caveman` (response compression skill), and `repomix` (repo packing). Move `claude-code` out of the `core` profile so AI tooling is opt-in. Manage a global `~/.claude/CLAUDE.md` that instructs Claude how to use all installed tools.

## Background

`claude-code` currently lives in `profiles/core/nixos.nix` under `environment.systemPackages`, making it unconditionally installed for all system configurations. The new `ai` profile follows the same `mySystem.ai.enable` opt-in pattern used by `gaming` and `theming`.

## Files Changed

| File | Change |
|------|--------|
| `modules/options.nix` | Add `mySystem.ai.enable` option |
| `profiles/core/nixos.nix` | Remove `claude-code` from `systemPackages` |
| `profiles/ai/nixos.nix` | New — system packages: `claude-code`, `rtk`, `nodejs` |
| `profiles/ai/home.nix` | New — npm installs, MCP registration, rtk init, CLAUDE.md |
| `hosts/nixos/default.nix` | Import `profiles/ai/nixos.nix`; set `mySystem.ai.enable = true` |
| `users/dillen/default.nix` | Import `profiles/ai/home.nix` |

## Tool Inventory

### rtk — nixpkgs (`pkgs.rtk` v0.42.3, MIT)

"Rust Token Killer." CLI proxy that intercepts Bash tool calls inside Claude Code and compresses output before it enters the context window. Reduces token consumption 60–90% on common dev commands (git, cargo, pytest, docker, etc.). After `rtk init -g`, a `PreToolUse` hook in `~/.claude/settings.json` transparently rewrites commands — zero per-command overhead for the user. Analytics via `rtk gain`.

### codegraph — npm (`@colbymchenry/codegraph`)

MCP server providing pre-indexed semantic code intelligence. Claude calls `codegraph_search` and `codegraph_explore` instead of reading whole files. Benchmarked at ~16% fewer tokens and ~58% fewer tool calls on typical tasks. Runs locally with no external services. MCP config: `{"command": "codegraph", "args": ["serve", "--mcp"]}`.

### caveman — Claude Code plugin (`JuliusBrussee/caveman`)

Claude Code skill that compresses AI response tokens by ~65% using terse "caveman" output style. Installed as a Claude Code marketplace plugin via `claude plugin marketplace add JuliusBrussee/caveman`. Triggered via `/caveman` or the global CLAUDE.md instruction to default to terse output.

### repomix — npm (`repomix`)

Fully standalone (no API keys, no accounts). Packs an entire repository into a single LLM-optimised file (XML/Markdown/plain text). Complements codegraph: use repomix at session start when Claude needs full context (new project onboarding, large refactors), then use codegraph's MCP tools for targeted queries throughout the session. Run ad-hoc: `repomix --output repomix-output.xml`.

## Architecture

### `profiles/ai/nixos.nix`

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

`rtk` is in nixpkgs. `nodejs` provides the npm runtime needed for codegraph, caveman, and repomix installs. `claude-code` moves here from `core`.

### `profiles/ai/home.nix`

`codegraph`, `caveman`, and `repomix` cannot be packaged cleanly from nixpkgs (not yet in the package set). They are installed via `home.activation` scripts that run during `nixos-rebuild switch`. Each script is idempotent — it checks whether the tool is already present before running.

Claude Code manages `~/.claude/settings.json` itself; the activation scripts append to it (via `rtk init -g` and the caveman installer) rather than home-manager owning the file, avoiding conflicts.

#### Activation scripts

**`installNpmTools`** — runs `npm install -g @colbymchenry/codegraph repomix` if either binary is missing from PATH.

**`registerCodegraphMcp`** — runs `claude mcp add codegraph -s user -- codegraph serve --mcp` if `claude mcp list` does not already show a `codegraph` entry.

**`installCaveman`** — runs `claude plugin marketplace add JuliusBrussee/caveman && claude plugin install caveman@caveman` if the caveman plugin directory is absent from `~/.claude/plugins/`.

**`initRtk`** — runs `rtk init -g` if the `rtk-rewrite` hook string is absent from `~/.claude/settings.json`.

All four use `lib.hm.dag.entryAfter ["writeBoundary"]`.

### Global CLAUDE.md — `~/.claude/CLAUDE.md`

Managed via `home.file.".claude/CLAUDE.md"`. Content instructs Claude how to use each installed tool:

```markdown
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
```

## Options

`modules/options.nix` gains:

```nix
ai.enable = lib.mkEnableOption "AI profile (Claude Code, rtk, codegraph, caveman, repomix)";
```

## Host/User Wiring

`hosts/nixos/default.nix` imports `profiles/ai/nixos.nix` alongside the other profiles and sets `mySystem.ai.enable = true`.

`users/dillen/default.nix` imports `profiles/ai/home.nix`.

## Post-Switch Notes

- `codegraph init` must be run manually once per project repository to build the initial index.
- `codegraph sync` keeps the index current after large changes (auto-sync handles small edits).
- context7 MCP (live library docs) is not included here but can be added later with `npx ctx7 setup --claude`.
