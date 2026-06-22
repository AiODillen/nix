{ ... }:
{
  programs.fish = {
    enable = true;
    shellAliases = {
      # Standalone home-manager rebuild (adjust the flake path to wherever
      # this repo lives on the target machine).
      rebuild = "home-manager switch --flake ~/Documents/nix#niklas";
    };
  };
}
