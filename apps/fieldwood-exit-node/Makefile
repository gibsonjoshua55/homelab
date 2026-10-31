TOOLS   := fcos-tailscale-tools
DOCKER  := docker run --rm -v "$(CURDIR)":/work -w /work
RUN     := $(DOCKER) $(TOOLS)
ARCH    ?= $(shell uname -m | sed 's/arm64/aarch64/')
STREAM  ?= stable
SSH_OPTS := -i .cache/test_ed25519 -p 2222 \
	-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR

.PHONY: tools ignition iso test ssh clean

tools:
	docker build -q -t $(TOOLS) test >/dev/null

secrets/tailscale.env secrets/authorized_keys:
	@echo "Missing $@ — copy it from secrets.example/ and fill it in." >&2; exit 1

## build/config.ign: Ignition for the real NUC
ignition: tools secrets/tailscale.env secrets/authorized_keys
	@mkdir -p build
	$(RUN) butane --pretty --strict --files-dir . config.bu -o build/config.ign
	@echo "Wrote build/config.ign"

## build/nuc-install.iso: USB installer that WIPES $(DEST_DEVICE) and installs unattended
iso: ignition
	@test -n "$(DEST_DEVICE)" || { echo "Set DEST_DEVICE, e.g. make iso DEST_DEVICE=/dev/nvme0n1" >&2; exit 1; }
	@mkdir -p .cache/images/x86_64
	$(RUN) sh -c 'set -e; \
	  iso=$$(coreos-installer download -s $(STREAM) -p metal -f iso -a x86_64 -C .cache/images/x86_64); \
	  rm -f build/nuc-install.iso; \
	  coreos-installer iso customize --dest-device $(DEST_DEVICE) \
	    --dest-ignition build/config.ign -o build/nuc-install.iso "$$iso"'
	@echo "Wrote build/nuc-install.iso (installs to $(DEST_DEVICE))"

.cache/test_ed25519:
	@mkdir -p .cache
	ssh-keygen -q -t ed25519 -N '' -C fcos-test -f $@

## Boot the config in a local QEMU VM (inside Docker). ARCH=x86_64 to match the NUC exactly.
test: ignition .cache/test_ed25519
	$(RUN) butane --pretty --strict --files-dir . test/overlay.bu -o build/test-overlay.ign
	$(RUN) butane --pretty --strict --files-dir . test/test.bu -o build/test.ign
	$(DOCKER) -it --name fcos-test -p 2222:2222 -e ARCH=$(ARCH) -e STREAM=$(STREAM) \
	  $(TOOLS) run-vm build/test.ign

ssh-test:
	ssh $(SSH_OPTS) core@localhost

clean:
	rm -rf build .cache/disk-*.qcow2
