# AI Profile Module Design

**Date:** 2026-06-16
**Status:** Approved

## Goal

Create a dedicated `profiles/ai` NixOS profile module that installs and configures Claude Code and its supporting AI tooling: `rtk` (command proxy), `codegraph` (semantic MCP server), `caveman` (response compression skill), `superpowers` (core skills library), and `repomix` (repo packing). Move `claude-code` out of the `core` profile so AI tooling is opt-in. Manage a global `~/.claude/CLAUDE.md` that instructs Claude how to use all installed tools.

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

Claude Code skill that compresses AI response tokens by ~65% using terse "caveman" output style. Pinned via `fetchFromGitHub` (rev + hash) and copied into the writable plugin cache, then registered in `installed_plugins.json` + `known_marketplaces.json` by activation scripts. Triggered via `/caveman` or the global CLAUDE.md instruction to default to terse output.

### superpowers — Claude Code plugin (`obra/superpowers` via `obra/superpowers-marketplace`)

Core skills library (TDD, debugging, brainstorming, planning, collaboration workflows). The plugin source is `obra/superpowers`; `obra/superpowers-marketplace` is only the marketplace index. Provisioned the same way as caveman: `fetchFromGitHub` pin of `obra/superpowers` at the release commit, copy into the plugin cache, register `superpowers@superpowers-marketplace` in `installed_plugins.json` and the `superpowers-marketplace` entry in `known_marketplaces.json`. Enabled via `enabledPlugins` in the declaratively-owned `settings.json`.

### repomix — npm (`repomix`)

Fully standalone (no API keys, no accounts). Packs an entire repository into a single LLM-optimised file (XML/Markdown/plain text). Complements codegraph: use repomix at session start when Claude needs full context (new project onboarding, large refactors), then use codegraph's MCP tools for targeted queries throughout the session. Run ad-hoc: `repomix --output repomix-output.xml`.

## Architecture

### `profiles/ai/nixos.nix`

```nix
{ config, lib, pkgs, ... }:
lib.mkIf config.mySystem.ai.enable {
  programs.nix-ld.enable = true;
  # codegraph's prebuilt native node addons (tree-sitter, better-sqlite3)
  # dynamically link against these at runtime under nix-ld.
  programs.nix-ld.libraries = with pkgs; [ stdenv.cc.cc.lib zlib openssl ];

  environment.systemPackages = with pkgs; [
    claude-code
    rtk
    nodejs
  ];
}
```

`rtk` is in nixpkgs. `nodejs` provides the npm runtime needed for codegraph and repomix installs. `claude-code` moves here from `core`. `nix-ld` is required so the prebuilt npm native binaries run on NixOS.

### `profiles/ai/home.nix`

`codegraph` and `repomix` are not in nixpkgs; they install to a user-local npm prefix (`~/.npm-global`) via a `home.activation` script. `caveman` and `superpowers` are Claude Code plugins, pinned via `fetchFromGitHub` and copied from the nix store into the writable plugin cache, then registered via `jq`-merged JSON.

`settings.json`, `CLAUDE.md`, and `RTK.md` are **owned declaratively** by home-manager (`home.file`). `settings.json` carries `enabledPlugins`, `effortLevel`, `theme`, and the rtk `PreToolUse` hook (`rtk hook claude`, which reads the tool-call JSON from stdin). Because the file is a read-only store symlink, changes made through the Claude Code UI cannot persist — edit the nix file and rebuild.

MCP and plugin registries live in separate JSON files Claude Code writes to at runtime (`~/.claude.json`, `~/.claude/plugins/*.json`); activation scripts `jq`-merge into them rather than overwriting, preserving runtime state.

#### Activation scripts

**`installNpmTools`** — `npm install -g --prefix ~/.npm-global @colbymchenry/codegraph@<ver> repomix@<ver>` with pinned versions. A `.nix-versions` stamp file forces reinstall when the pins change.

**`registerCodegraphMcp`** — `jq`-sets `.mcpServers.codegraph` in `~/.claude.json` to run `codegraph serve --mcp` (runs every switch).

**`installSuperpowersPlugin` / `registerSuperpowersPlugin` / `registerSuperpowersMarketplace`** — copy pinned `obra/superpowers` into the cache; merge `superpowers@superpowers-marketplace` into `installed_plugins.json` and `superpowers-marketplace` into `known_marketplaces.json`.

**`installCavemanPlugin` / `registerCavemanPlugin` / `registerCavemanMarketplace`** — same pattern for `JuliusBrussee/caveman`.

All use `lib.hm.dag.entryAfter` (`installNpmTools`/`install*Plugin`/`register*Marketplace` after `writeBoundary`; `register*Plugin` after their install step; `registerCodegraphMcp` after `installNpmTools`).

> **Pin hash note:** `superpowersSrc` ships with `lib.fakeHash` as a placeholder. The first `nixos-rebuild switch` fails and prints the real `got: sha256-…`; paste it into `home.nix` and rebuild again.

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
