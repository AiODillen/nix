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

    # GPU driver shim for running nix GUI apps on non-NixOS (standalone only).
    nixgl.url = "github:nix-community/nixGL";
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
      lib = nixpkgs.lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      # ── Main PC (NixOS) ──────────────────────────────────────────
      # Self-contained per-machine tree under machines/pc/. All config values
      # come from machines/pc/vars.nix, threaded to system + home modules as
      # `vars` via specialArgs.
      pcVars = import ./machines/pc/vars.nix;

      system = lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; vars = pcVars; };
        modules = [
          { nixpkgs.overlays = [ inputs.nur.overlays.default ]; }
          home-manager.nixosModules.home-manager
          stylix.nixosModules.stylix
          ./machines/pc/default.nix
        ];
      };

      # ── Mint laptop (standalone home-manager, non-NixOS) ─────────
      laptopVars = import ./machines/laptop/vars.nix;

      hmPkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
        overlays = [ inputs.nur.overlays.default ];
      };
    in
    {
      nixosConfigurations.${pcVars.hostname} = system;

      homeConfigurations.${laptopVars.user} = home-manager.lib.homeManagerConfiguration {
        pkgs = hmPkgs;
        extraSpecialArgs = { inherit inputs; vars = laptopVars; };
        modules = [
          inputs.stylix.homeModules.stylix
          ./machines/laptop/home.nix
        ];
      };

      checks.x86_64-linux.niri-config =
        let
          kdl = system.config.home-manager.users.${pcVars.user}
                  .xdg.configFile."niri/config.kdl".text;
        in
        pkgs.runCommand "niri-config-check" { buildInputs = [ pkgs.niri ]; } ''
          echo ${pkgs.lib.escapeShellArg kdl} > config.kdl
          niri validate --config config.kdl
          touch $out
        '';
    };
}
