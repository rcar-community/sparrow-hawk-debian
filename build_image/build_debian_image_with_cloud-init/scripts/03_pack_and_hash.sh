#!/usr/bin/env bash
set -euo pipefail
IMG="$1"

xz -T0 -9 "$IMG"   # out/*.img.xz を作る
