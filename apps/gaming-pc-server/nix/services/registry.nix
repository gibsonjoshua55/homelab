# Private Docker registry (CNCF distribution), served over HTTPS at
# https://registry.tail65441.ts.net; see tailscale-serve.nix.
# NixOS runs it natively as docker-registry.service, no container.
#
# Pushes and pulls need a login (htpasswd basic auth):
#   docker login registry.tail65441.ts.net
#
# Users live in secrets/secrets.yaml under registry.htpasswd, one
# `user:bcrypt-hash` per line. The registry only accepts bcrypt; make a
# line with `htpasswd -nB <user>` and paste it in with
# `npx nx secrets gaming-pc-server`:
#   registry:
#     htpasswd: |
#       josh:$2y$05$...
{ config, ... }:

let
  port = 5000;
  host = "registry.tail65441.ts.net";
in
{
  sops.secrets."registry/htpasswd" = {
    owner = "docker-registry";
    # The registry reads the file at startup, so pick up added users.
    restartUnits = [ "docker-registry.service" ];
  };

  services.dockerRegistry = {
    enable = true;
    # Localhost only: Tailscale serve is the sole way in, and it's what
    # terminates TLS (Docker clients won't send credentials over plain HTTP).
    listenAddress = "127.0.0.1";
    inherit port;
    # Deleting a tag only drops its manifest; the weekly GC frees the layers.
    enableDelete = true;
    enableGarbageCollect = true;
    garbageCollectDates = "weekly";
    extraConfig = {
      # Behind the proxy, build upload/redirect URLs from the public name
      # instead of the localhost address the request arrives on.
      http.host = "https://${host}";
      auth.htpasswd = {
        realm = host;
        path = config.sops.secrets."registry/htpasswd".path;
      };
    };
  };

  homelab.tailscaleServe.services.registry."443" = "http://localhost:${toString port}";
}
