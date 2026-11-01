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
| Mac        | Copy the folder to Windows (setup) | `npx nx copy-to-pc gaming-pc-server`                                                    |
| Mac        | Apply the config to the PC         | `npx nx deploy gaming-pc-server`                                                        |
| Mac        | Bump nixpkgs/NixOS-WSL             | `npx nx update gaming-pc-server`                                                        |
| Mac        | Delete VM output and the Nix cache | `npx nx clean gaming-pc-server`                                                         |

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

When you're done, the PC boots NixOS in WSL on its own, keeps it running
with the screen off, and joins the tailnet as `gaming-pc-server`. You can
then SSH in and reach its services from any device on the tailnet, with no
port forwarding.

WSL stays in its default **NAT** networking mode. Don't switch it to
mirrored: in mirrored mode, Tailscale inside NixOS clashes with Tailscale
on Windows. If Windows runs Tailscale too, the PC shows up twice on the
tailnet (as the Windows machine and as `gaming-pc-server`). That's
expected.

You need Windows 11 and an admin account. The PC never needs git access:
you copy the config over once for the first switch, and after that the Mac
pushes changes with `npx nx deploy`.

### 1. Install WSL

In an **admin** PowerShell:

```powershell
wsl --install --no-distribution
```

Reboot if it asks you to. Then make sure WSL is up to date (NixOS-WSL
needs WSL 2.4.4 or newer):

```powershell
wsl --update
wsl --version
```

### 2. Install NixOS-WSL

