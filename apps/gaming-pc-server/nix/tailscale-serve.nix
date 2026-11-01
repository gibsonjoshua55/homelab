# Tailscale Services (https://tailscale.com/kb/1552/tailscale-services)
# hosted by this machine. Service files add entries to
# homelab.tailscaleServe.services; this module applies all of them with
# `tailscale serve set-config --all`, so services removed here stop being
# served too.
#
# Not covered here, done once per tailnet: the node must carry a tag
# (service hosts must be tagged), each service must exist in the admin
# console, and each host must be approved there unless the policy file
# auto-approves it.
{ config, lib, pkgs, ... }:

let
  cfg = config.homelab.tailscaleServe;
  # Format: https://tailscale.com/kb/1589/tailscale-services-configuration-file
  serveConfig = pkgs.writeText "tailscale-serve.json" (builtins.toJSON {
    version = "0.0.1";
    services = lib.mapAttrs' (name: endpoints: lib.nameValuePair "svc:${name}" { inherit endpoints; }) cfg.services;
  });
in
{
  options.homelab.tailscaleServe.services = lib.mkOption {
    type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
    default = { };
    example = { mealie."tcp:443" = "http://localhost:9000"; };
    description = "Endpoints per service, keyed by service name without the svc: prefix.";
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
      script = "${lib.getExe config.services.tailscale.package} serve set-config --all ${serveConfig}";
    };
  };
}
