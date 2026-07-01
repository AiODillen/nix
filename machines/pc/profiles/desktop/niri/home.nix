{ lib, pkgs, config, vars, ... }:
let
  colors = config.lib.stylix.colors;
  themeSwitch = import ../../../../../modules/theme-switch.nix {
    inherit pkgs lib;
    themeMenu = import ../../../../../modules/theme-menu.nix;
    mode = "nixos";
  };
  c = colors.withHashtag; # base00..base0F as "#rrggbb"
  renderedKdl = lib.replaceStrings
    [ "@XKB_LAYOUT@" "@XKB_VARIANT@" "@BORDER_ACTIVE@" "@BORDER_INACTIVE@" ]
    [ vars.xkbLayout vars.xkbVariant "#${colors.base0D}" "#${colors.base01}" ]
    (builtins.readFile ./config.kdl);

  # wiremix has no stylix target; generate a base16 theme (inherits the built-in
  # "default" so any unset field falls back). foot is already stylix-themed, so
  # wiremix renders on a matching terminal background.
  wiremixToml = ''
    theme = "stylix"

    [themes.stylix]
    inherit = "default"
    default_device = { fg = "${c.base0D}" }
    default_stream = { fg = "${c.base0D}" }
    selector = { fg = "${c.base0E}" }
    tab = { fg = "${c.base04}" }
    tab_selected = { fg = "${c.base0D}", add_modifier = "BOLD" }
    tab_marker = { fg = "${c.base09}" }
    list_more = { fg = "${c.base04}" }
    node_title = { fg = "${c.base05}" }
    node_target = { fg = "${c.base0C}" }
    volume = { fg = "${c.base05}" }
    volume_empty = { fg = "${c.base03}" }
    volume_filled = { fg = "${c.base0B}" }
    meter_inactive = { fg = "${c.base03}" }
    meter_active = { fg = "${c.base0B}" }
    meter_overload = { fg = "${c.base08}" }
    meter_center_inactive = { fg = "${c.base03}" }
    meter_center_active = { fg = "${c.base0A}" }
    config_device = { fg = "${c.base05}" }
    config_profile = { fg = "${c.base0C}" }
    dropdown_icon = { fg = "${c.base0C}" }
    dropdown_border = { fg = "${c.base0D}" }
    dropdown_item = { fg = "${c.base05}" }
    dropdown_selected = { fg = "${c.base0D}", add_modifier = "BOLD" }
    dropdown_more = { fg = "${c.base04}" }
    help_border = { fg = "${c.base0D}" }
    help_item = { fg = "${c.base05}" }
    help_more = { fg = "${c.base04}" }
  '';
in
{
  imports = [ ./waybar.nix ];

  xdg.configFile."niri/config.kdl".text = renderedKdl;
  xdg.configFile."wiremix/wiremix.toml".text = wiremixToml;

  programs.foot.enable = true;
  programs.fuzzel.enable = true;
  home.packages = [
    pkgs.wiremix # pipewire TUI mixer (waybar audio module)
    themeSwitch # `theme-switch` — fuzzel theme picker (Mod+Shift+T)
  ];
  services.mako.enable = true;
  # Merges with stylix's color settings. Rounded corners + auto-dismiss.
  services.mako.settings = {
    default-timeout = 5000; # ms; notifications auto-dismiss after 5s
    border-radius = 12;
    border-size = 2;
    padding = "10";
    margin = "10";
  };
  # mako is spawn-at-startup'd by niri (not a HM systemd service), so a theme
  # rebuild rewrites ~/.config/mako/config but the running daemon keeps the old
  # colors. Reload it on activation. (|| true: no-op outside a live session.)
  home.activation.reloadMako = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.mako}/bin/makoctl reload 2>/dev/null || true
  '';
}
