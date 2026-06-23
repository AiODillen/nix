{ vars, ... }:
{
  programs.fish = {
    enable = true;
    shellAliases = {
      # Standalone home-manager rebuild. Flake path + output name come from
      # mySystem.standalone (flakePath / user), so a machine that clones the
      # repo elsewhere only edits that block, not this alias.
      rebuild = "home-manager switch --flake ${vars.flakePath}#${vars.user}";
      zzz = "systemctl suspend";
    };
  };
}
