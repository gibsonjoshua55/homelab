IMAGE ?= registry.tail65441.ts.net/hello
# The version is the short SHA of the last commit that touched this folder, so
# it only changes when the app does. Uncommitted changes add a -dirty suffix,
# and push refuses to run while that suffix is there.
SHA     := $(shell git log -1 --format=%h -- .)
DIRTY   := $(shell git status --porcelain -- .)
VERSION := $(or $(SHA),untracked)$(if $(DIRTY),-dirty)
# The server is x86_64; build arm64 too so the image also runs on the Mac.
PLATFORMS ?= linux/amd64,linux/arm64

.PHONY: version build serve push

version:
	@echo $(VERSION)

## Build for this machine only and load into the local Docker
build:
	docker build -t $(IMAGE):$(VERSION) -t $(IMAGE):latest .

serve: build
	docker run --rm -p 8080:80 $(IMAGE):$(VERSION)

## Build for every platform and push both tags (buildx can't keep a
## multi-arch image locally, so this rebuilds instead of reusing `build`)
push:
	@if [ -n "$(DIRTY)" ] || [ -z "$(SHA)" ]; then \
	  echo "apps/hello has uncommitted changes; commit before pushing so $(IMAGE):<sha> matches the code." >&2; \
	  exit 1; \
	fi
	docker buildx build --platform $(PLATFORMS) \
	  -t $(IMAGE):$(VERSION) -t $(IMAGE):latest --push .