Download `nixos.wsl` from the latest
[NixOS-WSL release](https://github.com/nix-community/NixOS-WSL/releases),
then install it:

```powershell
wsl --install --from-file $HOME\Downloads\nixos.wsl
wsl --set-default NixOS
```

The distro is named `NixOS` and its user is `nixos`. If anything differs,
follow the
[NixOS-WSL install guide](https://nix-community.github.io/NixOS-WSL/install.html).

If you use Docker Desktop on Windows, turn **off** its WSL integration for
NixOS (Settings → Resources → WSL integration). The config runs its own
Docker inside NixOS, and the two would fight over the socket.

### 3. Apply this config

Tailscale isn't running yet, so the Mac can't deploy. Do the first switch
on the PC instead. First get this folder onto the Windows drive. If the Mac
can already SSH into Windows (the `ssh` target), run this from the Mac:

```sh
npx nx copy-to-pc gaming-pc-server   # lands in C:\Users\<you>\gaming-pc-server
```

It connects to `jcgla@josh-desktop`; set `WINDOWS_HOST=user@host` to
change that. Otherwise, copy the folder over by hand or download the repo
as a zip. WSL sees the Windows drive under `/mnt/c`.

Open the distro (`wsl -d NixOS`) and switch to the config:

```sh
cd /mnt/c/Users/<you>/gaming-pc-server
sudo env NIX_CONFIG='experimental-features = nix-command flakes' \
  nixos-rebuild switch --flake .#gaming-pc-server
```

You can delete the folder afterwards.

Then restart the distro from PowerShell so the new hostname and settings
take effect:

```powershell
wsl --terminate NixOS
wsl -d NixOS
```

### 4. Join the tailnet

Inside NixOS:

```sh
sudo tailscale up --ssh --advertise-tags=tag:server
```

The tag has to exist in the tailnet policy file first (see
[Tailscale Services](#tailscale-services)). Open the login URL it prints and
approve the device. The login is stored in
`/var/lib/tailscale`, so you only do this once. `--ssh` turns on Tailscale
SSH: tailnet devices can run `ssh nixos@gaming-pc-server` without any SSH
keys. Tailscale access rules decide who can connect.

Tagged nodes don't expire, so you don't need to disable key expiry.

The test VM runs Tailscale too, but stays logged out unless you run this
command in it.

### 5. Keep WSL running

On its own, WSL starts only when something opens it, and it shuts down
when idle. That would take your services offline after every reboot. Three
Windows-side settings fix that. Nix can't manage them, so run these once.

**Start NixOS at boot.** In an **admin** PowerShell, register a task that
starts the distro when Windows boots and keeps a process attached so WSL
never considers it idle:

```powershell
$action    = New-ScheduledTaskAction -Execute "wsl.exe" `
  -Argument "-d NixOS --exec /run/current-system/sw/bin/sleep infinity"
$trigger   = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType S4U
$settings  = New-ScheduledTaskSettingsSet `
  -ExecutionTimeLimit ([TimeSpan]::Zero) `
  -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
  -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName "Keep NixOS WSL running" `
  -Action $action -Trigger $trigger -Principal $principal -Settings $settings
```

`-LogonType S4U` runs it whether or not you're logged in, without storing
your password. `-ExecutionTimeLimit 0` matters: by default, Task Scheduler
kills tasks after 72 hours.

**Turn off WSL's idle shutdown.** Create or edit `%UserProfile%\.wslconfig`:

```ini
[wsl2]
vmIdleTimeout=-1
```

**Never sleep, but let the screen turn off.** In an admin PowerShell:

```powershell
powercfg /change standby-timeout-ac 0     # never sleep
powercfg /change hibernate-timeout-ac 0   # never hibernate
powercfg /change monitor-timeout-ac 10    # screen off after 10 minutes
```

The PC keeps running while the monitor goes into standby. If the screen
won't turn off, `powercfg /requests` shows which app is keeping it awake.

Then run `wsl --shutdown` so WSL picks up `.wslconfig`.

### 6. Check it all works

Reboot Windows and **don't log in**. From another device on the tailnet:

```sh
ssh nixos@gaming-pc-server          # Tailscale SSH, no keys
curl -I https://mealie.tail65441.ts.net  # Mealie, via Tailscale Services
```

If both work, setup is done. If the PC doesn't appear on the tailnet until
you log in, the S4U task isn't starting WSL on this machine. Re-register it
with `New-ScheduledTaskTrigger -AtLogOn` and the default (interactive)
principal, and turn on Windows auto-login so it still comes up after a
reboot.

To check things from inside NixOS:

```sh
tailscale status                  # tailnet connection
systemctl status docker-mealie    # Mealie container
```

### 7. Finish setting up Mealie

Open `https://mealie.tail65441.ts.net` and sign in with Mealie's default
admin account (`changeme@example.com` / `MyPassword`). Change the email and
password right away. Sign-ups are off, so invite other users from Mealie's
admin settings.

## Tailscale Services

Mealie is published as the Tailscale Service `svc:mealie`, at
`https://mealie.tail65441.ts.net`. Tailscale handles HTTPS and proxies to
`localhost:9000`. Service files declare their endpoints with
`homelab.tailscaleServe.services`, and
[nix/tailscale-serve.nix](nix/tailscale-serve.nix) applies them on boot and
on every deploy.

Some of the setup lives in the tailnet, not in this config:

- **Policy file:** only tagged nodes can host services, and a tagged node
  isn't covered by the default "your own devices" SSH rule. Add both:
  ```jsonc
  "tagOwners": { "tag:server": ["autogroup:admin"] },
  "ssh": [
    { "action": "accept", "src": ["autogroup:admin"], "dst": ["tag:server"], "users": ["nixos", "root"] },
  ],
  ```
- **New services:** create each one under
  [Services](https://login.tailscale.com/admin/services) in the admin console
  before deploying it. If the host advertised the service before it existed,
  re-send the advertisement with
  `sudo tailscale serve drain svc:<name> && sudo tailscale serve advertise svc:<name>`.
- **Approval:** approve the host on the service's page. To skip that step,
  add the service to `autoApprovers.services` in the policy file.

Check what the node is serving with `sudo tailscale serve status`, and see
whether the config applied with `systemctl status tailscale-serve`.

## Changing the config

Edit the config, run `npx nx test gaming-pc-server` on the Mac to try it,
then apply it to the PC:

```sh
npx nx deploy gaming-pc-server
```

This evaluates the config on the Mac (inside Docker), so mistakes fail
before anything reaches the PC. Then it builds on the PC over Tailscale
SSH, natively and mostly from the NixOS binary cache, and switches to the
new system. The Mac must be on the tailnet. Committing first is up to you:
`deploy` sends what's in this folder now. Only this folder is mounted, so
Nix sees every file, git-tracked or not.

If Tailscale SSH asks you to approve the login in a browser, open the URL
it prints. If the container can't resolve `gaming-pc-server`, pass the
full MagicDNS name or the 100.x address:

```sh
DEPLOY_HOST=nixos@100.x.y.z npx nx deploy gaming-pc-server
```

`deploy` needs the first switch (step 3) done, because that's what lets
the `nixos` user receive builds from the Mac (`nix.settings.trusted-users`).

To undo a bad change, run `sudo nixos-rebuild switch --rollback` on the PC.

`system.stateVersion` records the release first installed. Leave it alone
when upgrading nixpkgs.

## Repo layout

```
flake.nix              Entry point: pins nixpkgs + NixOS-WSL; defines the WSL system and the test VMs
flake.lock             Exact pinned versions (commit it)
nix/common.nix         Shared config: goes on the PC and into the test VM
nix/wsl.nix            WSL-only settings
nix/test-vm.nix        Test-VM-only settings (user, SSH, QEMU options)
nix/tailscale-serve.nix  Applies the Tailscale Services that service files declare
nix/services/          One file per hosted service (e.g. mealie.nix), imported from common.nix
project.json           Nx targets
Makefile               What the Mac targets run; Nix runs inside Docker
.cache/                Built VM link and deploy's SSH known_hosts (gitignored)
```
