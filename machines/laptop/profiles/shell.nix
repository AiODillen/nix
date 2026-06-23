{ vars, ... }:
{
  programs.fish = {
    enable = true;
    shellAliases = {
      # Standalone home-manager rebuild against the flake in the current dir
      # (cd into the repo first). Output name comes from vars.user.
      rebuild = "home-manager switch --flake .#${vars.user}";
      zzz = "systemctl suspend";
    };
  };
}
