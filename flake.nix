{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur.follows = "stylix/nur";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      stylix,
      ...
    }@inputs:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      # Build the system once; read identity (hostname, user) from mySystem so
      # the flake output naming and checks stay in sync with the single config file.
      system = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.overlays = [ inputs.nur.overlays.default ]; }
          home-manager.nixosModules.home-manager
          stylix.nixosModules.stylix
          ./hosts/default/default.nix
        ];
      };
      cfg = system.config.mySystem;
    in
    {
      nixosConfigurations.${cfg.hostname} = system;

      checks.x86_64-linux = nixpkgs.lib.optionalAttrs (cfg.desktop == "niri") {
        niri-config =
          let
            kdl = system.config.home-manager.users.${cfg.user.name}
                    .xdg.configFile."niri/config.kdl".text;
          in
          pkgs.runCommand "niri-config-check" { buildInputs = [ pkgs.niri ]; } ''
            echo ${pkgs.lib.escapeShellArg kdl} > config.kdl
            niri validate --config config.kdl
            touch $out
          '';
      };
    };
}
