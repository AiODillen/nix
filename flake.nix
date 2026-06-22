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
      # The host assembly layers the shared settings + profiles + this
      # machine's device-specific values (machines/pc/). Identity (hostname,
      # user) is read back from mySystem so output naming/checks stay in sync.
      system = lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.overlays = [ inputs.nur.overlays.default ]; }
          home-manager.nixosModules.home-manager
          stylix.nixosModules.stylix
          ./machines/pc/default.nix
        ];
      };
      cfg = system.config.mySystem;

      # ── Mint laptop (standalone home-manager, non-NixOS) ─────────
      # Derive the laptop's mySystem by evaluating the shared schema + shared
      # settings + the laptop's device file — WITHOUT building a NixOS system.
      # Shared values (theming/locale/desktop/toggles) come from settings.nix;
      # only device-specific bits live in machines/laptop/device.nix.
      # Built with `home-manager switch --flake .#<standalone.user>`.
      laptopCfg =
        (lib.evalModules {
          modules = [
            ./modules/options.nix
            ./settings.nix
            ./machines/laptop/device.nix
          ];
        }).config.mySystem;

      hmPkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
        overlays = [ inputs.nur.overlays.default ];
      };
      hmSettings = {
        username       = laptopCfg.standalone.user;
        homeDirectory  = laptopCfg.standalone.homeDirectory;
        gpu            = laptopCfg.standalone.gpu;
        flakePath      = laptopCfg.standalone.flakePath;
        scheme         = laptopCfg.theming.scheme;
        polarity       = laptopCfg.theming.polarity;
        wallpaper      = laptopCfg.theming.wallpaper;
        localeMain     = laptopCfg.locale.main;
        localeRegional = laptopCfg.locale.regional;
        xkbLayout      = laptopCfg.locale.xkbLayout;
        xkbVariant     = laptopCfg.locale.xkbVariant;
        # feature toggles — mirror the NixOS profile enables
        theming        = laptopCfg.theming.enable;
        ai             = laptopCfg.ai.enable;
        gaming         = laptopCfg.gaming.enable;
        desktop        = laptopCfg.desktop;
      };
    in
    {
      nixosConfigurations.${cfg.hostname} = system;

      homeConfigurations = lib.optionalAttrs laptopCfg.standalone.enable {
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
