{ ... }:
{
  programs.fish = {
    enable = true;
    shellAliases = {
      # nixos-rebuild auto-detects the current hostname → no #hostname suffix needed
      rebuild = "sudo nixos-rebuild switch --flake ~/nixos-config";
    };
  };
}
