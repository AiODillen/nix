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

  # Primary user account. vars.user must match the account you create at NixOS
  # install — a matching name adopts/manages it, it does not create a second
  # user. No password is set here and mutableUsers stays true, so the password
  # you set at install (or later via `passwd`) persists across rebuilds.
  users.mutableUsers = true;
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

  # Firefox is managed entirely by Home Manager (package + policies + profiles),
  # mirroring the laptop. See machines/pc/profiles/theming/home.nix. Keeping it
  # in one place avoids a system-vs-HM Firefox split where bare `firefox` on
  # PATH could resolve to a policy-less build (no extensions).
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
