# hello (../../../../apps/hello): an nginx hello-world page, pulled from
# our own registry (registry.nix) and run as a Docker container.
# NixOS wraps it in a systemd service: docker-hello.service.
#
# To ship a new version: commit apps/hello, run `npx nx push hello`, set
# `version` below to what `npx nx version hello` prints, then deploy.
{ config, ... }:

let
  port = 8080;
  # Bump by hand: a tag pushed by `npx nx push hello`.
  version = "61deac1";
  # Pull straight from the registry on this machine, not through Tailscale
  # serve. Docker allows plain HTTP to localhost registries.
  registry = "localhost:5000";
  # This machine's own registry user: its bcrypt line is in
  # registry.htpasswd and its plain-text password in registry.server-password.
  username = "gaming-pc-server";
in
{
  # docker login reads this as root, so the default owner is fine.
  sops.secrets."registry/server-password" = { };

  virtualisation.oci-containers.containers.hello = {
    image = "${registry}/hello:${version}";
    # Localhost only: Tailscale serve is the sole way in.
    ports = [ "127.0.0.1:${toString port}:80" ];
    login = {
      inherit registry username;
      passwordFile = config.sops.secrets."registry/server-password".path;
    };
  };

  # The image comes from the local registry, so wait for it at boot.
  systemd.services.docker-hello = {
    wants = [ "docker-registry.service" ];
    after = [ "docker-registry.service" ];
  };

  # Served over HTTPS at https://hello.tail65441.ts.net; see tailscale-serve.nix.
  homelab.tailscaleServe.services.hello."443" = "http://localhost:${toString port}";
}
