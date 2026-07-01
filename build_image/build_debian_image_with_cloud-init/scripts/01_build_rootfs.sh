#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# 01_build_rootfs.sh (mmdebstrap edition)
#
# Purpose:
#   - Build a Debian/Ubuntu-like rootfs directory using mmdebstrap
#   - Install packages listed in config/packages.base.txt via --include
#   - Configure cloud-init NoCloud to read seeds from /boot (Imager 2.0 style)
#   - Optionally generate locale (ja_JP.UTF-8 by default) to avoid locale warnings
#   - Optionally apply overlay/ directory into rootfs
#
# Usage:
#   sudo scripts/01_build_rootfs.sh <arch> <suite> <mirror> <rootfs_dir> [packages_file]
#
# Example:
#   sudo scripts/01_build_rootfs.sh arm64 bookworm http://deb.debian.org/debian out/rootfs
#
# Notes:
#   - mmdebstrap CLI: mmdebstrap [OPTION...] [SUITE [TARGET [MIRROR...]]]
#   - --include accepts comma or whitespace separated package list.
#   - --customize-hook runs after packages installed, before final cleanup.
#   - --architectures controls native/foreign architectures in the chroot.
# -----------------------------------------------------------------------------

ARCH="${1:-}"
SUITE="${2:-}"
MIRROR="${3:-}"
ROOTFS="${4:-}"
PKG_FILE="${5:-config/packages.base.txt}"

# Optional knobs (env):
: "${COMPONENTS:=main,contrib}"          # used when MIRROR is a URI-only mirror
: "${VARIANT:=standard}"          # typical for minimal rootfs
: "${MODE:=auto}"                # mmdebstrap mode: auto/sudo/root/unshare/...
: "${ENABLE_LOCALE:=1}"          # 1: generate locale, 0: skip
: "${DEFAULT_LOCALE:=ja_JP.UTF-8}"
: "${OVERLAY:=1}"                # 1: apply overlay/, 0: skip
: "${CLOUDINIT_CFG:=1}"          # 1: install cloud-init NoCloud config, 0: skip
: "${APT_CLEAN:=1}"              # 1: clean apt cache in chroot (smaller rootfs)

if [[ -z "${ARCH}" || -z "${SUITE}" || -z "${MIRROR}" || -z "${ROOTFS}" ]]; then
  echo "ERROR: Missing arguments."
  echo "Usage: sudo $0 <arch> <suite> <mirror> <rootfs_dir> [packages_file]"
  exit 1
fi

if [[ ! -f "${PKG_FILE}" ]]; then
  echo "ERROR: packages file not found: ${PKG_FILE}"
  exit 1
fi

if ! command -v mmdebstrap >/dev/null 2>&1; then
  echo "ERROR: mmdebstrap not found. Install it first (e.g. apt install mmdebstrap)."
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

CLOUD_CFG_90="${PROJ_ROOT}/config/cloud/90-datasource.cfg"
CLOUD_CFG_91="${PROJ_ROOT}/config/cloud/91-nocloud.cfg"
OVERLAY_DIR="${PROJ_ROOT}/overlay"

# Convert packages.base.txt -> whitespace-separated list (strip comments/blank lines)
# mmdebstrap --include supports comma OR whitespace separated lists.  (manpage) 
PKGS="$(sed -e 's/#.*$//' -e '/^[[:space:]]*$/d' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
       "${PKG_FILE}" | tr '\n' ' ')"

# Safety: refuse empty package list (usually means file formatting issue)
if [[ -z "${PKGS// }" ]]; then
  echo "ERROR: package list is empty after filtering: ${PKG_FILE}"
  exit 1
fi

# Prepare output directory
mkdir -p "$(dirname "${ROOTFS}")"

# If target exists, mmdebstrap may refuse unless skipped; we choose to wipe it here.
if [[ -e "${ROOTFS}" ]]; then
  echo "INFO: Removing existing target: ${ROOTFS}"
  rm -rf "${ROOTFS}"
fi

# Build customize hooks
CUSTOMIZE_HOOKS=()

# 1) cloud-init NoCloud config (read seed from /boot)
if [[ "${CLOUDINIT_CFG}" == "1" ]]; then
  if [[ -f "${CLOUD_CFG_90}" ]]; then
    CUSTOMIZE_HOOKS+=("--customize-hook=install -D -m 0644 '${CLOUD_CFG_90}' \"\$1/etc/cloud/cloud.cfg.d/90-datasource.cfg\"")
  else
    echo "WARN: ${CLOUD_CFG_90} not found; skipping NoCloud datasource_list pin."
  fi

  if [[ -f "${CLOUD_CFG_91}" ]]; then
    CUSTOMIZE_HOOKS+=("--customize-hook=install -D -m 0644 '${CLOUD_CFG_91}' \"\$1/etc/cloud/cloud.cfg.d/91-nocloud.cfg\"")
  else
    echo "WARN: ${CLOUD_CFG_91} not found; skipping NoCloud seedfrom config."
  fi
