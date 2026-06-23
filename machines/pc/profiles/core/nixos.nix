{ pkgs, vars, ... }:
let
  kernelPackages =
    {
      default = pkgs.linuxPackages;
      latest = pkgs.linuxPackages_latest;
      zen = pkgs.linuxPackages_zen;
    }
    .${vars.kernel};
in
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = kernelPackages;

  # networking.hostName is set in machines/pc/default.nix.
  networking.networkmanager.enable = true;

  time.timeZone = vars.timezone;

  i18n.defaultLocale = vars.localeMain;
  i18n.extraLocaleSettings = {
    LC_ADDRESS = vars.localeRegional;
    LC_IDENTIFICATION = vars.localeRegional;
    LC_MEASUREMENT = vars.localeRegional;
    LC_MONETARY = vars.localeRegional;
    LC_NAME = vars.localeRegional;
    LC_NUMERIC = vars.localeRegional;
    LC_PAPER = vars.localeRegional;
    LC_TELEPHONE = vars.localeRegional;
    LC_TIME = vars.localeRegional;
  };

  console.keyMap = vars.consoleKeymap;

  # Primary user account (folded in from the old users/nixos.nix).
  users.users.${vars.user} = {
    isNormalUser = true;
    description = vars.fullName;
    shell = pkgs.fish;
    extraGroups = vars.extraGroups;
  };

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
