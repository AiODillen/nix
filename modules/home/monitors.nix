# Shared home-manager module: output switching via kanshi (niri only).
#
# Declares the `monitors` option schema and builds `services.kanshi` from it.
# It holds NO machine-specific data — each device sets `monitors.profiles` in
# its own per-device file (machines/<name>/monitors.nix), so monitor config
# (which is device-specific) stays out of the shared mySystem options.
#
# kanshi drives outputs at runtime via wlr-output-management, which niri
# implements but GNOME/mutter does not — so callers gate `monitors.enable` on
# the niri desktop. kanshi applies the FIRST profile whose listed outputs are
# ALL connected; order profiles most-specific first.
{ config, lib, ... }:
let
  cfg = config.monitors;

  # Emit only the keys the user set; kanshi/HM default the rest. criteria
  # (connector) is the one required field. Refresh rate rides along in `mode`
  # ("<w>x<h>@<rate>Hz"); VRR is `adaptiveSync`.
  mkOutput =
    o:
    { criteria = o.connector; }
    // lib.optionalAttrs (o.status != null) { inherit (o) status; }
    // lib.optionalAttrs (o.mode != null) { inherit (o) mode; }
    // lib.optionalAttrs (o.scale != null) { inherit (o) scale; }
    // lib.optionalAttrs (o.position != null) { inherit (o) position; }
    // lib.optionalAttrs (o.transform != null) { inherit (o) transform; }
    // lib.optionalAttrs (o.adaptiveSync != null) { inherit (o) adaptiveSync; };

  # Catch-all appended last: kanshi's "*" matches any output, so when none of
  # the configured profiles fully match the connected set, this enables every
  # output (extended desktop) instead of leaving them unmanaged. Not mirroring —
  # niri/kanshi can't clone outputs declaratively.
  fallback = lib.optional cfg.fallbackAllOn {
    profile.name = "fallback-all-on";
    profile.outputs = [
      {
        criteria = "*";
        status = "enable";
      }
    ];
  };
in
{
  options.monitors = {
    enable = lib.mkEnableOption "kanshi output switching (niri only)";
    fallbackAllOn = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Append a catch-all kanshi profile (`output "*" enable`) after the
        configured profiles, so when no earlier profile matches the connected
        outputs, every output is simply enabled (extended desktop) rather than
        left unmanaged. This is "all on", not true mirroring — niri/kanshi
        cannot clone outputs declaratively (that needs wl-mirror).
      '';
    };
    profiles = lib.mkOption {
      default = [ ];
      description = "Ordered list of kanshi profiles. Connector names from `niri msg outputs`.";
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Profile name.";
            };
            outputs = lib.mkOption {
              description = "Outputs this profile applies to (all must be connected for it to match).";
              type = lib.types.listOf (
                lib.types.submodule {
                  options = {
                    connector = lib.mkOption {
                      type = lib.types.str;
                      description = "Connector name or output description (kanshi criteria).";
                    };
                    status = lib.mkOption {
                      type = lib.types.nullOr (lib.types.enum [ "enable" "disable" ]);
                      default = null;
                      description = "Enable or disable this output (null = kanshi default, enabled).";
                    };
                    mode = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                      example = "3440x1440@100Hz";
                      description = ''
                        Mode "<w>x<h>[@<rate>[Hz]]". This is where the refresh
                        rate is set (the @<rate>Hz part). Default: preferred mode.
                      '';
                    };
                    scale = lib.mkOption {
                      type = lib.types.nullOr lib.types.float;
                      default = null;
                      description = "Scale factor.";
                    };
                    position = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                      example = "0,0";
                      description = "Position \"x,y\" in the global layout.";
                    };
                    transform = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                      example = "90";
                      description = "Output transform (e.g. \"90\", \"flipped-180\").";
                    };
                    adaptiveSync = lib.mkOption {
                      type = lib.types.nullOr lib.types.bool;
                      default = null;
                      example = true;
                      description = "Variable refresh rate (VRR / adaptive sync) for this output.";
                    };
                  };
                }
              );
            };
          };
        }
      );
    };
  };

  config = lib.mkIf cfg.enable {
    services.kanshi = {
      enable = true;
      settings =
        (map (p: {
          profile.name = p.name;
          profile.outputs = map mkOutput p.outputs;
        }) cfg.profiles)
        ++ fallback;
    };

    # HM's kanshi unit lists no restart trigger for its config file, so a
    # config-only change (e.g. a new mode/refresh rate) leaves the unit
    # unchanged and sd-switch won't restart the running daemon — it keeps the
    # stale in-memory config. Tie the unit to the generated config's store path
    # so `home-manager switch` restarts kanshi whenever the config changes.
    systemd.user.services.kanshi.Unit.X-Restart-Triggers = [
      config.xdg.configFile."kanshi/config".source
    ];
  };
}
