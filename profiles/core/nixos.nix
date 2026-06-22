{ config, pkgs, ... }:
let
  cfg = config.mySystem;
  kernelPackages =
    {
      default = pkgs.linuxPackages;
      latest = pkgs.linuxPackages_latest;
      zen = pkgs.linuxPackages_zen;
    }
    .${cfg.kernel};
in
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = kernelPackages;

  networking.hostName = cfg.hostname;
  networking.networkmanager.enable = true;

  time.timeZone = cfg.timezone;

  i18n.defaultLocale = cfg.locale.main;
  i18n.extraLocaleSettings = {
    LC_ADDRESS = cfg.locale.regional;
    LC_IDENTIFICATION = cfg.locale.regional;
    LC_MEASUREMENT = cfg.locale.regional;
    LC_MONETARY = cfg.locale.regional;
    LC_NAME = cfg.locale.regional;
    LC_NUMERIC = cfg.locale.regional;
    LC_PAPER = cfg.locale.regional;
    LC_TELEPHONE = cfg.locale.regional;
    LC_TIME = cfg.locale.regional;
  };

  console.keyMap = cfg.locale.consoleKeymap;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  programs.firefox.enable = true;
  programs.firefox.policies.ExtensionSettings = {
    "uBlock0@raymondhill.net" = {
      installation_mode = "force_installed";
      install_url = "file://${pkgs.nur.repos.rycee.firefox-addons.ublock-origin}/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/uBlock0@raymondhill.net.xpi";
    };
    "78272b6fa58f4a1abaac99321d503a20@proton.me" = {
      installation_mode = "force_installed";
      install_url = "file://${pkgs.nur.repos.rycee.firefox-addons.proton-pass}/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/78272b6fa58f4a1abaac99321d503a20@proton.me.xpi";
    };
  };
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    git
    micro
    gram
    nil
    playerctl # MPRIS control for multimedia keys (Play/Pause/Next/Prev)
    brightnessctl # screen brightness keys
    btop
    gearlever
  ];

  system.stateVersion = "26.05";
}
