SHELL := /bin/bash
ARCH ?= arm64
SUITE ?= trixie
MIRROR ?= http://deb.debian.org/debian

NAME ?= sparrowhawk
REPO_OWNER := $(shell git remote -v | grep origin | head -1 | sed -e 's/.*github\.com[:/]//' -e 's/\/.*//')
DATE := $(shell date +%Y%m%d)
OUTDIR := out
ROOTFS := $(OUTDIR)/rootfs
IMG := $(OUTDIR)/$(NAME)-$(SUITE)-$(ARCH)-$(DATE).img
XZ := $(IMG).xz
REPO := $(OUTDIR)/repo.json

SIZE_GIB ?= 4
BOOT_MIB ?= 512

# GitHub release tag that will actually host $(XZ)/$(REPO)/icons.
# Defaults to the standalone "binary_release" channel; CI overrides this
# with the branch's real release tag (e.g. v2026-07-01, dev-latest, next-release)
# once it's known, so repo.json points at where the assets really land.
RELEASE_TAG ?= binary_release
RELEASE_URL := https://github.com/$(REPO_OWNER)/sparrow-hawk-debian/releases/download/$(RELEASE_TAG)

.PHONY: all clean rootfs image repo

all: $(REPO)

image: $(IMG).xz

rootfs.done:
	rm -f rootfs.done
	-mkdir $(OUTDIR)
	sudo scripts/01_build_rootfs.sh "$(ARCH)" "$(SUITE)" "$(MIRROR)" "$(ROOTFS)" && touch rootfs.done

$(IMG).xz: rootfs.done
	sudo scripts/02_make_disk_image.sh "$(ROOTFS)" "$(IMG)" "$(SIZE_GIB)" "$(BOOT_MIB)"
	sudo scripts/03_pack_and_hash.sh "$(IMG)"

$(REPO): $(IMG).xz
	python3 scripts/04_update_repo_json.py "$(XZ)" "$(REPO)" \
		"$(RELEASE_URL)/$(notdir $(XZ))" \
		"$(RELEASE_URL)/sh-mascot.png"

repo: $(REPO)

clean:
	sudo rm -rf "$(OUTDIR)" rootfs.done

install:
	sudo cp $(REPO) $(IMG).xz /var/www/html/sh-image

