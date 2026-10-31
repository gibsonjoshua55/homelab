# NixOS config shared by the WSL distro and the local test VM.
# WSL-only settings live in wsl.nix; test-VM-only settings in test-vm.nix.
{ pkgs, ... }:

{
  networking.hostName = "gaming-pc-server";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Log in once by hand with `sudo tailscale up --ssh`; the login persists
  # in /var/lib/tailscale across rebuilds and restarts.
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
