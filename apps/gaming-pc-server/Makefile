# Every target runs Nix inside Docker, so the Mac needs only Docker.
# Downloads and builds are cached in a per-arch Docker volume.
ARCH     ?= $(shell uname -m | sed 's/arm64/aarch64/')
PLATFORM := $(if $(filter x86_64,$(ARCH)),linux/amd64,linux/arm64)
NIX      := docker run --rm --platform $(PLATFORM) \
	-v gaming-pc-server-nix-$(ARCH):/nix -v "$(CURDIR)":/work -w /work \
	-e NIX_CONFIG="$$(printf 'experimental-features = nix-command flakes\nsandbox = false\nfilter-syscalls = false')"
SSH_OPTS := -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR

.PHONY: check build-wsl _build-wsl test ssh-test clean update

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
	$(NIX) -it --name gaming-pc-server-test -p 2222:2222 nixos/nix sh -c '\
	  nix build -o .cache/test-vm-$(ARCH) \
	    .#nixosConfigurations.test-vm-$(ARCH).config.system.build.vm && \
	  cd /tmp && exec /work/.cache/test-vm-$(ARCH)/bin/run-gaming-pc-server-test-vm'

ssh-test:
	ssh $(SSH_OPTS) nixos@localhost

clean:
	rm -rf .cache
	-docker volume rm gaming-pc-server-nix-aarch64 gaming-pc-server-nix-x86_64

## Bump nixpkgs/NixOS-WSL in flake.lock
update:
	$(NIX) nixos/nix nix flake update
