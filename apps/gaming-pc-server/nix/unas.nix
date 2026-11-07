# The UNAS's SMB share (//unas.internal/Shared_Drive), mounted at /mnt/unas.
#
# It's an automount: the share mounts the first time something opens
# /mnt/unas and unmounts again after 10 idle minutes. Boot never waits on
# the NAS, and a NAS that's down only fails the access, not the system.
#
# Credentials come from secrets/secrets.yaml (unas.username, unas.password).
# Files show up as owned by the `nixos` user; the NAS enforces its own
# permissions on top of that.
{ config, ... }:

let
  mountPoint = "/mnt/unas";
in
{
  sops.secrets."unas/username" = { };
  sops.secrets."unas/password" = { };

  # mount.cifs reads this file (root-only, 0400) instead of taking the
  # password on the command line.
  sops.templates."unas-smb-credentials".content = ''
    username=${config.sops.placeholder."unas/username"}
    password=${config.sops.placeholder."unas/password"}
  '';

  fileSystems.${mountPoint} = {
    device = "//unas.internal/Shared_Drive";
    fsType = "cifs";
    options = [
      "credentials=${config.sops.templates."unas-smb-credentials".path}"
      "uid=nixos"
      "gid=users"
      "file_mode=0664"
      "dir_mode=0775"
      # Mount on first access, not at boot, and never block boot on it.
      "noauto"
      "nofail"
      "_netdev"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "x-systemd.mount-timeout=10s"
      # Wait for the network and Tailscale, which takes over DNS.
      "x-systemd.after=network-online.target"
      "x-systemd.after=tailscaled.service"
      "x-systemd.requires=network-online.target"
    ];
  };
}
