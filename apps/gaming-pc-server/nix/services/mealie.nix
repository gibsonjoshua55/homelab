# Mealie recipe manager (https://mealie.io), run as a Docker container.
# NixOS wraps it in a systemd service: docker-mealie.service.
{ ... }:

let
  port = 9000;
  dataDir = "/var/lib/mealie";
in
{
  virtualisation.docker.enable = true;
  virtualisation.oci-containers.backend = "docker";

  # Keep data on the Linux disk, not /mnt/c: SQLite is slow and locks badly
  # over the Windows mount.
  systemd.tmpfiles.rules = [ "d ${dataDir} 0750 root root -" ];

  virtualisation.oci-containers.containers.mealie = {
    # Bump by hand; see https://github.com/mealie-recipes/mealie/releases
    image = "ghcr.io/mealie-recipes/mealie:v3.29.0";
    ports = [ "${toString port}:9000" ];
    volumes = [ "${dataDir}:/app/data" ];
    environment = {
      ALLOW_SIGNUP = "false";
      TZ = "America/New_York";
      BASE_URL = "https://mealie.tail65441.ts.net";
    };
  };

  # Served over HTTPS at https://mealie.tail65441.ts.net; see tailscale-serve.nix.
  homelab.tailscaleServe.services.mealie."tcp:443" = "http://localhost:${toString port}";
}