fi

# 2) locale generation (fix invalid locale warnings)
# We do it in customize-hook so that locales package is already available if included.
if [[ "${ENABLE_LOCALE}" == "1" ]]; then
  # Generate DEFAULT_LOCALE and set as default locale.
  # Use LANG=C during generation to keep tools quiet/stable.
  CUSTOMIZE_HOOKS+=("--customize-hook=chroot \"\$1\" bash -lc 'set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive
    command -v locale-gen >/dev/null 2>&1 || apt-get update && apt-get install -y --no-install-recommends locales
    sed -i \"s/^# *${DEFAULT_LOCALE} UTF-8/${DEFAULT_LOCALE} UTF-8/\" /etc/locale.gen || true
    locale-gen ${DEFAULT_LOCALE}
    update-locale LANG=${DEFAULT_LOCALE} LC_CTYPE=${DEFAULT_LOCALE} LC_MESSAGES=${DEFAULT_LOCALE}
  '")
fi

# 3) enable systemd units (cloud-init + ssh)
CUSTOMIZE_HOOKS+=("--customize-hook=chroot \"\$1\" bash -lc 'set -euo pipefail
  systemctl enable cloud-init cloud-init-local cloud-config cloud-final 2>/dev/null || true
  systemctl enable ssh 2>/dev/null || true
'")

# 4) Apply overlay/
if [[ "${OVERLAY}" == "1" && -d "${OVERLAY_DIR}" ]]; then
  CUSTOMIZE_HOOKS+=("--customize-hook=rsync -aHAX --numeric-ids '${OVERLAY_DIR}/' \"\$1/\"")
fi

# 5) Setup sparrow hawk package
CUSTOMIZE_HOOKS+=("--customize-hook=chroot \"\$1\" bash -lc 'set -euo pipefail
  export DEBIAN_FRONTEND=noninteractive
  echo \"deb [trusted=yes] https://yhamamachi.github.io/apt-repo/ bookworm main\" > /etc/apt/sources.list.d/sparrow-hawk.list
  apt-get update && apt-get install -y sparrow-hawk-bsp
'")

# 6) apt cleanup
if [[ "${APT_CLEAN}" == "1" ]]; then
  CUSTOMIZE_HOOKS+=("--customize-hook=chroot \"\$1\" bash -lc 'apt-get clean || true; rm -rf /var/lib/apt/lists/* || true'")
fi

# 7) Network setup
CUSTOMIZE_HOOKS+=("--customize-hook=chroot \"\$1\" bash -lc 'set -euo pipefail
  mkdir -p /boot
  cat > /etc/netplan/99-end0.yaml <<EOF
network:
  version: 2
  ethernets:
    end0:
      dhcp4: true
      dhcp6: true
      optional: true
EOF
'")

echo "=== mmdebstrap build parameters ==="
echo "ARCH       : ${ARCH}"
echo "SUITE      : ${SUITE}"
echo "MIRROR     : ${MIRROR}"
echo "TARGET     : ${ROOTFS}"
echo "VARIANT    : ${VARIANT}"
echo "MODE       : ${MODE}"
echo "COMPONENTS : ${COMPONENTS}"
echo "PKG_FILE   : ${PKG_FILE}"
echo "INCLUDE_PKGS (filtered): ${PKGS}"
echo "==================================="

# Run mmdebstrap
# Key options used:
#   --variant=...        choose minimal package set
#   --mode=...           how to create chroot (auto/root/unshare/...)
#   --components=...     components for URI-only mirror
#   --architectures=...  native architecture in chroot
#   --include=...        additional packages list
#   --customize-hook=... post-install customization (runs with $1 = chroot dir)
#
mmdebstrap \
  --variant="${VARIANT}" \
  --mode="${MODE}" \
  --components="${COMPONENTS}" \
  --architectures="${ARCH}" \
  --include="${PKGS}" \
  "${CUSTOMIZE_HOOKS[@]}" \
  "${SUITE}" \
  "${ROOTFS}" \
  "${MIRROR}"

echo "DONE: rootfs built at ${ROOTFS}"
