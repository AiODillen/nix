# UNIMPORTED: still uses the old mySystem schema. Not imported by this machine
# (feature off). Convert config.mySystem / osConfig.mySystem refs to `vars` before
# re-importing — vars.nix already carries gamescope / rocmGfx / storageMounts.
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
    hash = "sha256-0WupTacT1jIwVBloj1i0RF7wIllVtP8eMPRl7VrXdbE=";
  };

  # Pinned npm tool versions installed to ~/.npm-global on activation.
  # These live outside flake.lock — bump manually when upstream releases.
  codegraphVersion = "1.0.1";
  repomixVersion = "1.14.1";

  # Frozen timestamp written into plugin metadata. Not a real install time —
  # keeps the JSON reproducible. Claude Code only reads the fields, doesn't care
  # what they say.
  frozenTs = "1970-01-01T00:00:00.000Z";
in
lib.mkIf osConfig.mySystem.ai.enable {
  home.sessionPath = [ "$HOME/.npm-global/bin" ];

  # codegraph + repomix installed to user-local npm prefix (nix store is read-only).
  # Stamp file forces reinstall on version bump. Network required on first activation.
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

  # Plugin install pattern: copy from nix store to writable path so Claude can
  # create .in_use/ lock files alongside the plugin tree.
  home.activation.installSuperpowersPlugin = lib.hm.dag.entryAfter ["writeBoundary"] ''
    _dst="$HOME/.claude/plugins/cache/superpowers-marketplace/superpowers/${superpowersVersion}"
    if [ ! -f "$_dst/.claude-plugin/plugin.json" ]; then
      $DRY_RUN_CMD rm -rf "$_dst"
      $DRY_RUN_CMD mkdir -p "$(dirname "$_dst")"
      $DRY_RUN_CMD cp -r "${superpowersSrc}" "$_dst"
      $DRY_RUN_CMD chmod -R u+w "$_dst"
    fi
  '';

  home.activation.registerSuperpowersPlugin = lib.hm.dag.entryAfter ["installSuperpowersPlugin"] ''
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

  home.activation.registerSuperpowersMarketplace = lib.hm.dag.entryAfter ["writeBoundary"] ''
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

  home.activation.installCavemanPlugin = lib.hm.dag.entryAfter ["writeBoundary"] ''
    _dst="$HOME/.claude/plugins/cache/caveman/caveman/${cavemanVersion}"
    if [ ! -f "$_dst/.claude-plugin/plugin.json" ]; then
      $DRY_RUN_CMD rm -rf "$_dst"
      $DRY_RUN_CMD mkdir -p "$(dirname "$_dst")"
      $DRY_RUN_CMD cp -r "${cavemanSrc}" "$_dst"
      $DRY_RUN_CMD chmod -R u+w "$_dst"
    fi
  '';

  home.activation.registerCavemanPlugin = lib.hm.dag.entryAfter ["installCavemanPlugin"] ''
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

  home.activation.registerCavemanMarketplace = lib.hm.dag.entryAfter ["writeBoundary"] ''
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
