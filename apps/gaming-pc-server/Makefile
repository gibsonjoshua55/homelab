# Every target runs Nix inside Docker, so the Mac needs only Docker.
# Downloads and builds are cached in a per-arch Docker volume.
ARCH     ?= $(shell uname -m | sed 's/arm64/aarch64/')
PLATFORM := $(if $(filter x86_64,$(ARCH)),linux/amd64,linux/arm64)
NIX      := docker run --rm --platform $(PLATFORM) \
	-v gaming-pc-server-nix-$(ARCH):/nix -v "$(CURDIR)":/work -w /work \
	-e NIX_CONFIG="$$(printf 'experimental-features = nix-command flakes\nsandbox = false\nfilter-syscalls = false')"
DEPLOY_HOST ?= nixos@gaming-pc-server
# Windows' own OpenSSH server on the PC, for copy-to-pc.
WINDOWS_HOST ?= jcgla@josh-desktop
SSH_OPTS := -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR

.PHONY: check build-wsl _build-wsl test ssh-test copy-to-pc deploy clean update

## Evaluate every config in the flake
check:
	$(NIX) nixos/nix nix flake check --no-build --all-systems

## Build the real WSL system (x86_64; emulated on Apple Silicon, so slow)
build-wsl:
	$(MAKE) ARCH=x86_64 _build-wsl
_build-wsl:
	$(NIX) nixos/nix nix build --no-link \
	  .#nixosConfigurations.gaming-pc-server.config.system.build.toplevel

## Boot the shared config in a local QEMU VM (inside Docker). Fresh disk each run.
test:
	$(NIX) -it --name gaming-pc-server-test -p 2222:2222 -p 9000:9000 nixos/nix sh -c '\
	  nix build -o .cache/test-vm-$(ARCH) \
	    .#nixosConfigurations.test-vm-$(ARCH).config.system.build.vm && \
	  cd /tmp && exec /work/.cache/test-vm-$(ARCH)/bin/run-gaming-pc-server-test-vm'

ssh-test:
	ssh $(SSH_OPTS) nixos@localhost

## Copy this folder to C:\Users\<you>\gaming-pc-server for the first switch.
## Uses Windows' tar.exe; COPYFILE_DISABLE skips macOS ._ metadata files.
copy-to-pc:
	COPYFILE_DISABLE=1 tar -cf - -C .. --exclude .cache --exclude 'result*' $(notdir $(CURDIR)) \
	  | ssh $(WINDOWS_HOST) tar -xf -

## Evaluate here, then build on the PC and switch it, over Tailscale SSH.
## --no-reexec: otherwise nixos-rebuild builds the PC's (x86_64) copy of itself here.
deploy:
	mkdir -p .cache
	$(NIX) -it -e NIX_SSHOPTS="-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/work/.cache/known_hosts" \
	  nixos/nix nix shell --inputs-from . nixpkgs#nixos-rebuild-ng nixpkgs#openssh -c \
	  nixos-rebuild switch --flake .#gaming-pc-server --no-reexec --sudo --use-substitutes \
	    --target-host $(DEPLOY_HOST) --build-host $(DEPLOY_HOST)

clean:
	rm -rf .cache
	-docker volume rm gaming-pc-server-nix-aarch64 gaming-pc-server-nix-x86_64

## Bump nixpkgs/NixOS-WSL in flake.lock
update:
	$(NIX) nixos/nix nix flake update
