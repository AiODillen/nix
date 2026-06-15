{ ... }:
{
  programs.fish = {
    enable = true;
    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --flake ~/nixos-config/.#nixos";
    };
  };
}
