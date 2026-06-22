# Output switching, via kanshi. All knobs come from the one config file
# (mySystem.standalone.monitors in hosts/default/default.nix), threaded here as
# settings.monitors — nothing machine-specific is hardcoded in this overlay.
#
# This maps the configured profile list straight onto kanshi profiles. kanshi
# applies the FIRST profile whose listed outputs are all connected, so the order
# from the config file is preserved (list multi-monitor docks before the bare
# laptop fallback). To show only externals, the panel must be listed with
# status = "disable" in that profile, else the compositor keeps it on.
#
# kanshi binds to graphical-session.target (config.wayland.systemd.target),
# which the template's niri.service drives, so the kanshi user service starts
# inside the niri session.
{ lib, settings, ... }:
let
  m = settings.monitors;

  # Emit only the keys the user set; kanshi/HM default the rest. criteria is the
  # one required field.
  mkOutput =
    o:
    { criteria = o.connector; }
    // lib.optionalAttrs (o.status != null) { inherit (o) status; }
    // lib.optionalAttrs (o.scale != null) { inherit (o) scale; }
    // lib.optionalAttrs (o.position != null) { inherit (o) position; }
    // lib.optionalAttrs (o.mode != null) { inherit (o) mode; }
    // lib.optionalAttrs (o.transform != null) { inherit (o) transform; };

  # Catch-all appended last: kanshi's "*" matches any output, so when none of
  # the configured profiles fully match the connected set, this enables every
  # output (extended desktop) instead of leaving them unmanaged. Not mirroring —
  # niri/kanshi can't clone outputs declaratively.
  fallback = lib.optional m.fallbackAllOn {
    profile.name = "fallback-all-on";
    profile.outputs = [
      {
        criteria = "*";
        status = "enable";
      }
    ];
  };
in
lib.mkIf m.enable {
  services.kanshi = {
    enable = true;
    settings =
      (map (p: {
        profile.name = p.name;
        profile.outputs = map mkOutput p.outputs;
      }) m.profiles)
      ++ fallback;
  };
}
