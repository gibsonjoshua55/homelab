# Secrets with sops-nix (https://github.com/Mic92/sops-nix).
# secrets/secrets.yaml is encrypted to the age keys in ../.sops.yaml; edit it
# with `npx nx secrets gaming-pc-server`. At activation the machine decrypts
# each declared secret to /run/secrets/<name> (root-owned, 0400 by default).
#
# Declare secrets in the service file that uses them, e.g.:
#   sops.secrets."unas/password".owner = "foo";
#   ... then read config.sops.secrets."unas/password".path
#
# The machine's own age key isn't in Nix: create it once on the PC with
#   sudo mkdir -p /var/lib/sops-nix
#   sudo nix shell nixpkgs#age -c age-keygen -o /var/lib/sops-nix/key.txt
# and add its public key to .sops.yaml.
{
  sops.defaultSopsFile = ../secrets/secrets.yaml;
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  # No OpenSSH on WSL (Tailscale SSH instead), so there's no host key to
  # derive an age key from.
  sops.age.sshKeyPaths = [ ];
  sops.gnupg.sshKeyPaths = [ ];
}
