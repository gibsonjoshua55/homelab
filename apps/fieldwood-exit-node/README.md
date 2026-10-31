# fieldwood-exit-node

Turns an old Intel NUC into a headless Tailscale **exit node** running
[Fedora CoreOS](https://fedoraproject.org/coreos/) (FCOS). After it's
installed it updates itself and needs no maintenance beyond an occasional
check.

You only need Docker and Node.js on your workstation. Butane,
coreos-installer and QEMU all run in a tools container built from
[`test/Dockerfile`](test/Dockerfile).

## Quick reference

Run these from the repo root. Each target is defined in
[`project.json`](project.json) and delegates to the `Makefile` in this
directory.

| I want to…                        | Run                                                                                           |
| --------------------------------- | --------------------------------------------------------------------------------------------- |
| Build the Ignition config         | `npx nx ignition fieldwood-exit-node` → `build/config.ign`                                    |
| Build a USB installer for the NUC | `DEST_DEVICE=/dev/nvme0n1 npx nx iso fieldwood-exit-node`                                     |
| Try the config in a local VM      | `npx nx test fieldwood-exit-node` (then `npx nx ssh-test fieldwood-exit-node` in another tab) |
| Same, with the NUC's CPU arch     | `ARCH=x86_64 npx nx test fieldwood-exit-node`                                                 |
| Delete build output and VM disks  | `npx nx clean fieldwood-exit-node` (keeps downloaded FCOS images)                             |

Target variables such as `DEST_DEVICE`, `ARCH` and `STREAM` are passed as
environment variables, as shown above. `npx nx <target> fieldwood-exit-node`
is shorthand for `npx nx run fieldwood-exit-node:<target>`.

## How it works

FCOS has no installer UI. You write a **Butane** file
([`config.bu`](config.bu)), compile it to an **Ignition** JSON file, and
Ignition applies it **once, on the first boot** of a fresh install. Later
edits to `config.bu` do nothing to a machine that's already running. See
[Changing the config](#changing-the-config).

`config.bu` sets up:

- **SSH**: your key(s) from `secrets/authorized_keys` for the `core` user
  (passwordless `sudo`).
- **Hostname**: `tailscale-exit`.
- **IP forwarding**: on for IPv4 and IPv6, which exit nodes need.
- **Tailscale**:
  - Adds Tailscale's official Fedora repo.
  - `tailscale-install.service` runs once on first boot. It layers the
    `tailscale` RPM onto the OS with `rpm-ostree install --apply-live` (no
    reboot) and starts `tailscaled`.
  - A drop-in makes `tailscaled` use nftables. FCOS kernels lack legacy
    iptables, so exit-node NAT doesn't work without it.
  - `tailscale-up.service` runs
    `tailscale up --advertise-exit-node --ssh` on every boot. The auth key
    from `secrets/tailscale.env` only matters until the node has logged in
    once.
- **Automatic updates**: Zincati, FCOS's update agent, downloads OS updates
  when they're released, but only reboots between **08:00 and 09:00 UTC**
  (3–4am EST, 4–5am EDT). Every OS update also pulls the newest Tailscale
  RPM, so Tailscale updates on the same schedule as the OS.

### Why it's built this way

- **A layered RPM, not a container.** Tailscale runs on the host, so exit-node
  routing, nftables and Tailscale SSH all just work. If it ran in a
  container, it would need privileged mode and host networking, and
  Tailscale SSH would drop you into the container instead of the host.
- **Install on first boot, not baked into the image.** This way you can use
  the stock FCOS image and don't have to build or host a custom OS image.
- **Everything runs in Docker.** Butane, coreos-installer and QEMU don't
  need to be installed on the Mac.

## First-time setup

```sh
mkdir -p secrets
cp secrets.example/* secrets/
# edit secrets/authorized_keys  -> your SSH public key(s), one per line
# edit secrets/tailscale.env    -> TS_AUTHKEY=tskey-auth-...
```

`secrets/` is gitignored, so it won't be on a fresh clone. Recreate it as
shown above.

**Auth key:** create one under
[Settings → Keys](https://login.tailscale.com/admin/settings/keys). Auth
keys expire (90 days at most), so make a new one each time you install. If
you leave `TS_AUTHKEY` empty, log in interactively instead: the login URL
appears in `journalctl -u tailscale-up`, which you can read over SSH on the
LAN.

## Test in a local VM

```sh
npx nx test fieldwood-exit-node               # same arch as this Mac (aarch64): faster
ARCH=x86_64 npx nx test fieldwood-exit-node   # same arch as the NUC: slower, closest to real
```

This boots a fresh FCOS VM with QEMU inside Docker. Docker Desktop on a Mac
has no KVM, so QEMU emulates the CPU in software, and first boot takes a few
minutes. The serial console takes over the terminal. Press **Ctrl-A, then
X** to quit.

The VM uses the real config, plus two test-only overrides from
[`test/overlay.bu`](test/overlay.bu): a throwaway SSH key and the hostname
`tailscale-exit-test`. To check it from another terminal:

```sh
npx nx ssh-test fieldwood-exit-node
rpm-ostree status          # tailscale listed under LayeredPackages
systemctl status tailscale-install tailscaled tailscale-up
tailscale status
```

The test VM joins your tailnet for real. Use an **ephemeral** auth key for
testing so the node removes itself once the VM is gone.

How the test files fit together: [`test/test.bu`](test/test.bu) merges
`build/config.ign` and then `build/test-overlay.ign`. In an Ignition merge,
later configs override earlier ones, which is why the overlay has to be a
separate file.

## Install on the NUC

### Option A: unattended USB installer (recommended)

> ⚠️ The installer **wipes `DEST_DEVICE` without asking**.

```sh
DEST_DEVICE=/dev/nvme0n1 npx nx iso fieldwood-exit-node    # or /dev/sda, whichever disk the NUC has
diskutil list                        # find the USB stick, e.g. /dev/disk4
diskutil unmountDisk /dev/diskN
sudo dd if=build/nuc-install.iso of=/dev/rdiskN bs=4m
```

Each run downloads the latest FCOS `stable` ISO (cached in `.cache/`). Boot
the NUC from the stick (F10 opens the boot menu on most NUCs). It installs
and then reboots. Pull the stick out when it reboots.

To find the right disk name, boot any Linux live USB on the NUC and run
`lsblk`.

### Option B: by hand

Boot the stock FCOS live ISO, copy `build/config.ign` onto the machine (USB
stick, `scp`, or `python3 -m http.server`), then run:

```sh
sudo coreos-installer install /dev/nvme0n1 --ignition-file config.ign
```

### After installing

In the [admin console](https://login.tailscale.com/admin/machines), find
`tailscale-exit` and do two things:

1. **Edit route settings → Use as exit node.** It won't route traffic until
   you approve this.
2. **Disable key expiry.** Otherwise the node logs out after about 180 days
   and you'll need LAN access to log it back in.

Tailscale SSH (`ssh core@tailscale-exit`) only lets you in if your tailnet
policy has an `ssh` rule that allows it. Plain SSH with your key over the LAN
always works.

## Operating it

Connect with `ssh core@tailscale-exit` over the tailnet, or use the NUC's LAN
IP (check your router's DHCP list).

```sh
rpm-ostree status                 # current/previous OS deployments + layered packages
journalctl -u zincati -e          # update agent: what it downloaded, when it'll reboot
tailscale status                  # tailnet connectivity
journalctl -u tailscale-up -e     # login problems
```

**Roll back a bad update:** `sudo rpm-ostree rollback -r` boots the previous
deployment. FCOS keeps the last one.

**Re-login to Tailscale** (e.g. the key expired):
`sudo tailscale up --advertise-exit-node --ssh --force-reauth`, then open the
URL it prints.

**Add or replace an SSH key:** edit
`/home/core/.ssh/authorized_keys.d/ignition`. Also update
`secrets/authorized_keys` so the next install gets the change.

**Change the update window:** edit
`/etc/zincati/config.d/55-updates-strategy.toml`, then run
`sudo systemctl restart zincati`.

### Changing the config

Ignition only runs on first boot. To change a machine that's already
running, either:

- **Make the same change by hand** on the NUC (files under `/etc` are
  writable and survive updates). Also edit `config.bu` so it stays the
  source of truth.
- **Reinstall**: rebuild the ISO and boot from it again. You'll need a fresh
  auth key, and the old node will show up as a duplicate in the admin
  console. Remove it there.

## Troubleshooting

**OS updates stop happening.** Look at `journalctl -u zincati` and
`rpm-ostree status`. The most likely cause: every update also has to
download Tailscale. If `pkgs.tailscale.com` is down or its GPG key has
changed, the whole update fails and Zincati keeps retrying. If the key
changed, compare the repo definition in `config.bu` against
[Tailscale's Fedora install docs](https://tailscale.com/download/linux/fedora)
and fix `/etc/yum.repos.d/tailscale.repo` to match.

**Exit node is approved but no traffic flows.** Check that forwarding is on
(`sysctl net.ipv4.ip_forward` should print `1`) and that `tailscaled` is
using nftables (`journalctl -u tailscaled | grep -i nftables`).

**`npx nx ignition fieldwood-exit-node` fails with "Missing secrets/…".**
You're on a fresh clone. Do [First-time setup](#first-time-setup).

**Tools image fails to build.** [`test/Dockerfile`](test/Dockerfile) pins a
Fedora release. Once that release reaches end of life, raise the number to a
current one.

**`butane` rejects the config after a tools upgrade.** `version: 1.6.0` at
the top of each `.bu` file is the
[Butane spec version](https://coreos.github.io/butane/specs/). Newer Butane
still accepts older specs, so this usually only fails if the spec was
changed by hand.

## Repo layout

```
config.bu              The real machine config (the only file that matters on the NUC)
project.json           Nx targets (ignition, iso, test, ssh-test, ssh, clean)
Makefile               What each Nx target runs; everything runs inside the tools container
secrets.example/       Templates for secrets/ (gitignored)
test/Dockerfile        Tools image: butane, coreos-installer, QEMU (used by every target, not just tests)
test/run-vm.sh         Boots a throwaway QEMU VM from an Ignition file
test/test.bu           Merges the real config + the test overlay
test/overlay.bu        Test-only overrides (throwaway SSH key, hostname)
build/                 Generated .ign and .iso files (gitignored)
.cache/                Downloaded FCOS images, VM disks, test SSH key (gitignored)
```
