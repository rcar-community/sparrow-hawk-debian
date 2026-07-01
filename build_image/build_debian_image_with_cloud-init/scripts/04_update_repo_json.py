#!/usr/bin/env python3
import json
import hashlib
import os
import sys
import tempfile
import subprocess
from datetime import datetime

# Usage:
#   python3 scripts/04_update_repo_json.sh <image_xz_path> <repo_json_path> <image_url> [<icon_url>]
#
# Example:
#   python3 scripts/04_update_repo_json.sh out/myos.img.xz out/repo.json \
#     https://example.com/images/myos.img.xz \
#     https://example.com/icons/myos.png

xz_path = sys.argv[1]
repo_path = sys.argv[2]
image_url = sys.argv[3]
icon_url = sys.argv[4] if len(sys.argv) >= 5 else "https://example.com/icons/myos.png"

def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def xz_decompress_to_temp_img(xz_file: str) -> str:
    """
    Decompress .img.xz into a temporary .img file using system 'xz'.
    Returns the temp file path. Caller must delete it.
    """
    # Create temp file (we want a path, not an already-open fd, to let xz write it)
    fd, tmp_img = tempfile.mkstemp(prefix="imager_extract_", suffix=".img")
    os.close(fd)

    # xz -dc input.xz > tmp_img
    # Use -T0 for parallel threads if supported; harmless if not.
    cmd = ["xz", "-dc", xz_file]
    with open(tmp_img, "wb") as out:
        subprocess.run(cmd, check=True, stdout=out)

    return tmp_img

# ---- Compressed download metadata (.img.xz) ----
image_download_size = os.path.getsize(xz_path)
image_download_sha256 = sha256_file(xz_path)

# ---- Extracted image metadata (temporary .img) ----
tmp_img = None
try:
    tmp_img = xz_decompress_to_temp_img(xz_path)
    extract_size = os.path.getsize(tmp_img)
    extract_sha256 = sha256_file(tmp_img)
finally:
    if tmp_img and os.path.exists(tmp_img):
        try:
            os.remove(tmp_img)
        except Exception:
            pass

# ? release_date = script run date (local)
release_date = datetime.now().date().isoformat()

# ---- Device profiles (Pi4 + Pi5 + no filtering) ----
imager_block = {
    "latest_version": "2.0.0",
    "url": "https://www.raspberrypi.com/software/",
    "devices": [
        {
            "name": "No filtering",
            "tags": ["all"],
            "default": True,
            "matching_type": "inclusive",
            "description": "Show all images without filtering"
        },
        {
            "name": "Sparrow Hawk 8GB/16GB",
            "icon": icon_url.replace("sh-mascot","sh"),
            "tags": ["sh"],
            "matching_type": "exclusive",
            "description": "Retronix SparrowHawk (R-Car V4H)"
        },
    ]
}

# ---- OS entry ----
os_entry = {
    "name": "SparrowHawk Debian based OS",
    "description": "Debian based rootfs + cloud-init",
    "icon": icon_url,
    "url": image_url,
    "release_date": release_date,
    "init_format": "cloudinit",

    # Pi4/Pi5 + no-filter
    "devices": ["sh", "all"],

    # compressed file metadata
    "image_download_size": image_download_size,
    "image_download_sha256": image_download_sha256,

    # extracted image metadata (for accurate writing progress/validation)
    "extract_size": extract_size,
    "extract_sha256": extract_sha256
}

repo = {
    "imager": imager_block,
    "os_list": [os_entry]
}

os.makedirs(os.path.dirname(repo_path) or ".", exist_ok=True)
with open(repo_path, "w", encoding="utf-8") as f:
    json.dump(repo, f, ensure_ascii=False, indent=2)
    f.write("\n")

print(f"Wrote: {repo_path}")
print(f"release_date: {release_date}")
print(f"image_download_size: {image_download_size}")
print(f"image_download_sha256: {image_download_sha256}")
print(f"extract_size: {extract_size}")
print(f"extract_sha256: {extract_sha256}")

