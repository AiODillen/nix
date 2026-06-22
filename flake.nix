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

      # ── Standalone home-manager (non-NixOS) ──────────────────────
      # Identity comes from mySystem.standalone; everything else is inherited
      # from the shared mySystem block above, so default.nix drives every
      # config. Built with `home-manager switch --flake .#<standalone.user>`.
      hmPkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
        overlays = [ inputs.nur.overlays.default ];
      };
      hmSettings = {
        username       = cfg.standalone.user;
        homeDirectory  = cfg.standalone.homeDirectory;
        gpu            = cfg.standalone.gpu;
        flakePath      = cfg.standalone.flakePath;
        monitors       = cfg.standalone.monitors;
        scheme         = cfg.theming.scheme;
        polarity       = cfg.theming.polarity;
        wallpaper      = cfg.theming.wallpaper;
        localeMain     = cfg.locale.main;
        localeRegional = cfg.locale.regional;
        xkbLayout      = cfg.locale.xkbLayout;
        xkbVariant     = cfg.locale.xkbVariant;
        # feature toggles — mirror the NixOS profile enables
        theming        = cfg.theming.enable;
        ai             = cfg.ai.enable;
        gaming         = cfg.gaming.enable;
        desktop        = cfg.desktop;
      };
    in
    {
      nixosConfigurations.${cfg.hostname} = system;

      homeConfigurations = nixpkgs.lib.optionalAttrs cfg.standalone.enable {
        ${hmSettings.username} = home-manager.lib.homeManagerConfiguration {
          pkgs = hmPkgs;
          extraSpecialArgs = { inherit inputs; settings = hmSettings; };
          modules = [
            inputs.stylix.homeModules.stylix
            ./machines/laptop/home.nix
          ];
        };
      };

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
