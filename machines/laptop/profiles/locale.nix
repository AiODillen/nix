{ vars, ... }:
let
  regional = vars.localeRegional;
in
{
  # No system locale-gen on non-NixOS; HM only exports env vars. The glibc
  # locale must already exist on the distro (check `locale -a`).
  home.sessionVariables = {
    LANG = vars.localeMain;

    LC_ADDRESS        = regional;
    LC_IDENTIFICATION = regional;
    LC_MEASUREMENT    = regional;
    LC_MONETARY       = regional;
    LC_NAME           = regional;
    LC_NUMERIC        = regional;
    LC_PAPER          = regional;
    LC_TELEPHONE      = regional;
    LC_TIME           = regional;

    # Read by both niri (Wayland) and X11.
    XKB_DEFAULT_LAYOUT  = vars.xkbLayout;
    XKB_DEFAULT_VARIANT = vars.xkbVariant;
  };
}
