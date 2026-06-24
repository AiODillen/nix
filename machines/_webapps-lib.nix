# Shared definition of the headless-installable Firefox PWAs and the idempotent
# `firefoxpwa site install` snippet, so the laptop (HM) and pc (NixOS+HM)
# activation scripts install the same set from one source of truth.
#
# Only apps that serve an unauthenticated web-app manifest can be installed
# this way (the positional arg is the MANIFEST URL, and firefoxpwa requires the
# manifest origin == start_url origin). Teams qualifies. Outlook does NOT — its
# manifest is auth-gated — so Outlook is installed via the browser extension,
# not here.
{ lib }:
let
  webapps = [
    { name = "Microsoft Teams"; manifestUrl = "https://teams.microsoft.com/manifest.json"; }
  ];

  # Render one idempotent install line per webapp. `firefoxpwa profile list`
  # prints each installed app as `- <name>: <url> (<ULID>)`; skip install when
  # the name is already present. Names are fixed strings here, so grep -F is safe.
  installLine = ffpwa: app: ''
    "${ffpwa}/bin/firefoxpwa" profile list 2>/dev/null | grep -qF ${lib.escapeShellArg app.name} \
      || "${ffpwa}/bin/firefoxpwa" site install ${lib.escapeShellArg app.manifestUrl} --name ${lib.escapeShellArg app.name}
  '';

  # Whole block in a subshell + `|| true`: HM concatenates all activation
  # blocks into ONE bash script, so a bare failure here could abort the entire
  # switch. The guard makes a network error / refused install a no-op that
  # retries on the next switch instead of breaking activation.
  installScript = { firefoxpwa }: ''
    (
    ${lib.concatMapStrings (installLine firefoxpwa) webapps}
    ) || true
  '';
in
{
  inherit webapps installScript;
}
