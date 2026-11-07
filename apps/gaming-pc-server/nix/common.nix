# NixOS config shared by the WSL distro and the local test VM.
# WSL-only settings live in wsl.nix; test-VM-only settings in test-vm.nix.
{ pkgs, ... }:

{
  imports = [
    ./secrets.nix
    ./tailscale-serve.nix
    ./unas.nix
    ./services/mealie.nix
    ./services/postgres.nix
    ./services/postgres-backup.nix
  ];

  networking.hostName = "gaming-pc-server";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  # `nx deploy` copies unsigned build inputs from the Mac; only trusted
  # users may add those to the store.
  nix.settings.trusted-users = [ "@wheel" ];

  # Log in once by hand with `sudo tailscale up --ssh --advertise-tags=tag:server`;
  # the login and tag persist in /var/lib/tailscale across rebuilds and
  # restarts. The tag is required to host Tailscale Services.
  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  environment.systemPackages = with pkgs; [
    git
    vim
  ];

  # The NixOS release this machine was first installed with. Don't bump it
  # on upgrades; see `man configuration.nix`.
  system.stateVersion = "26.05";
}
