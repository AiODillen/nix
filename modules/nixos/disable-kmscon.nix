{ ... }:
{
  # Disable kmscon entirely to avoid conflicts with Stylix in nixpkgs 26.05
  # Stylix's kmscon module tries to set services.kmscon.config which no longer exists
  services.kmscon.enable = false;
}
