SHELL := /bin/bash
ARCH ?= arm64
SUITE ?= trixie
MIRROR ?= http://deb.debian.org/debian

NAME ?= sparrowhawk
REPO_OWNER := $(shell git remote -v | grep origin | head -1 | sed -e 's/.*github\.com[:/]//' -e 's/\/.*//')
DATE := $(shell date +%Y%m%d)
OUTDIR := out

# Desktop environment to install (ex. "make image DESKTOP=xfce").
# Empty means the headless image.
DESKTOP ?=
ifeq ($(DESKTOP),)
SUFFIX :=
SIZE_GIB ?= 4
else
SUFFIX := -$(DESKTOP)
SIZE_GIB ?= 8
endif

ROOTFS := $(OUTDIR)/rootfs$(SUFFIX)
IMG := $(OUTDIR)/$(NAME)-$(SUITE)$(SUFFIX)-$(ARCH)-$(DATE).img
XZ := $(IMG).xz
REPO := $(OUTDIR)/repo.json
# Images listed in repo.json (headless + desktop variants)
DESKTOPS ?= xfce
XZ_HEADLESS := $(OUTDIR)/$(NAME)-$(SUITE)-$(ARCH)-$(DATE).img.xz
XZ_DESKTOPS := $(foreach d,$(DESKTOPS),$(OUTDIR)/$(NAME)-$(SUITE)-$(d)-$(ARCH)-$(DATE).img.xz)
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

rootfs$(SUFFIX).done:
	rm -f rootfs$(SUFFIX).done
	-mkdir $(OUTDIR)
	sudo env DESKTOP="$(DESKTOP)" scripts/01_build_rootfs.sh "$(ARCH)" "$(SUITE)" "$(MIRROR)" "$(ROOTFS)" && touch rootfs$(SUFFIX).done

$(IMG).xz: rootfs$(SUFFIX).done
	sudo scripts/02_make_disk_image.sh "$(ROOTFS)" "$(IMG)" "$(SIZE_GIB)" "$(BOOT_MIB)"
	sudo scripts/03_pack_and_hash.sh "$(IMG)"

# repo.json lists the headless image and the desktop images. The desktop
# images are built by "make image DESKTOP=<name>" and are listed only if exist.
$(REPO): $(XZ_HEADLESS)
	python3 scripts/04_update_repo_json.py "$(REPO)" \
		"$(RELEASE_URL)/sh-mascot.png" \
		"$(XZ_HEADLESS)" "$(RELEASE_URL)/$(notdir $(XZ_HEADLESS))" "" \
		$(foreach x,$(wildcard $(XZ_DESKTOPS)),"$(x)" "$(RELEASE_URL)/$(notdir $(x))" "$(patsubst $(OUTDIR)/$(NAME)-$(SUITE)-%-$(ARCH)-$(DATE).img.xz,%,$(x))")

repo: $(REPO)

clean:
	sudo rm -rf "$(OUTDIR)" rootfs*.done

install:
	sudo cp $(REPO) $(IMG).xz /var/www/html/sh-image

