# Test-only settings: turn the shared config into a headless QEMU VM.
# WSL creates the `nixos` user for us; here we make it by hand.
{ lib, modulesPath, ... }:

{
  imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];

  networking.hostName = lib.mkForce "gaming-pc-server-test";

  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    password = "nixos";
  };
  security.sudo.wheelNeedsPassword = false;
  services.getty.autologinUser = "nixos";

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  virtualisation = {
    graphics = false;
    memorySize = 4096;
    cores = 4;
    forwardPorts = [
      {
        from = "host";
        host.port = 2222;
        guest.port = 22;
      }
    ];
  };
}
