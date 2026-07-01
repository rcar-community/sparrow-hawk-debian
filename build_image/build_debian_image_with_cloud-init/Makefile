SHELL := /bin/bash
ARCH ?= arm64
SUITE ?= trixie
MIRROR ?= http://deb.debian.org/debian

NAME ?= sparrowhawk
DATE := $(shell date +%Y%m%d)
OUTDIR := out
ROOTFS := $(OUTDIR)/rootfs
IMG := $(OUTDIR)/$(NAME)-$(SUITE)-$(ARCH)-$(DATE).img
XZ := $(IMG).xz
REPO := $(OUTDIR)/repo.json

SIZE_GIB ?= 4
BOOT_MIB ?= 512

.PHONY: all clean rootfs repo

all: $(REPO)

rootfs.done:
	rm -f rootfs.done
	-mkdir $(OUTDIR)
	sudo scripts/01_build_rootfs.sh "$(ARCH)" "$(SUITE)" "$(MIRROR)" "$(ROOTFS)" && touch rootfs.done

$(IMG).xz: rootfs.done
	sudo scripts/02_make_disk_image.sh "$(ROOTFS)" "$(IMG)" "$(SIZE_GIB)" "$(BOOT_MIB)" 
	sudo scripts/03_pack_and_hash.sh "$(IMG)"

$(REPO): $(IMG).xz
	python3 scripts/04_update_repo_json.py "$(XZ)" "$(REPO)" \
		"https://github.com/yhamamachi/apt-repo-test/releases/download/binary_release/$(notdir $(XZ))" \
		"https://github.com/yhamamachi/apt-repo-test/releases/download/binary_release/sh-mascot.png"

clean:
	sudo rm -rf "$(OUTDIR)" rootfs.done

install:
	sudo cp $(REPO) $(IMG).xz /var/www/html/sh-image

github_release: $(IMG).xz ${REPO}
	gh release create binary_release --title "Image Release" --prerelease -n "Release" \
		$(IMG).xz ${REPO} images/sh-mascot.png images/sh.png

