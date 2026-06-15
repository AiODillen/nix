{
  description = "NixOS configuration — nixos";

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
    in
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          home-manager.nixosModules.home-manager
          stylix.nixosModules.stylix
          ./hosts/nixos/default.nix
        ];
      };

      checks.x86_64-linux =
        let
          cfg = self.nixosConfigurations.nixos.config.mySystem;
        in
        nixpkgs.lib.optionalAttrs (cfg.desktop == "niri") {
          niri-config =
            let
              kdl = self.nixosConfigurations.nixos.config
                      .home-manager.users.dillen
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
