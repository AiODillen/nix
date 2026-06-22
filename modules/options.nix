{ config, lib, ... }:
{
  options.mySystem = {
    # ── Identity ────────────────────────────────────────────────
    user = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "dillen";
        description = "Primary login username. Home directory derived as /home/<name>.";
      };
      fullName = lib.mkOption {
        type = lib.types.str;
        default = "dillen";
        description = "GECOS / description for the user account.";
      };
      extraGroups = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "networkmanager" "wheel" ];
        description = "Extra groups for the primary user.";
      };
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      default = "nixos";
      description = "System hostname.";
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "Europe/Berlin";
      description = "IANA timezone.";
    };

    locale = {
      main = lib.mkOption {
        type = lib.types.str;
        default = "en_US.UTF-8";
        description = "Primary locale (LANG).";
      };
      regional = lib.mkOption {
        type = lib.types.str;
        default = "de_DE.UTF-8";
        description = "Regional locale for LC_TIME, LC_MEASUREMENT, etc.";
      };
      consoleKeymap = lib.mkOption {
        type = lib.types.str;
        default = "de-latin1-nodeadkeys";
        description = "TTY console keymap.";
      };
      xkbLayout = lib.mkOption {
        type = lib.types.str;
        default = "de";
        description = "X/Wayland keyboard layout.";
      };
      xkbVariant = lib.mkOption {
        type = lib.types.str;
        default = "nodeadkeys";
        description = "X/Wayland keyboard variant.";
      };
    };

    # ── Kernel ─────────────────────────────────────────────────
    kernel = lib.mkOption {
      type = lib.types.enum [ "default" "latest" "zen" ];
      default = "default";
      description = "Kernel package. zen=gaming-tuned, latest=newest mainline.";
    };

    # ── Desktop ────────────────────────────────────────────────
    desktop = lib.mkOption {
      type = lib.types.enum [ "niri" "gnome" ];
      default = "niri";
      description = "Which desktop environment to enable.";
    };

    # ── Standalone (non-NixOS) ─────────────────────────────────
    # Marks this checkout as also targeting a non-NixOS machine via a
    # standalone home-manager output. Identity lives here; everything else
    # (theming, locale, profile toggles, desktop) is inherited from the shared
    # mySystem block, so default.nix drives every config. Built with
    # `home-manager switch --flake .#<standalone.user>`.
    standalone = {
      enable = lib.mkEnableOption "standalone home-manager output for a non-NixOS machine";
      user = lib.mkOption {
        type = lib.types.str;
        default = config.mySystem.user.name;
        description = "Login user on the non-NixOS machine. Defaults to the NixOS user.name.";
      };
      homeDirectory = lib.mkOption {
        type = lib.types.str;
        default = "/home/${config.mySystem.standalone.user}";
        description = "Home directory on the non-NixOS machine.";
      };
      gpu = lib.mkOption {
        type = lib.types.enum [ "mesa" "nvidia" ];
        default = "mesa";
        description = ''
          GPU vendor of the non-NixOS machine, selecting the nixGL wrapper used
          to run nix GL/Vulkan apps (a non-NixOS box has no /run/opengl-driver).
          "mesa" -> nixGLIntel/nixVulkanIntel (covers Intel + AMD).
          "nvidia" -> nixGLNvidia/nixVulkanNvidia (proprietary driver; unfree and
          pinned to the host driver version).
        '';
      };
      flakePath = lib.mkOption {
        type = lib.types.str;
        default = "~/Documents/nix";
        description = ''
          Path to this repo on the non-NixOS machine, used by the `rebuild`
          shell alias. Adjust if the repo is cloned elsewhere.
        '';
      };
      monitors = {
        # Output switching via kanshi (niri only), configured as a direct list
        # of kanshi profiles. Consumed by the machine overlay
        # (machines/<name>/monitors.nix). kanshi applies the FIRST profile whose
        # listed outputs are ALL connected, so order profiles most-specific
        # first (e.g. a multi-monitor dock before a bare-laptop fallback). To
        # show only externals, list the internal panel with status = "disable"
        # in that profile (otherwise the compositor keeps it on).
        enable = lib.mkEnableOption "kanshi output switching (niri)";
        fallbackAllOn = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Append a catch-all kanshi profile (`output "*" enable`) after the
            configured profiles, so when no earlier profile matches the current
            set of connected outputs, every output is simply enabled (extended
            desktop) rather than left in an unmanaged state. Note: this is "all
            on", not true mirroring — niri/kanshi cannot clone outputs
            declaratively (that needs wl-mirror).
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
                        mode = lib.mkOption {
                          type = lib.types.nullOr lib.types.str;
                          default = null;
                          example = "3440x1440@60Hz";
                          description = "Mode \"<w>x<h>[@<rate>[Hz]]\" (default: preferred).";
                        };
                        transform = lib.mkOption {
                          type = lib.types.nullOr lib.types.str;
                          default = null;
                          example = "90";
                          description = "Output transform (e.g. \"90\", \"flipped-180\").";
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
    };

    # ── Profiles ───────────────────────────────────────────────
    ai.enable = lib.mkEnableOption "AI profile (Claude Code, rtk, codegraph, caveman, repomix)";

    gaming = {
      enable = lib.mkEnableOption "gaming profile (Steam, gamescope, gaming home apps)";
      gamescope = {
        width = lib.mkOption {
          type = lib.types.int;
          default = 3440;
          description = "Gamescope render width.";
        };
        height = lib.mkOption {
          type = lib.types.int;
          default = 1440;
          description = "Gamescope render height.";
        };
      };
    };

    localAi = {
      enable = lib.mkEnableOption "local AI profile (Ollama ROCm, Open WebUI, ROCm tools)";
      rocmGfx = lib.mkOption {
        type = lib.types.str;
        default = "11.0.0";
        description = "HSA_OVERRIDE_GFX_VERSION for ROCm. 7900 XTX=11.0.0, 7800/7700 XT=11.0.1, 6900 XT=10.3.0.";
      };
    };

    theming = {
      enable = lib.mkEnableOption "stylix theming profile (system + home)";
      wallpaper = lib.mkOption {
        type = lib.types.path;
        default = ../wallpaper.png;
        description = "Wallpaper image used by stylix.";
      };
      polarity = lib.mkOption {
        type = lib.types.enum [ "dark" "light" "either" ];
        default = "dark";
        description = "Stylix polarity. Must match scheme: dark schemes need \"dark\", etc.";
      };
      scheme = lib.mkOption {
        type = lib.types.str;
        default = "catppuccin-mocha";
        description = ''
          base16-schemes name. File resolves to
          ''${pkgs.base16-schemes}/share/themes/<scheme>.yaml.

          Popular picks (all in pkgs.base16-schemes):
            Dark  : catppuccin-mocha, catppuccin-macchiato, catppuccin-frappe,
                    gruvbox-dark-hard, gruvbox-dark-medium, gruvbox-material-dark-hard,
                    nord, dracula, tokyo-night-dark, tokyo-night-storm, tokyo-night-moon,
                    rose-pine, rose-pine-moon, kanagawa, kanagawa-dragon,
                    everforest, everforest-dark-hard, onedark, ayu-dark, ayu-mirage,
                    solarized-dark, material-darker, monokai, gotham
            Light : catppuccin-latte, gruvbox-light-hard, gruvbox-light-medium,
                    rose-pine-dawn, tokyo-night-light, solarized-light,
                    ayu-light, nord-light, material-lighter
        '';
      };
    };

    storage.automount = {
      enable = lib.mkEnableOption "automount profile (extra filesystems under /home/<user>)";
      mounts = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            path = lib.mkOption {
              type = lib.types.str;
              description = "Mount path relative to home (e.g. \"Grab\" → /home/<user>/Grab).";
            };
            uuid = lib.mkOption {
              type = lib.types.str;
              description = "Filesystem UUID (from `lsblk -f`).";
            };
            fsType = lib.mkOption {
              type = lib.types.str;
              default = "ext4";
              description = "Filesystem type.";
            };
          };
        });
        default = [ ];
        description = "Filesystems to automount under the user's home.";
      };
    };
  };
}
