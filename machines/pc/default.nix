# Main PC — NixOS host. Self-contained: imports this machine's hardware +
# profiles + home-manager glue. `vars` comes from flake.nix via specialArgs.
{ config, inputs, vars, ... }:
{
  disabledModules = [
    # Stylix's kmscon module is incompatible with nixpkgs 26.05.
    # TODO: drop once upstream stylix release-26.05 ships the fix.
    "${inputs.stylix}/modules/kmscon/nixos.nix"
  ];

  imports = [
    ./hardware.nix
    ./profiles/core/nixos.nix
    ./profiles/shell/nixos.nix
    ./profiles/theming/nixos.nix
    ./profiles/desktop/niri/nixos.nix
  ];

  networking.hostName = vars.hostname;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit inputs vars; };
    users.${vars.user} = import ./home.nix;
  };
}
