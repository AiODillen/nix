# Main PC — NixOS host. Self-contained: imports this machine's hardware +
# profiles + home-manager glue. `vars` comes from flake.nix via specialArgs.
{ inputs, lib, vars, ... }:
let
  m = vars.modules;

  # Hardware is read live from the running machine's scan, never committed —
  # so a fresh install boots its own disks (no stale UUIDs). This makes eval
  # impure: build with `--impure` (nixos-rebuild/nixos-install/flake check).
  # When the live scan is absent (evaluating this config from another machine,
  # or flake check on a non-NixOS box) fall back to a placeholder stub that only
  # satisfies module eval and never boots anything.
  liveHardware = /etc/nixos/hardware-configuration.nix;
  hardwareModule =
    if builtins.pathExists liveHardware then liveHardware else ./hardware-fallback.nix;
in
{
  disabledModules = [
    # Stylix's kmscon module is incompatible with nixpkgs 26.05.
    # TODO: drop once upstream stylix release-26.05 ships the fix.
    "${inputs.stylix}/modules/kmscon/nixos.nix"
  ];

  # Base profiles always imported; optional ones gated by vars.modules.
  imports =
    [
      hardwareModule
      ./profiles/core/nixos.nix
      ./profiles/shell/nixos.nix
    ]
    ++ lib.optional m.theming ./profiles/theming/nixos.nix
    ++ lib.optional m.desktop ./profiles/desktop/niri/nixos.nix
    ++ lib.optional m.gaming ./profiles/gaming/nixos.nix
    ++ lib.optional m.ai ./profiles/ai/nixos.nix
    ++ lib.optional m.localAi ./profiles/local-ai/nixos.nix
    ++ lib.optional m.storage ./profiles/storage/nixos.nix;

  networking.hostName = vars.hostname;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit inputs vars; };
    users.${vars.user} = import ./home.nix;
  };
}
