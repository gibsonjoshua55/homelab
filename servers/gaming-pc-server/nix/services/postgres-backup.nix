# Nightly Postgres backup, using NixOS's built-in services.postgresqlBackup,
# copied to the UNAS share (see ../unas.nix).
#
# pg_dumpall writes every database plus roles to all.sql.gz in
# /var/backup/postgresql, keeping the previous night's as all.prev.sql.gz.
# Each run then copies all.sql.gz to the UNAS, replacing the last copy.
#
# The dump stays on the local disk first because the module creates its
# folder with a boot-time tmpfiles rule. Pointed at /mnt/unas, that rule
# would trigger the automount before the network is up.
#
# Run one now:  sudo systemctl start postgresqlBackup
# Check runs:   systemctl list-timers postgresqlBackup; journalctl -u postgresqlBackup
{ config, pkgs, ... }:

let
  local = config.services.postgresqlBackup.location;
  # The hostname keeps the test VM's backups apart from the PC's.
  dest = "/mnt/unas/backups/${config.networking.hostName}/postgres";
in
{
  services.postgresqlBackup = {
    enable = true;
    # The machine runs on UTC; pin the time to the night where we live.
    startAt = "*-*-* 03:00:00 America/New_York";
  };

  # The module Requires= Postgres but doesn't order after it, so a run
  # right after boot (a missed one, via Persistent below) races its startup.
  systemd.services.postgresqlBackup.after = [ "postgresql.target" ];

  systemd.services.postgresqlBackup.serviceConfig = {
    # Opening /mnt/unas mounts the share. If the NAS is down this fails the
    # run (visible in the journal), but the local dump is already written.
    ExecStartPost = pkgs.writeShellScript "copy-postgres-backup-to-unas" ''
      set -euo pipefail
      ${pkgs.coreutils}/bin/mkdir -p ${dest}
      # Copy, then rename, so the share never holds a half-written dump.
      ${pkgs.coreutils}/bin/cp ${local}/all.sql.gz ${dest}/.all.sql.gz.partial
      ${pkgs.coreutils}/bin/mv -f ${dest}/.all.sql.gz.partial ${dest}/all.sql.gz
    '';
    # The share is mounted as nixos:users with group-writable folders.
    SupplementaryGroups = [ "users" ];
  };

  # If the PC was off or asleep at the scheduled time, run once it's back.
  systemd.timers.postgresqlBackup.timerConfig.Persistent = true;
}
