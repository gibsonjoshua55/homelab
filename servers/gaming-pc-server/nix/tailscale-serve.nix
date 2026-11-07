# Tailscale Services (https://tailscale.com/kb/1552/tailscale-services)
# hosted by this machine. Service files add entries to
# homelab.tailscaleServe.services; this module resets the node's serve
# config and applies all of them, so services removed here stop being
# served (and advertised) too.
#
# Not covered here, done once per tailnet: the node must carry a tag
# (service hosts must be tagged), each service must exist in the admin
# console, and each host must be approved there unless the policy file
# auto-approves it.
{ config, lib, pkgs, ... }:

let
  cfg = config.homelab.tailscaleServe;
  tailscale = lib.getExe config.services.tailscale.package;
  # Format: https://tailscale.com/kb/1589/tailscale-services-configuration-file
  # Endpoints are left empty: in this format the target's scheme sets both
  # the frontend and the backend protocol, so it can't express HTTPS in front
  # of a plain-HTTP backend. The file only sets which services are advertised;
  # `tailscale serve --https` adds the endpoints below.
  serveConfig = pkgs.writeText "tailscale-serve.json" (builtins.toJSON {
    version = "0.0.1";
    services = lib.mapAttrs' (name: _: lib.nameValuePair "svc:${name}" { endpoints = { }; }) cfg.services;
  });
  serveCommands = lib.concatLists (lib.mapAttrsToList (name: endpoints:
    lib.mapAttrsToList (port: target:
      "${tailscale} serve --service=svc:${name} --https=${port} --yes ${lib.escapeShellArg target}"
    ) endpoints
  ) cfg.services);
in
{
  options.homelab.tailscaleServe.services = lib.mkOption {
    type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
    default = { };
    example = { mealie."443" = "http://localhost:9000"; };
    description = "HTTPS ports and their backend per service, keyed by service name without the svc: prefix.";
  };

  config = lib.mkIf config.services.tailscale.enable {
    systemd.services.tailscale-serve = {
      description = "Apply Tailscale Services config";
      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];
      wantedBy = [ "multi-user.target" ];
      # tailscaled may still be connecting at boot. Give up after a few tries
      # so a logged-out node (e.g. the test VM) doesn't retry forever.
      startLimitBurst = 5;
      startLimitIntervalSec = 300;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = 10;
      };
      # The store path changes with the config, so a rebuild reruns this.
      # set-config validates against the stored state instead of replacing
      # it, so reapplying even an identical config fails ("port 443 is
      # already serving https"). Reset first; --all owns everything anyway.
      script = ''
        ${tailscale} serve reset
        ${tailscale} serve set-config --all ${serveConfig}
        ${lib.concatStringsSep "\n" serveCommands}
      '';
    };
  };
}
