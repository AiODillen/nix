{ pkgs, ... }:
{
  # System account for dillen. Home-manager config lives in users/dillen/default.nix.
  users.users.dillen = {
    isNormalUser = true;
    description = "dillen";
    shell = pkgs.fish;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };
}
