# PostgreSQL, run natively by NixOS (postgresql.service), not in Docker.
# Data lives in /var/lib/postgresql/<major>, on the Linux disk.
#
# Services add their own database and role, e.g.:
#   services.postgresql.ensureDatabases = [ "foo" ];
#   services.postgresql.ensureUsers = [ { name = "foo"; ensureDBOwnership = true; } ];
# A system user of the same name then connects over the Unix socket with no
# password (peer auth).
{ pkgs, ... }:

{
  services.postgresql = {
    enable = true;
    # Pinned so a nixpkgs bump never changes the major version. Upgrading
    # majors needs a manual pg_upgrade; see the NixOS manual's PostgreSQL
    # chapter.
    package = pkgs.postgresql_18;
  };
}
