{ pkgs, ... }:
{
  xdg.enable = true;

  home.packages = with pkgs; [
    git
    micro
    gram
    nil
    playerctl       # MPRIS control for multimedia keys
    brightnessctl   # screen brightness keys
    btop
    gearlever
  ];
}
