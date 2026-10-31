# gaming-pc-server

[NixOS](https://nixos.org/) running in WSL on the Windows gaming PC, built
on [NixOS-WSL](https://github.com/nix-community/NixOS-WSL). You can try
changes in a local VM on the Mac before applying them to the PC.

The Mac needs only Docker and Node.js. Nix itself runs in the
[`nixos/nix`](https://hub.docker.com/r/nixos/nix) container.

## Quick reference

Run these from the repo root. Each target is defined in
[`project.json`](project.json).

| Where      | I want to…                         | Run                                                                                     |
| ---------- | ---------------------------------- | --------------------------------------------------------------------------------------- |
| Mac        | Check every config evaluates       | `npx nx check gaming-pc-server`                                                         |
| Mac        | Try the config in a local VM       | `npx nx test gaming-pc-server` (then `npx nx ssh-test gaming-pc-server` in another tab) |
| Mac        | Build the real WSL system          | `npx nx build-wsl gaming-pc-server` (x86_64 under emulation: slow)                      |
| Mac        | Bump nixpkgs/NixOS-WSL             | `npx nx update gaming-pc-server`                                                        |
| Mac        | Delete VM output and the Nix cache | `npx nx clean gaming-pc-server`                                                         |
| PC, in WSL | Build without applying             | `npx nx build gaming-pc-server`                                                         |
| PC, in WSL | Build and apply the config         | `npx nx switch gaming-pc-server`                                                        |

## How the config is split

The WSL distro and the test VM share most of their config, and each adds
its own pieces on top. [`flake.nix`](flake.nix) puts them together:

| Output                             | Modules                                      | Used for                  |
| ---------------------------------- | -------------------------------------------- | ------------------------- |
| `gaming-pc-server`                 | NixOS-WSL + `nix/common.nix` + `nix/wsl.nix` | The real distro on the PC |
| `test-vm-aarch64`/`test-vm-x86_64` | `nix/common.nix` + `nix/test-vm.nix`         | Local QEMU VM             |

Put new settings in [`nix/common.nix`](nix/common.nix) so the VM
tests them too. Only WSL-specific options (`wsl.*`) go in
[`nix/wsl.nix`](nix/wsl.nix).

## Test in a local VM

```sh
npx nx test gaming-pc-server               # same arch as this Mac (aarch64): faster
ARCH=x86_64 npx nx test gaming-pc-server   # same arch as the PC: slower, closest to real
```

This builds the VM with Nix and boots it with QEMU, all inside Docker. The
first run downloads a lot; later runs reuse the `gaming-pc-server-nix-<arch>`
Docker volume. Docker Desktop has no KVM, so the CPU is emulated and boot
takes a minute or two. You land in the serial console, already logged in as
`nixos`. Press **Ctrl-A, then X** to quit.

From another terminal, `npx nx ssh-test gaming-pc-server` connects over SSH
(password `nixos`). Every run starts from a fresh disk.

What the VM does **not** cover: anything WSL provides, such as Windows
interop, `/mnt/c` mounts, WSL networking and how NixOS-WSL creates the
default user. The VM has its own kernel and bootloader, and test-only
settings in [`nix/test-vm.nix`](nix/test-vm.nix) (a `nixos` user with a
password, autologin, SSH and the hostname `gaming-pc-server-test`).

## First-time setup on the PC

1. On Windows, install the stock NixOS-WSL distro by following the
   [NixOS-WSL install guide](https://nix-community.github.io/NixOS-WSL/install.html).
2. Open it (`wsl -d NixOS`), then clone this repo and apply the config.
   The stock image has neither git nor Node.js, so borrow them for the
   first switch:

   ```sh
   nix-shell -p git nodejs
   git clone <this repo> ~/homelab && cd ~/homelab
   npm ci
   npx nx switch gaming-pc-server
   ```

3. From Windows, run `wsl --terminate NixOS` and reopen the distro so the
   new hostname and settings take effect.
4. Join the tailnet. Open the login URL it prints:

   ```sh
   sudo tailscale up --ssh
   ```

   The login is stored in `/var/lib/tailscale`, so you only do this once.
   `--ssh` turns on Tailscale SSH, so you can reach the distro with
   `ssh nixos@gaming-pc-server` from any device on the tailnet. The
   test VM runs Tailscale too, but stays logged out unless you run this
   command in it.

## Changing the config

Edit the config, run `npx nx test gaming-pc-server` on the Mac to try it,
commit, then pull on the PC and run `npx nx switch gaming-pc-server`. To
undo a bad change on the PC, run `sudo nixos-rebuild switch --rollback`.

Nix only sees files that git tracks. If you add a new `.nix` file,
`git add` it before switching on the PC, or you'll get a "path does not
exist" error. The Mac targets mount only this folder, so they don't have
this problem.

`system.stateVersion` records the release first installed. Leave it alone
when upgrading nixpkgs.

## Repo layout

```
flake.nix              Entry point: pins nixpkgs + NixOS-WSL; defines the WSL system and the test VMs
flake.lock             Exact pinned versions (commit it)
nix/common.nix         Shared config: goes on the PC and into the test VM
nix/wsl.nix            WSL-only settings
nix/test-vm.nix        Test-VM-only settings (user, SSH, QEMU options)
project.json           Nx targets
Makefile               What the Mac targets run; Nix runs inside Docker
.cache/                Built VM link (gitignored)
```
