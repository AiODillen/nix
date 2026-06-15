{ config, lib, ... }:
lib.mkIf (config.mySystem.desktop == "niri") {
  programs.niri = {
    enable = true;
    useNautilus = false;
  };

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${config.programs.niri.package}/bin/niri-session";
      user = "dillen";
    };
  };
}
