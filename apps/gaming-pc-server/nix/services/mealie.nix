# Mealie recipe manager (https://mealie.io), run as a Docker container.
# NixOS wraps it in a systemd service: docker-mealie.service.
{ config, ... }:

let
  port = 9000;
  dataDir = "/var/lib/mealie";
  # The container runs as this host uid (no user namespace remapping), so
  # Postgres peer auth sees it as the `mealie` user below.
  uid = 911;
in
{
  virtualisation.docker.enable = true;
  virtualisation.oci-containers.backend = "docker";

  users.users.mealie = {
    inherit uid;
    isSystemUser = true;
    group = "mealie";
  };
  users.groups.mealie.gid = uid;

  # Keep data on the Linux disk, not /mnt/c: it's slow over the Windows mount.
  # Holds images and backups; recipes themselves live in Postgres.
  systemd.tmpfiles.rules = [ "d ${dataDir} 0750 mealie mealie -" ];

  services.postgresql = {
    ensureDatabases = [ "mealie" ];
    ensureUsers = [
      {
        name = "mealie";
        ensureDBOwnership = true;
      }
    ];
  };

  virtualisation.oci-containers.containers.mealie = {
    # Bump by hand; see https://github.com/mealie-recipes/mealie/releases
    image = "ghcr.io/mealie-recipes/mealie:v3.29.0";
    ports = [ "${toString port}:9000" ];
    volumes = [
      "${dataDir}:/app/data"
      # Postgres' Unix socket; connecting through it needs no password.
      "/run/postgresql:/run/postgresql"
    ];
    environment = {
      ALLOW_SIGNUP = "false";
      TZ = "America/New_York";
      BASE_URL = "https://mealie.tail65441.ts.net";
      PUID = toString config.users.users.mealie.uid;
      PGID = toString config.users.groups.mealie.gid;
      DB_ENGINE = "postgres";
      POSTGRES_URL_OVERRIDE = "postgresql://mealie@/mealie?host=/run/postgresql";
    };
  };

  # Start after the database and role exist. Requires= also restarts Mealie
  # whenever Postgres restarts, which matters because systemd recreates
  # /run/postgresql then and the container's bind mount would go stale.
  systemd.services.docker-mealie = {
    requires = [ "postgresql.service" "postgresql-setup.service" ];
    after = [ "postgresql.service" "postgresql-setup.service" ];
  };

  # Served over HTTPS at https://mealie.tail65441.ts.net; see tailscale-serve.nix.
  homelab.tailscaleServe.services.mealie."443" = "http://localhost:${toString port}";
}
