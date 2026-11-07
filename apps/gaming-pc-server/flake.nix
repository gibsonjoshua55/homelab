{
  description = "NixOS on WSL for the Windows gaming PC";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Decrypts secrets/*.yaml on the machine at activation; see nix/secrets.nix.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, nixos-wsl, sops-nix, ... }:
    let
      # Local test VM: the shared config without WSL, booted with QEMU.
      mkTestVm =
        system:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            sops-nix.nixosModules.sops
            ./nix/common.nix
            ./nix/test-vm.nix
          ];
        };
    in
    {
      nixosConfigurations = {
        gaming-pc-server = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            nixos-wsl.nixosModules.default
            sops-nix.nixosModules.sops
            ./nix/common.nix
            ./nix/wsl.nix
          ];
        };
        test-vm-aarch64 = mkTestVm "aarch64-linux";
        test-vm-x86_64 = mkTestVm "x86_64-linux";
      };
    };
}
